import alpaca_trade_api as tradeapi
import pandas as pd
from binance.client import Client
import os



def get_historical_data_SMA(lookback=22,symbol = "BTCUSDT"):

    if (symbol == "BTC/USD"):
        symbol = "BTCUSDT"
    elif(symbol == "ETH/USD"):
        symbol = "ETHUSDT"

        
    BINANCE_API_KEY = os.getenv("BINANCE_API_KEY", "")
    BINANCE_SECRET_KEY = os.getenv("BINANCE_SECRET_KEY", "")
    client = Client(BINANCE_API_KEY, BINANCE_SECRET_KEY)

    # Fetch hourly klines since we will aggregate them into 16-hour candles.
    # To get 'lookback' number of 16H candles, we need at least lookback*16 hourly candles.
    klines = client.get_klines(symbol=symbol, interval=Client.KLINE_INTERVAL_1HOUR, limit=lookback*16)
    
    # Define column names returned by the Binance API
    columns = ["timestamp", "open", "high", "low", "close", "volume", "close_time",
               "quote_asset_volume", "number_of_trades", "taker_buy_base", "taker_buy_quote", "ignore"]
    df = pd.DataFrame(klines, columns=columns)

    # Convert timestamp to datetime and relevant columns to float
    df["timestamp"] = pd.to_datetime(df["timestamp"], unit="ms")
    df[["open", "high", "low", "close", "volume"]] = df[["open", "high", "low", "close", "volume"]].astype(float)

    # Set timestamp as index and sort by time
    df.set_index("timestamp", inplace=True)
    df = df.sort_index()

    # Resample to 16-hour candles
    df_resampled = df.resample("16h").agg({
        "open": "first",
        "high": "max",
        "low": "min",
        "close": "last",
        "volume": "sum"
    })

    # Add rolling averages
    df_resampled["9-day"] = df_resampled["close"].rolling(9).mean()
    df_resampled["21-day"] = df_resampled["close"].rolling(21).mean()

    return df_resampled

def check_signal_SMA(data):
    """Generates BUY/SELL signals based on moving averages."""
    latest = data.iloc[-1]
    prev = data.iloc[-2]

    if prev['9-day'] < prev['21-day'] and latest['9-day'] > latest['21-day']:
        return "BUY"
    elif prev['9-day'] > prev['21-day'] and latest['9-day'] < latest['21-day']:
        return "SELL"
    return None
