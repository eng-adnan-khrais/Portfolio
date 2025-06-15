from binance.client import Client
import pandas as pd
import os
import joblib
import sys
import io

def get_historical_data(symbol):

    """
    Fetches OHLCV from Binance, computes continuous Target (% change), MACD, MACD_Signal,
    scales MACD features, and returns:
        - np.array of shape (1, window, 3)
        - last RSI value as integer
    """
    # Extract_scalers
    if symbol == "BTC/USD":
        scaler_std = joblib.load("scaler_standard-BTC-25D.pkl")
        symbol = "BTCUSDT"
        window = 25

    elif symbol == "ETH/USD":
        scaler_std = joblib.load("scaler_standard-ETH-10D.pkl")
        symbol = "ETHUSDT"
        window = 10

    extra_days = 26 + 10
    lookback = window + extra_days

    # Initialize Binance client
    api_key = os.getenv('BINANCE_API_KEY', '')
    secret_key = os.getenv('BINANCE_SECRET_KEY', '')
    client = Client(api_key, secret_key)

    # Fetch klines (1-hour interval)
    klines = client.get_klines(
        symbol=symbol,
        interval=Client.KLINE_INTERVAL_1DAY,
        limit=lookback
    )

    # Convert to DataFrame
    cols = [
        'timestamp', 'open', 'high', 'low', 'close', 'volume',
        'close_time', 'quote_asset_volume', 'trades',
        'taker_buy_base', 'taker_buy_quote', 'ignore'
    ]
    df = pd.DataFrame(klines, columns=cols)
    df['timestamp'] = pd.to_datetime(df['timestamp'], unit='ms')
    df.set_index('timestamp', inplace=True)
    df['close'] = df['close'].astype(float)

    # Build DataFrame with close and continuous Target
    data = pd.DataFrame({'close': df['close']})
    data['Target'] = data['close'].pct_change() * 100

    # Compute MACD and MACD signal
    ema12 = data['close'].ewm(span=12, adjust=False).mean()
    ema26 = data['close'].ewm(span=26, adjust=False).mean()
    data['MACD'] = ema12 - ema26
    data['MACD_Signal'] = data['MACD'].ewm(span=9, adjust=False).mean()

    # Compute RSI series (not added to `data`)
    delta = data['close'].diff(1)
    gain = delta.where(delta > 0, 0).rolling(14).mean()
    loss = -delta.where(delta < 0, 0).rolling(14).mean()
    rs = gain / loss
    rsi_series = 100 - (100 / (1 + rs))

    # Drop NaNs and keep only required columns
    data.dropna(inplace=True)
    data = data[['Target', 'MACD', 'MACD_Signal']]

    # Take the last `window` rows
    window_df = data.iloc[-window:].copy()

    # Scale MACD features
    macd_cols = ['MACD_Signal','MACD']
    window_df[macd_cols] = scaler_std.transform(window_df[macd_cols])

    # Build input array
    arr = window_df.to_numpy(dtype='float32').reshape(1, window, 3)

    # Align RSI series with valid data indices and get last RSI value
    rsi_valid = rsi_series.loc[data.index]
    last_rsi = int(rsi_valid.iloc[-1])

    return arr, last_rsi
