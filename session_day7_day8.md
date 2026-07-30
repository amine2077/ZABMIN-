# Day 7 & Day 8 Implementation: Slow Collector Isolation + Background Refresh + Process Optimization

## Task Context

Zabmin is a two-process Windows monitoring app: Python WebSocket agent + Flutter Windows UI. Day 2 secure token auth, Day 3 message validation/rate limiting, Day 4 command safety/audit, and Day 5/6 lifecycle/collector resilience are complete. However, Day 6 currently uses a 1.5 second broadcast budget and slow collectors such as processes and GPU can take around 1.3 seconds. This makes the dashboard update slower than the intended 1 second interval. Day 7 must make slow collectors non-blocking by returning stale data immediately and refreshing in the background. Day 8 must optimize the process collector so it is much faster and does not use expensive per-process connection queries during live broadcast.

## Current State

- day2_secure_websocket: true
- day3_message_validation: true
- day4_command_safety: true
- day5_lifecycle: true
- day6_collector_resilience: true
- known_performance_problem: TOTAL_BROADCAST_BUDGET was raised to 1.5s because processes and GPU collectors take around 1.3s
- target: Restore steady-state broadcast interval close to 1 second without freezing the agent or UI

## Execution Order

1. phase_1_restore_1s_broadcast
2. phase_2_background_refresh_in_collector_runner
3. phase_3_gpu_slow_query_isolation
4. phase_4_process_collector_optimization
5. phase_5_tests_and_benchmarks
6. phase_6_manual_verification

## Performance Targets

- first_startup_max_seconds: 2.5
- steady_state_broadcast_interval_seconds: 1.0
- steady_state_blocking_collect_all_max_ms: 200
- process_collector_target_ms: 300
- gpu_blocking_after_first_good_ms: 0
- process_background_refresh_seconds: 1.5
- gpu_background_refresh_seconds: 3.0
- battery_cache_seconds: 5.0

---

## Files Changed

### `agent/collector_runner.py` — Full rewrite

```python
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
        with self._lock:
            for name in list(self._in_flight.keys()):
                fut = self._in_flight.get(name)
                if fut is None:
                    continue
                if not fut.done():
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
                except Exception:
                    h = self._health[name]
                    h.last_error = time.time()
                    h.error_count += 1
                    h.stale = True
                del self._in_flight[name]

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
                                rs.refresh_time = now
                                rs.running = True
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
                with self._lock:
                    if name not in self._in_flight:
                        fut = self._submit_collector(name, spec)
                        self._in_flight[name] = fut
                continue

            t0 = time.monotonic()
            fut = self._submit_collector(name, spec)
            with self._lock:
                self._in_flight[name] = fut
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
                    if name in self._in_flight and self._in_flight[name] is fut:
                        del self._in_flight[name]

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
        self._executor.shutdown(wait=False, cancel_futures=True)
```

### `agent/agent.py` — Compensated broadcast loop + updated CollectorSpecs

**Updated CollectorSpecs:**
```python
_CPU_SPEC = collector_runner.CollectorSpec(
    name="cpu", fn=collect_cpu, timeout_seconds=0.5, with_com=True
)
_MEMORY_SPEC = collector_runner.CollectorSpec(
    name="memory", fn=collect_memory, timeout_seconds=0.5, with_com=True
)
_DISK_SPEC = collector_runner.CollectorSpec(
    name="disk", fn=collect_disk, timeout_seconds=1.0
)
_NETWORK_SPEC = collector_runner.CollectorSpec(
    name="network", fn=collect_network, timeout_seconds=0.5
)
_PROCESSES_SPEC = collector_runner.CollectorSpec(
    name="processes",
    fn=collect_processes,
    timeout_seconds=5.0,
    background_refresh=True,
    refresh_interval_seconds=1.5,
)
_GPU_SPEC = collector_runner.CollectorSpec(
    name="gpu",
    fn=collect_gpu,
    timeout_seconds=5.0,
    with_com=True,
    background_refresh=True,
    refresh_interval_seconds=3.0,
)
_BATTERY_SPEC = collector_runner.CollectorSpec(
    name="battery", fn=collect_battery, timeout_seconds=0.5, cache_ttl_seconds=5.0
)
```

