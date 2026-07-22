import asyncio, json, websockets

async def t():
    ws = await websockets.connect('ws://localhost:8765')
    msg = await asyncio.wait_for(ws.recv(), timeout=3)
    d = json.loads(msg)
    print('version:', d.get('version'))
    print('cpu keys:', list(d.get('cpu',{}).keys()))
    print('has battery:', 'battery' in d)
    await ws.close()
    await ws.wait_closed()

if __name__ == "__main__":
    asyncio.run(t())
