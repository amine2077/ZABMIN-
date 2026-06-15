import psutil

from cpu_state import get_cpu_data


def collect():
    """Collect CPU metrics from the monitor thread."""
    try:
        total, per_core = get_cpu_data()
        freq = psutil.cpu_freq()
        freq_mhz = round(freq.current) if freq else 0
        return {
            "percent_total": round(total, 1),
            "percent_per_core": [round(v, 1) for v in per_core],
            "freq_mhz": freq_mhz,
            "core_count": psutil.cpu_count(logical=False) or 0,
            "thread_count": psutil.cpu_count(logical=True) or 0,
        }
    except Exception:
        return {
            "percent_total": 0.0,
            "percent_per_core": [],
            "freq_mhz": 0,
            "core_count": 0,
            "thread_count": 0,
        }
