import numpy as np
import pandas as pd
import os
import time
import alpaca_trade_api as tradeapi
from binance.client import Client


# Binance credentials (set in environment or directly here for testing)
BINANCE_API_KEY = os.getenv("BINANCE_API_KEY", "")
BINANCE_SECRET_KEY = os.getenv("BINANCE_SECRET_KEY", "")
client = Client(BINANCE_API_KEY, BINANCE_SECRET_KEY)

def get_historical_data_ADX(lookback=30,symbol = "BTCUSDT"):
    
    if (symbol == "BTC/USD"):
        symbol = "BTCUSDT"
    elif(symbol == "ETH/USD"):
        symbol = "ETHUSDT"
            
    klines = client.get_klines(symbol=symbol, interval=Client.KLINE_INTERVAL_1DAY, limit=lookback)

    columns = ["timestamp", "open", "high", "low", "close", "volume", "close_time",
               "quote_asset_volume", "number_of_trades", "taker_buy_base", "taker_buy_quote", "ignore"]
    df = pd.DataFrame(klines, columns=columns)
    df["timestamp"] = pd.to_datetime(df["timestamp"], unit="ms")
    df.set_index("timestamp", inplace=True)
    df[["open", "high", "low", "close", "volume"]] = df[["open", "high", "low", "close", "volume"]].astype(float)
    df = df.sort_index()

    # SMA calculation
    df['9-day'] = df['close'].rolling(9).mean()
    df['21-day'] = df['close'].rolling(21).mean()

    # ADX calculation
    df['TR'] = np.maximum.reduce([
        df['high'] - df['low'],
        abs(df['high'] - df['close'].shift(1)),
        abs(df['low'] - df['close'].shift(1))
    ])
    df['ATR'] = df['TR'].rolling(14).mean()
    df['+DM'] = np.where((df['high'] - df['high'].shift(1)) > (df['low'].shift(1) - df['low']),
                         np.maximum(df['high'] - df['high'].shift(1), 0), 0)
    df['-DM'] = np.where((df['low'].shift(1) - df['low']) > (df['high'] - df['high'].shift(1)),
                         np.maximum(df['low'].shift(1) - df['low'], 0), 0)
    df['+DI'] = 100 * (df['+DM'].rolling(14).mean() / df['ATR'])
    df['-DI'] = 100 * (df['-DM'].rolling(14).mean() / df['ATR'])
    df['DX'] = 100 * (abs(df['+DI'] - df['-DI']) / (df['+DI'] + df['-DI']))
    df['ADX'] = df['DX'].rolling(14).mean()

    return df

def check_signal_ADX(data):

    latest = data.iloc[-1]
    prev = data.iloc[-2]

    if prev['9-day'] < prev['21-day'] and latest['9-day'] > latest['21-day'] and latest['ADX'] > 20:
        return "BUY"
    elif prev['9-day'] > prev['21-day'] and latest['9-day'] < latest['21-day'] and latest['ADX'] > 20:
        return "SELL"
    return None
