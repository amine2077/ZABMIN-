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
    background: bool = False
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
    background_refresh: bool = False
    refresh_interval_seconds: float = 1.0


FIRST_STARTUP_BUDGET = 2.5
STEADY_STATE_BUDGET = 0.9


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


class _RefreshState:
    __slots__ = ("refresh_time", "running")

    def __init__(self):
        self.refresh_time = 0.0
        self.running = False


class CollectorRunner:
    def __init__(self, specs: list[CollectorSpec]):
        self._specs = {s.name: s for s in specs}
        self._health: dict[str, CollectorHealth] = {}
        self._cache: dict[str, tuple[float, CollectorResult]] = {}
        self._last_good: dict[str, CollectorResult] = {}
        self._broadcast_count = 0
        self._executor = ThreadPoolExecutor(max_workers=len(specs) + 1)
        self._in_flight: dict[str, object] = {}
        self._in_flight_started: dict[str, float] = {}
        self._refresh_state: dict[str, _RefreshState] = {}
        self._lock = threading.Lock()
        for s in specs:
            self._health[s.name] = CollectorHealth(name=s.name)
            self._refresh_state[s.name] = _RefreshState()

    def _compute_budget(self) -> float:
        for name, spec in self._specs.items():
            if spec.background_refresh and name not in self._last_good:
                return FIRST_STARTUP_BUDGET
        return STEADY_STATE_BUDGET

    def _submit_collector(self, name: str, spec: CollectorSpec):
        wrapped = _COMWorker(spec.fn) if spec.with_com else spec.fn
        return self._executor.submit(wrapped)

    def _consume_completed_futures(self):
        now = time.monotonic()
        with self._lock:
            for name in list(self._in_flight.keys()):
                fut = self._in_flight.get(name)
                if fut is None:
                    continue
                if not fut.done():
                    spec = self._specs.get(name)
                    started = self._in_flight_started.get(name, now)
                    stuck_timeout = (
                        max(spec.timeout_seconds * 3, 10.0) if spec else 10.0
                    )
                    if (now - started) > stuck_timeout:
                        logger.warning(
                            f"Discarding stuck future for {name} "
                            f"after {now - started:.1f}s"
                        )
                        del self._in_flight[name]
                        self._in_flight_started.pop(name, None)
                        rs = self._refresh_state.get(name)
                        if rs:
                            rs.running = False
                    continue
                try:
                    data = fut.result(timeout=0)
                    result = CollectorResult(
                        name=name, ok=True, data=data, duration_ms=0, background=True
                    )
                    self._last_good[name] = result
                    spec = self._specs.get(name)
                    if spec and spec.cache_ttl_seconds > 0:
                        self._cache[name] = (time.monotonic(), result)
                    h = self._health[name]
                    h.last_ok = time.time()
                    h.last_duration_ms = 0
                    h.timeout_count = 0
                    h.error_count = 0
                    h.stale = False
                except Exception as e:
                    logger.warning(f"Background future {name} failed: {e}")
                    h = self._health[name]
                    h.last_error = time.time()
                    h.error_count += 1
                    h.stale = True
                del self._in_flight[name]
                self._in_flight_started.pop(name, None)
                rs = self._refresh_state.get(name)
                if rs:
                    rs.running = False

    def collect_all(self) -> dict[str, CollectorResult]:
        self._broadcast_count += 1
        now = time.monotonic()
        results: dict[str, CollectorResult] = {}
        submitted: dict[str, tuple[object, CollectorSpec, float]] = {}

        self._consume_completed_futures()

        for name, spec in self._specs.items():
            cached_entry = self._cache.get(name)
            if cached_entry is not None:
                cached_time, cached_result = cached_entry
                if (now - cached_time) < spec.cache_ttl_seconds:
                    results[name] = replace(cached_result, cached=True)
                    continue

            if spec.background_refresh:
                stale = self._last_good.get(name)
                if stale is not None:
                    results[name] = replace(stale, stale=True)
                    rs = self._refresh_state[name]
                    if rs.running:
                        continue
                    if (now - rs.refresh_time) >= spec.refresh_interval_seconds:
                        with self._lock:
                            if name not in self._in_flight:
                                fut = self._submit_collector(name, spec)
                                self._in_flight[name] = fut
                                self._in_flight_started[name] = time.monotonic()
                                rs.refresh_time = now
                                rs.running = True
                    continue

            with self._lock:
                fut = self._in_flight.get(name)

            if fut is not None and fut.done():
                with self._lock:
                    if name in self._in_flight and self._in_flight[name] is fut:
                        del self._in_flight[name]
                        self._in_flight_started.pop(name, None)
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
                with self._lock:
                    if name not in self._in_flight:
                        fut = self._submit_collector(name, spec)
                        self._in_flight[name] = fut
                        self._in_flight_started[name] = time.monotonic()
                continue

            t0 = time.monotonic()
            fut = self._submit_collector(name, spec)
            with self._lock:
                self._in_flight[name] = fut
                self._in_flight_started[name] = t0
            submitted[name] = (fut, spec, t0)

        budget = self._compute_budget()
        deadline = time.monotonic() + budget
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
                    if (
                        name in self._in_flight
                        and self._in_flight[name] is fut
                        and fut.done()
                    ):
                        del self._in_flight[name]
                        self._in_flight_started.pop(name, None)

        if self._broadcast_count >= 10:
            self._broadcast_count = 0
            self._log_health_summary(results)

        return results

    def _log_health_summary(self, results: dict[str, CollectorResult]):
        parts = []
        for name, r in results.items():
            if r.stale:
                tag = "stale"
            elif r.cached:
                tag = "cached"
            elif r.background:
                tag = "background"
            elif r.error:
                tag = "error"
            else:
                tag = "ok"
            parts.append(f"{name}={tag}/{r.duration_ms:.0f}ms")
        logger.info(f"collector_health {' '.join(parts)}")

    def get_health(self, name: str) -> CollectorHealth | None:
        return self._health.get(name)

    def get_all_health(self) -> dict[str, CollectorHealth]:
        return dict(self._health)

    def shutdown(self):
        with self._lock:
            for name in list(self._in_flight.keys()):
                rs = self._refresh_state.get(name)
                if rs:
                    rs.running = False
            self._in_flight.clear()
            self._in_flight_started.clear()
        self._executor.shutdown(wait=False, cancel_futures=True)
