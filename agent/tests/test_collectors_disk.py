"""Test disk collector — verifies partition enumeration + delta I/O speed."""

from unittest.mock import patch

import pytest

_REAL_NOW = 2000.0


class FakePartition:
    def __init__(self, device, mountpoint, fstype, opts):
        self.device = device
        self.mountpoint = mountpoint
        self.fstype = fstype
        self.opts = opts


class FakeDiskUsage:
    def __init__(self, total, used, free, percent):
        self.total = total
        self.used = used
        self.free = free
        self.percent = percent


class FakeDiskIO:
    def __init__(self, read_bytes, write_bytes):
        self.read_bytes = read_bytes
        self.write_bytes = write_bytes


@pytest.fixture(autouse=True)
def reset_globals():
    """Reset module-level prev state before each test."""
    import collectors.disk as disk_mod

    disk_mod._prev_io = {}
    disk_mod._prev_time = None


@pytest.fixture(autouse=True)
def mock_kernel32():
    """Mock the kernel32 ctypes calls used for volume labels and drive types."""
    with patch("collectors.disk._kernel32") as mock:
        mock.GetVolumeInformationW.return_value = 1
        mock.GetDriveTypeW.return_value = 3
        mock.CreateFileW.return_value = 999
        mock.DeviceIoControl.return_value = 1
        mock.CloseHandle.return_value = None
        yield mock


def _make_standard_fake_io():
    return {
        "PhysicalDrive0": FakeDiskIO(
            read_bytes=100 * 1024**2, write_bytes=50 * 1024**2
        ),
    }


def _make_partitions():
    return [
        FakePartition(
            device="C:\\",
            mountpoint="C:\\",
            fstype="NTFS",
            opts="rw,fixed",
        ),
    ]


def _make_usages():
    total_bytes = 256 * 1024**3
    used_bytes = 128 * 1024**3
    return FakeDiskUsage(
        total=total_bytes,
        used=used_bytes,
        free=total_bytes - used_bytes,
        percent=50.0,
    )


def test_collect_first_tick_zero_speed():
    with (
        patch("collectors.disk.psutil.disk_partitions") as mock_parts,
        patch("collectors.disk.psutil.disk_usage") as mock_usage,
        patch("collectors.disk.psutil.disk_io_counters") as mock_io,
        patch("time.monotonic") as mock_time,
    ):
        mock_parts.return_value = _make_partitions()
        mock_usage.return_value = _make_usages()
        mock_io.return_value = _make_standard_fake_io()
        mock_time.return_value = _REAL_NOW

        from collectors.disk import collect

        result = collect()
        assert result["percent"] == 50.0
        assert len(result["partitions"]) == 1
        assert result["partitions"][0]["read_mb_s"] == 0.0
        assert result["partitions"][0]["write_mb_s"] == 0.0


def test_collect_second_tick_computes_speed():
    with (
        patch("collectors.disk.psutil.disk_partitions") as mock_parts,
        patch("collectors.disk.psutil.disk_usage") as mock_usage,
        patch("collectors.disk.psutil.disk_io_counters") as mock_io,
        patch("time.monotonic") as mock_time,
    ):
        mock_parts.return_value = _make_partitions()
        mock_usage.return_value = _make_usages()
        mock_time.side_effect = [_REAL_NOW, _REAL_NOW + 3.0]

        io_first = _make_standard_fake_io()
        io_second = {
            "PhysicalDrive0": FakeDiskIO(
                read_bytes=250 * 1024**2, write_bytes=80 * 1024**2
            ),
        }
        mock_io.side_effect = [io_first, io_second]

        from collectors.disk import collect

        collect()
        result = collect()
        dt = 3.0
        read_delta = (250 - 100) * 1024**2
        write_delta = (80 - 50) * 1024**2
        expected_read_mb_s = round(read_delta / dt / (1024**2), 2)
        expected_write_mb_s = round(write_delta / dt / (1024**2), 2)
        assert result["partitions"][0]["read_mb_s"] == expected_read_mb_s
        assert result["partitions"][0]["write_mb_s"] == expected_write_mb_s


def test_cdrom_partition_excluded():
    with (
        patch("collectors.disk.psutil.disk_partitions") as mock_parts,
        patch("collectors.disk.psutil.disk_usage") as mock_usage,
        patch("collectors.disk.psutil.disk_io_counters") as mock_io,
        patch("time.monotonic") as mock_time,
    ):
        mock_parts.return_value = [
            FakePartition(
                device="D:\\",
                mountpoint="D:\\",
                fstype="UDF",
                opts="rw,cdrom",
            ),
        ]
        mock_usage.return_value = _make_usages()
        mock_io.return_value = {}
        mock_time.return_value = _REAL_NOW

        from collectors.disk import collect

        result = collect()
        assert len(result["partitions"]) == 0


def test_fallback_on_exception():
    with (
        patch("collectors.disk.psutil.disk_partitions") as mock_parts,
        patch("time.monotonic") as mock_time,
    ):
        mock_parts.side_effect = RuntimeError("disk fail")
        mock_time.return_value = _REAL_NOW

        from collectors.disk import collect

        result = collect()
        assert result["total_gb"] == 0.0
        assert result["partitions"] == []


def test_aggregate_totals():
    partitions = [
        FakePartition(device="C:\\", mountpoint="C:\\", fstype="NTFS", opts="rw,fixed"),
        FakePartition(device="D:\\", mountpoint="D:\\", fstype="NTFS", opts="rw,fixed"),
    ]
    c_usage = FakeDiskUsage(
        total=256 * 1024**3, used=128 * 1024**3, free=128 * 1024**3, percent=50.0
    )
    d_usage = FakeDiskUsage(
        total=512 * 1024**3, used=256 * 1024**3, free=256 * 1024**3, percent=50.0
    )
    with (
        patch("collectors.disk.psutil.disk_partitions") as mock_parts,
        patch("collectors.disk.psutil.disk_usage") as mock_usage,
        patch("collectors.disk.psutil.disk_io_counters") as mock_io,
        patch("time.monotonic") as mock_time,
    ):
        mock_parts.return_value = partitions
        mock_usage.side_effect = [c_usage, d_usage]
        mock_io.return_value = {}
        mock_time.return_value = _REAL_NOW

        from collectors.disk import collect

        result = collect()
        assert result["total_gb"] == pytest.approx((256 + 512) / 1, rel=1e-3)
        assert result["used_gb"] == pytest.approx((128 + 256) / 1, rel=1e-3)
        assert result["percent"] == pytest.approx(50.0, rel=1e-3)
