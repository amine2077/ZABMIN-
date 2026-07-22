"""Test if asyncio.to_thread works in this process."""
import asyncio
import time

async def test():
    t0 = time.monotonic()
    result = await asyncio.wait_for(
        asyncio.to_thread(lambda: 42),
        timeout=2.0,
    )
    elapsed = time.monotonic() - t0
    print(f"to_thread(lambda: 42) = {result} in {elapsed:.2f}s")

    t0 = time.monotonic()
    result = await asyncio.wait_for(
        asyncio.to_thread(lambda: time.sleep(0.5) or 99),
        timeout=2.0,
    )
    elapsed = time.monotonic() - t0
    print(f"to_thread(sleep 0.5) = {result} in {elapsed:.2f}s")

if __name__ == "__main__":
    asyncio.run(test())
