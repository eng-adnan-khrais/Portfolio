import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';

import '../widgets/slider.dart';
import '../data/appData.dart';

class TradeTab extends StatefulWidget {
  final VoidCallback onStartSuccess;

  const TradeTab({super.key, required this.onStartSuccess});

  @override
  State<TradeTab> createState() => _TradeTabState();
}

class _TradeTabState extends State<TradeTab> {
  String _selectedSymbol = 'BTC/USD';
  int _selectedStrategyNumber = 1;
  bool _isTrading = false;
  String? _userId;
  String? _accountUrl;

  final Map<int, String> _strategyMap = {
    1: 'ML Model',
    2: 'SMA',
    3: 'MACD',
    4: 'Hull-Ma',
    5: 'SMA&ADX',
    6: 'RSI&SMA50',
    7: 'Dummy Strategy',
  };

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _userId = prefs.getString('user_id');
      _accountUrl = prefs.getString('account');
    });
  }

  Future<void> _startTrading() async {
    final double? risk = MySliderWidget.riskPercentage;

    if (_userId == null || _accountUrl == null || risk == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please complete all fields before starting trading.')),
      );
      return;
    }

    final appData = Provider.of<AppData>(context, listen: false);
    appData.setStrategy(_strategyMap[_selectedStrategyNumber]!);
    appData.setSymbol(_selectedSymbol);

    final payload = {
      'user_id': _userId!,
      'symbol': _selectedSymbol,
      'strategy': _selectedStrategyNumber.toString(),
      'risk': risk.toString(),
      'account': _accountUrl!,
    };

    try {
      final response = await http.post(
        Uri.parse('http://10.0.2.2:5004/start-trading'),
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: payload,
      );

      if (response.statusCode == 200) {
        print('✅ Trading started successfully!');
        widget.onStartSuccess(); // 🔁 Notify MainPage to switch to Dashboard tab
      } else {
        print('❌ Failed to start trading. Status: ${response.statusCode}');
        print('Server response: ${response.body}');
      }
    } catch (e) {
      print('❌ Error starting trading: $e');
    }
  }

  Future<void> _stopTrading() async {
    if (_userId == null) return;

    try {
      final response = await http.post(
        Uri.parse('http://10.0.2.2:5004/stop-trading'),
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: {'user_id': _userId!},
      );

      if (response.statusCode == 200) {
        print('🛑 Trading stopped successfully!');
      } else {
        print('❌ Failed to stop trading. Status: ${response.statusCode}');
        print('Server response: ${response.body}');
      }
    } catch (e) {
      print('❌ Error stopping trading: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: IntrinsicHeight(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 32),
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Symbol',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w400,
                                  color: Colors.white54,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 16),
                                decoration: BoxDecoration(
                                  color: Color(0xFF2A2D35),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: DropdownButtonHideUnderline(
                                  child: DropdownButton<String>(
                                    isExpanded: true,
                                    value: _selectedSymbol,
                                    dropdownColor: const Color(0xFF2A2D35),
                                    icon: const Icon(Icons.arrow_drop_down, color: Colors.white54),
                                    style: const TextStyle(color: Colors.white, fontSize: 16),
                                    items: const [
                                      DropdownMenuItem(
                                        value: 'BTC/USD',
                                        child: Text('BTC/USD', overflow: TextOverflow.ellipsis),
                                      ),
                                      DropdownMenuItem(
                                        value: 'ETH/USD',
                                        child: Text('ETH/USD', overflow: TextOverflow.ellipsis),
                                      ),
                                    ],
                                    onChanged: (value) {
                                      setState(() => _selectedSymbol = value!);
                                    },
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Strategy',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w400,
                                  color: Colors.white54,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 16),
                                decoration: BoxDecoration(
                                  color: Color(0xFF2A2D35),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: DropdownButtonHideUnderline(
                                  child: DropdownButton<int>(
                                    isExpanded: true,
                                    value: _selectedStrategyNumber,
                                    dropdownColor: const Color(0xFF2A2D35),
                                    icon: const Icon(Icons.arrow_drop_down, color: Colors.white54),
                                    style: const TextStyle(color: Colors.white, fontSize: 16),
                                    items: _strategyMap.entries.map((entry) {
                                      return DropdownMenuItem<int>(
                                        value: entry.key,
                                        child: Text(entry.value, overflow: TextOverflow.ellipsis),
                                      );
                                    }).toList(),
                                    onChanged: (value) {
                                      if (value != null) {
                                        setState(() => _selectedStrategyNumber = value);
                                      }
                                    },
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 30),
                    const Text(
                      'Capital Risk Ratio',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w400,
                        color: Colors.white54,
                      ),
                    ),
                    const SizedBox(height: 10),
                    MySliderWidget(),
                    const Spacer(),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                        child: Consumer<AppData>(
                          builder: (context, appData, _) {
                            final isBotRunning = appData.botStatus == "Running";

                            return ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: isBotRunning ? Colors.red : const Color(0xFF0F4C4C),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              onPressed: () async {
                                if (isBotRunning) {
                                  await _stopTrading();
                                } else {
                                  await _startTrading();
                                }

                                // No need to set _isTrading manually here, bot status will reflect update
                              },
                              child: Text(
                                isBotRunning ? 'STOP TRADING' : 'START TRADING',
                                style: const TextStyle(color: Colors.white, fontSize: 16),
                              ),
                            );
                          },
                        ),

                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