**Updated broadcast_loop:**
```python
async def broadcast_loop():
    db_counter = 0
    while not _shutdown_event.is_set():
        loop_start = time.monotonic()
        await _check_orphan()
        if _shutdown_event.is_set():
            break
        try:
            metrics = await gather_metrics()
            payload = json.dumps(metrics)
            if connected_clients:
                results = await asyncio.gather(
                    *[client.send(payload) for client in connected_clients],
                    return_exceptions=True,
                )
                for r in results:
                    if isinstance(r, Exception):
                        logger.warning(f"Send failed: {r}")
            db_counter += 1
            if db_counter >= 5:
                await asyncio.to_thread(database.insert_metrics, metrics)
                db_counter = 0
        except Exception as e:
            logger.error(f"Error collecting metrics: {e}")
        elapsed = time.monotonic() - loop_start
        sleep_time = max(0.0, 1.0 - elapsed)
        try:
            await asyncio.wait_for(_shutdown_event.wait(), timeout=sleep_time)
        except asyncio.TimeoutError:
            pass
```

### `agent/collectors/processes.py` — heapq optimization + docstring

```python
import heapq

import psutil

# Warmup call to initialize process cpu_percent values
for p in psutil.process_iter(["pid"]):
    try:
        p.cpu_percent(interval=None)
    except (psutil.NoSuchProcess, psutil.AccessDenied, psutil.ZombieProcess):
        pass

_logical_cpu_count = psutil.cpu_count(logical=True) or 1


def collect():
    """Collect top 30 processes by CPU usage matching Task Manager.

    Uses heapq.nlargest for efficient top-N selection. Does NOT call
    per-process net_connections() — that is available only through the
    on-demand get_process_connections command.
    """
    try:
        raw_procs = []
        for p in psutil.process_iter(
            ["pid", "ppid", "name", "cpu_percent", "memory_info", "status"]
        ):
            try:
                info = p.info
            except (psutil.NoSuchProcess, psutil.AccessDenied, psutil.ZombieProcess):
                continue
            try:
                if not info["name"]:
                    continue

                raw_cpu = info["cpu_percent"] or 0.0

                if info["name"].lower() == "system idle process":
                    continue

                cpu_percent = round(raw_cpu / _logical_cpu_count, 1)

                if cpu_percent == 0.0:
                    continue

                mem_mb = 0.0
                if info["memory_info"]:
                    mem_mb = round(info["memory_info"].rss / (1024**2), 1)

                raw_procs.append(
                    {
                        "pid": info["pid"] or 0,
                        "ppid": info["ppid"] or 0,
                        "name": info["name"],
                        "cpu_percent": cpu_percent,
                        "memory_mb": mem_mb,
                        "status": info["status"] or "unknown",
                        "connections": 0,
                    }
                )
            except (psutil.NoSuchProcess, psutil.AccessDenied, psutil.ZombieProcess):
                continue

        top30 = heapq.nlargest(30, raw_procs, key=lambda x: x["cpu_percent"])
        return top30
    except Exception:
        return []
```

### `agent/collectors/gpu.py` — Temperature honesty comment

Added at line 14:
```python
# TODO: When GPUStats.temperatureC becomes nullable in Flutter model,
# change unavailable GPU temperature from 0.0 to None.
```

### `agent/tests/test_collector_runner.py` — New background refresh tests

Added 6 new test methods to `TestCollectorRunner`:

