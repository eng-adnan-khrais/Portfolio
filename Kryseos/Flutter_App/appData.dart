import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

class AppData extends ChangeNotifier {
  double profit = 0.0;
  String botStatus = "Stopped";
  double realBalance = 0.0;
  String id = "";
  double cash = 0.0;
  String currency = "USD";
  String strategy = "";
  String symbol = "";
  int numTrades = 0;
  double winningRate = 0.0;
  double profitRatio = 0.0;
  double riskRatio = 0.0;

  List<double> profitRatios = [];
  List<double> equity = [];
  List<DateTime> history = [];

  List<MapEntry<DateTime, double>> get equityWithHistory {
    final result = <MapEntry<DateTime, double>>[];
    final len = history.length < equity.length ? history.length : equity.length;
    for (int i = 0; i < len; i++) {
      result.add(MapEntry(history[i], equity[i]));
    }
    return result;
  }



  void updateFromServer(Map<String, dynamic> json) {
    final dateFormat = DateFormat("MMM d, yyyy, hh:mm:ss a");

    if (json.containsKey('alpaca_user_id')) id = json['alpaca_user_id'];
    if (json.containsKey('cash')) cash = json['cash'];
    if (json.containsKey('currency')) currency = json['currency'];
    if (json.containsKey('current_equity')) realBalance = json['current_equity'];
    if (json.containsKey('total_profit')) profit = json['total_profit'];
    if (json.containsKey('profit_ratio')) profitRatio = json['profit_ratio'];
    if (json.containsKey('winning_rate')) winningRate = json['winning_rate'];
    if (json.containsKey('num_trades')) numTrades = json['num_trades'];

    if (json.containsKey('trade_profit_ratios')) {
      profitRatios = List<double>.from(json['trade_profit_ratios']);
    }

    if (json.containsKey('equity_history')) {
      equity = List<double>.from(json['equity_history']);
    }

    if (json.containsKey('sell_fill_times')) {
      try {
        history = List<String>.from(json['sell_fill_times'])
            .map((s) => dateFormat.parse(s))
            .toList();
      } catch (e) {
        print("❌ Failed to parse sell_fill_times: $e");
        history = [];
      }
    }

    notifyListeners();
  }



  void updateBotStatus(String newStatus) {
    botStatus = newStatus;
    notifyListeners();
  }

  void setStrategy(String newStrategy) {
    strategy = newStrategy;
    notifyListeners();
  }

  void setSymbol(String newSymbol) {
    symbol = newSymbol;
    notifyListeners();
  }

  void setRiskRatio(double value) {
    riskRatio = value;
    notifyListeners();
  }

  void addEquityPoint(double value, DateTime time) {
    equity.add(value);
    history.add(time);
    notifyListeners();
  }

  void setEquityAndHistory(List<double> values, List<DateTime> times) {
    equity = values;
    history = times;
    notifyListeners();
  }

  WebSocketChannel? channel; // ✅ Add this line

  void setChannel(WebSocketChannel newChannel) {
    channel = newChannel;
    notifyListeners();
  }

  void closeChannel() {
    channel?.sink.close();
    channel = null;
    notifyListeners();
  }
}


