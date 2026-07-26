import os

import psutil

PROTECTED_PIDS = frozenset({0, 4})

PROTECTED_PROCESS_NAMES = frozenset(
    {
        "system",
        "registry",
        "smss.exe",
        "csrss.exe",
        "wininit.exe",
        "services.exe",
        "lsass.exe",
        "winlogon.exe",
    }
)


def is_protected_pid(pid: int) -> bool:
    return pid in PROTECTED_PIDS


def is_protected_process_name(name: str | None) -> bool:
    if name is None:
        return False
    base = os.path.basename(name).lower()
    return base in PROTECTED_PROCESS_NAMES


def is_agent_pid(pid: int) -> bool:
    return pid == os.getpid()


def get_process_name_safe(pid: int) -> str | None:
    try:
        return psutil.Process(pid).name()
    except Exception:
        return None


def _determine_error_when_name_unavailable(pid: int) -> str:
    try:
        psutil.Process(pid)
    except psutil.NoSuchProcess:
        return "process_not_found"
    except psutil.AccessDenied:
        return "access_denied"
    except psutil.ZombieProcess:
        return "process_not_found"
    except Exception:
        return "internal_error"
    return "access_denied"


def _check_allowed(pid: int) -> tuple[bool, str | None]:
    if is_protected_pid(pid):
        return False, "protected_process"
    if is_agent_pid(pid):
        return False, "agent_process"
    name = get_process_name_safe(pid)
    if name is None:
        return False, _determine_error_when_name_unavailable(pid)
    if is_protected_process_name(name):
        return False, "protected_process"
    return True, None


def check_kill_allowed(pid: int) -> tuple[bool, str | None]:
    return _check_allowed(pid)


def check_priority_allowed(pid: int) -> tuple[bool, str | None]:
    return _check_allowed(pid)


def check_connections_allowed(pid: int) -> tuple[bool, str | None]:
    return _check_allowed(pid)
