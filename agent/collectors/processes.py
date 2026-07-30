import heapq

import psutil

# Warmup call to initialize process cpu_percent values
for p in psutil.process_iter(["pid"]):
    try:
        p.cpu_percent(interval=None)
    except (psutil.NoSuchProcess, psutil.AccessDenied, psutil.ZombieProcess):
        pass

_logical_cpu_count = psutil.cpu_count(logical=True) or 1


def collect():
    """Collect top 30 processes by CPU usage matching Task Manager.

    Uses heapq.nlargest for efficient top-N selection. Does NOT call
    per-process net_connections() — that is available only through the
    on-demand get_process_connections command.
    """
    try:
        raw_procs = []
        for p in psutil.process_iter(
            ["pid", "ppid", "name", "cpu_percent", "memory_info", "status"]
        ):
            try:
                info = p.info
            except (psutil.NoSuchProcess, psutil.AccessDenied, psutil.ZombieProcess):
                continue
            try:
                if not info["name"]:
                    continue

                raw_cpu = info["cpu_percent"] or 0.0

                if info["name"].lower() == "system idle process":
                    continue

                cpu_percent = round(raw_cpu / _logical_cpu_count, 1)

                if cpu_percent == 0.0:
                    continue

                mem_mb = 0.0
                if info["memory_info"]:
                    mem_mb = round(info["memory_info"].rss / (1024**2), 1)

                raw_procs.append(
                    {
                        "pid": info["pid"] or 0,
                        "ppid": info["ppid"] or 0,
                        "name": info["name"],
                        "cpu_percent": cpu_percent,
                        "memory_mb": mem_mb,
                        "status": info["status"] or "unknown",
                        "connections": 0,
                    }
                )
            except (psutil.NoSuchProcess, psutil.AccessDenied, psutil.ZombieProcess):
                continue

        top30 = heapq.nlargest(30, raw_procs, key=lambda x: x["cpu_percent"])
        return top30
    except Exception:
        return []
