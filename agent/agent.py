import asyncio
import json
import logging
import logging.handlers
import os
import secrets
import threading
import time
from urllib.parse import parse_qs, urlparse

import psutil
import websockets

import audit as _audit
import cpu_state
import database
import message_validation
import process_policy
import rate_limit
import runtime
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
    os.path.join(_logs_dir, "agent.log"), maxBytes=5 * 1024 * 1024, backupCount=3
)
_file_handler.setFormatter(logging.Formatter("%(asctime)s [%(levelname)s] %(message)s"))
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


def get_websocket_request_path(websocket) -> str | None:
    """Safely extract the request path from a websockets ServerConnection.

    Returns None if the request is not yet available (should not happen
    once the handler is called, but guard against it anyway).
    """
    if websocket.request is None:
        return None
    return websocket.request.path


def extract_token_from_request_path(request_path: str) -> str | None:
    """Extract the token query parameter from a WebSocket request path.

    Returns None if the parameter is missing or the path is malformed.
    """
    params = parse_qs(urlparse(request_path).query)
    return params.get("token", [None])[0]


def token_is_valid(token: str | None) -> bool:
    """Constant-time comparison of the provided token against the session token.

    Returns True only if token matches _SESSION_TOKEN.
    """
    if token is None:
        return False
    return secrets.compare_digest(token, _SESSION_TOKEN)


def _check_origin(websocket) -> tuple[bool, int | None, str | None]:
    """Check Host and Origin headers for extra hardening.

    Returns (ok, close_code, reason).
    """
    try:
        headers = websocket.request.headers
    except Exception:
        return True, None, None

    host = headers.get("host")
    if host is not None:
        if isinstance(host, bytes):
            host = host.decode()
        if not host.startswith("127.0.0.1:") and not host.startswith("localhost:"):
            return False, 4403, "forbidden"

    origin = headers.get("origin")
    if origin is not None:
        if isinstance(origin, bytes):
            origin = origin.decode()
        allowed = origin in (
            "http://localhost",
            "http://127.0.0.1",
            "file://",
        ) or origin.startswith(("http://localhost:", "http://127.0.0.1:"))
        if not allowed:
            return False, 4403, "forbidden"

    return True, None, None


def _get_safe_error_response(msg_type: str, msg: dict, error: str) -> dict | None:
    """Return a safe error response for a failed message, or None if no response."""
    request_id = msg.get("request_id")

    if msg_type == "kill_process":
        return {
            "type": "kill_result",
            "pid": msg.get("pid"),
            "request_id": request_id,
            "success": False,
            "error": error,
        }
    if msg_type == "set_priority":
        return {
            "type": "priority_result",
            "pid": msg.get("pid"),
            "request_id": request_id,
            "success": False,
            "error": error,
        }
    if msg_type == "get_process_connections":
        return {
            "type": "process_connections",
            "pid": msg.get("pid"),
            "request_id": request_id,
            "connections": [],
            "error": error,
        }
    if msg_type == "get_priority":
        return {
            "type": "priority_info",
            "pid": msg.get("pid"),
            "request_id": request_id,
            "priority": None,
            "error": error,
        }
    if msg_type == "get_history":
        return {
            "type": "history",
            "request_id": request_id,
            "data": [],
            "error": error,
        }
    return None


def _psutil_error_to_string(e: Exception) -> str:
    if isinstance(e, psutil.NoSuchProcess):
        return "process_not_found"
    if isinstance(e, psutil.ZombieProcess):
        return "process_not_found"
    if isinstance(e, psutil.AccessDenied):
        return "access_denied"
    return "internal_error"


def _handle_kill_process(msg: dict) -> dict:
    pid = msg["pid"]
    request_id = msg["request_id"]
    proc_name = process_policy.get_process_name_safe(pid)
    allowed, policy_error = process_policy.check_kill_allowed(pid)
    if not allowed:
        _audit.audit_event(
            "kill_process", pid, proc_name, request_id, "denied", policy_error
        )
        return _get_safe_error_response("kill_process", msg, policy_error)
    try:
        psutil.Process(pid).kill()
        _audit.audit_event("kill_process", pid, proc_name, request_id, "success")
        return {
            "type": "kill_result",
            "pid": pid,
            "request_id": request_id,
            "success": True,
        }
    except Exception as e:
        error = _psutil_error_to_string(e)
        _audit.audit_event("kill_process", pid, proc_name, request_id, "failed", error)
        return _get_safe_error_response("kill_process", msg, error)


