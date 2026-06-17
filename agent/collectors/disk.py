import time
import ctypes
import ctypes.wintypes
import psutil

_prev_io = None
_prev_time = None
_kernel32 = ctypes.windll.kernel32


def _get_volume_label(mountpoint):
    try:
        buf = ctypes.create_unicode_buffer(261)
        result = _kernel32.GetVolumeInformationW(
            mountpoint, buf, 261, None, None, None, None, 0
        )
        if result and buf.value:
            return buf.value
    except Exception:
        pass
    return ""


def collect():
    """Collect disk metrics for all partitions with real elapsed time for delta."""
    global _prev_io, _prev_time

    try:
        partitions = []
        total_all = 0.0
        used_all = 0.0

        for part in psutil.disk_partitions(all=False):
            try:
                usage = psutil.disk_usage(part.mountpoint)
            except (PermissionError, OSError):
                continue

            total_gb = round(usage.total / (1024**3), 1)
            used_gb = round(usage.used / (1024**3), 1)
            free_gb = round(usage.free / (1024**3), 1)
            percent = round(usage.percent, 1)
            label = _get_volume_label(part.mountpoint)

            total_all += usage.total
            used_all += usage.used

            partitions.append({
                "device": part.device,
                "mountpoint": part.mountpoint,
                "label": label,
                "filesystem": part.fstype,
                "total_gb": total_gb,
                "used_gb": used_gb,
                "free_gb": free_gb,
                "percent": percent,
            })

        if total_all > 0:
            percent_all = round((used_all / total_all) * 100, 1)
        else:
            percent_all = 0.0

        total_gb_all = round(total_all / (1024**3), 1)
        used_gb_all = round(used_all / (1024**3), 1)

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
            "total_gb": total_gb_all,
            "used_gb": used_gb_all,
            "percent": percent_all,
            "read_mb_s": read_mb_s,
            "write_mb_s": write_mb_s,
            "partitions": partitions,
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
            "partitions": [],
        }
