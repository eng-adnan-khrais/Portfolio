import alpaca_trade_api as tradeapi
import pandas as pd
import numpy as np
from binance.client import Client
import os


def get_historical_data_RSI(lookback=50,symbol = "BTCUSDT"):
    
    if (symbol == "BTC/USD"):
        symbol = "BTCUSDT"
    elif(symbol == "ETH/USD"):
        symbol = "ETHUSDT"


    BINANCE_API_KEY = os.getenv("BINANCE_API_KEY", "")
    BINANCE_SECRET_KEY = os.getenv("BINANCE_SECRET_KEY", "")
    client = Client(BINANCE_API_KEY, BINANCE_SECRET_KEY)

    # Fetch hourly klines since we will aggregate them into 10-hour candles.
    # To get 'lookback' number of 10H candles, we need at least lookback*10 hourly candles.
    klines = client.get_klines(symbol=symbol, interval=Client.KLINE_INTERVAL_1HOUR, limit=lookback*10)
    
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

    # Resample to 10-hour candles
    df_resampled = df.resample("10h").agg({
        "open": "first",
        "high": "max",
        "low": "min",
        "close": "last",
        "volume": "sum"
    })


    # Compute RSI (period=14) on the 10-hour candles
    period = 14
    delta = df_resampled['close'].diff()
    gain = delta.where(delta > 0, 0)
    loss = -delta.where(delta < 0, 0)
    avg_gain = gain.rolling(window=period).mean()
    avg_loss = loss.rolling(window=period).mean()
    RS = avg_gain / avg_loss
    df_resampled['RSI'] = 100 - (100 / (1 + RS))

    # Compute a 50-period SMA on the 10-hour candles for trend filtering
    df_resampled['SMA50'] = df_resampled['close'].rolling(window=50).mean()

    return df_resampled

def check_signal_RSI(data):
    """Generates BUY/SELL signals based on RSI and SMA50 (trend)."""
    latest = data.iloc[-1]
    prev = data.iloc[-2]
    
    current_price = latest['close']
    current_SMA50 = latest['SMA50']

    # Set dynamic RSI thresholds based on trend
    if current_price > current_SMA50:
        buy_threshold = 40    # Uptrend: milder oversold threshold
        sell_threshold = 80   # Uptrend: higher overbought threshold
    else:
        buy_threshold = 30
        sell_threshold = 70

    # Generate signals using conditions identical to your backtest code:
    # For BUY: RSI crosses below the chosen threshold and current price is below SMA50.
    # For SELL: RSI crosses above the chosen threshold and current price is above SMA50.
    if (prev['RSI'] >= buy_threshold) and (latest['RSI'] < buy_threshold) and (current_price < current_SMA50):
        return "BUY"
    elif (prev['RSI'] <= sell_threshold) and (latest['RSI'] > sell_threshold) and (current_price > current_SMA50):
        return "SELL"
    return None
