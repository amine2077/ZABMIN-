import psutil


def collect():
    try:
        bat = psutil.sensors_battery()
        if bat is None:
            return None
        return {
            "percent": round(bat.percent, 1),
            "power_plugged": bat.power_plugged,
            "secs_left": bat.secsleft if bat.secsleft > 0 else None,
        }
    except Exception:
        return None
