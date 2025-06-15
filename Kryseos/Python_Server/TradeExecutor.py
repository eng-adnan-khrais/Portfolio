from flask import Flask, request, jsonify
import threading
import time
import sys
import io
import alpaca_trade_api as tradeapi
from SMA import get_historical_data_SMA, check_signal_SMA
from MACD import get_historical_data_MACD, check_signal_MACD
from Hull import get_historical_data_HMA, check_signal_HMA
from SMAADX import get_historical_data_ADX, check_signal_ADX
from RSISMA50 import get_historical_data_RSI, check_signal_RSI
import math
import pandas as pd
import json
from sqlalchemy.future import select
from database import AsyncSessionLocal
from models import User

def get_alpaca_account_info(api):
    print("🔍 Fetching Alpaca account info")
    try:
        account = api.get_account()
        return {
            "user_id": account.account_number,
            "cash": float(account.cash),
            "currency": account.currency
        }
    except Exception as e:
        print(f"❌ Error fetching account info: {e}")
        return None

async def analyze_trading_performance(api, user_id):
    print(f"📊 Analyzing performance for user: {user_id}")
    try:
        account = api.get_account()
        current_equity = round(float(account.equity), 2)
        alpaca_user_id = account.account_number
        cash = float(account.cash)
        currency = account.currency

        async with AsyncSessionLocal() as session:
            result = await session.execute(select(User).where(User.user_id == user_id))
            user = result.scalar_one_or_none()

            if user is None:
                raise ValueError(f"User {user_id} not found in DB")

            equity_history = user.equity or []

            if not equity_history or round(equity_history[-1], 2) != current_equity:
                equity_history.append(current_equity)
                user.equity = equity_history
                await session.commit()
                print("📈 Equity updated")
            else:
                print("⚠️ Duplicate equity skipped")

        orders = api.list_orders(status='filled', limit=100)
        orders_data = []
        raw_sell_fill_times = []

        for o in orders:
            if o.filled_avg_price is None or o.submitted_at is None:
                continue

            if o.side.lower() == 'sell' and o.filled_at is not None:
                dt = pd.to_datetime(o.filled_at)
                if dt.tzinfo is None:
                    dt = dt.tz_localize("UTC")
                raw_sell_fill_times.append(dt)

            orders_data.append({
                'Side': o.side,
                'Price': float(o.filled_avg_price),
                'Time': pd.to_datetime(o.submitted_at)
            })

        df = pd.DataFrame(orders_data)
        if not df.empty and 'Time' in df.columns:
            df.sort_values('Time', inplace=True)
            df.reset_index(drop=True, inplace=True)
        else:
            print("⚠️ No valid orders found")
            df = pd.DataFrame(columns=["Side", "Price", "Time"])

        sell_fill_times = [
            dt.tz_convert(None).strftime("%b %d, %Y, %I:%M:%S %p")
            for dt in raw_sell_fill_times
        ]

        trade_profit_ratios = []
        last_trade_profit_ratio = 0.0
        i = 0
        while i < len(df) - 1:
            side1, price1 = df.loc[i, ['Side', 'Price']]
            side2, price2 = df.loc[i + 1, ['Side', 'Price']]

            if side1 != side2:
                buy_price = price1 if side1.lower() == 'buy' else price2
                sell_price = price2 if side1.lower() == 'buy' else price1
                ratio = (sell_price - buy_price) / sell_price
                trade_profit_ratios.append(ratio)
                last_trade_profit_ratio = ratio
                i += 2
            else:
                i += 1

        if len(equity_history) >= 2:
            total_profit = round(equity_history[-1] - equity_history[0], 2)
            profit_ratio = round(total_profit / equity_history[0], 4)
        else:
            total_profit = 0.0
            profit_ratio = 0.0

        winning_rate = (
            len([r for r in trade_profit_ratios if r > 0]) / len(trade_profit_ratios)
            if trade_profit_ratios else 0.0
        )
        num_trades = math.floor(len(df) / 2)

        print("✅ Performance metrics calculated")
        return {
            "alpaca_user_id": alpaca_user_id,
            "cash": cash,
            "currency": currency,
            "current_equity": current_equity,
            "equity_history": equity_history,
            "total_profit": total_profit,
            "profit_ratio": profit_ratio,
            "last_trade_profit_ratio": last_trade_profit_ratio,
            "trade_profit_ratios": trade_profit_ratios,
            "winning_rate": winning_rate,
            "num_trades": num_trades,
            "sell_fill_times": sell_fill_times
        }

    except Exception as e:
        print(f"❌ Error in performance analysis: {e}")
        return None

def get_position(api, symbol="BTCUSD"):
    try:
        symbol_no_slash = symbol.replace("/", "")
        position = float(api.get_position(symbol_no_slash).qty)
        return position
    except Exception as e:
        print(f"⚠️ No position or error for {symbol}: {e}")
        return 0

def trade(api, signal, risk=0.5, symbol="BTC/USD"):
    print(f"📤 Trade request | Signal: {signal} | Symbol: {symbol}")
    if signal:
        position = get_position(api, symbol)
        if symbol == "BTC/USD":
            price = api.get_latest_crypto_trades("BTC/USD")["BTC/USD"].p
        elif symbol == "ETH/USD":
            price = api.get_latest_crypto_trades("ETH/USD")["ETH/USD"].p

        cash = float(api.get_account().cash)
        quantity = (cash * risk) / price

        if signal == "BUY":
            if position == 0 and quantity > 0:
                print("🟢 Executing BUY")
                api.submit_order(
                    symbol=symbol,
                    qty=quantity,
                    side="buy",
                    type="market",
                    time_in_force="gtc"
                )

        elif signal == "SELL":
            if position > 0:
                print("🔴 Executing SELL")
                api.close_all_positions()

        print(f"✅ Trade complete | Signal: {signal}")