def _handle_get_process_connections(msg: dict) -> dict:
    pid = msg["pid"]
    request_id = msg["request_id"]
    proc_name = process_policy.get_process_name_safe(pid)
    allowed, policy_error = process_policy.check_connections_allowed(pid)
    if not allowed:
        _audit.audit_event(
            "get_process_connections",
            pid,
            proc_name,
            request_id,
            "denied",
            policy_error,
        )
        return _get_safe_error_response("get_process_connections", msg, policy_error)
    try:
        conns = psutil.Process(pid).net_connections()
        conn_list = []
        for c in conns:
            local = f"{c.laddr.ip}:{c.laddr.port}" if c.laddr else "—"
            remote = f"{c.raddr.ip}:{c.raddr.port}" if c.raddr else "—"
            proto = "UDP" if c.type == 2 else "TCP"
            conn_list.append(
                {
                    "local_addr": local,
                    "remote_addr": remote,
                    "status": c.status or "UNKNOWN",
                    "protocol": proto,
                }
            )
        _audit.audit_event(
            "get_process_connections", pid, proc_name, request_id, "success"
        )
        return {
            "type": "process_connections",
            "pid": pid,
            "request_id": request_id,
            "connections": conn_list,
        }
    except Exception as e:
        error = _psutil_error_to_string(e)
        _audit.audit_event(
            "get_process_connections", pid, proc_name, request_id, "failed", error
        )
        return _get_safe_error_response("get_process_connections", msg, error)


def _handle_set_priority(msg: dict) -> dict:
    pid = msg["pid"]
    priority = msg["priority"]
    request_id = msg["request_id"]
    proc_name = process_policy.get_process_name_safe(pid)
    allowed, policy_error = process_policy.check_priority_allowed(pid)
    if not allowed:
        _audit.audit_event(
            "set_priority", pid, proc_name, request_id, "denied", policy_error
        )
        return _get_safe_error_response("set_priority", msg, policy_error)
    try:
        p = psutil.Process(pid)
        p.nice(priority)
        current = p.nice()
        _audit.audit_event("set_priority", pid, proc_name, request_id, "success")
        return {
            "type": "priority_result",
            "pid": pid,
            "request_id": request_id,
            "success": True,
            "priority": current,
        }
    except Exception as e:
        error = _psutil_error_to_string(e)
        _audit.audit_event("set_priority", pid, proc_name, request_id, "failed", error)
        return _get_safe_error_response("set_priority", msg, error)


def _handle_get_priority(msg: dict) -> dict:
    pid = msg["pid"]
    request_id = msg["request_id"]
    proc_name = process_policy.get_process_name_safe(pid)
    allowed, policy_error = process_policy.check_priority_allowed(pid)
    if not allowed:
        _audit.audit_event(
            "get_priority", pid, proc_name, request_id, "denied", policy_error
        )
        return _get_safe_error_response("get_priority", msg, policy_error)
    try:
        current = psutil.Process(pid).nice()
        _audit.audit_event("get_priority", pid, proc_name, request_id, "success")
        return {
            "type": "priority_info",
            "pid": pid,
            "request_id": request_id,
            "priority": current,
        }
    except Exception as e:
        error = _psutil_error_to_string(e)
        _audit.audit_event("get_priority", pid, proc_name, request_id, "failed", error)
        return _get_safe_error_response("get_priority", msg, error)


connected_clients = set()
_shutdown_event = asyncio.Event()

_SESSION_TOKEN: str = runtime.generate_token()

_RATE_LIMITER = rate_limit.RateLimiter(
    limits={
        "kill_process": 5,
        "set_priority": 10,
        "get_process_connections": 10,
        "get_priority": 20,
        "get_history": 20,
        "shutdown": 3,
    }
)

# TEMP: Day 1 baseline measurement, remove or replace with agent/collector_runner.py timing framework in Day 6
_collector_timing_counter = 0


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
        logger.debug(f"Collector {label} OK in {time.monotonic() - t0:.1f}s")
        return result
    except asyncio.TimeoutError:
        logger.warning(f"Collector {label} timed out (>{timeout}s)")
        return None
    except Exception as e:
        logger.warning(f"Collector {label} failed: {e}")
        return None


