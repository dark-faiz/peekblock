import asyncio
import websockets

async def echo(websocket, path):
    print("Client connected!")
    try:
        async for message in websocket:
            print(f"Received: {message}")
            await websocket.send(f"Echo: {message}")
    except websockets.exceptions.ConnectionClosed:
        print("Client disconnected")

async def main():
    async with websockets.serve(echo, "0.0.0.0", 81):
        await asyncio.Future()  # Keep running forever

# Run the server
asyncio.run(main())
