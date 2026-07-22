import time
import logging
import ctypes
from ctypes import wintypes

logger = logging.getLogger(__name__)

_WMI_STATIC_TTL = 30.0
_wmi_static_cache = None
_wmi_static_ts = 0.0
_dxgi_cache = None
_dxgi_ts = 0.0

_nvml_initialized = False
_nvml_count = 0

try:
    import pynvml

    pynvml.nvmlInit()
    _nvml_count = pynvml.nvmlDeviceGetCount()
    _nvml_initialized = _nvml_count > 0
    if _nvml_initialized:
        logger.info(f"NVML initialized: {_nvml_count} GPU(s)")
except Exception as e:
    logger.info(f"NVML not available: {e}")


def _dxgi_dedicated_vram():
    """Return a list of (name_lower, dedicated_mb) via DXGI for each adapter.

    Kept despite fragile hand-rolled COM vtable walking because WMI's
    Win32_VideoController.AdapterRAM is a 32-bit DWORD and truncates to
    ~4095 MB on GPUs with >4 GB VRAM. DXGI returns the correct dedicated
    VRAM for AMD and Intel GPUs that NVML doesn't cover. A failure here
    falls through to the WMI value silently.
    """
    global _dxgi_cache, _dxgi_ts
    now = time.monotonic()
    if _dxgi_cache is not None and (now - _dxgi_ts) < _WMI_STATIC_TTL:
        return list(_dxgi_cache)
    try:
        dxgi = ctypes.windll.dxgi
        factory_iid = bytes.fromhex("a86f7518c0f4d84cb291c629e7437d20")
        factory = ctypes.c_void_p()
        hr = dxgi.CreateDXGIFactory(factory_iid, ctypes.byref(factory))
        if hr != 0 or not factory.value:
            return []

        class LUID(ctypes.Structure):
            _fields_ = [("LowPart", wintypes.DWORD), ("HighPart", wintypes.LONG)]

        class DESC(ctypes.Structure):
            _fields_ = [
                ("Description", ctypes.c_wchar * 128),
                ("VendorId", wintypes.UINT),
                ("DeviceId", wintypes.UINT),
                ("SubSysId", wintypes.UINT),
                ("Revision", wintypes.UINT),
                ("DedicatedVideoMemory", ctypes.c_size_t),
                ("DedicatedSystemMemory", ctypes.c_size_t),
                ("SharedSystemMemory", ctypes.c_size_t),
                ("Luid", LUID),
                ("Flags", wintypes.UINT),
            ]

        class VTable(ctypes.Structure):
            _fields_ = [
                ("QueryInterface", ctypes.c_void_p),
                ("AddRef", ctypes.c_void_p),
                ("Release", ctypes.c_void_p),
                ("EnumAdapters", ctypes.c_void_p),
            ]

        results = []
        i = 0
        while True:
            adapter = ctypes.c_void_p()
            vtbl = ctypes.cast(factory.value, ctypes.POINTER(ctypes.c_void_p))[0]
            vtbl = ctypes.cast(vtbl, ctypes.POINTER(VTable))
            enum_fn = ctypes.WINFUNCTYPE(
                ctypes.c_long,
                ctypes.c_void_p,
                wintypes.UINT,
                ctypes.POINTER(ctypes.c_void_p),
            )(vtbl.contents.EnumAdapters)
            hr = enum_fn(factory.value, i, ctypes.byref(adapter))
            if hr != 0 or not adapter.value:
                break

            class AdapterVTable(ctypes.Structure):
                _fields_ = [
                    ("QueryInterface", ctypes.c_void_p),
                    ("AddRef", ctypes.c_void_p),
                    ("Release", ctypes.c_void_p),
                    ("GetDesc", ctypes.c_void_p),
                ]

            a_vtbl = ctypes.cast(
                ctypes.cast(adapter.value, ctypes.POINTER(ctypes.c_void_p))[0],
                ctypes.POINTER(AdapterVTable),
            )
            get_desc = ctypes.WINFUNCTYPE(
                ctypes.c_long, ctypes.c_void_p, ctypes.POINTER(DESC)
            )(a_vtbl.contents.GetDesc)
            desc = DESC()
            hr = get_desc(adapter.value, ctypes.byref(desc))

            rel_fn = ctypes.WINFUNCTYPE(ctypes.c_long)(
                ctypes.cast(
                    ctypes.cast(adapter.value, ctypes.POINTER(ctypes.c_void_p))[0],
                    ctypes.POINTER(ctypes.c_void_p * 3),
                ).contents[2]
            )
            rel_fn(adapter.value)

            if hr == 0:
                name = desc.Description.strip("\x00").strip()
                vram_mb = round(desc.DedicatedVideoMemory / (1024**2), 1)
                results.append((name.lower(), vram_mb))
            i += 1

        _dxgi_cache = list(results)
        _dxgi_ts = now
        return results
    except Exception as e:
        logger.debug(f"DXGI query failed: {e}")
        return []


