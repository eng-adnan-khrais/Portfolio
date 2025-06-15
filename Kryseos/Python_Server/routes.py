from fastapi import APIRouter, Form, WebSocket, WebSocketDisconnect
from fastapi.responses import JSONResponse
import threading
import uuid
import httpx
import asyncio
import json
import os
from cryptography.fernet import Fernet
from sqlalchemy.future import select
from models import User
from database import AsyncSessionLocal
from services import (
    user_locks, user_configs, user_threads, user_sockets,
    user_thread_function, user_credentials, user_feedback, user_running_flags,
    broadcast_feedback_to_user, send_bot_status
)
from TradeExecutor import analyze_trading_performance
import alpaca_trade_api as tradeapi

router = APIRouter()
fernet = Fernet(os.environ["FERNET_KEY"])

def encrypt(text: str) -> str:
    return fernet.encrypt(text.encode()).decode()

def decrypt(token: str) -> str:
    return fernet.decrypt(token.encode()).decode()

# 🔐 Validate Alpaca API keys
async def validate_alpaca_keys(api_key: str, api_secret: str, account: str) -> bool:
    url = f"{account}/v2/account"
    headers = {
        "APCA-API-KEY-ID": api_key,
        "APCA-API-SECRET-KEY": api_secret
    }
    try:
        async with httpx.AsyncClient() as client:
            response = await client.get(url, headers=headers, timeout=5)
            print("✅ Alpaca credentials validated")
            return response.status_code == 200
    except Exception:
        return False

@router.post("/login")
async def login(api_key: str = Form(...), api_secret: str = Form(...), account: str = Form(...)):
    if account not in ["https://paper-api.alpaca.markets", "https://live-api.alpaca.markets"]:
        return JSONResponse(content={"message": "Invalid account URL"}, status_code=400)

    is_valid = await validate_alpaca_keys(api_key, api_secret, account)
    if not is_valid:
        return JSONResponse(content={"message": "Invalid API keys. Please enter valid keys."}, status_code=401)

    enc_key = encrypt(api_key)
    enc_secret = encrypt(api_secret)

    async with AsyncSessionLocal() as session:
        result = await session.execute(select(User))
        users = result.scalars().all()

        user_id = None
        for user in users:
            try:
                if (
                    decrypt(user.api_key) == api_key and
                    decrypt(user.api_secret) == api_secret and
                    user.account == account
                ):
                    user_id = user.user_id
                    break
            except Exception:
                continue

        if user_id is None:
            user_id = str(uuid.uuid4())
            session.add(User(
                user_id=user_id,
                api_key=enc_key,
                api_secret=enc_secret,
                account=account,
                equity=[]
            ))
            await session.commit()

    if user_id not in user_locks:
        user_credentials[user_id] = {"api_key": api_key, "api_secret": api_secret, "account": account}
        user_feedback[user_id] = {}
        user_locks[user_id] = threading.Lock()
        user_configs[user_id] = None
        user_running_flags[user_id] = [False]
        user_sockets[user_id] = set()
        thread = threading.Thread(target=user_thread_function, args=(user_id,), daemon=True)
        thread.start()
        user_threads[user_id] = thread
        print(f"🟢 Initialized session and thread for user {user_id}")

    try:
        api = tradeapi.REST(api_key, api_secret, account, api_version="v2")
        feedback = await analyze_trading_performance(api, user_id)
        if feedback:
            user_feedback[user_id] = feedback
            await asyncio.sleep(1.5)
            await broadcast_feedback_to_user(user_id, feedback)

        is_running = user_running_flags.get(user_id, [False])[0]
        await send_bot_status(user_id, "Running" if is_running else "Stopped")
    except Exception:
        pass

    return JSONResponse(content={"message": "Login successful", "user_id": user_id}, status_code=200)


@router.post("/start-trading")
async def start_trading(user_id: str = Form(...), symbol: str = Form(...), strategy: int = Form(...), risk: float = Form(...), account: str = Form(...)):
    if user_id not in user_locks:
        return JSONResponse(content={"message": "Invalid user ID"}, status_code=401)

    with user_locks[user_id]:
        user_configs[user_id] = {
            "symbol": symbol,
            "strategy": strategy,
            "risk": risk,
            "account": account
        }

    print(f"▶️ Trading started for user {user_id}")
    await send_bot_status(user_id, "Running")
    return JSONResponse(content={"message": "Trading started", "user_id": user_id}, status_code=200)

@router.post("/stop-trading")
async def stop_trading(user_id: str = Form(...)):
    if user_id not in user_locks:
        return JSONResponse(content={"message": "Invalid user ID"}, status_code=401)

    with user_locks[user_id]:
        user_configs[user_id] = None

    print(f"⏹️ Trading stopped for user {user_id}")
    await send_bot_status(user_id, "Stopped")
    return JSONResponse(content={"message": "Trading stopped", "user_id": user_id}, status_code=200)

@router.websocket("/ws/{user_id}")
async def websocket_endpoint(websocket: WebSocket, user_id: str):
    await websocket.accept()
    user_sockets.setdefault(user_id, set()).add(websocket)

    if user_id in user_feedback and user_feedback[user_id]:
        try:
            await websocket.send_text(json.dumps({
                "type": "performance_update",
                "data": user_feedback[user_id]
            }))
        except Exception as e:
            print(f"❌ WebSocket error sending feedback: {e}")

    try:
        is_running = user_running_flags.get(user_id, [False])[0]
        await websocket.send_text(json.dumps({
            "type": "bot_status",
            "data": {"status": "Running" if is_running else "Stopped"}
        }))
    except Exception as e:
        print(f"❌ WebSocket error sending status: {e}")

    try:
        while True:
            await websocket.receive_text()
    except WebSocketDisconnect:
        user_sockets[user_id].discard(websocket)
        print(f"🔌 WebSocket disconnected for user {user_id}")

@router.post("/logout")
async def logout(user_id: str = Form(...)):
    if user_id in user_sockets:
        for ws in list(user_sockets[user_id]):
            try:
                await ws.close()
            except:
                pass
        user_sockets[user_id].clear()

    if user_id in user_configs:
        user_configs[user_id] = None
    if user_id in user_feedback:
        user_feedback[user_id] = {}
    if user_id in user_running_flags:
        user_running_flags[user_id][0] = False

    print(f"👋 User {user_id} logged out and memory cleared")
    return JSONResponse(content={"message": "Logout successful"}, status_code=200)