# TEMP: Day 1 baseline measurement, remove or replace with agent/collector_runner.py timing framework in Day 6
async def gather_metrics():
    """Collect all metrics in parallel threads. Only cpu+memory need COM init."""
    global _collector_timing_counter
    _timings = {}

    async def _timed(label, coro):
        t0 = time.monotonic()
        result = await coro
        _timings[label] = (time.monotonic() - t0) * 1000
        return result

    cpu_task = _timed("cpu", _run_in_thread(collect_cpu, "cpu", with_com=True))
    mem_task = _timed("memory", _run_in_thread(collect_memory, "memory", with_com=True))
    disk_task = _timed("disk", _run_in_thread(collect_disk, "disk"))
    net_task = _timed("network", _run_in_thread(collect_network, "network"))
    procs_task = _timed("processes", _run_in_thread(collect_processes, "processes"))
    gpu_task = _timed("gpu", _run_in_thread(collect_gpu, "gpu", with_com=True))
    battery_task = _timed("battery", _run_in_thread(collect_battery, "battery"))

    cpu, mem, disk, net, procs, gpu, battery = await asyncio.gather(
        cpu_task,
        mem_task,
        disk_task,
        net_task,
        procs_task,
        gpu_task,
        battery_task,
    )

    _collector_timing_counter += 1
    if _collector_timing_counter >= 10:
        _collector_timing_counter = 0
        logger.info(
            f"collector timings: cpu={_timings.get('cpu', 0):.0f}ms "
            f"mem={_timings.get('memory', 0):.0f}ms "
            f"disk={_timings.get('disk', 0):.0f}ms "
            f"net={_timings.get('network', 0):.0f}ms "
            f"proc={_timings.get('processes', 0):.0f}ms "
            f"gpu={_timings.get('gpu', 0):.0f}ms "
            f"batt={_timings.get('battery', 0):.0f}ms"
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
    request_path = get_websocket_request_path(websocket)
    if request_path is None:
        await websocket.close(code=4401, reason="unauthorized")
        return
    token = extract_token_from_request_path(request_path)
    if not token_is_valid(token):
        await websocket.close(code=4401, reason="unauthorized")
        return

    origin_ok, close_code, close_reason = _check_origin(websocket)
    if not origin_ok:
        await websocket.close(code=close_code, reason=close_reason)
        return

    connected_clients.add(websocket)
    logger.info(f"Client connected. Total: {len(connected_clients)}")
    try:
        async for raw_message in websocket:
            try:
                msg = json.loads(raw_message)
            except json.JSONDecodeError:
                await websocket.close(code=4400, reason="invalid_message")
                continue

            if not isinstance(msg, dict):
                await websocket.close(code=4400, reason="invalid_message")
                continue

            msg_type = msg.get("type")
            if not isinstance(msg_type, str):
                await websocket.close(code=4400, reason="invalid_message")
                continue

            if not message_validation.is_known_type(msg_type):
                logger.debug(f"Ignoring unknown message type: {msg_type}")
                continue

            ok, error = message_validation.validate_message(msg)
            if not ok:
                error_response = _get_safe_error_response(msg_type, msg, error)
                if error_response is not None:
                    await websocket.send(json.dumps(error_response))
                continue

            if not _RATE_LIMITER.allow(msg_type):
                _audit.audit_event(
                    msg_type,
                    msg.get("pid"),
                    None,
                    msg.get("request_id"),
                    "rate_limited",
                )
                error_response = _get_safe_error_response(msg_type, msg, "rate_limited")
                if error_response is not None:
                    await websocket.send(json.dumps(error_response))
                else:
                    logger.warning(f"{msg_type} rate limited, ignoring")
                continue

            if msg_type == "kill_process":
                response = _handle_kill_process(msg)
                await websocket.send(json.dumps(response))

            elif msg_type == "get_process_connections":
                response = _handle_get_process_connections(msg)
                await websocket.send(json.dumps(response))

            elif msg_type == "set_priority":
                response = _handle_set_priority(msg)
                await websocket.send(json.dumps(response))

            elif msg_type == "get_priority":
                response = _handle_get_priority(msg)
                await websocket.send(json.dumps(response))

            elif msg_type == "get_history":
                minutes = msg.get("duration_minutes")
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
                _audit.audit_event(
                    "shutdown", None, None, msg.get("request_id"), "success"
                )
                _shutdown_event.set()
                break

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
    _write_pid_file()
    try:
        perf_thread = threading.Thread(target=cpu_state.perf_monitor_loop, daemon=True)
        perf_thread.start()
        logger.info("Performance counter thread started")

        try:
            server = await websockets.serve(
                handler,
                "127.0.0.1",
                0,
                max_size=65536,
                max_queue=32,
                ping_interval=20,
                ping_timeout=20,
            )
        except OSError as e:
            reason = f"Failed to bind to 127.0.0.1: {e}"
            logger.error(reason)
            _write_status(False, reason)
            return
        except Exception as e:
            reason = f"Failed to start server: {e}"
            logger.error(reason)
            _write_status(False, reason)
            return

        port: int | None = None
        if server.sockets:
            port = server.sockets[0].getsockname()[1]
        if port is None:
            reason = "Server started but no socket is bound"
            logger.error(reason)
            _write_status(False, reason)
            server.close()
            return

        try:
            runtime.write_runtime(os.getpid(), port, _SESSION_TOKEN)
        except RuntimeError as e:
            logger.error(str(e))
            _write_status(False, str(e))
            server.close()
            return
        logger.info(f"Listening on 127.0.0.1:{port}")

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
        runtime.cleanup_runtime()
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
