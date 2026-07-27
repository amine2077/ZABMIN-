import logging
import threading
import time
from concurrent.futures import ThreadPoolExecutor
from concurrent.futures import TimeoutError as FuturesTimeout
from dataclasses import dataclass, replace

logger = logging.getLogger(__name__)


@dataclass
class CollectorResult:
    name: str
    ok: bool
    data: dict | list | None
    duration_ms: float
    stale: bool = False
    cached: bool = False
    error: str | None = None


@dataclass
class CollectorHealth:
    name: str
    last_ok: float | None = None
    last_error: float | None = None
    last_duration_ms: float = 0.0
    timeout_count: int = 0
    error_count: int = 0
    stale: bool = False


@dataclass
class CollectorSpec:
    name: str
    fn: callable
    timeout_seconds: float = 1.0
    cache_ttl_seconds: float = 0.0
    with_com: bool = False
    critical: bool = False


TOTAL_BROADCAST_BUDGET = 1.5


class _COMWorker:
    def __init__(self, fn):
        self._fn = fn

    def __call__(self):
        _com_initialized = False
        try:
            import pythoncom

            pythoncom.CoInitializeEx(0)
            _com_initialized = True
        except Exception:
            pass
        try:
            return self._fn()
        finally:
            if _com_initialized:
                try:
                    import pythoncom

                    pythoncom.CoUninitialize()
                except Exception:
                    pass


class CollectorRunner:
    def __init__(self, specs: list[CollectorSpec]):
        self._specs = {s.name: s for s in specs}
        self._health: dict[str, CollectorHealth] = {}
        self._cache: dict[str, tuple[float, CollectorResult]] = {}
        self._last_good: dict[str, CollectorResult] = {}
        self._broadcast_count = 0
        self._executor = ThreadPoolExecutor(max_workers=len(specs) + 1)
        self._in_flight: dict[str, object] = {}
        self._lock = threading.Lock()
        for s in specs:
            self._health[s.name] = CollectorHealth(name=s.name)

    def _submit_collector(self, name: str, spec: CollectorSpec):
        wrapped = _COMWorker(spec.fn) if spec.with_com else spec.fn
        return self._executor.submit(wrapped)

    def collect_all(self) -> dict[str, CollectorResult]:
        self._broadcast_count += 1
        now = time.monotonic()
        results: dict[str, CollectorResult] = {}
        submitted: dict[str, tuple[object, CollectorSpec, float]] = {}

        for name, spec in self._specs.items():
            cached_entry = self._cache.get(name)
            if cached_entry is not None:
                cached_time, cached_result = cached_entry
                if (now - cached_time) < spec.cache_ttl_seconds:
                    results[name] = replace(cached_result, cached=True)
                    continue

            with self._lock:
                fut = self._in_flight.get(name)

            if fut is not None and fut.done():
                with self._lock:
                    if name in self._in_flight and self._in_flight[name] is fut:
                        del self._in_flight[name]
                fut = None

            if fut is not None:
                stale = self._last_good.get(name)
                if stale is not None:
                    results[name] = replace(stale, stale=True)
                else:
                    results[name] = CollectorResult(
                        name=name,
                        ok=False,
                        data=None,
                        duration_ms=0,
                        stale=True,
                        error="in_flight",
                    )
                continue

            if cached_entry is not None and spec.cache_ttl_seconds > 0:
                stale = self._last_good.get(name)
                if stale is not None:
                    results[name] = replace(stale, stale=True)
                fut = self._submit_collector(name, spec)
                with self._lock:
                    self._in_flight[name] = fut
                continue

            t0 = time.monotonic()
            fut = self._submit_collector(name, spec)
            with self._lock:
                self._in_flight[name] = fut
            submitted[name] = (fut, spec, t0)

        deadline = time.monotonic() + TOTAL_BROADCAST_BUDGET
        for name, (fut, spec, t0) in submitted.items():
            remaining = max(
                0.01, min(spec.timeout_seconds, deadline - time.monotonic())
            )
            try:
                data = fut.result(timeout=remaining)
                elapsed = (time.monotonic() - t0) * 1000
                result = CollectorResult(
                    name=name,
                    ok=True,
                    data=data,
                    duration_ms=round(elapsed, 1),
                )
                results[name] = result
                self._last_good[name] = result
                if spec.cache_ttl_seconds > 0:
                    self._cache[name] = (t0, result)
                h = self._health[name]
                h.last_ok = time.time()
                h.last_duration_ms = elapsed
                h.timeout_count = 0
                h.error_count = 0
                h.stale = False
            except FuturesTimeout:
                elapsed = (time.monotonic() - t0) * 1000
                h = self._health[name]
                h.timeout_count += 1
                h.last_duration_ms = elapsed
                h.stale = True
                stale = self._last_good.get(name)
                if stale is not None:
                    results[name] = replace(stale, stale=True)
                    logger.warning(f"Collector {name} timed out, using stale")
                else:
                    results[name] = CollectorResult(
                        name=name,
                        ok=False,
                        data=None,
                        duration_ms=round(elapsed, 1),
                        stale=True,
                        error="timeout",
                    )
                    logger.warning(f"Collector {name} timed out, no stale available")
            except Exception as e:
                elapsed = (time.monotonic() - t0) * 1000
                h = self._health[name]
                h.last_error = time.time()
                h.error_count += 1
                h.last_duration_ms = elapsed
                h.stale = True
                logger.warning(f"Collector {name} failed: {e}")
                stale = self._last_good.get(name)
                if stale is not None:
                    results[name] = replace(stale, stale=True)
                else:
                    results[name] = CollectorResult(
                        name=name,
                        ok=False,
                        data=None,
                        duration_ms=round(elapsed, 1),
                        stale=True,
                        error=str(e),
                    )
            finally:
                with self._lock:
                    if name in self._in_flight and self._in_flight[name] is fut:
                        del self._in_flight[name]

        if self._broadcast_count >= 10:
            self._broadcast_count = 0
            self._log_health_summary(results)

        return results

    def _log_health_summary(self, results: dict[str, CollectorResult]):
        parts = []
        for name, r in results.items():
            tag = "ok"
            if r.stale:
                tag = "stale"
            if r.cached:
                tag = "cached"
            if r.error and r.stale:
                tag = "timeout" if "timeout" in r.error else "error"
            parts.append(f"{name}={tag}/{r.duration_ms:.0f}ms")
        logger.info(f"collector_health {' '.join(parts)}")

    def get_health(self, name: str) -> CollectorHealth | None:
        return self._health.get(name)

    def get_all_health(self) -> dict[str, CollectorHealth]:
        return dict(self._health)

    def shutdown(self):
        with self._lock:
            self._in_flight.clear()
        self._executor.shutdown(wait=False, cancel_futures=True)
