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


def _error_fn():
    raise RuntimeError("something broke")


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