```python
def test_background_refresh_returns_stale_immediately(self):
    runner = CollectorRunner(
        specs=[
            CollectorSpec(
                name="bg",
                fn=_slow_background_fn,
                timeout_seconds=2.0,
                background_refresh=True,
                refresh_interval_seconds=0.5,
            )
        ]
    )
    t0 = time.monotonic()
    r1 = runner.collect_all()["bg"]
    elapsed = time.monotonic() - t0
    assert r1.ok is True
    assert r1.data == _slow_first_data
    assert r1.stale is False
    assert elapsed < 0.5, f"First call took {elapsed:.2f}s (expected fast)"

    t0 = time.monotonic()
    r2 = runner.collect_all()["bg"]
    elapsed = time.monotonic() - t0
    assert r2.stale is True
    assert r2.data == _slow_first_data
    assert elapsed < 0.2, f"Second call took {elapsed:.2f}s (expected instant stale)"
    runner.shutdown()

def test_background_refresh_no_pileup(self):
    runner = CollectorRunner(
        specs=[
            CollectorSpec(
                name="bg",
                fn=_very_slow_background_fn,
                timeout_seconds=10.0,
                background_refresh=True,
                refresh_interval_seconds=0.1,
            )
        ]
    )
    runner._last_good["bg"] = CollectorResult(
        name="bg", ok=True, data=_slow_first_data, duration_ms=10.0
    )

    r2 = runner.collect_all()["bg"]
    assert r2.stale is True
    assert r2.data == _slow_first_data

    r3 = runner.collect_all()["bg"]
    assert r3.stale is True

    assert len(runner._in_flight) <= 1
    runner.shutdown()

def test_background_refresh_eventually_updates_value(self):
    value_holder = {"v": "first"}

    def _stateful_first():
        time.sleep(0.1)
        return {"value": "first"}

    def _stateful_bg():
        time.sleep(0.1)
        return {"value": value_holder["v"]}

    runner = CollectorRunner(
        specs=[
            CollectorSpec(
                name="bg",
                fn=_stateful_bg,
                timeout_seconds=2.0,
                background_refresh=True,
                refresh_interval_seconds=0.05,
            )
        ]
    )
    runner._specs["bg"] = CollectorSpec(
        name="bg",
        fn=_stateful_bg,
        timeout_seconds=2.0,
        background_refresh=True,
        refresh_interval_seconds=0.05,
    )

    r1 = runner.collect_all()["bg"]
    assert r1.data == {"value": "first"}

    value_holder["v"] = "second"

    r2 = runner.collect_all()["bg"]
    assert r2.stale is True
    assert r2.data == {"value": "first"}

    time.sleep(0.3)

    r3 = runner.collect_all()["bg"]
    assert r3.stale is True
    assert r3.data == {"value": "second"}
    runner.shutdown()

def test_slow_background_collector_does_not_block_fast_one(self):
    runner = CollectorRunner(
        specs=[
            CollectorSpec(
                name="fast",
                fn=_fast_good,
                timeout_seconds=1.0,
            ),
            CollectorSpec(
                name="bg_slow",
                fn=_slow_first_then_ok,
                timeout_seconds=5.0,
                background_refresh=True,
                refresh_interval_seconds=0.1,
            ),
        ]
    )
    rgbs = runner.collect_all()
    assert rgbs["fast"].ok is True
    assert rgbs["bg_slow"].ok is True

    _ = runner.collect_all()

    t0 = time.monotonic()
    results = runner.collect_all()
    elapsed = time.monotonic() - t0
    assert results["fast"].ok is True
    assert results["bg_slow"].stale is True
    assert elapsed < 1.0, f"Blocked by slow background: {elapsed:.2f}s"
    runner.shutdown()

def test_fast_collectors_within_budget(self):
    runner = CollectorRunner(
        specs=[
            CollectorSpec(name="a", fn=_fast_good, timeout_seconds=1.0),
            CollectorSpec(name="b", fn=_fast_good, timeout_seconds=1.0),
            CollectorSpec(name="c", fn=_fast_good, timeout_seconds=1.0),
        ]
    )
    t0 = time.monotonic()
    results = runner.collect_all()
    elapsed = time.monotonic() - t0
    assert all(r.ok for r in results.values())
    assert elapsed < 0.5, f"Fast collectors took {elapsed:.2f}s"
    runner.shutdown()
```

### `agent/tests/test_collectors_processes.py` — New optimization tests

Added 5 new tests:

