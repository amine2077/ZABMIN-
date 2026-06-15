import time
import psutil

_prev_io = None
_prev_time = None


def collect():
    """Collect network metrics using real elapsed time for delta."""
    global _prev_io, _prev_time

    try:
        io = psutil.net_io_counters()
        total_sent_gb = round(io.bytes_sent / (1024**3), 1)
        total_recv_gb = round(io.bytes_recv / (1024**3), 1)

        now = time.monotonic()

        if _prev_io is not None:
            dt = now - _prev_time
            if dt > 0:
                sent_bytes = (io.bytes_sent - _prev_io.bytes_sent) / dt
                recv_bytes = (io.bytes_recv - _prev_io.bytes_recv) / dt
                sent_mb_s = round(sent_bytes / (1024**2), 1)
                recv_mb_s = round(recv_bytes / (1024**2), 1)
            else:
                sent_mb_s = 0.0
                recv_mb_s = 0.0
        else:
            sent_mb_s = 0.0
            recv_mb_s = 0.0

        _prev_io = io
        _prev_time = now

        return {
            "sent_mb_s": sent_mb_s,
            "recv_mb_s": recv_mb_s,
            "total_sent_gb": total_sent_gb,
            "total_recv_gb": total_recv_gb,
        }
    except Exception:
        _prev_io = None
        _prev_time = None
        return {
            "sent_mb_s": 0.0,
            "recv_mb_s": 0.0,
            "total_sent_gb": 0.0,
            "total_recv_gb": 0.0,
        }
