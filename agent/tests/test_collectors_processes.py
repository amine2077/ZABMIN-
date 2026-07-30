"""Test processes collector — verifies CPU/core-count division, sorting, filtering."""

from unittest.mock import MagicMock, PropertyMock, patch

import psutil
import pytest


def make_fake_proc(pid, name, cpu_percent, rss, status="running", ppid=0):
    p = MagicMock()
    info = {
        "pid": pid,
        "ppid": ppid,
        "name": name,
        "cpu_percent": cpu_percent,
        "memory_info": MagicMock(rss=rss) if rss else None,
        "status": status,
    }
    type(p).info = PropertyMock(return_value=info)
    return p


@pytest.fixture(autouse=True)
def mock_psutil():
    with patch("collectors.processes.psutil") as mock:
        procs = [
            make_fake_proc(1, "System", 0.0, 0),
            make_fake_proc(100, "chrome.exe", 80.0, 500 * 1024**2),
            make_fake_proc(200, "python.exe", 40.0, 200 * 1024**2),
            make_fake_proc(300, "system idle process", 90.0, 0),
            make_fake_proc(400, "notepad.exe", 10.0, 30 * 1024**2),
        ]
        mock.process_iter.return_value = procs
        mock.cpu_count.side_effect = lambda logical=True: 8 if logical else 4
        yield mock


def test_ppid_included():
    from collectors.processes import collect

    result = collect()
    assert len(result) > 0
    for p in result:
        assert "ppid" in p


def test_cpu_percent_divided_by_core_count():
    from collectors.processes import collect

    result = collect()
    for p in result:
        name = p["name"]
        if name == "chrome.exe":
            assert p["cpu_percent"] == 10.0  # 80 / 8
        elif name == "python.exe":
            assert p["cpu_percent"] == 5.0  # 40 / 8
        elif name == "notepad.exe":
            assert (
                p["cpu_percent"] == 1.2
            )  # 10 / 8 → round(1.25, 1) = 1.2 (banker's rounding)


def test_sort_by_cpu_descending():
    from collectors.processes import collect

    result = collect()
    cpus = [p["cpu_percent"] for p in result]
    assert cpus == sorted(cpus, reverse=True)


def test_system_idle_process_excluded():
    from collectors.processes import collect

    names = [p["name"] for p in collect()]
    assert "system idle process" not in names


def test_zero_cpu_processes_excluded():
    from collectors.processes import collect

    names = [p["name"] for p in collect()]
    assert "System" not in names


def test_top_30_limit():
    from collectors.processes import collect

    procs = [make_fake_proc(i, f"proc_{i}.exe", 10.0, 100 * 1024**2) for i in range(50)]
    with patch("collectors.processes.psutil.process_iter") as mock_iter:
        mock_iter.return_value = procs
        result = collect()
        assert len(result) <= 30


def test_heapq_nlargest_used():
    from collectors.processes import collect

    procs = [
        make_fake_proc(i, f"proc_{i}.exe", float(i), 100 * 1024**2) for i in range(50)
    ]
    with patch("collectors.processes.psutil.process_iter") as mock_iter:
        mock_iter.return_value = procs
        result = collect()
        cpus = [p["cpu_percent"] for p in result]
        expected = sorted(
            [round(float(i) / 8, 1) for i in range(50) if round(float(i) / 8, 1) > 0],
            reverse=True,
        )[:30]
        assert cpus == expected


def test_no_net_connections_called():
    from collectors.processes import collect

    procs = [make_fake_proc(1, "test.exe", 50.0, 100 * 1024**2)]
    with (
        patch("collectors.processes.psutil.process_iter") as mock_iter,
        patch("collectors.processes.psutil.Process.net_connections") as mock_nc,
    ):
        mock_iter.return_value = procs
        result = collect()
        assert len(result) == 1
        assert result[0]["connections"] == 0
        mock_nc.assert_not_called()


