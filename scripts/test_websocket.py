#!/usr/bin/env python3
"""
WebSocket client example for Matching Engine
Subscribes to market data and trade feeds
"""

import asyncio
import websockets
import json

async def subscribe_market_data():
    uri = "ws://localhost:8081"
    print(f"Connecting to Market Data feed at {uri}...")
    
    try:
        async with websockets.connect(uri) as websocket:
            print("Connected to Market Data feed!")
            print("Waiting for order book updates...\n")
            
            while True:
                message = await websocket.recv()
                data = json.loads(message)
                
                print("=" * 60)
                print(f"Order Book Update - {data['symbol']}")
                print(f"Timestamp: {data['timestamp']}")
                print("-" * 60)
                
                print("BIDS:")
                for price, qty in data['bids'][:5]:
                    print(f"  {price:>10} : {qty}")
                
                print("\nASKS:")
                for price, qty in data['asks'][:5]:
                    print(f"  {price:>10} : {qty}")
                
                print("=" * 60)
                print()
                
    except Exception as e:
        print(f"Error: {e}")

async def subscribe_trades():
    uri = "ws://localhost:8082"
    print(f"Connecting to Trade feed at {uri}...")
    
    try:
        async with websockets.connect(uri) as websocket:
            print("Connected to Trade feed!")
            print("Waiting for trades...\n")
            
            while True:
                message = await websocket.recv()
                data = json.loads(message)
                
                print(f"TRADE: {data['symbol']} | "
                      f"Price: ${data['price']} | "
                      f"Qty: {data['quantity']} | "
                      f"Side: {data['aggressor_side']} | "
                      f"ID: {data['trade_id']}")
                
    except Exception as e:
        print(f"Error: {e}")

async def main():
    print("=" * 60)
    print("Matching Engine WebSocket Client")
    print("=" * 60)
    print()
    
    # Run both subscriptions concurrently
    await asyncio.gather(
        subscribe_market_data(),
        subscribe_trades()
    )

if __name__ == "__main__":
    try:
        asyncio.run(main())
    except KeyboardInterrupt:
        print("\nDisconnected")
