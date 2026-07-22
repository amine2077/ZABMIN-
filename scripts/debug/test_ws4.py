import asyncio, json, websockets, time

async def t():
    t0 = time.monotonic()
    print(f"Connecting at {t0:.1f}...")
    ws = await websockets.connect('ws://localhost:8765')
    print(f"Connected in {time.monotonic()-t0:.1f}s")
    try:
        msg = await asyncio.wait_for(ws.recv(), timeout=15)
        d = json.loads(msg)
        print(f"GOT MESSAGE at {time.monotonic()-t0:.1f}s: cpu={d.get('cpu',{}).get('percent_total')}%")
    except asyncio.TimeoutError:
        print(f"TIMEOUT after {time.monotonic()-t0:.1f}s - no data received")
    await ws.close()
    await ws.wait_closed()

if __name__ == "__main__":
    asyncio.run(t())
