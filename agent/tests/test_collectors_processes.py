"""Test processes collector — verifies CPU/core-count division, sorting, filtering."""
from unittest.mock import MagicMock, PropertyMock, patch

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