class _GoodProcess:
    def __init__(self, pid, name, cpu_percent, rss):
        self.pid = pid
        self._info = {
            "pid": pid,
            "ppid": 0,
            "name": name,
            "cpu_percent": cpu_percent,
            "memory_info": type("mem", (), {"rss": rss})(),
            "status": "running",
        }

    @property
    def info(self):
        return self._info

    def cpu_percent(self, interval=None):
        return 0.0


class _BadProcessNoSuch:
    pid = 999

    @property
    def info(self):
        raise psutil.NoSuchProcess(999)

    def cpu_percent(self, interval=None):
        return 0.0


class _BadProcessAccessDenied:
    pid = 999

    @property
    def info(self):
        raise psutil.AccessDenied(999)

    def cpu_percent(self, interval=None):
        return 0.0


def test_good_process_survives_no_such_process():
    """Good process survives when a bad process raises NoSuchProcess."""
    import collectors.processes as cp

    class _GM(MagicMock):
        pass

    class _BM(MagicMock):
        pass

    good = _GM()
    good.pid = 100
    type(good).info = PropertyMock(
        return_value={
            "pid": 100,
            "ppid": 0,
            "name": "good.exe",
            "cpu_percent": 50.0,
            "memory_info": MagicMock(rss=200 * 1024**2),
            "status": "running",
        }
    )

    bad = _BM()
    bad.pid = 999
    type(bad).info = PropertyMock(side_effect=psutil.NoSuchProcess(999))

    with (
        patch("collectors.processes.psutil.process_iter") as mock_iter,
    ):
        mock_iter.return_value = [bad, good]

        raw = []
        for p in cp.psutil.process_iter(["pid"]):
            try:
                info = p.info
            except (psutil.NoSuchProcess, psutil.AccessDenied, psutil.ZombieProcess):
                continue
            raw.append(info["pid"])

        assert 999 not in raw
        assert 100 in raw


def test_good_process_survives_access_denied():
    """Good process survives when bad process raises AccessDenied (inline)."""
    import collectors.processes as cp

    class _G(MagicMock):
        pass

    class _B(MagicMock):
        pass

    good = _G()
    good.pid = 100
    type(good).info = PropertyMock(
        return_value={
            "pid": 100,
            "ppid": 0,
            "name": "good.exe",
            "cpu_percent": 50.0,
            "memory_info": MagicMock(rss=200 * 1024**2),
            "status": "running",
        }
    )

    bad = _B()
    bad.pid = 999
    type(bad).info = PropertyMock(side_effect=psutil.AccessDenied(999))

    with patch("collectors.processes.psutil.process_iter") as mock_iter:
        mock_iter.return_value = [bad, good]
        raw = []
        for p in cp.psutil.process_iter(["pid"]):
            try:
                info = p.info
            except (psutil.NoSuchProcess, psutil.AccessDenied, psutil.ZombieProcess):
                continue
            raw.append(info["pid"])
        assert 999 not in raw
        assert 100 in raw


def test_good_process_survives_bad_memory_info():
    from collectors.processes import collect

    bad = make_fake_proc(999, "bad.exe", 50.0, None, status="running")
    bad.info = {
        "pid": 999,
        "ppid": 0,
        "name": "bad.exe",
        "cpu_percent": 50.0,
        "memory_info": None,
        "status": "running",
    }

    good = make_fake_proc(100, "good.exe", 50.0, 200 * 1024**2)

    with (
        patch("collectors.processes.psutil.process_iter", return_value=[bad, good]),
        patch("collectors.processes._logical_cpu_count", 1),
    ):
        result = collect()
        assert len(result) >= 1
        names = [p["name"] for p in result]
        assert "good.exe" in names


def test_fallback_on_exception():
    with patch("collectors.processes.psutil.process_iter") as mock_iter:
        mock_iter.side_effect = RuntimeError("process fail")
        from collectors.processes import collect

        result = collect()
        assert result == []


def test_connection_field_present():
    from collectors.processes import collect

    result = collect()
    assert len(result) > 0
    assert all("connections" in p for p in result)
    assert all(p["connections"] == 0 for p in result)
