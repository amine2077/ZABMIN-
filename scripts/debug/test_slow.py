"""Measure what's slow in each collector."""
import sys, os, time
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import cpu_state
import threading
from collectors.cpu import _cpu_temperature_c, _cpu_throttled

if __name__ == "__main__":
    thread = threading.Thread(target=cpu_state.perf_monitor_loop, daemon=True)
    thread.start()
    time.sleep(2)

    state = cpu_state.read_state()
    t0 = time.monotonic()
    import psutil
    freq = psutil.cpu_freq()
    print(f"psutil.cpu_freq(): {time.monotonic()-t0:.2f}s - {freq}")

    t0 = time.monotonic()
    temp = _cpu_temperature_c()
    print(f"_cpu_temperature_c(): {time.monotonic()-t0:.2f}s - {temp}")

    t0 = time.monotonic()
    throttled = _cpu_throttled(freq)
    print(f"_cpu_throttled(): {time.monotonic()-t0:.2f}s - {throttled}")

    t0 = time.monotonic()
    per_core = state["cpu_per_core"]
    total = state["cpu_total"]
    print(f"state read: {time.monotonic()-t0:.2f}s")

    t0 = time.monotonic()
    name = freq.__class__.__name__
    print(f"freq attr: {time.monotonic()-t0:.2f}s - {name}")
