import asyncio, json, websockets, time

async def t():
    t0 = time.monotonic()
    print(f"Connecting...")
    async with websockets.connect('ws://localhost:8765') as ws:
        print(f"Connected in {time.monotonic()-t0:.1f}s")
        msg = await asyncio.wait_for(ws.recv(), timeout=15)
        d = json.loads(msg)
        print(f"GOT v{d['version']} cpu={d['cpu']['percent_total']}% "
              f"temp={d['cpu']['temperature_c']} at {time.monotonic()-t0:.1f}s")
        print("SUCCESS!")

if __name__ == "__main__":
    asyncio.run(t())
