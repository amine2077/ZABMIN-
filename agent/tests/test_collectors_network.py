"""Test network collector — verifies delta-based I/O speed calculation."""
from unittest.mock import MagicMock, patch

import pytest

_FAKE_NOW = 1000.0


@pytest.fixture(autouse=True)
def reset_globals():
    """Reset module-level state before each test."""
    import collectors.network as net_mod

    net_mod._prev_io = None
    net_mod._prev_time = None


@pytest.fixture(autouse=True)
def mock_psutil():
    with patch("collectors.network.psutil") as mock:
        io = MagicMock()
        io.bytes_sent = 500 * 1024**2  # 500 MB
        io.bytes_recv = 1000 * 1024**2  # 1000 MB
        mock.net_io_counters.return_value = io
        yield mock


def _call_collect():
    from collectors.network import collect

    return collect()


def test_first_call_returns_zero_speed(mock_psutil):
    result = _call_collect()
    assert result["sent_mb_s"] == 0.0
    assert result["recv_mb_s"] == 0.0
    assert result["total_sent_gb"] == 0.5
    assert result["total_recv_gb"] == 1.0


def test_second_call_computes_delta():
    with patch("time.monotonic") as mock_time:
        mock_time.side_effect = [_FAKE_NOW, _FAKE_NOW + 2.0]
        _call_collect()
        io2 = MagicMock()
        io2.bytes_sent = 700 * 1024**2
        io2.bytes_recv = 1600 * 1024**2
        with patch("collectors.network.psutil.net_io_counters") as mock_io:
            mock_io.return_value = io2
            result = _call_collect()
            sent_delta = (700 - 500) * 1024**2
            recv_delta = (1600 - 1000) * 1024**2
            assert result["sent_mb_s"] == pytest.approx(
                (sent_delta / 2.0) / 1024**2, rel=1e-3
            )
            assert result["recv_mb_s"] == pytest.approx(
                (recv_delta / 2.0) / 1024**2, rel=1e-3
            )
            expected_total_sent_gb = round(
                (700 * 1024**2) / (1024**3), 1
            )
            assert result["total_sent_gb"] == pytest.approx(
                expected_total_sent_gb, rel=1e-3
            )


def test_zero_dt_does_not_divide_by_zero():
    with patch("time.monotonic") as mock_time:
        mock_time.side_effect = [_FAKE_NOW, _FAKE_NOW]
        _call_collect()
        io2 = MagicMock()
        io2.bytes_sent = 700 * 1024**2
        io2.bytes_recv = 1600 * 1024**2
        with patch("collectors.network.psutil.net_io_counters") as mock_io:
            mock_io.return_value = io2
            result = _call_collect()
            assert result["sent_mb_s"] == 0.0
            assert result["recv_mb_s"] == 0.0


def test_fallback_on_exception(reset_globals):
    with patch("collectors.network.psutil.net_io_counters") as mock:
        mock.side_effect = RuntimeError("no net")
        result = _call_collect()
        assert result["sent_mb_s"] == 0.0
        assert result["recv_mb_s"] == 0.0


def test_recovery_after_exception():
    with patch("collectors.network.psutil.net_io_counters") as mock:
        mock.side_effect = RuntimeError("fail")
        _call_collect()
        mock.side_effect = None
        io = MagicMock()
        io.bytes_sent = 0
        io.bytes_recv = 0
        mock.return_value = io
        with patch("time.monotonic") as mock_time:
            mock_time.side_effect = [_FAKE_NOW, _FAKE_NOW + 1.0]
            result = _call_collect()
            assert result["sent_mb_s"] == 0.0
            assert result["recv_mb_s"] == 0.0
