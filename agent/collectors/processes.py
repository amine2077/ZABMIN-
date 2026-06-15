import psutil

# Warmup call to initialize process cpu_percent values
for p in psutil.process_iter(['pid']):
    try:
        p.cpu_percent(interval=None)
    except (psutil.NoSuchProcess, psutil.AccessDenied, psutil.ZombieProcess):
        pass

_logical_cpu_count = psutil.cpu_count(logical=True) or 1


def collect():
    """Collect top 30 processes by CPU usage matching Task Manager."""
    try:
        procs = []
        for p in psutil.process_iter(
            ["pid", "name", "cpu_percent", "memory_info", "status", "net_connections"]
        ):
            try:
                info = p.info
                if not info["name"]:
                    continue

                raw_cpu = info["cpu_percent"] or 0.0

                # System Idle Process reports inverse of actual usage
                if info["name"].lower() == "system idle process":
                    cpu_percent = round((100.0 - raw_cpu) / _logical_cpu_count, 1)
                else:
                    cpu_percent = round(raw_cpu / _logical_cpu_count, 1)

                if cpu_percent == 0.0:
                    continue

                mem_mb = 0.0
                if info["memory_info"]:
                    mem_mb = round(info["memory_info"].rss / (1024**2), 1)

                connections = 0
                try:
                    conns = info["net_connections"]
                    if conns is not None:
                        connections = len(conns)
                except Exception:
                    connections = 0

                procs.append({
                    "pid": info["pid"] or 0,
                    "name": info["name"],
                    "cpu_percent": cpu_percent,
                    "memory_mb": mem_mb,
                    "status": info["status"] or "unknown",
                    "connections": connections,
                })
            except (psutil.NoSuchProcess, psutil.AccessDenied, psutil.ZombieProcess):
                continue

        procs.sort(key=lambda x: x["cpu_percent"], reverse=True)
        return procs[:30]
    except Exception:
        return []
