"""Test GPU collector — NVML/WMI/DXGI multi-source merge."""
from unittest.mock import MagicMock, patch

import pytest


@pytest.fixture(autouse=True)
def mock_pynvml():
    """Mock pynvml before gpu module is imported to avoid real NVML init."""
    with patch.dict("sys.modules", {"pynvml": MagicMock()}) as mock_dict:
        pynvml = mock_dict["pynvml"]
        pynvml.nvmlInit.return_value = None
        pynvml.nvmlDeviceGetCount.return_value = 0
        yield pynvml


@pytest.fixture(autouse=True)
def mock_wmi():
    """Mock wmi.WMI() calls (lazily imported inside functions)."""
    with patch("wmi.WMI") as mock:
        yield mock


@pytest.fixture(autouse=True)
def mock_dxgi():
    """Mock DXGI ctypes calls (expensive COM interop)."""
    with patch("collectors.gpu.ctypes.windll.dxgi") as mock:
        mock.CreateDXGIFactory.return_value = 0
        yield mock


def _reload_gpu():
    import importlib

    import collectors.gpu as gpu_mod

    importlib.reload(gpu_mod)
    return gpu_mod


def test_no_gpu_returns_empty_list(mock_pynvml):
    mock_pynvml.nvmlDeviceGetCount.return_value = 0
    gpu_mod = _reload_gpu()
    with patch("collectors.gpu._get_wmi_gpu_static", return_value=[]):
        result = gpu_mod.collect()
        assert result == []


def test_nvml_gpu_data(mock_pynvml):
    mock_pynvml.nvmlDeviceGetCount.return_value = 1
    handle = MagicMock()
    mock_pynvml.nvmlDeviceGetHandleByIndex.return_value = handle
    mock_pynvml.nvmlDeviceGetName.return_value = "NVIDIA GeForce RTX 4090"
    mem_info = MagicMock(total=24 * 1024**3, used=12 * 1024**3)
    mock_pynvml.nvmlDeviceGetMemoryInfo.return_value = mem_info
    mock_pynvml.nvmlDeviceGetTemperature.return_value = 65.0
    mock_pynvml.nvmlDeviceGetFanSpeed.return_value = 40
    util_rates = MagicMock(gpu=45.0)
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
        g = result[0]
        assert "NVIDIA" in g["name"]
        assert g["vram_total_mb"] == round(24 * 1024**3 / 1024**2, 1)
        assert g["vram_used_mb"] == round(12 * 1024**3 / 1024**2, 1)
        assert "535.98" in g["driver_version"]
        assert g["temperature_c"] == 65.0
        assert g["fan_percent"] == 40.0


def test_wmi_fallback_for_non_nvidia_gpu(mock_pynvml, mock_wmi):
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
        g = result[0]
        assert "AMD" in g["name"]
        assert g["vram_total_mb"] > 0
        assert g["utilization_percent"] == 0.0


def test_wmi_static_caching(mock_pynvml, mock_wmi):
    mock_pynvml.nvmlDeviceGetCount.return_value = 0
    mock_wmi.return_value.Win32_VideoController.return_value = [
        MagicMock(
            Name="Intel(R) UHD Graphics",
            AdapterRAM=1 * 1024**3,
            DriverVersion="30.0.101.1693",
        ),
    ]

    gpu_mod = _reload_gpu()
    with (
        patch("collectors.gpu._dxgi_dedicated_vram", return_value=[]),
        patch("collectors.gpu._get_intel_gpu_utilization", return_value=15.0),
    ):
        result = gpu_mod.collect()
        assert len(result) == 1
        second_result = gpu_mod.collect()
        assert second_result == result


def test_dxgi_corrects_vram(mock_pynvml, mock_wmi):
    mock_pynvml.nvmlDeviceGetCount.return_value = 0
    mock_wmi.return_value.Win32_VideoController.return_value = [
        MagicMock(
            Name="AMD Radeon RX 7900 XTX",
            AdapterRAM=4095 * 1024**2,
            DriverVersion="",
        ),
    ]

    gpu_mod = _reload_gpu()
    dxgi_data = [("amd radeon rx 7900 xtx", 24576.0)]
    with (
        patch("collectors.gpu._dxgi_dedicated_vram", return_value=dxgi_data),
        patch("collectors.gpu._get_intel_gpu_utilization", return_value=0.0),
    ):
        result = gpu_mod.collect()
        assert len(result) == 1
        assert result[0]["vram_total_mb"] == 24576.0


def test_intel_util_fallback(mock_pynvml, mock_wmi):
    mock_pynvml.nvmlDeviceGetCount.return_value = 0
    mock_wmi.return_value.Win32_VideoController.return_value = [
        MagicMock(
            Name="Intel(R) UHD Graphics",
            AdapterRAM=1 * 1024**3,
            DriverVersion="30.0.101.1693",
        ),
    ]

    gpu_mod = _reload_gpu()
    with (
        patch("collectors.gpu._dxgi_dedicated_vram", return_value=[]),
        patch("collectors.gpu._get_intel_gpu_utilization", return_value=42.0),
    ):
        result = gpu_mod.collect()
        assert len(result) == 1
        assert result[0]["utilization_percent"] == 42.0


def test_fallback_on_exception(mock_pynvml, mock_wmi):
    mock_pynvml.nvmlDeviceGetCount.return_value = 0
    gpu_mod = _reload_gpu()
    with patch("collectors.gpu._collect_inner") as mock_inner:
        mock_inner.side_effect = RuntimeError("gpu fail")
        result = gpu_mod.collect()
        assert result == []
