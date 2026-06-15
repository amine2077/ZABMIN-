import ctypes
import time
import threading
import psutil
import logging

logger = logging.getLogger(__name__)

_cpu_percent_total = 0.0
_cpu_percent_per_core: list[float] = []
_ram_percent = 0.0
_ram_used_gb = 0.0
_ram_total_gb = 0.0
_state_lock = threading.Lock()

PDH = ctypes.windll.pdh
PDH_HQUERY = ctypes.c_void_p()
PDH_HCOUNTER_CPU = ctypes.c_void_p()
PDH_HCOUNTER_RAM = ctypes.c_void_p()
PDH_FMT_DOUBLE = 0x00000200

class PDH_FMT_COUNTERVALUE_DOUBLE(ctypes.Structure):
    _fields_ = [
        ("CStatus", ctypes.c_long),
        ("doubleValue", ctypes.c_double),
    ]


def _init_perf_counters():
    PDH.PdhOpenQueryW(None, 0, ctypes.byref(PDH_HQUERY))
    PDH.PdhAddEnglishCounterW(
        PDH_HQUERY,
        r"\Processor Information(_Total)\% Processor Utility",
        0,
        ctypes.byref(PDH_HCOUNTER_CPU),
    )
    PDH.PdhAddEnglishCounterW(
        PDH_HQUERY,
        r"\Memory\% Committed Bytes In Use",
        0,
        ctypes.byref(PDH_HCOUNTER_RAM),
    )
    PDH.PdhCollectQueryData(PDH_HQUERY)
    time.sleep(1)


def _read_perf_counter(hcounter):
    value = PDH_FMT_COUNTERVALUE_DOUBLE()
    status = PDH.PdhGetFormattedCounterValue(hcounter, PDH_FMT_DOUBLE, None, ctypes.byref(value))
    if status == 0:
        return value.doubleValue
    return None


def perf_monitor_loop():
    global _cpu_percent_total, _cpu_percent_per_core, _ram_percent, _ram_used_gb, _ram_total_gb

    use_fallback = False
    try:
        _init_perf_counters()
    except Exception as e:
        logger.warning(f"Perf counters failed, falling back to psutil: {e}")
        use_fallback = True

    if use_fallback:
        _perf_monitor_loop_fallback()
        return

    psutil.cpu_percent(interval=None, percpu=True)

    while True:
        time.sleep(1)
        PDH.PdhCollectQueryData(PDH_HQUERY)
        time.sleep(0.05)

        cpu_val = _read_perf_counter(PDH_HCOUNTER_CPU)
        ram_val = _read_perf_counter(PDH_HCOUNTER_RAM)

        try:
            per_core = psutil.cpu_percent(interval=None, percpu=True)
        except Exception:
            per_core = []

        try:
            vm = psutil.virtual_memory()
            ram_total_gb = round(vm.total / (1024 ** 3), 1)
            ram_used_gb = round(vm.used / (1024 ** 3), 1)
        except Exception:
            ram_total_gb = 0.0
            ram_used_gb = 0.0

        with _state_lock:
            _cpu_percent_total = round(cpu_val, 1) if cpu_val is not None else 0.0
            _cpu_percent_per_core = [round(v, 1) for v in per_core]
            _ram_percent = round(ram_val, 1) if ram_val is not None else 0.0
            _ram_used_gb = ram_used_gb
            _ram_total_gb = ram_total_gb


def _perf_monitor_loop_fallback():
    global _cpu_percent_total, _cpu_percent_per_core, _ram_percent, _ram_used_gb, _ram_total_gb
    psutil.cpu_percent(interval=None)
    psutil.cpu_percent(interval=None, percpu=True)
    while True:
        time.sleep(1)
        total = psutil.cpu_percent(interval=None)
        per_core = psutil.cpu_percent(interval=None, percpu=True)
        vm = psutil.virtual_memory()
        with _state_lock:
            _cpu_percent_total = round(total, 1)
            _cpu_percent_per_core = [round(v, 1) for v in per_core]
            _ram_percent = round(vm.percent, 1)
            _ram_used_gb = round(vm.used / (1024 ** 3), 1)
            _ram_total_gb = round(vm.total / (1024 ** 3), 1)


def read_state():
    with _state_lock:
        return {
            "cpu_total": _cpu_percent_total,
            "cpu_per_core": list(_cpu_percent_per_core),
            "ram_percent": _ram_percent,
            "ram_used_gb": _ram_used_gb,
            "ram_total_gb": _ram_total_gb,
        }
