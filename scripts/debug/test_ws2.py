import asyncio, json, websockets, time

async def t():
    t0 = time.monotonic()
    ws = await websockets.connect('ws://localhost:8765')
    print(f"Connected in {time.monotonic()-t0:.1f}s")
    for i in range(5):
        msg = await asyncio.wait_for(ws.recv(), timeout=10)
        d = json.loads(msg)
        elapsed = time.monotonic() - t0
        gpu = d.get('gpu', [])
        if isinstance(gpu, list):
            gpu_status = f"{len(gpu)} gpus"
        else:
            gpu_status = "no gpu"
        procs = d.get('processes', [])
        if isinstance(procs, list):
            procs_status = f"{len(procs)} procs"
        else:
            procs_status = "no procs"
        print(f"[{elapsed:.1f}s] v{d['version']} cpu={d['cpu']['percent_total']}% {gpu_status} {procs_status}")
    await ws.close()
    await ws.wait_closed()
    print(f"Done in {time.monotonic()-t0:.1f}s")

if __name__ == "__main__":
    asyncio.run(t())
