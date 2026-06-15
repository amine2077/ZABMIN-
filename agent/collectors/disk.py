import time
import psutil

_prev_io = None
_prev_time = None


def collect():
    """Collect disk metrics using real elapsed time for delta."""
    global _prev_io, _prev_time

    try:
        usage = psutil.disk_usage("C:\\")
        total_gb = round(usage.total / (1024**3), 1)
        used_gb = round(usage.used / (1024**3), 1)
        percent = round(usage.percent, 1)

        now = time.monotonic()
        io = psutil.disk_io_counters()

        if _prev_io is not None and io is not None:
            dt = now - _prev_time
            if dt > 0:
                read_bytes = (io.read_bytes - _prev_io.read_bytes) / dt
                write_bytes = (io.write_bytes - _prev_io.write_bytes) / dt
                read_mb_s = round(read_bytes / (1024**2), 1)
                write_mb_s = round(write_bytes / (1024**2), 1)
            else:
                read_mb_s = 0.0
                write_mb_s = 0.0
        else:
            read_mb_s = 0.0
            write_mb_s = 0.0

        _prev_io = io
        _prev_time = now

        return {
            "total_gb": total_gb,
            "used_gb": used_gb,
            "percent": percent,
            "read_mb_s": read_mb_s,
            "write_mb_s": write_mb_s,
        }
    except Exception:
        _prev_io = None
        _prev_time = None
        return {
            "total_gb": 0.0,
            "used_gb": 0.0,
            "percent": 0.0,
            "read_mb_s": 0.0,
            "write_mb_s": 0.0,
        }
