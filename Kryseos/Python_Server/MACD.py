import alpaca_trade_api as tradeapi
import pandas as pd
from binance.client import Client
import os

# Alpaca API Credentials

# Initialize Alpaca API


def get_historical_data_MACD(lookback=100,symbol="BTCUSDT"):

    if (symbol == "BTC/USD"):
        symbol = "BTCUSDT"
    elif(symbol == "ETH/USD"):
        symbol = "ETHUSDT"

    BINANCE_API_KEY = os.getenv("BINANCE_API_KEY", "")
    BINANCE_SECRET_KEY = os.getenv("BINANCE_SECRET_KEY", "")
    client = Client(BINANCE_API_KEY, BINANCE_SECRET_KEY)

     # Fetch historical Klines (candlestick) data
    klines = client.get_klines(symbol=symbol, interval=Client.KLINE_INTERVAL_8HOUR, limit=lookback)

    # Convert data into a DataFrame
    columns = ["timestamp", "open", "high", "low", "close", "volume", "close_time",
               "quote_asset_volume", "number_of_trades", "taker_buy_base", "taker_buy_quote", "ignore"]
    df = pd.DataFrame(klines, columns=columns)

    # Convert timestamp to datetime
    df["timestamp"] = pd.to_datetime(df["timestamp"], unit="ms")

    # Convert relevant columns to float
    df[["open", "high", "low", "close", "volume"]] = df[["open", "high", "low", "close", "volume"]].astype(float)

    # Set timestamp as index and sort
    df.set_index("timestamp", inplace=True)
    df = df.sort_index()

    # Calculate EMAs
    df["EMA-12"] = df["close"].ewm(span=12, adjust=False).mean()
    df["EMA-26"] = df["close"].ewm(span=26, adjust=False).mean()

    # Calculate MACD line
    df["MACD"] = df["EMA-12"] - df["EMA-26"]

    # Calculate Signal line (9-day EMA of MACD)
    df["Signal"] = df["MACD"].ewm(span=9, adjust=False).mean()

    return df

def check_signal_MACD(data):
    """Generates BUY/SELL signals based on moving averages."""
    latest = data.iloc[-1]
    prev = data.iloc[-2]

    if prev["MACD"] < prev["Signal"] and latest["MACD"] > latest["Signal"]:
        return "BUY"

    # SELL signal: MACD crosses below Signal line (bearish crossover)
    elif prev["MACD"] > prev["Signal"] and latest["MACD"] < latest["Signal"]:
        return "SELL"
