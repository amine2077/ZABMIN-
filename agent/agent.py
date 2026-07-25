import asyncio
import json
import logging
import logging.handlers
import os
import threading
import time

import psutil
import websockets

import cpu_state
import database
from collectors.battery import collect as collect_battery
from collectors.cpu import collect as collect_cpu
from collectors.disk import collect as collect_disk
from collectors.gpu import collect as collect_gpu
from collectors.memory import collect as collect_memory
from collectors.network import collect as collect_network
from collectors.processes import collect as collect_processes

AGENT_DIR = os.path.dirname(os.path.abspath(__file__))
PID_FILE = os.path.join(AGENT_DIR, "agent.pid")
STATUS_FILE = os.path.join(AGENT_DIR, "agent_status.json")

logging.basicConfig(
    level=logging.INFO, format="%(asctime)s [%(levelname)s] %(message)s"
)
logger = logging.getLogger(__name__)

_logs_dir = os.path.join(AGENT_DIR, "logs")
os.makedirs(_logs_dir, exist_ok=True)
_file_handler = logging.handlers.RotatingFileHandler(
    os.path.join(_logs_dir, "agent.log"),
    maxBytes=5 * 1024 * 1024,
    backupCount=3,
)
_file_handler.setFormatter(
    logging.Formatter("%(asctime)s [%(levelname)s] %(message)s")
)
logging.getLogger().addHandler(_file_handler)


def _write_status(ok: bool, reason: str = ""):
    try:
        payload = {"ok": ok}
        if reason:
            payload["reason"] = reason
        with open(STATUS_FILE, "w", encoding="utf-8") as f:
            json.dump(payload, f)
    except Exception as e:
        logger.warning(f"Failed to write status file: {e}")


def _clear_status():
    try:
        if os.path.exists(STATUS_FILE):
            os.remove(STATUS_FILE)
    except OSError:
        pass


connected_clients = set()
_shutdown_event = asyncio.Event()


def _write_pid_file():
    try:
        with open(PID_FILE, "w", encoding="utf-8") as f:
            f.write(str(os.getpid()))
        logger.info(f"Wrote PID {os.getpid()} to {PID_FILE}")
    except Exception as e:
        logger.warning(f"Failed to write PID file: {e}")


def _run_with_com(fn):
    """Wrap a collector so asyncio.to_thread workers have COM initialized (required for WMI on Windows)."""

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


COLLECTOR_TIMEOUT = 10.0


async def _run_in_thread(fn, label, with_com=False, timeout=COLLECTOR_TIMEOUT):
    """Run a collector in a thread pool, optionally with COM init.

    Returns the collector result or None if it times out / fails.
    """
    wrapped = _run_with_com(fn) if with_com else fn
    try:
        t0 = time.monotonic()
        result = await asyncio.wait_for(
            asyncio.to_thread(wrapped),
            timeout=timeout,
        )
        logger.debug(f"Collector {label} OK in {time.monotonic()-t0:.1f}s")
        return result
    except asyncio.TimeoutError:
        logger.warning(f"Collector {label} timed out (>{timeout}s)")
        return None
    except Exception as e:
        logger.warning(f"Collector {label} failed: {e}")
        return None


