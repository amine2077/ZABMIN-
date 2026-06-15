import psutil


def collect():
    """Collect memory metrics matching Task Manager."""
    try:
        mem = psutil.virtual_memory()
        used = mem.total - mem.available
        return {
            "total_gb": round(mem.total / (1024**3), 1),
            "used_gb": round(used / (1024**3), 1),
            "percent": round((used / mem.total) * 100, 1),
        }
    except Exception:
        return {
            "total_gb": 0.0,
            "used_gb": 0.0,
            "percent": 0.0,
        }
