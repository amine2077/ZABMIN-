import asyncio
import json
import time
import logging
import threading
import psutil
import websockets

import cpu_state
from collectors.disk import collect as collect_disk
from collectors.network import collect as collect_network
from collectors.processes import collect as collect_processes

logging.basicConfig(level=logging.INFO, format="%(asctime)s [%(levelname)s] %(message)s")
logger = logging.getLogger(__name__)

connected_clients = set()


def _collect_cpu_threaded():
    state = cpu_state.read_state()
    try:
        freq = psutil.cpu_freq()
        freq_mhz = round(freq.current) if freq else 0
        return {
            "percent_total": state["cpu_total"],
            "percent_per_core": state["cpu_per_core"],
            "freq_mhz": freq_mhz,
            "core_count": psutil.cpu_count(logical=False) or 0,
            "thread_count": psutil.cpu_count(logical=True) or 0,
        }
    except Exception:
        return {
            "percent_total": state["cpu_total"],
            "percent_per_core": state["cpu_per_core"],
            "freq_mhz": 0,
            "core_count": 0,
            "thread_count": 0,
        }


def _collect_memory_threaded():
    state = cpu_state.read_state()
    return {
        "total_gb": state["ram_total_gb"],
        "used_gb": state["ram_used_gb"],
        "percent": state["ram_percent"],
    }


def gather_metrics():
    return {
        "timestamp": int(time.time()),
        "cpu": _collect_cpu_threaded(),
        "memory": _collect_memory_threaded(),
        "disk": collect_disk(),
        "network": collect_network(),
        "processes": collect_processes(),
    }


async def handler(websocket):
    connected_clients.add(websocket)
    logger.info(f"Client connected. Total: {len(connected_clients)}")
    try:
        async for _ in websocket:
            pass
    except websockets.ConnectionClosed:
        pass
    except Exception:
        pass
    finally:
        connected_clients.discard(websocket)
        logger.info(f"Client disconnected. Total: {len(connected_clients)}")


async def broadcast_loop():
    while True:
        try:
            metrics = gather_metrics()
            payload = json.dumps(metrics)
            if connected_clients:
                await asyncio.gather(
                    *[client.send(payload) for client in connected_clients],
                    return_exceptions=True,
                )
        except Exception as e:
            logger.error(f"Error collecting metrics: {e}")
        await asyncio.sleep(1)


async def main():
    logger.info("Starting Zabmin agent on ws://localhost:8765")

    perf_thread = threading.Thread(target=cpu_state.perf_monitor_loop, daemon=True)
    perf_thread.start()
    logger.info("Performance counter thread started")

    try:
        server = await websockets.serve(handler, "localhost", 8765)
    except OSError as e:
        errno = getattr(e, "winerror", None) or getattr(e, "errno", None)
        if errno == 10048:
            logger.error("Port 8765 is already in use. Another agent may be running.")
            logger.error("Run: taskkill /F /IM python.exe")
        else:
            logger.error(f"Failed to bind to port 8765: {e}")
        return
    except Exception as e:
        err_str = str(e).lower()
        if "10048" in err_str or "socket address" in err_str:
            logger.error("Port 8765 is already in use. Another agent may be running.")
            logger.error("Run: taskkill /F /IM python.exe")
        else:
            logger.error(f"Failed to start server: {e}")
        return

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


if __name__ == "__main__":
    asyncio.run(main())
