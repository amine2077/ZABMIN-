import time
import ctypes
import ctypes.wintypes
import psutil

_prev_io = {}
_prev_time = None
_kernel32 = ctypes.windll.kernel32

INVALID_HANDLE_VALUE = ctypes.c_void_p(-1).value
GENERIC_READ = 0x80000000
FILE_SHARE_READ = 0x00000001
FILE_SHARE_WRITE = 0x00000002
OPEN_EXISTING = 3
IOCTL_VOLUME_GET_VOLUME_DISK_EXTENTS = 0x00560000


class _DISK_EXTENT(ctypes.Structure):
    _fields_ = [
        ("DiskNumber", ctypes.wintypes.DWORD),
        ("StartingOffset", ctypes.c_longlong),
        ("ExtentLength", ctypes.c_longlong),
    ]


class _VOLUME_DISK_EXTENTS(ctypes.Structure):
    _fields_ = [
        ("NumberOfDiskExtents", ctypes.wintypes.DWORD),
        ("Extents", _DISK_EXTENT * 1),
    ]


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


def _get_physical_drive_number(mountpoint):
    """Open the volume and ask Windows which physical disk(s) back it."""
    vol_path = f"\\\\.\\{mountpoint.rstrip(chr(92))}"
    handle = _kernel32.CreateFileW(
        vol_path,
        GENERIC_READ,
        FILE_SHARE_READ | FILE_SHARE_WRITE,
        None,
        OPEN_EXISTING,
        0,
        None,
    )
    if handle == INVALID_HANDLE_VALUE or handle is None:
        return None
    try:
        out = ctypes.create_string_buffer(ctypes.sizeof(_VOLUME_DISK_EXTENTS) + 64)
        bytes_returned = ctypes.wintypes.DWORD(0)
        ok = _kernel32.DeviceIoControl(
            handle,
            IOCTL_VOLUME_GET_VOLUME_DISK_EXTENTS,
            None,
            0,
            out,
            ctypes.sizeof(out),
            ctypes.byref(bytes_returned),
            None,
        )
        if not ok:
            return None
        extents = ctypes.cast(out, ctypes.POINTER(_VOLUME_DISK_EXTENTS)).contents
        return int(extents.Extents[0].DiskNumber)
    except Exception:
        return None
    finally:
        try:
            _kernel32.CloseHandle(handle)
        except Exception:
            pass


def _is_real_partition(part):
    opts = (part.opts or "").lower()
    if "cdrom" in opts:
        return False
    fstype = (part.fstype or "").lower()
    if fstype in ("", "udf", "cdfs"):
        return False
    try:
        drive_type = _kernel32.GetDriveTypeW(part.mountpoint)
    except Exception:
        drive_type = 0
    if drive_type in (0, 1, 5):
        return False
    return True


def collect():
    """Collect disk metrics for every real partition with per-disk I/O speed."""
    global _prev_io, _prev_time

    try:
        partitions = []
        total_all = 0.0
        used_all = 0.0

        for part in psutil.disk_partitions(all=True):
            if not _is_real_partition(part):
                continue
            try:
                usage = psutil.disk_usage(part.mountpoint)
            except (PermissionError, OSError):
                continue

            total_gb = round(usage.total / (1024**3), 1)
            used_gb = round(usage.used / (1024**3), 1)
            free_gb = round(usage.free / (1024**3), 1)
            percent = round(usage.percent, 1)
            label = _get_volume_label(part.mountpoint)
            drive_num = _get_physical_drive_number(part.mountpoint)

            total_all += usage.total
            used_all += usage.used

            partitions.append(
                {
                    "device": part.device,
                    "mountpoint": part.mountpoint,
                    "label": label,
                    "filesystem": part.fstype,
                    "total_gb": total_gb,
                    "used_gb": used_gb,
                    "free_gb": free_gb,
                    "percent": percent,
                    "physical_drive": f"PhysicalDrive{drive_num}"
                    if drive_num is not None
                    else "",
                    "read_mb_s": 0.0,
                    "write_mb_s": 0.0,
                }
            )

        if total_all > 0:
            percent_all = round((used_all / total_all) * 100, 1)
        else:
            percent_all = 0.0

        total_gb_all = round(total_all / (1024**3), 1)
        used_gb_all = round(used_all / (1024**3), 1)

        now = time.monotonic()
        per_disk = psutil.disk_io_counters(perdisk=True) or {}

        if _prev_time is not None:
            dt = now - _prev_time
            if dt > 0 and per_disk:
                drive_speeds = {}
                for name, io in per_disk.items():
                    prev = _prev_io.get(name)
                    if prev is None:
                        continue
                    rb = (io.read_bytes - prev.read_bytes) / dt
                    wb = (io.write_bytes - prev.write_bytes) / dt
                    drive_speeds[name] = (
                        round(max(rb, 0) / (1024**2), 2),
                        round(max(wb, 0) / (1024**2), 2),
                    )
                for p in partitions:
                    pd = p["physical_drive"]
                    if pd and pd in drive_speeds:
                        p["read_mb_s"] = drive_speeds[pd][0]
                        p["write_mb_s"] = drive_speeds[pd][1]
                _prev_io = per_disk
            else:
                _prev_io = per_disk
        else:
            _prev_io = per_disk

        _prev_time = now

        read_total = sum(p["read_mb_s"] for p in partitions)
        write_total = sum(p["write_mb_s"] for p in partitions)

        return {
            "total_gb": total_gb_all,
            "used_gb": used_gb_all,
            "percent": percent_all,
            "read_mb_s": round(read_total, 2),
            "write_mb_s": round(write_total, 2),
            "partitions": partitions,
        }
    except Exception:
        _prev_io = {}
        _prev_time = None
        return {
            "total_gb": 0.0,
            "used_gb": 0.0,
            "percent": 0.0,
            "read_mb_s": 0.0,
            "write_mb_s": 0.0,
            "partitions": [],
        }
