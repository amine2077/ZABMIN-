import logging

import psutil

logger = logging.getLogger(__name__)

_ram_speed_mhz = 0
_speed_queried = False


def _get_ram_speed():
    global _ram_speed_mhz, _speed_queried
    if _speed_queried:
        return _ram_speed_mhz
    _speed_queried = True
    try:
        import wmi

        c = wmi.WMI()
        speeds = []
        for stick in c.Win32_PhysicalMemory():
            if stick.ConfiguredClockSpeed:
                speeds.append(int(stick.ConfiguredClockSpeed))
        if speeds:
            _ram_speed_mhz = max(speeds)
    except Exception as e:
        logger.warning(f"WMI RAM speed query failed: {e}")
    return _ram_speed_mhz


def collect():
    """Collect memory metrics matching Task Manager, with extra details."""
    try:
        mem = psutil.virtual_memory()
        used = mem.total - mem.available
        return {
            "total_gb": round(mem.total / (1024**3), 1),
            "used_gb": round(used / (1024**3), 1),
            "percent": round((used / mem.total) * 100, 1),
            "available_gb": round(mem.available / (1024**3), 1),
            "cached_gb": round(getattr(mem, "cached", 0) / (1024**3), 1),
            "speed_mhz": _get_ram_speed(),
        }
    except Exception:
        return {
            "total_gb": 0.0,
            "used_gb": 0.0,
            "percent": 0.0,
            "available_gb": 0.0,
            "cached_gb": 0.0,
            "speed_mhz": 0,
        }
