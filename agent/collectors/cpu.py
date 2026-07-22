import logging
import time

import psutil

import cpu_state

logger = logging.getLogger(__name__)

_freq_cache = None
_freq_cache_ts = 0.0
_FREQ_CACHE_TTL = 30.0

_temp_cache = None
_temp_cache_ts = 0.0
_TEMP_CACHE_TTL = 60.0


def _cpu_temperature_c() -> float | None:
    """Read CPU package temperature via WMI MSAcpi_ThermalZoneTemperature.

    Returns degrees Celsius, or None if unavailable.
    """
    try:
        import pythoncom

        pythoncom.CoInitializeEx(0)
    except Exception:
        pass
    try:
        import wmi

        c = wmi.WMI(namespace=r"root\wmi")
        zones = c.MSAcpi_ThermalZoneTemperature()
        if not zones:
            return None
        temps = []
        for z in zones:
            try:
                dk = int(z.CurrentTemperature)
                celsius = (dk / 10.0) - 273.15
                if 0 < celsius < 150:
                    temps.append(celsius)
            except (ValueError, AttributeError, TypeError):
                continue
        res = round(max(temps), 1) if temps else None
        del c, zones
        return res
    except Exception as e:
        logger.debug(f"CPU temperature via WMI failed: {e}")
        return None


def _cpu_throttled(freq) -> bool:
    """Detect throttling by comparing current freq against max.

    Returns True if current frequency is below 50% of max.
    """
    try:
        if freq and freq.max and freq.max > 0:
            ratio = freq.current / freq.max
            return ratio < 0.5
    except Exception:
        pass
    return False


def collect():
    """Collect CPU metrics from the monitor thread."""
    try:
        state = cpu_state.read_state()
        total = state["cpu_total"]
        per_core = state["cpu_per_core"]

        t0 = time.monotonic()
        global _freq_cache, _freq_cache_ts
        now = time.monotonic()
        if _freq_cache is None or (now - _freq_cache_ts) > _FREQ_CACHE_TTL:
            _freq_cache = psutil.cpu_freq()
            _freq_cache_ts = now
        freq = _freq_cache
        freq_mhz = round(freq.current) if freq else 0
        t1 = time.monotonic()
        if t1 - t0 > 0.5:
            logger.warning(f"CPU freq took {t1-t0:.2f}s")

        global _temp_cache, _temp_cache_ts
        now = time.monotonic()
        if _temp_cache is None or (now - _temp_cache_ts) > _TEMP_CACHE_TTL:
            _temp_cache = _cpu_temperature_c()
            _temp_cache_ts = now
        temp = _temp_cache

        return {
            "percent_total": round(total, 1),
            "percent_per_core": [round(v, 1) for v in per_core],
            "freq_mhz": freq_mhz,
            "core_count": psutil.cpu_count(logical=False) or 0,
            "thread_count": psutil.cpu_count(logical=True) or 0,
            "temperature_c": temp,
            "throttled": _cpu_throttled(freq),
        }
    except Exception:
        return {
            "percent_total": 0.0,
            "percent_per_core": [],
            "freq_mhz": 0,
            "core_count": 0,
            "thread_count": 0,
            "temperature_c": None,
            "throttled": False,
        }
