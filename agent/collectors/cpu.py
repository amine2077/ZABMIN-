import logging

import psutil

import cpu_state

logger = logging.getLogger(__name__)


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
        if not temps:
            return None
        return round(max(temps), 1)
    except Exception as e:
        logger.debug(f"CPU temperature via WMI failed: {e}")
        return None
    finally:
        try:
            import pythoncom

            pythoncom.CoUninitialize()
        except Exception:
            pass


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
        freq = psutil.cpu_freq()
        freq_mhz = round(freq.current) if freq else 0
        return {
            "percent_total": round(total, 1),
            "percent_per_core": [round(v, 1) for v in per_core],
            "freq_mhz": freq_mhz,
            "core_count": psutil.cpu_count(logical=False) or 0,
            "thread_count": psutil.cpu_count(logical=True) or 0,
            "temperature_c": _cpu_temperature_c(),
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
