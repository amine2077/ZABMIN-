import logging

logger = logging.getLogger(__name__)

_nvml_initialized = False
_gpu_count = 0

try:
    import pynvml
    pynvml.nvmlInit()
    _gpu_count = pynvml.nvmlDeviceGetCount()
    _nvml_initialized = _gpu_count > 0
    if _nvml_initialized:
        logger.info(f"NVML initialized: {_gpu_count} GPU(s) found")
except Exception as e:
    logger.info(f"NVML not available: {e}")

_wmi_gpu_info = None
_wmi_gpu_fetched = False


def _get_wmi_gpu_static():
    global _wmi_gpu_info, _wmi_gpu_fetched
    if _wmi_gpu_fetched:
        return _wmi_gpu_info
    _wmi_gpu_fetched = True
    try:
        import wmi
        c = wmi.WMI()
        gpus = []
        for gpu in c.Win32_VideoController():
            vram_mb = round((gpu.AdapterRAM or 0) / (1024**2))
            gpus.append({
                "name": gpu.Name or "Unknown GPU",
                "vram_total_mb": float(vram_mb),
                "vram_used_mb": 0.0,
                "vram_percent": 0.0,
                "temperature_c": 0.0,
                "fan_percent": 0.0,
                "utilization_percent": 0.0,
                "driver_version": gpu.DriverVersion or "",
            })
        _wmi_gpu_info = gpus
        return gpus
    except Exception as e:
        logger.warning(f"WMI GPU query failed: {e}")
        _wmi_gpu_info = []
        return []


def _get_intel_gpu_utilization():
    """Get Intel/AMD GPU 3D engine utilization via WMI performance counters."""
    try:
        import wmi
        perf = wmi.WMI(namespace="root\\cimv2")
        total_3d = 0.0
        count = 0
        for item in perf.Win32_PerfFormattedData_GPUPerformanceCounters_GPUEngine():
            name = item.Name or ""
            if "engtype_3D" in name:
                total_3d += float(item.UtilizationPercentage or 0)
                count += 1
        if count > 0:
            return min(total_3d, 100.0)
        return 0.0
    except Exception as e:
        logger.debug(f"GPU perf counter failed: {e}")
        return 0.0


def _get_wmi_gpu_dedicated_memory():
    """Try to get dedicated video memory usage from DXGI or WMI."""
    try:
        import wmi
        c = wmi.WMI()
        for gpu in c.Win32_VideoController():
            dedicated_used = getattr(gpu, "AdapterRAM", 0) or 0
            return round(dedicated_used / (1024**2))
    except Exception:
        pass
    return 0


def collect():
    """Collect GPU metrics. Uses NVML for NVIDIA, falls back to WMI for Intel/AMD."""
    if _nvml_initialized:
        try:
            gpus = []
            for i in range(_gpu_count):
                handle = pynvml.nvmlDeviceGetHandleByIndex(i)
                name = pynvml.nvmlDeviceGetName(handle)
                if isinstance(name, bytes):
                    name = name.decode("utf-8")

                mem_info = pynvml.nvmlDeviceGetMemoryInfo(handle)
                vram_total_mb = round(mem_info.total / (1024**2), 1)
                vram_used_mb = round(mem_info.used / (1024**2), 1)
                vram_percent = round((mem_info.used / mem_info.total) * 100, 1) if mem_info.total > 0 else 0.0

                try:
                    temp = pynvml.nvmlDeviceGetTemperature(handle, pynvml.NVML_TEMPERATURE_GPU)
                except Exception:
                    temp = 0

                try:
                    fan = pynvml.nvmlDeviceGetFanSpeed(handle)
                except Exception:
                    fan = 0

                try:
                    utilization = pynvml.nvmlDeviceGetUtilizationRates(handle)
                    gpu_util = utilization.gpu
                except Exception:
                    gpu_util = 0

                try:
                    driver = pynvml.nvmlSystemGetDriverVersion()
                    if isinstance(driver, bytes):
                        driver = driver.decode("utf-8")
                except Exception:
                    driver = ""

                gpus.append({
                    "name": name,
                    "vram_total_mb": vram_total_mb,
                    "vram_used_mb": vram_used_mb,
                    "vram_percent": vram_percent,
                    "temperature_c": float(temp),
                    "fan_percent": float(fan),
                    "utilization_percent": float(gpu_util),
                    "driver_version": driver,
                })
            return gpus
        except Exception as e:
            logger.warning(f"NVML collect failed: {e}")

    gpus = _get_wmi_gpu_static()
    if not gpus:
        return []

    utilization = _get_intel_gpu_utilization()

    result = []
    for gpu in gpus:
        result.append({
            "name": gpu["name"],
            "vram_total_mb": gpu["vram_total_mb"],
            "vram_used_mb": 0.0,
            "vram_percent": 0.0,
            "temperature_c": 0.0,
            "fan_percent": 0.0,
            "utilization_percent": utilization,
            "driver_version": gpu["driver_version"],
        })
    return result
