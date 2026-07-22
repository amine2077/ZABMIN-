"""Isolate whether COM init or threading causes the hang."""
import sys, os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import asyncio
import cpu_state
import threading
import time

thread = threading.Thread(target=cpu_state.perf_monitor_loop, daemon=True)
thread.start()
time.sleep(2)

from collectors import processes as pmod
from collectors import gpu as gmod

def test_no_com(fn, label):
    t0 = time.monotonic()
    try:
        fn()
        print(f"  {label} no-COM: OK ({time.monotonic()-t0:.1f}s)")
    except Exception as e:
        print(f"  {label} no-COM: ERROR {e} ({time.monotonic()-t0:.1f}s)")

def test_with_com(fn, label):
    def _wrapped():
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
    t0 = time.monotonic()
    try:
        _wrapped()
        print(f"  {label} w/COM: OK ({time.monotonic()-t0:.1f}s)")
    except Exception as e:
        print(f"  {label} w/COM: ERROR {e} ({time.monotonic()-t0:.1f}s)")

if __name__ == "__main__":
    import concurrent.futures

    for label, fn in [("processes", pmod.collect), ("gpu", gmod.collect)]:
        for test_fn, desc in [(test_no_com, "no COM"), (test_with_com, "w/ COM")]:
            with concurrent.futures.ThreadPoolExecutor(max_workers=1) as ex:
                fut = ex.submit(test_fn, fn, f"{label} {desc}")
                try:
                    fut.result(timeout=5.0)
                except concurrent.futures.TimeoutError:
                    print(f"  {label} {desc}: HANG (>5s)")
                except Exception as e:
                    print(f"  {label} {desc}: FAIL {e}")
