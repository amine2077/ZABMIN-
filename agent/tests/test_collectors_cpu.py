from unittest.mock import MagicMock, patch

import pytest


@pytest.fixture(autouse=True)
def mock_cpu_state():
    with patch("collectors.cpu.cpu_state") as mock:
        mock.read_state.return_value = {
            "cpu_total": 35.2,
            "cpu_per_core": [30.1, 40.3, 25.0, 45.5],
        }
        yield mock


@pytest.fixture(autouse=True)
def mock_psutil():
    with patch("collectors.cpu.psutil") as mock:
        mock.cpu_freq.return_value = MagicMock(current=3200.0, max=5000.0)
        mock.cpu_count.side_effect = lambda logical: 4 if not logical else 8
        yield mock


@patch("collectors.cpu._cpu_temperature_c", return_value=68.5)
def test_collect_returns_correct_structure(mock_temp):
    from collectors.cpu import collect

    result = collect()
    assert result["percent_total"] == 35.2
    assert result["percent_per_core"] == [30.1, 40.3, 25.0, 45.5]
    assert result["freq_mhz"] == 3200
    assert result["core_count"] == 4
    assert result["thread_count"] == 8
    assert result["temperature_c"] == 68.5
    assert result["throttled"] is False


@patch("collectors.cpu._cpu_temperature_c", return_value=68.5)
def test_collect_values_from_cpu_state(mock_temp):
    from collectors.cpu import collect

    result = collect()
    assert result["percent_total"] == 35.2
    assert len(result["percent_per_core"]) == 4


@patch("collectors.cpu._cpu_temperature_c", return_value=68.5)
def test_collect_fallback_on_exception(mock_temp, mock_psutil, mock_cpu_state):
    mock_cpu_state.read_state.side_effect = RuntimeError("state error")
    from collectors.cpu import collect

    result = collect()
    assert result["percent_total"] == 0.0
    assert result["percent_per_core"] == []
    assert result["freq_mhz"] == 0
    assert result["core_count"] == 0
    assert result["thread_count"] == 0
    assert result["temperature_c"] is None
    assert result["throttled"] is False


@patch("collectors.cpu._cpu_temperature_c", return_value=None)
def test_collect_with_no_freq(mock_temp, mock_psutil):
    mock_psutil.cpu_freq.return_value = None
    from collectors.cpu import collect

    with patch("collectors.cpu._freq_cache", None):
        result = collect()
    assert result["freq_mhz"] == 0


def test_throttle_true_when_below_half_max():
    freq = MagicMock(current=1200.0, max=5000.0)
    from collectors.cpu import _cpu_throttled

    assert _cpu_throttled(freq) is True


def test_throttle_false_above_half_max():
    freq = MagicMock(current=3000.0, max=5000.0)
    from collectors.cpu import _cpu_throttled

    assert _cpu_throttled(freq) is False


def test_throttle_false_when_no_max():
    freq = MagicMock(current=1200.0, max=None)
    from collectors.cpu import _cpu_throttled

    assert _cpu_throttled(freq) is False


def test_temperature_c_returns_none_when_no_wmi():
    from collectors.cpu import _cpu_temperature_c

    import builtins
    real_import = builtins.__import__

    def fake_import(name, *args, **kwargs):
        if name == "wmi":
            raise ModuleNotFoundError("no wmi")
        return real_import(name, *args, **kwargs)

    with patch("builtins.__import__", side_effect=fake_import):
        result = _cpu_temperature_c()
        assert result is None
