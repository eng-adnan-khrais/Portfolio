import os
import pandas as pd
import numpy as np
import alpaca_trade_api as tradeapi
from binance.client import Client

# Alpaca API Credentials

def get_historical_data_HMA(lookback=65,symbol = "BTCUSDT"):
    
    if (symbol == "BTC/USD"):
        symbol = "BTCUSDT"
    elif(symbol == "ETH/USD"):
        symbol = "ETHUSDT"

    BINANCE_API_KEY = os.getenv("BINANCE_API_KEY", "")
    BINANCE_SECRET_KEY = os.getenv("BINANCE_SECRET_KEY", "")
    client = Client(BINANCE_API_KEY, BINANCE_SECRET_KEY)

    klines = client.get_klines(symbol=symbol, interval=Client.KLINE_INTERVAL_1DAY, limit=lookback)
    columns = ["timestamp", "open", "high", "low", "close", "volume", "close_time",
               "quote_asset_volume", "number_of_trades", "taker_buy_base", "taker_buy_quote", "ignore"]
    df = pd.DataFrame(klines, columns=columns)
    df["timestamp"] = pd.to_datetime(df["timestamp"], unit="ms")
    df[["open", "high", "low", "close", "volume"]] = df[["open", "high", "low", "close", "volume"]].astype(float)
    df.set_index("timestamp", inplace=True)
    df = df.sort_index()

    # HMA calculation
    length = 55
    sqrt_len = int(np.sqrt(length))
    half_len = length // 2

    # Step 1: WMA of close with length and half length
    weights_len = np.arange(1, length + 1)
    weights_half = np.arange(1, half_len + 1)
    wma_full = df['close'].rolling(length).apply(lambda x: np.dot(x, weights_len) / weights_len.sum(), raw=True)
    wma_half = df['close'].rolling(half_len).apply(lambda x: np.dot(x, weights_half) / weights_half.sum(), raw=True)

    # Step 2: 2*WMA(half) - WMA(full)
    raw_hull = 2 * wma_half - wma_full

    # Step 3: Final HMA = WMA of result with sqrt_len
    weights_sqrt = np.arange(1, sqrt_len + 1)
    df['HMA'] = raw_hull.rolling(sqrt_len).apply(lambda x: np.dot(x, weights_sqrt) / weights_sqrt.sum(), raw=True)

    return df

def check_signal_HMA(data):

    latest = data.iloc[-1]['HMA']
    prev = data.iloc[-3]['HMA']  # 2 bars ago

    if latest > prev:
        return "BUY"
    elif latest < prev:
        return "SELL"
    return None