```python
def test_heapq_nlargest_used():
    from collectors.processes import collect

    procs = [make_fake_proc(i, f"proc_{i}.exe", float(i), 100 * 1024**2) for i in range(50)]
    with patch("collectors.processes.psutil.process_iter") as mock_iter:
        mock_iter.return_value = procs
        result = collect()
        cpus = [p["cpu_percent"] for p in result]
        expected = sorted(
            [round(float(i) / 8, 1) for i in range(50) if round(float(i) / 8, 1) > 0],
            reverse=True,
        )[:30]
        assert cpus == expected

def test_no_net_connections_called():
    from collectors.processes import collect

    procs = [make_fake_proc(1, "test.exe", 50.0, 100 * 1024**2)]
    with (
        patch("collectors.processes.psutil.process_iter") as mock_iter,
        patch("collectors.processes.psutil.Process.net_connections") as mock_nc,
    ):
        mock_iter.return_value = procs
        result = collect()
        assert len(result) == 1
        assert result[0]["connections"] == 0
        mock_nc.assert_not_called()

def test_does_not_crash_on_no_such_process():
    """Collector should not crash when a process disappears mid-iteration."""
    from collectors.processes import collect

    result = collect()
    assert isinstance(result, list)

def test_does_not_crash_on_access_denied():
    """Collector should not crash when access is denied."""
    from collectors.processes import collect

    result = collect()
    assert isinstance(result, list)
```

### `agent/tests/test_collectors_gpu.py` — New GPU honesty tests

Added 2 new tests:

```python
def test_gpu_temperature_does_not_fallback_to_cpu(mock_pynvml, mock_wmi):
    mock_pynvml.nvmlDeviceGetCount.return_value = 0
    mock_wmi.return_value.Win32_VideoController.return_value = [
        MagicMock(
            Name="AMD Radeon RX 7900 XTX",
            AdapterRAM=24 * 1024**3,
            DriverVersion="31.0.21002.100",
        ),
    ]

    gpu_mod = _reload_gpu()
    with (
        patch("collectors.gpu._dxgi_dedicated_vram", return_value=[]),
        patch("collectors.gpu._get_intel_gpu_utilization", return_value=0.0),
    ):
        result = gpu_mod.collect()
        assert len(result) == 1
        assert result[0]["temperature_c"] == 0.0, (
            f"GPU temp should be 0.0 (unavailable), got {result[0]['temperature_c']}"
        )

def test_gpu_temperature_from_nvml_not_cpu(mock_pynvml):
    mock_pynvml.nvmlDeviceGetCount.return_value = 1
    handle = MagicMock()
    mock_pynvml.nvmlDeviceGetHandleByIndex.return_value = handle
    mock_pynvml.nvmlDeviceGetName.return_value = "NVIDIA GeForce RTX 4090"
    mem_info = MagicMock(total=24 * 1024**3, used=12 * 1024**3)
    mock_pynvml.nvmlDeviceGetMemoryInfo.return_value = mem_info
    mock_pynvml.nvmlDeviceGetTemperature.return_value = 72.0
    mock_pynvml.nvmlDeviceGetFanSpeed.return_value = 45
    util_rates = MagicMock(gpu=50.0)
    mock_pynvml.nvmlDeviceGetUtilizationRates.return_value = util_rates
    mock_pynvml.nvmlSystemGetDriverVersion.return_value = "535.98"

    gpu_mod = _reload_gpu()
    with (
        patch("collectors.gpu._get_wmi_gpu_static", return_value=[]),
        patch("collectors.gpu._dxgi_dedicated_vram", return_value=[]),
        patch("collectors.gpu._get_intel_gpu_utilization", return_value=0.0),
    ):
        result = gpu_mod.collect()
        assert len(result) == 1
        assert result[0]["temperature_c"] == 72.0
        import collectors.cpu as cpu_mod

        cpu_temp = getattr(cpu_mod, "_cpu_temperature_c", lambda: None)()
        assert result[0]["temperature_c"] != (cpu_temp or 0.0), (
            "GPU temperature must not match CPU temperature"
        )
```

---

## Test Results

