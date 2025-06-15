import 'package:flutter/material.dart';
import 'package:candlesticks/candlesticks.dart';
import 'package:http/http.dart' as http;
import 'package:web_socket_channel/web_socket_channel.dart';
import 'dart:convert';

class MarketTab extends StatefulWidget {
  const MarketTab({super.key});

  @override
  State<MarketTab> createState() => _MarketTabState();
}

class _MarketTabState extends State<MarketTab> {
  List<Candle> candles = [];
  String selectedSymbol = "BTCUSDT";
  String selectedInterval = "1m";
  double? currentPrice;
  WebSocketChannel? _channel;
  bool isLoading = true;

  final List<String> intervals = ["1m", "5m", "15m", "1h", "4h", "1d"];
  final Map<String, String> symbols = {
    "BTC/USD": "BTCUSDT",
    "ETH/USD": "ETHUSDT",
    "BNB/USD": "BNBUSDT",
    "SOL/USD": "SOLUSDT",
  };

  @override
  void initState() {
    super.initState();
    fetchInitialCandles();
    subscribeToWebSocket();
  }

  @override
  void dispose() {
    _channel?.sink.close();
    super.dispose();
  }

  Future<void> fetchInitialCandles() async {
    setState(() => isLoading = true);
    try {
      final uri = Uri.parse(
          "https://api.binance.com/api/v3/klines?symbol=$selectedSymbol&interval=$selectedInterval&limit=500");
      final response = await http.get(uri);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final parsedCandles = data.map<Candle?>((e) {
          try {
            final open = double.tryParse(e[1]) ?? 0;
            final high = double.tryParse(e[2]) ?? 0;
            final low = double.tryParse(e[3]) ?? 0;
            final close = double.tryParse(e[4]) ?? 0;
            final volume = double.tryParse(e[5]) ?? 0;
            final timestamp = e[0];

            if ([open, high, low, close, volume].any((v) => v == 0 || v.isNaN)) return null;

            return Candle(
              date: DateTime.fromMillisecondsSinceEpoch(timestamp),
              open: open,
              high: high,
              low: low,
              close: close,
              volume: volume,
            );
          } catch (_) {
            return null;
          }
        }).whereType<Candle>().toList();

        setState(() {
          candles = parsedCandles;
          currentPrice = candles.isNotEmpty ? candles.last.close : null;
          isLoading = false;
        });
      } else {
        print("Failed to load candles: ${response.statusCode}");
        setState(() => isLoading = false);
      }
    } catch (e) {
      print("Error in fetchInitialCandles: $e");
      setState(() => isLoading = false);
    }
  }

  void subscribeToWebSocket() {
    _channel?.sink.close();
    final streamUrl =
        "wss://stream.binance.com:9443/ws/${selectedSymbol.toLowerCase()}@kline_${selectedInterval}";
    _channel = WebSocketChannel.connect(Uri.parse(streamUrl));

    _channel!.stream.listen((event) {
      try {
        final data = json.decode(event);
        final kline = data['k'];
        final close = double.parse(kline['c']);
        if (close == 0 || close.isNaN) return;

        final updatedCandle = Candle(
          date: DateTime.fromMillisecondsSinceEpoch(kline['t']),
          open: double.parse(kline['o']),
          high: double.parse(kline['h']),
          low: double.parse(kline['l']),
          close: close,
          volume: double.parse(kline['v']),
        );

        setState(() {
          currentPrice = updatedCandle.close;
          final last = candles.isNotEmpty ? candles.last : null;
          if (last != null &&
              last.date.millisecondsSinceEpoch ==
                  updatedCandle.date.millisecondsSinceEpoch) {
            candles[candles.length - 1] = updatedCandle;
          } else if (last == null || updatedCandle.date.isAfter(last.date)) {
            candles.add(updatedCandle);
            if (candles.length > 500) {
              candles.removeAt(0);
            }
          }
        });
      } catch (e) {
        print("WebSocket parsing error: $e");
      }
    });
  }

  void onSelectionChange() {
    fetchInitialCandles();
    subscribeToWebSocket();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF191B20),
      child: Column(
        children: [
          if (currentPrice != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: const BoxDecoration(
                color: Color(0xFF191B20),
              ),
              child: Center(
                child: Text(
                  '${selectedSymbol.replaceAll("USDT", "/USD")} Price: \$${currentPrice!.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          Expanded(
            child: isLoading
                ? const Center(child: CircularProgressIndicator())
                : Candlesticks(candles: candles),
          ),
          Container(
            padding: const EdgeInsets.all(16.0),
            decoration: const BoxDecoration(
              color: Color(0xFF1C1F24),
              border: Border(top: BorderSide(color: Colors.white10)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2A2D35),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        isExpanded: true,
                        dropdownColor: const Color(0xFF2A2D35),
                        value: selectedSymbol,
                        icon: const Icon(Icons.arrow_drop_down, color: Colors.white54),
                        style: const TextStyle(color: Colors.white, fontSize: 16),
                        items: symbols.entries.map((entry) {
                          return DropdownMenuItem<String>(
                            value: entry.value,
                            child: Text(entry.key),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setState(() {
                            selectedSymbol = value!;
                            isLoading = true;
                          });
                          onSelectionChange();
                        },
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2A2D35),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        isExpanded: true,
                        dropdownColor: const Color(0xFF2A2D35),
                        value: selectedInterval,
                        icon: const Icon(Icons.arrow_drop_down, color: Colors.white54),
                        style: const TextStyle(color: Colors.white, fontSize: 16),
                        items: intervals.map((interval) {
                          return DropdownMenuItem<String>(
                            value: interval,
                            child: Text(interval.toUpperCase()),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setState(() {
                            selectedInterval = value!;
                            isLoading = true;
                          });
                          onSelectionChange();
                        },
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
