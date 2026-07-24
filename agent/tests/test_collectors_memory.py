"""Test memory collector — verifies total-available formula, not psutil's used."""

from unittest.mock import MagicMock, patch

import pytest


@pytest.fixture(autouse=True)
def mock_psutil():
    with patch("collectors.memory.psutil") as mock:
        mem = MagicMock()
        mem.total = 16 * 1024**3
        mem.available = 4 * 1024**3
        mem.used = 10 * 1024**3  # deliberately different from total-available
        mem.cached = 2 * 1024**3
        mem.percent = 62.5
        mock.virtual_memory.return_value = mem
        yield mock


@pytest.fixture(autouse=True)
def mock_wmi():
    """Prevent real WMI calls in _get_ram_speed.

    Uses patch.dict(sys.modules) instead of patch("wmi.WMI") because
    the real wmi module calls GetObject("winmgmts:") at import time,
    which fails with COM error when WMI is unavailable.
    """
    mock_module = MagicMock()
    mock_module.WMI.return_value.Win32_PhysicalMemory.return_value = []
    with patch.dict("sys.modules", {"wmi": mock_module}):
        yield mock_module.WMI


def test_collect_uses_total_minus_available_not_psutil_used():
    from collectors.memory import collect

    result = collect()
    expected_used = 16.0 - 4.0
    assert result["used_gb"] == expected_used
    assert result["total_gb"] == 16.0
    assert result["percent"] == 75.0
    assert result["available_gb"] == 4.0


def test_cached_gb_is_present():
    from collectors.memory import collect

    result = collect()
    assert result["cached_gb"] == 2.0


def test_speed_mhz_fallback_to_zero_when_no_wmi_sticks():
    from collectors.memory import collect

    result = collect()
    assert result["speed_mhz"] == 0


def test_fallback_on_exception():
    from collectors.memory import collect

    with patch("collectors.memory.psutil.virtual_memory") as mock_vm:
        mock_vm.side_effect = RuntimeError("no mem")
        result = collect()
        assert result["total_gb"] == 0.0
        assert result["used_gb"] == 0.0
        assert result["percent"] == 0.0


def test_with_speed_mhz_cached():
    from collectors.memory import collect

    with patch("collectors.memory._get_ram_speed") as mock_speed:
        mock_speed.return_value = 3200
        result = collect()
        assert result["speed_mhz"] == 3200
