import asyncio, json, websockets, time

async def t():
    t0 = time.monotonic()
    ws = await websockets.connect('ws://localhost:8765')
    print(f"Connected in {time.monotonic()-t0:.1f}s")
    for i in range(3):
        msg = await asyncio.wait_for(ws.recv(), timeout=10)
        d = json.loads(msg)
        elapsed = time.monotonic() - t0
        gpu = d.get('gpu', [])
        procs = d.get('processes', [])
        print(f"[{elapsed:.1f}s] v{d['version']} cpu={d['cpu']['percent_total']}% "
              f"temp={d['cpu']['temperature_c']} procs={len(procs)} gpu={len(gpu)}")
    print("SUCCESS - agent is sending data!")
    await ws.close()
    await ws.wait_closed()

if __name__ == "__main__":
    asyncio.run(t())