async def gather_metrics():
    """Collect all metrics in parallel threads. Only cpu+memory need COM init."""
    cpu_task = _run_in_thread(collect_cpu, "cpu", with_com=True)
    mem_task = _run_in_thread(collect_memory, "memory", with_com=True)
    disk_task = _run_in_thread(collect_disk, "disk")
    net_task = _run_in_thread(collect_network, "network")
    procs_task = _run_in_thread(collect_processes, "processes")
    gpu_task = _run_in_thread(collect_gpu, "gpu", with_com=True)
    battery_task = _run_in_thread(collect_battery, "battery")

    cpu, mem, disk, net, procs, gpu, battery = await asyncio.gather(
        cpu_task,
        mem_task,
        disk_task,
        net_task,
        procs_task,
        gpu_task,
        battery_task,
    )
    payload = {
        "version": 3,
        "timestamp": int(time.time()),
        "cpu": cpu
        or {
            "percent_total": 0.0,
            "percent_per_core": [],
            "freq_mhz": 0,
            "core_count": 0,
            "thread_count": 0,
            "temperature_c": None,
            "throttled": False,
        },
        "memory": mem
        or {
            "total_gb": 0.0,
            "used_gb": 0.0,
            "percent": 0.0,
            "available_gb": 0.0,
            "cached_gb": 0.0,
        },
        "disk": disk
        or {
            "total_gb": 0.0,
            "used_gb": 0.0,
            "percent": 0.0,
            "read_mb_s": 0.0,
            "write_mb_s": 0.0,
        },
        "network": net
        or {
            "sent_mb_s": 0.0,
            "recv_mb_s": 0.0,
            "total_sent_gb": 0.0,
            "total_recv_gb": 0.0,
        },
        "processes": procs or [],
        "gpu": gpu or [],
    }
    if battery is not None:
        payload["battery"] = battery
    return payload


async def handler(websocket):
    connected_clients.add(websocket)
    logger.info(f"Client connected. Total: {len(connected_clients)}")
    try:
        async for raw_message in websocket:
            try:
                msg = json.loads(raw_message)
                msg_type = msg.get("type")

                if msg_type == "kill_process":
                    pid = msg.get("pid")
                    request_id = msg.get("request_id")
                    try:
                        psutil.Process(pid).kill()
                        await websocket.send(
                            json.dumps(
                                {
                                    "type": "kill_result",
                                    "pid": pid,
                                    "request_id": request_id,
                                    "success": True,
                                }
                            )
                        )
                    except (psutil.NoSuchProcess, psutil.AccessDenied) as e:
                        await websocket.send(
                            json.dumps(
                                {
                                    "type": "kill_result",
                                    "pid": pid,
                                    "request_id": request_id,
                                    "success": False,
                                    "error": str(e),
                                }
                            )
                        )

                elif msg_type == "get_process_connections":
                    pid = msg.get("pid")
                    request_id = msg.get("request_id")
                    try:
                        conns = psutil.Process(pid).net_connections()
                        conn_list = []
                        for c in conns:
                            local = f"{c.laddr.ip}:{c.laddr.port}" if c.laddr else "—"
                            remote = (
                                f"{c.raddr.ip}:{c.raddr.port}" if c.raddr else "—"
                            )
                            proto = "UDP" if c.type == 2 else "TCP"
                            conn_list.append(
                                {
                                    "local_addr": local,
                                    "remote_addr": remote,
                                    "status": c.status or "UNKNOWN",
                                    "protocol": proto,
                                }
                            )
                        await websocket.send(
                            json.dumps(
                                {
                                    "type": "process_connections",
                                    "pid": pid,
                                    "request_id": request_id,
                                    "connections": conn_list,
                                }
                            )
                        )
                    except (psutil.NoSuchProcess, psutil.AccessDenied) as e:
                        await websocket.send(
                            json.dumps(
                                {
                                    "type": "process_connections",
                                    "pid": pid,
                                    "request_id": request_id,
                                    "connections": [],
                                    "error": str(e),
                                }
                            )
                        )

                elif msg_type == "set_priority":
                    pid = msg.get("pid")
                    priority = msg.get("priority")
                    request_id = msg.get("request_id")
                    try:
                        p = psutil.Process(pid)
                        p.nice(priority)
                        current = p.nice()
                        await websocket.send(
                            json.dumps(
                                {
                                    "type": "priority_result",
                                    "pid": pid,
                                    "request_id": request_id,
                                    "success": True,
                                    "priority": current,
                                }
                            )
                        )
                    except (psutil.NoSuchProcess, psutil.AccessDenied, ValueError) as e:
                        await websocket.send(
                            json.dumps(
                                {
                                    "type": "priority_result",
                                    "pid": pid,
                                    "request_id": request_id,
                                    "success": False,
                                    "error": str(e),
                                }
                            )
                        )

                elif msg_type == "get_priority":
                    pid = msg.get("pid")
                    request_id = msg.get("request_id")
                    try:
                        current = psutil.Process(pid).nice()
                        await websocket.send(
                            json.dumps(
                                {
                                    "type": "priority_info",
                                    "pid": pid,
                                    "request_id": request_id,
                                    "priority": current,
                                }
                            )
                        )
                    except (psutil.NoSuchProcess, psutil.AccessDenied) as e:
                        await websocket.send(
                            json.dumps(
                                {
                                    "type": "priority_info",
                                    "pid": pid,
                                    "request_id": request_id,
                                    "priority": None,
                                    "error": str(e),
                                }
                            )
                        )

                elif msg_type == "get_history":
                    minutes = msg.get("duration_minutes", 60)
                    request_id = msg.get("request_id")
                    rows = await asyncio.to_thread(database.get_history, minutes)
                    await websocket.send(
                        json.dumps(
                            {
                                "type": "history",
                                "request_id": request_id,
                                "data": rows,
                            }
                        )
                    )

                elif msg_type == "shutdown":
                    logger.info("Shutdown requested via WebSocket")
                    _shutdown_event.set()
                    break

            except json.JSONDecodeError as e:
                logger.debug(f"Invalid JSON from client: {e}")
            except Exception as e:
                logger.error(f"Error handling message: {e}")
    except websockets.ConnectionClosed:
        pass
    except Exception:
        pass
    finally:
        connected_clients.discard(websocket)
        logger.info(f"Client disconnected. Total: {len(connected_clients)}")


