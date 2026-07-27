"""Live agent smoke test. Requires agent running on port from runtime.json."""

import asyncio
import json
import os
from pathlib import Path

import websockets


def get_runtime() -> dict:
    path = Path(os.environ.get("LOCALAPPDATA", "")) / "Zabmin" / "runtime.json"
    if not path.exists():
        raise FileNotFoundError(f"runtime.json not found at {path}")
    return json.loads(path.read_text("utf-8"))


async def smoke_test():
    rt = get_runtime()
    port = rt["port"]
    token = rt["token"]
    uri = f"ws://127.0.0.1:{port}/?token={token}"

    print(f"Connecting to {uri}")
    async with websockets.connect(uri) as ws:
        # 1. Metrics broadcast should arrive within 5s
        print("\n--- 1. Waiting for metrics broadcast ---")
        msg = await asyncio.wait_for(ws.recv(), timeout=5.0)
        data = json.loads(msg)
        assert data.get("version") == 3, f"Expected version 3, got: {data}"
        assert "cpu" in data, "Expected cpu in metrics"
        print(f"  OK: metrics (v3) received, cpu={data['cpu'].get('percent_total')}%")

        # 2. Kill PID 0 (rejected by validation as invalid_pid)
        print("\n--- 2. Kill PID 0 (invalid) ---")
        req = {"type": "kill_process", "pid": 0, "request_id": 1001}
        await ws.send(json.dumps(req))
        resp = json.loads(await asyncio.wait_for(ws.recv(), timeout=5.0))
        assert resp.get("type") == "kill_result"
        assert resp.get("request_id") == 1001
        assert resp.get("pid") == 0
        assert resp.get("success") is False
        assert resp.get("error") == "invalid_pid"
        print(f"  OK: PID 0 -> {resp['error']}")

        # 3. Kill protected PID 4 (System process, hits policy)
        print("\n--- 3. Kill protected PID 4 (System) ---")
        req = {"type": "kill_process", "pid": 4, "request_id": 1007}
        await ws.send(json.dumps(req))
        resp = json.loads(await asyncio.wait_for(ws.recv(), timeout=5.0))
        assert resp.get("type") == "kill_result"
        assert resp.get("request_id") == 1007
        assert resp.get("pid") == 4
        assert resp.get("success") is False
        assert resp.get("error") == "protected_process"
        print(f"  OK: PID 4 -> {resp['error']}")

        # 4. Kill agent itself
        print("\n--- 4. Kill agent itself ---")
        req = {"type": "kill_process", "pid": rt["pid"], "request_id": 1002}
        await ws.send(json.dumps(req))
        resp = json.loads(await asyncio.wait_for(ws.recv(), timeout=5.0))
        assert resp.get("type") == "kill_result"
        assert resp.get("request_id") == 1002
        assert resp.get("pid") == rt["pid"]
        assert resp.get("success") is False
        assert resp.get("error") == "agent_process", (
            f"Expected agent_process, got {resp.get('error')}"
        )
        print(f"  OK: Self-kill -> {resp['error']}")

        # 5. Kill non-existent PID (99999)
        print("\n--- 5. Kill non-existent PID 99999 ---")
        req = {"type": "kill_process", "pid": 99999, "request_id": 1003}
        await ws.send(json.dumps(req))
        resp = json.loads(await asyncio.wait_for(ws.recv(), timeout=5.0))
        assert resp.get("type") == "kill_result"
        assert resp.get("request_id") == 1003
        assert resp.get("success") is False
        assert resp.get("error") == "process_not_found"
        print(f"  OK: PID 99999 kill -> {resp['error']}")

        # 6. Set priority on non-existent PID
        print("\n--- 6. Set priority on non-existent PID 99999 ---")
        req = {
            "type": "set_priority",
            "pid": 99999,
            "priority": 16384,
            "request_id": 1004,
        }
        await ws.send(json.dumps(req))
        resp = json.loads(await asyncio.wait_for(ws.recv(), timeout=5.0))
        assert resp.get("type") == "priority_result"
        assert resp.get("request_id") == 1004
        assert resp.get("success") is False
        assert resp.get("error") == "process_not_found"
        print(f"  OK: set_priority 99999 -> {resp['error']}")

        # 7. Get priority on agent itself
        print("\n--- 7. Get priority on agent itself ---")
        req = {"type": "get_priority", "pid": rt["pid"], "request_id": 1005}
        await ws.send(json.dumps(req))
        resp = json.loads(await asyncio.wait_for(ws.recv(), timeout=5.0))
        assert resp.get("type") == "priority_info"
        assert resp.get("request_id") == 1005
        assert resp.get("pid") == rt["pid"]
        assert resp.get("error") == "agent_process", (
            f"Expected agent_process, got {resp.get('error')}"
        )
        print(f"  OK: get_priority agent -> {resp['error']}")

        # 8. Get connections on non-existent PID
        print("\n--- 8. Get connections on non-existent PID 99999 ---")
        req = {"type": "get_process_connections", "pid": 99999, "request_id": 1006}
        await ws.send(json.dumps(req))
        resp = json.loads(await asyncio.wait_for(ws.recv(), timeout=5.0))
        assert resp.get("type") == "process_connections"
        assert resp.get("request_id") == 1006
        assert resp.get("pid") == 99999
        assert resp.get("error") == "process_not_found"
        print(f"  OK: connections 99999 -> {resp['error']}")

        # 9. Rate limiting (5 rapid kill requests)
        print("\n--- 9. Rate limiting ---")
        for i in range(6):
            req = {"type": "kill_process", "pid": 99999, "request_id": 1100 + i}
            await ws.send(json.dumps(req))
        rate_limited = False
        for i in range(6):
            resp = json.loads(await asyncio.wait_for(ws.recv(), timeout=5.0))
            if resp.get("error") == "rate_limited":
                rate_limited = True
                print(f"  OK: rate_limited at request_id={resp.get('request_id')}")
                break
        assert rate_limited, "Expected at least one rate_limited response"
        if not rate_limited:
            print("  FAIL: No rate_limited response received")

    print("\n=== All smoke tests passed ===")


if __name__ == "__main__":
    asyncio.run(smoke_test())
