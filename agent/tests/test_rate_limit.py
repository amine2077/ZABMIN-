from rate_limit import RateLimiter


class TestRateLimiter:
    def test_allow_first_request(self):
        limiter = RateLimiter(limits={"kill_process": 5})
        assert limiter.allow("kill_process", now=0.0) is True

    def test_block_after_limit_exceeded(self):
        limiter = RateLimiter(limits={"kill_process": 3})
        assert limiter.allow("kill_process", now=0.0) is True
        assert limiter.allow("kill_process", now=1.0) is True
        assert limiter.allow("kill_process", now=2.0) is True
        assert limiter.allow("kill_process", now=3.0) is False

    def test_tracks_different_actions_separately(self):
        limiter = RateLimiter(limits={"kill_process": 2, "get_history": 3})
        assert limiter.allow("kill_process", now=0.0) is True
        assert limiter.allow("kill_process", now=1.0) is True
        assert limiter.allow("kill_process", now=2.0) is False
        assert limiter.allow("get_history", now=3.0) is True
        assert limiter.allow("get_history", now=4.0) is True
        assert limiter.allow("get_history", now=5.0) is True
        assert limiter.allow("get_history", now=6.0) is False

    def test_allows_again_after_window_expires(self):
        limiter = RateLimiter(limits={"kill_process": 2}, window=60.0)
        assert limiter.allow("kill_process", now=0.0) is True
        assert limiter.allow("kill_process", now=1.0) is True
        assert limiter.allow("kill_process", now=2.0) is False
        assert limiter.allow("kill_process", now=62.0) is True

    def test_unlimited_action(self):
        limiter = RateLimiter(limits={})
        for i in range(100):
            assert limiter.allow("anything", now=float(i)) is True

    def test_exact_boundary(self):
        limiter = RateLimiter(limits={"kill_process": 2}, window=10.0)
        assert limiter.allow("kill_process", now=0.0) is True
        assert limiter.allow("kill_process", now=9.0) is True
        # At 10.0: 0.0 expired (10s ago), only 9.0 in window
        assert limiter.allow("kill_process", now=10.0) is True
        # Now 9.0 + 10.0 = 2, block
        assert limiter.allow("kill_process", now=10.0001) is False

    def test_shutdown_limit(self):
        limiter = RateLimiter(limits={"shutdown": 3})
        assert limiter.allow("shutdown", now=0.0) is True
        assert limiter.allow("shutdown", now=1.0) is True
        assert limiter.allow("shutdown", now=2.0) is True
        assert limiter.allow("shutdown", now=3.0) is False

    def test_mixed_actions_dont_interfere(self):
        limiter = RateLimiter(limits={"kill_process": 1, "shutdown": 1})
        assert limiter.allow("kill_process", now=0.0) is True
        assert limiter.allow("shutdown", now=1.0) is True
        assert limiter.allow("kill_process", now=2.0) is False
        assert limiter.allow("shutdown", now=3.0) is False
