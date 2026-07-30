import os
import sys
import time

sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))

from collector_runner import CollectorResult, CollectorRunner, CollectorSpec


def _fast_good():
    return {"value": 42}


def _fast_good_list():
    return [{"pid": 1}]


def _fast_none():
    return None


def _slow_fn():
    time.sleep(0.5)
    return {"value": 99}


def _very_slow_fn():
    time.sleep(5.0)
    return {"value": 99}


def _moderate_slow_fn():
    time.sleep(1.5)
    return {"value": 99}


def _error_fn():
    raise RuntimeError("something broke")


_background_data = {"value": "fresh"}

_slow_first_data = {"value": "slow_first"}


def _slow_background_fn():
    time.sleep(0.3)
    return _slow_first_data


def _very_slow_background_fn():
    time.sleep(5.0)
    return {"value": "would_block"}


def _slow_first_then_ok():
    time.sleep(0.3)
    return {"value": "bg_ok"}


class TestCollectorResult:
    def test_ok_result(self):
        r = CollectorResult(name="cpu", ok=True, data={"value": 1}, duration_ms=5.0)
        assert r.name == "cpu"
        assert r.ok is True
        assert r.data == {"value": 1}
        assert r.stale is False
        assert r.cached is False

    def test_error_result(self):
        r = CollectorResult(
            name="cpu", ok=False, data=None, duration_ms=5.0, error="timeout"
        )
        assert r.ok is False
        assert r.error == "timeout"