async def broadcast_loop():
    db_counter = 0
    while not _shutdown_event.is_set():
        try:
            metrics = await gather_metrics()
            payload = json.dumps(metrics)
            if connected_clients:
                results = await asyncio.gather(
                    *[client.send(payload) for client in connected_clients],
                    return_exceptions=True,
                )
                for r in results:
                    if isinstance(r, Exception):
                        logger.warning(f"Send failed: {r}")
            db_counter += 1
            if db_counter >= 5:
                await asyncio.to_thread(database.insert_metrics, metrics)
                db_counter = 0
        except Exception as e:
            logger.error(f"Error collecting metrics: {e}")
        try:
            await asyncio.wait_for(_shutdown_event.wait(), timeout=1)
        except asyncio.TimeoutError:
            pass


async def main():
    logger.info("Starting Zabmin agent on ws://localhost:8765")
    _write_pid_file()
    try:
        perf_thread = threading.Thread(
            target=cpu_state.perf_monitor_loop, daemon=True
        )
        perf_thread.start()
        logger.info("Performance counter thread started")

        try:
            server = await websockets.serve(handler, "localhost", 8765)
        except OSError as e:
            errno = getattr(e, "winerror", None) or getattr(e, "errno", None)
            if errno == 10048:
                reason = "Port 8765 is already in use. Another agent may be running."
                logger.error(reason)
            else:
                reason = f"Failed to bind to port 8765: {e}"
                logger.error(reason)
            _write_status(False, reason)
            return
        except Exception as e:
            err_str = str(e).lower()
            if "10048" in err_str or "socket address" in err_str:
                reason = "Port 8765 is already in use. Another agent may be running."
                logger.error(reason)
            else:
                reason = f"Failed to start server: {e}"
                logger.error(reason)
            _write_status(False, reason)
            return

        _write_status(True)
        logger.info("Server started")
        try:
            broadcast_task = asyncio.create_task(broadcast_loop())
            await broadcast_task
        except asyncio.CancelledError:
            pass
        finally:
            server.close()
            await server.wait_closed()
            logger.info("Server closed")
    finally:
        _clear_status()
        try:
            os.remove(PID_FILE)
        except OSError:
            pass


if __name__ == "__main__":
    try:
        asyncio.run(main())
    except Exception as e:
        logger.exception("Fatal agent error")
        _write_status(False, str(e))