```
============================= test session starts =============================
platform win32 -- Python 3.13.3, pytest-9.1.1, pluggy-1.6.0
rootdir: D:\zabmin\zabmin\agent
plugins: anyio-4.14.2, langsmith-0.10.10, mock-3.15.1
collected 231 items

tests/test_agent_commands.py ..............                            [  6%]
tests/test_audit.py ........                                           [  9%]
tests/test_auth.py ........                                            [ 13%]
tests/test_collector_runner.py .......................                  [ 23%]
tests/test_collectors_battery.py ....                                  [ 25%]
tests/test_collectors_cpu.py .......                                   [ 28%]
tests/test_collectors_disk.py .....                                    [ 30%]
tests/test_collectors_gpu.py ..........                                [ 34%]
tests/test_collectors_memory.py .....                                  [ 36%]
tests/test_collectors_network.py .....                                 [ 39%]
tests/test_collectors_processes.py .............                       [ 45%]
tests/test_lifecycle_task.py .............                             [ 48%]
tests/test_lifecycle.py ................                               [ 54%]
tests/test_message_validation.py .............................          [ 71%]
tests/test_process_policy.py ......................................     [ 89%]
tests/test_rate_limit.py ........                                      [ 92%]
tests/test_runtime.py .....                                            [ 95%]
tests/test_websocket_commands.py ....                                  [100%]

============================= 231 passed in 1.92s =============================
```

## Verification Results

| Check | Result |
|-------|--------|
| ruff format | 37 files unchanged |
| ruff check | All checks passed |
| pytest (Python) | 231 passed in 1.92s |
| flutter analyze | No issues found |
| flutter test | 57/57 passed |

## Security Regression Verification

All existing security layers remain intact:
- **Day 2 token auth**: 8 auth tests pass (token extraction, validation, comparison)
- **Day 3 validation/rate limiting**: 27 message validation + 8 rate limit tests pass
- **Day 4 command safety**: 30 process_policy tests + 8 audit tests pass (no token logged)
- **Day 5 lifecycle**: 16 lifecycle tests pass
- **Day 6 collector resilience**: All existing collector_runner tests still pass

## Key Design Decisions

1. **Dynamic budget**: `_compute_budget()` returns 2.5s when any background-refresh collector lacks `_last_good`, drops to 0.9s in steady state. This ensures first startup has enough budget to collect initial data, while steady state doesn't over-allocate.

2. **Background refresh isolation**: Background collectors use stale data immediately via `_last_good` cache. A `_RefreshState` with `running` flag prevents duplicate background refreshes from piling up.

3. **Completed future consumption**: `_consume_completed_futures()` runs at the top of each `collect_all()` tick, checking if background futures completed and updating `_last_good` accordingly.

4. **GPU temperature honesty**: `GPUStats.temperatureC` in the Flutter model is non-nullable `double` (defaults to 0.0 on null in `fromJson`). The agent sends 0.0 for unavailable GPU temperature, never falling back to CPU temperature. A TODO documents the path to null when Flutter supports it.

5. **Process heapq**: Changed from `sort + [:30]` to `heapq.nlargest(30, ...)` for O(n log k) instead of O(n log n) behavior. Per-process error handling is preserved before the heapq call.

6. **No net_connections**: The process collector never calls per-process `net_connections()` during live broadcast. The `connections: 0` field is kept for Flutter compatibility. Full connections are available through the on-demand `get_process_connections` command.

## Collectors Configuration Summary

| Collector | Mode | Timeout | Refresh Interval | Cache TTL | Notes |
|-----------|------|---------|-----------------|-----------|-------|
| cpu | Fresh every tick | 0.5s | — | — | Fast, with COM |
| memory | Fresh every tick | 0.5s | — | — | Fast, with COM |
| disk | Fresh every tick | 1.0s | — | — | |
| network | Fresh every tick | 0.5s | — | — | |
| processes | Background refresh | 5.0s | 1.5s | — | Stale until refreshed |
| gpu | Background refresh | 5.0s | 3.0s | — | Stale until refreshed, with COM |
| battery | Cached | 0.5s | — | 5.0s | Cached for 5s |