class TestCollectorRunner:
    def test_fast_collector_returns_ok(self):
        runner = CollectorRunner(
            specs=[CollectorSpec(name="fast", fn=_fast_good, timeout_seconds=1.0)]
        )
        results = runner.collect_all()
        assert "fast" in results
        r = results["fast"]
        assert r.ok is True
        assert r.data == {"value": 42}
        assert r.stale is False
        runner.shutdown()

    def test_fast_collector_list(self):
        runner = CollectorRunner(
            specs=[CollectorSpec(name="fast", fn=_fast_good_list, timeout_seconds=1.0)]
        )
        results = runner.collect_all()
        r = results["fast"]
        assert r.ok is True
        assert r.data == [{"pid": 1}]
        runner.shutdown()

    def test_collector_with_none_data(self):
        runner = CollectorRunner(
            specs=[CollectorSpec(name="none", fn=_fast_none, timeout_seconds=1.0)]
        )
        results = runner.collect_all()
        r = results["none"]
        assert r.ok is True
        assert r.data is None
        runner.shutdown()

    def test_slow_collector_times_out_and_returns_stale(self):
        runner = CollectorRunner(
            specs=[CollectorSpec(name="slow", fn=_fast_good, timeout_seconds=0.5)]
        )
        results = runner.collect_all()
        assert results["slow"].ok is True

        runner._specs["slow"] = CollectorSpec(
            name="slow", fn=_very_slow_fn, timeout_seconds=0.1
        )
        results = runner.collect_all()
        r = results["slow"]
        assert r.stale is True
        assert r.data == {"value": 42}
        runner.shutdown()

    def test_slow_collector_returns_safe_default_on_first_call(self):
        runner = CollectorRunner(
            specs=[CollectorSpec(name="slow", fn=_very_slow_fn, timeout_seconds=0.1)]
        )
        results = runner.collect_all()
        r = results["slow"]
        assert r.stale is True
        assert r.data is None
        assert r.error == "timeout"
        runner.shutdown()

    def test_exception_collector_does_not_crash(self):
        runner = CollectorRunner(
            specs=[CollectorSpec(name="bad", fn=_error_fn, timeout_seconds=1.0)]
        )
        results = runner.collect_all()
        r = results["bad"]
        assert r.ok is False
        assert r.error is not None
        runner.shutdown()

    def test_exception_then_stale_fallback(self):
        runner = CollectorRunner(
            specs=[CollectorSpec(name="bad", fn=_fast_good, timeout_seconds=1.0)]
        )
        results = runner.collect_all()
        assert results["bad"].ok is True

        runner._specs["bad"] = CollectorSpec(
            name="bad", fn=_error_fn, timeout_seconds=1.0
        )
        results = runner.collect_all()
        r = results["bad"]
        assert r.stale is True
        assert r.data == {"value": 42}
        runner.shutdown()

    def test_cache_returns_before_ttl(self):
        call_count = 0

        def _cached_fn():
            nonlocal call_count
            call_count += 1
            return {"value": call_count}

        runner = CollectorRunner(
            specs=[
                CollectorSpec(
                    name="cached",
                    fn=_cached_fn,
                    timeout_seconds=1.0,
                    cache_ttl_seconds=60.0,
                )
            ]
        )
        r1 = runner.collect_all()["cached"]
        assert r1.data == {"value": 1}
        r2 = runner.collect_all()["cached"]
        assert r2.cached is True
        assert r2.data == {"value": 1}
        assert call_count == 1
        runner.shutdown()

    def test_health_tracks_timeout_and_error(self):
        runner = CollectorRunner(
            specs=[CollectorSpec(name="test", fn=_very_slow_fn, timeout_seconds=0.05)]
        )
        runner.collect_all()
        h = runner.get_health("test")
        assert h is not None
        assert h.timeout_count >= 1
        assert h.stale is True
        runner.shutdown()

    def test_multiple_collectors_return_all(self):
        runner = CollectorRunner(
            specs=[
                CollectorSpec(name="a", fn=_fast_good, timeout_seconds=1.0),
                CollectorSpec(name="b", fn=_fast_good, timeout_seconds=1.0),
            ]
        )
        results = runner.collect_all()
        assert "a" in results
        assert "b" in results
        assert results["a"].ok is True
        assert results["b"].ok is True
        runner.shutdown()

    def test_shutdown_does_not_hang(self):
        runner = CollectorRunner(
            specs=[CollectorSpec(name="a", fn=_fast_good, timeout_seconds=1.0)]
        )
        runner.collect_all()
        runner.shutdown()

    # --- Background refresh tests ---

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
        assert elapsed < 0.2, (
            f"Second call took {elapsed:.2f}s (expected instant stale)"
        )
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

    # --- Broadcast budget / slow-collector isolation ---

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

    def test_multiple_background_refresh_cycles(self):
        value_holder = {"v": 1}

        def _bg_fn():
            return {"value": value_holder["v"]}

        runner = CollectorRunner(
            specs=[
                CollectorSpec(
                    name="bg",
                    fn=_bg_fn,
                    timeout_seconds=5.0,
                    background_refresh=True,
                    refresh_interval_seconds=5.0,
                )
            ]
        )

        r1 = runner.collect_all()["bg"]
        assert r1.data == {"value": 1}

        r2 = runner.collect_all()["bg"]
        assert r2.stale is True
        assert r2.data == {"value": 1}

        value_holder["v"] = 2
        time.sleep(0.15)

        runner._consume_completed_futures()
        assert runner._refresh_state["bg"].running is False

        r3 = runner.collect_all()["bg"]
        assert r3.stale is True
        assert r3.data == {"value": 2}

        value_holder["v"] = 3
        runner._refresh_state["bg"].refresh_time = 0.0

        r4 = runner.collect_all()["bg"]
        assert r4.stale is True
        assert r4.data == {"value": 2}

        time.sleep(0.15)
        runner._consume_completed_futures()

        r5 = runner.collect_all()["bg"]
        assert r5.stale is True
        assert r5.data == {"value": 3}
        runner.shutdown()

    def test_stuck_future_cleanup(self):
        runner = CollectorRunner(
            specs=[
                CollectorSpec(
                    name="stuck",
                    fn=_very_slow_fn,
                    timeout_seconds=5.0,
                )
            ]
        )

        fut = runner._submit_collector("stuck", runner._specs["stuck"])
        runner._in_flight["stuck"] = fut
        runner._in_flight_started["stuck"] = time.monotonic() - 30.0

        runner._consume_completed_futures()

        assert "stuck" not in runner._in_flight
        assert "stuck" not in runner._in_flight_started
        runner.shutdown()

    def test_no_duplicate_in_flight_background(self):
        runner = CollectorRunner(
            specs=[
                CollectorSpec(
                    name="bg",
                    fn=_very_slow_background_fn,
                    timeout_seconds=10.0,
                    background_refresh=True,
                    refresh_interval_seconds=0.05,
                )
            ]
        )
        runner._last_good["bg"] = CollectorResult(
            name="bg", ok=True, data=_slow_first_data, duration_ms=10.0
        )

        r1 = runner.collect_all()["bg"]
        assert r1.stale is True
        assert len(runner._in_flight) <= 1

        r2 = runner.collect_all()["bg"]
        assert r2.stale is True
        assert len(runner._in_flight) <= 1

        runner.shutdown()

    def test_collect_all_fast_in_steady_state(self):
        runner = CollectorRunner(
            specs=[
                CollectorSpec(
                    name="fast",
                    fn=_fast_good,
                    timeout_seconds=0.5,
                ),
                CollectorSpec(
                    name="slow_bg",
                    fn=_moderate_slow_fn,
                    timeout_seconds=5.0,
                    background_refresh=True,
                    refresh_interval_seconds=1.0,
                ),
            ]
        )

        r1 = runner.collect_all()
        assert r1["fast"].ok is True
        assert r1["slow_bg"].ok is True

        time.sleep(0.1)

        t0 = time.monotonic()
        r2 = runner.collect_all()
        elapsed = time.monotonic() - t0
        assert r2["fast"].ok is True
        assert r2["slow_bg"].stale is True
        assert elapsed < 0.3, f"collect_all blocked for {elapsed:.2f}s"
        runner.shutdown()

    def test_background_refresh_running_reset_on_exception(self):
        def _fail_bg():
            time.sleep(0.05)
            raise RuntimeError("bg failed")

        runner = CollectorRunner(
            specs=[
                CollectorSpec(
                    name="bg",
                    fn=_fail_bg,
                    timeout_seconds=5.0,
                    background_refresh=True,
                    refresh_interval_seconds=5.0,
                )
            ]
        )

        result = CollectorResult(name="bg", ok=True, data={"value": 1}, duration_ms=5.0)
        runner._last_good["bg"] = result

        r2 = runner.collect_all()["bg"]
        assert r2.stale is True
        assert r2.data == {"value": 1}
        assert runner._refresh_state["bg"].running is True

        time.sleep(0.15)
        runner._consume_completed_futures()
        assert runner._refresh_state["bg"].running is False
        assert "bg" not in runner._in_flight
        runner.shutdown()

    def test_no_duplicate_in_flight_via_foreground(self):
        runner = CollectorRunner(
            specs=[
                CollectorSpec(
                    name="a",
                    fn=_very_slow_fn,
                    timeout_seconds=0.05,
                )
            ]
        )

        r1 = runner.collect_all()
        assert r1["a"].stale is True

        in_flight_count_before = len(runner._in_flight)
        runner.collect_all()
        assert len(runner._in_flight) <= in_flight_count_before
        runner.shutdown()