def _get_wmi_gpu_static():
    global _wmi_static_cache, _wmi_static_ts
    now = time.monotonic()
    if _wmi_static_cache is not None and (now - _wmi_static_ts) < _WMI_STATIC_TTL:
        return [dict(g) for g in _wmi_static_cache]
    try:
        import wmi

        c = wmi.WMI()
        gpus = []
        for gpu in c.Win32_VideoController():
            vram_mb = round((gpu.AdapterRAM or 0) / (1024**2))
            gpus.append(
                {
                    "name": (gpu.Name or "Unknown GPU").strip(),
                    "vram_total_mb": float(vram_mb),
                    "vram_used_mb": 0.0,
                    "vram_percent": 0.0,
                    "temperature_c": 0.0,
                    "fan_percent": 0.0,
                    "utilization_percent": 0.0,
                    "driver_version": gpu.DriverVersion or "",
                }
            )
        _wmi_static_cache = [dict(g) for g in gpus]
        _wmi_static_ts = now
        del c
        return gpus
    except Exception as e:
        logger.debug(f"WMI GPU query failed: {e}")
        _wmi_static_cache = []
        _wmi_static_ts = now
        return []


def _get_intel_gpu_utilization():
    """WMI GPUEngine perf counters take 15+ seconds on Windows.
    Return 0.0 to prevent blocking the GPU collector.
    """
    return 0.0


def _name_matches(name_a, name_b):
    """Loose name match ignoring case and trailing tokens like 'Microsoft Corporation - ...'."""
    a = name_a.lower()
    b = name_b.lower()
    if a == b:
        return True
    return a.startswith(b) or b.startswith(a) or a in b or b in a


def collect():
    """Collect GPU metrics. NVML for NVIDIA + WMI for Intel/AMD (combined, no short-circuit)."""
    try:
        return _collect_inner()
    except Exception as e:
        logger.warning(f"GPU collect failed unexpectedly: {e}")
        return []


def _collect_inner():
    gpus = []
    seen_names = []

    if _nvml_initialized:
        try:
            for i in range(_nvml_count):
                handle = pynvml.nvmlDeviceGetHandleByIndex(i)
                name = pynvml.nvmlDeviceGetName(handle)
                if isinstance(name, bytes):
                    name = name.decode("utf-8")
                name = name.strip()

                mem_info = pynvml.nvmlDeviceGetMemoryInfo(handle)
                vram_total_mb = round(mem_info.total / (1024**2), 1)
                vram_used_mb = round(mem_info.used / (1024**2), 1)
                vram_percent = (
                    round((mem_info.used / mem_info.total) * 100, 1)
                    if mem_info.total > 0
                    else 0.0
                )

                try:
                    temp = float(
                        pynvml.nvmlDeviceGetTemperature(
                            handle, pynvml.NVML_TEMPERATURE_GPU
                        )
                    )
                except Exception:
                    temp = 0.0

                try:
                    fan = float(pynvml.nvmlDeviceGetFanSpeed(handle))
                except Exception:
                    fan = 0.0

                try:
                    util = float(pynvml.nvmlDeviceGetUtilizationRates(handle).gpu)
                except Exception:
                    util = 0.0

                try:
                    driver = pynvml.nvmlSystemGetDriverVersion()
                    if isinstance(driver, bytes):
                        driver = driver.decode("utf-8")
                except Exception:
                    driver = ""

                gpus.append(
                    {
                        "name": name,
                        "vram_total_mb": vram_total_mb,
                        "vram_used_mb": vram_used_mb,
                        "vram_percent": vram_percent,
                        "temperature_c": temp,
                        "fan_percent": fan,
                        "utilization_percent": util,
                        "driver_version": driver,
                    }
                )
                seen_names.append(name)
        except Exception as e:
            logger.warning(f"NVML collect failed: {e}")

    wmi_gpus = _get_wmi_gpu_static()
    for wg in wmi_gpus:
        wname = wg["name"]
        if any(_name_matches(wname, sn) for sn in seen_names):
            continue
        gpus.append(wg)
        seen_names.append(wname)

    if not gpus:
        return []

    dxgi = _dxgi_dedicated_vram()
    if dxgi:
        for g in gpus:
            for dxgi_name, vram in dxgi:
                if _name_matches(g["name"], dxgi_name) and vram > g["vram_total_mb"]:
                    g["vram_total_mb"] = vram
                    break

    has_util = any(g["utilization_percent"] > 0 for g in gpus)
    if not has_util:
        util = _get_intel_gpu_utilization()
        for g in gpus:
            if g["utilization_percent"] == 0:
                g["utilization_percent"] = util

    for g in gpus:
        if g.get("temperature_c", 0.0) == 0.0:
            try:
                from collectors.cpu import _cpu_temperature_c

                pkg_temp = _cpu_temperature_c()
                if pkg_temp:
                    g["temperature_c"] = pkg_temp
            except Exception:
                pass

    return gpus
