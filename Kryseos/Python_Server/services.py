import threading
import time
import asyncio
import json
from fastapi import WebSocket

import alpaca_trade_api as tradeapi
from tensorflow.keras.models import load_model

from Model_strategy_BTC_ETH import get_historical_data
from SMA import get_historical_data_SMA, check_signal_SMA
from MACD import get_historical_data_MACD, check_signal_MACD
from Hull import get_historical_data_HMA, check_signal_HMA
from SMAADX import get_historical_data_ADX, check_signal_ADX
from RSISMA50 import get_historical_data_RSI, check_signal_RSI
from TradeExecutor import trade, get_position
from TradeExecutor import analyze_trading_performance

# Persistent user data
user_credentials = {}
user_configs = {}
user_feedback = {}

# Runtime memory
user_threads = {}
user_locks = {}
user_sockets = {}
user_running_flags = {}

# Load ML model once
model_BTC = load_model("model-daily-MACD-BTC-25D.h5", compile=False)
model_ETH = load_model("model-daily-MACD-ETH-10D.h5", compile=False)


def interruptible_sleep(user_id: str, total_seconds: int, check_interval: int = 2):
    slept = 0
    while slept < total_seconds:
        if user_configs.get(user_id) is None:
            print(f"[sleep] interrupted for {user_id}")
            return
        time.sleep(check_interval)
        slept += check_interval


async def broadcast_feedback_to_user(user_id: str, feedback: dict):
    if user_id in user_sockets:
        for ws in list(user_sockets[user_id]):
            try:
                await send_feedback(ws, feedback)
            except Exception as e:
                print(f"[feedback] failed to send for {user_id}: {e}")


async def analyze_and_broadcast(api, user_id):
    try:
        feedback = await analyze_trading_performance(api, user_id)
        if feedback:
            user_feedback[user_id] = feedback
            await broadcast_feedback_to_user(user_id, feedback)
            print(f"[feedback] sent for {user_id}")
    except Exception as e:
        print(f"[feedback] analyze failed for {user_id}: {e}")


def user_thread_function(user_id):
    print(f"[thread] started for {user_id}")
    user_running_flags[user_id] = [False]
    api = None
    prev_config = None

    loop = asyncio.new_event_loop()
    asyncio.set_event_loop(loop)

    while True:
        try:
            config = user_configs.get(user_id)

            if config != prev_config:
                if config is not None:
                    creds = user_credentials.get(user_id)
                    if not creds:
                        time.sleep(5)
                        continue

                    api = tradeapi.REST(
                        creds["api_key"],
                        creds["api_secret"],
                        creds["account"],
                        api_version='v2'
                    )
                    user_running_flags[user_id][0] = True
                    prev_config = config

                    try:
                        feedback = loop.run_until_complete(analyze_trading_performance(api, user_id))
                        if feedback:
                            user_feedback[user_id] = feedback
                            loop.run_until_complete(broadcast_feedback_to_user(user_id, feedback))
                    except Exception as e:
                        print(f"[thread] initial feedback error for {user_id}: {e}")
                else:
                    if user_running_flags[user_id][0]:
                        print(f"[thread] stopped for {user_id}")
                        user_running_flags[user_id][0] = False
                        prev_config = None
                        api = None

            if user_running_flags[user_id][0] and config:
                strategy = int(config["strategy"])
                symbol = config["symbol"]
                risk = float(config["risk"])
                signal = "NONE"

                if strategy == 1:
                    arr_data, last_rsi = get_historical_data(symbol=symbol)
                    predict = 0
                    if symbol == "BTCUSD":
                        predict = model_BTC.predict(arr_data)
                        ris_UL = 83
                        ris_LL = 25
                    elif symbol == "ETHUSD":
                        predict = model_ETH.predict(arr_data)
                        ris_UL = 80
                        ris_LL = 15

                    if predict > 0 and last_rsi < ris_LL:
                        signal = "BUY"
                    elif predict < 0 and last_rsi > ris_UL:
                        signal = "SELL"

                elif strategy == 2:
                    df = get_historical_data_SMA(symbol=symbol)
                    signal = check_signal_SMA(df)
                elif strategy == 3:
                    df = get_historical_data_MACD(symbol=symbol)
                    signal = check_signal_MACD(df)
                elif strategy == 4:
                    df = get_historical_data_HMA(symbol=symbol)
                    signal = check_signal_HMA(df)
                elif strategy == 5:
                    df = get_historical_data_ADX(symbol=symbol)
                    signal = check_signal_ADX(df)
                elif strategy == 6:
                    df = get_historical_data_RSI(symbol=symbol)
                    signal = check_signal_RSI(df)
                elif strategy == 7:
                    signal = "BUY"
                    trade(api, signal, risk, symbol)
                    interruptible_sleep(user_id, 30)
                    signal = "SELL"
                    trade(api, signal, risk, symbol)
                    loop.run_until_complete(analyze_and_broadcast(api, user_id))
                    interruptible_sleep(user_id, 30)
                    continue
                else:
                    interruptible_sleep(user_id, 10)
                    continue

                trade(api, signal, risk, symbol)

                if signal == "SELL":
                    loop.run_until_complete(analyze_and_broadcast(api, user_id))

                sleep_times = {1: 86400, 2: 3600 * 16, 3: 3600 * 8, 4: 86400, 5: 86400, 6: 36000}
                interruptible_sleep(user_id, sleep_times.get(strategy, 30))

            time.sleep(2)

        except Exception as e:
            print(f"[thread] loop error for {user_id}: {e}")
            time.sleep(10)


async def send_feedback(websocket: WebSocket, message: dict):
    try:
        await websocket.send_text(json.dumps({
            "type": "performance_update",
            "data": message
        }))
    except Exception as e:
        print(f"[feedback] websocket send error: {e}")


async def send_bot_status(user_id: str, status: str):
    message = {
        "type": "bot_status",
        "data": {"status": status}
    }

    if user_id in user_sockets:
        for ws in list(user_sockets[user_id]):
            try:
                await ws.send_text(json.dumps(message))
                print(f"[bot status] sent '{status}' to {user_id}")
            except Exception as e:
                print(f"[bot status] send error for {user_id}: {e}")
