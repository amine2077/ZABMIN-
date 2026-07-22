"""Isolate which collector hangs when run via asyncio.to_thread with COM init."""
import sys, os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import asyncio
import cpu_state
import threading
import time

thread = threading.Thread(target=cpu_state.perf_monitor_loop, daemon=True)
thread.start()
time.sleep(2)

COLLECTORS = [
    ("cpu", "collectors.cpu", "collect"),
    ("memory", "collectors.memory", "collect"),
    ("disk", "collectors.disk", "collect"),
    ("network", "collectors.network", "collect"),
    ("processes", "collectors.processes", "collect"),
    ("gpu", "collectors.gpu", "collect"),
    ("battery", "collectors.battery", "collect"),
]

def _run_with_com(fn):
    def _inner():
        try:
            import pythoncom
            pythoncom.CoInitializeEx(0)
        except Exception:
            pass
        try:
            return fn()
        finally:
            try:
                import pythoncom
                pythoncom.CoUninitialize()
            except Exception:
                pass
    return _inner

async def test_one(mod_name, fn_name):
    mod = __import__(mod_name, fromlist=[fn_name])
    fn = getattr(mod, fn_name)
    try:
        result = await asyncio.wait_for(
            asyncio.to_thread(_run_with_com(fn)),
            timeout=5.0,
        )
        typ = type(result).__name__
        if isinstance(result, dict):
            print(f"  OK {mod_name}.{fn_name} -> dict[{len(result)} keys]")
        elif isinstance(result, list):
            print(f"  OK {mod_name}.{fn_name} -> list[{len(result)} items]")
        else:
            print(f"  OK {mod_name}.{fn_name} -> {typ}")
    except asyncio.TimeoutError:
        print(f"  HANG {mod_name}.{fn_name} (timeout 5s)")

async def main():
    for label, mod, fn in COLLECTORS:
        print(f"Testing {label}...")
        await test_one(mod, fn)

if __name__ == "__main__":
    asyncio.run(main())
