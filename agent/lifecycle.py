import logging
import os
import sys

logger = logging.getLogger(__name__)

MUTEX_NAME = "Local\\ZabminAgent"

_HAS_CTYPES = hasattr(sys, "getwindowsversion") or os.name == "nt"


if _HAS_CTYPES:
    import ctypes
    from ctypes import wintypes

    _kernel32 = ctypes.windll.kernel32

    _CreateMutexW = _kernel32.CreateMutexW
    _CreateMutexW.restype = wintypes.HANDLE
    _CreateMutexW.argtypes = [
        ctypes.c_void_p,
        wintypes.BOOL,
        wintypes.LPCWSTR,
    ]

    _ReleaseMutex = _kernel32.ReleaseMutex
    _ReleaseMutex.restype = wintypes.BOOL
    _ReleaseMutex.argtypes = [wintypes.HANDLE]

    _CloseHandle = _kernel32.CloseHandle
    _CloseHandle.restype = wintypes.BOOL
    _CloseHandle.argtypes = [wintypes.HANDLE]

    _GetLastError = _kernel32.GetLastError
    _GetLastError.restype = wintypes.DWORD
    _GetLastError.argtypes = []

    ERROR_ALREADY_EXISTS = 0x000000B7


def acquire_agent_mutex():
    if not _HAS_CTYPES:
        return None
    try:
        handle = _CreateMutexW(None, True, MUTEX_NAME)
        if not handle or handle == 0:
            raise RuntimeError("CreateMutexW returned NULL")
        err = _GetLastError()
        if err == ERROR_ALREADY_EXISTS:
            return handle, True
        return handle, False
    except Exception as e:
        logger.warning(f"Mutex acquisition failed (non-Windows or missing ctypes): {e}")
        return None


def release_agent_mutex(handle):
    if not _HAS_CTYPES or handle is None:
        return
    try:
        _ReleaseMutex(handle)
        _CloseHandle(handle)
    except Exception:
        pass


def is_pid_alive(pid: int) -> bool:
    if not isinstance(pid, int) or pid <= 0:
        return False
    try:
        import psutil

        return psutil.pid_exists(pid)
    except Exception:
        return False


def is_zabmin_agent_process(pid: int) -> bool:
    try:
        import psutil

        p = psutil.Process(pid)
        name = (p.name() or "").lower()
        cmdline = " ".join(p.cmdline()).lower() if p.cmdline() else ""
        if "python" in name and ("agent.py" in cmdline or "zabmin-agent" in cmdline):
            return True
        return "zabmin-agent" in name
    except Exception:
        return False


def get_process_command_line(pid: int) -> str:
    try:
        import psutil

        p = psutil.Process(pid)
        return " ".join(p.cmdline()).lower() if p.cmdline() else ""
    except Exception:
        return ""


def is_runtime_valid(runtime_data: dict | None) -> bool:
    if not isinstance(runtime_data, dict):
        return False
    pid = runtime_data.get("pid")
    port = runtime_data.get("port")
    token = runtime_data.get("token")
    if not isinstance(pid, int) or pid <= 0:
        return False
    if not isinstance(port, int) or port <= 0 or port > 65535:
        return False
    if not isinstance(token, str) or len(token) < 8:
        return False
    return is_pid_alive(pid) and is_zabmin_agent_process(pid)
