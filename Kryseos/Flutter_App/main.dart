import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../pages/login.dart';
import '../data/appData.dart';

void startWebSocket(BuildContext context, String userId) {
  final appData = Provider.of<AppData>(context, listen: false);

  final newChannel = WebSocketChannel.connect(
    Uri.parse('ws://10.0.2.2:5004/ws/$userId'), // ✅ Use actual server if needed
  );

  appData.setChannel(newChannel); // ✅ Store in AppData

  newChannel.stream.listen(
        (message) {
      try {
        final data = jsonDecode(message);
        if (data['type'] == 'performance_update' && data['data'] != null) {
          print('🔄 Received performance update: ${jsonEncode(data['data'])}');
          appData.updateFromServer(data['data']);
        } else if (data['type'] == 'bot_status' && data['data'] != null) {
          final status = data['data']['status'];
          print('📡 Received bot status: $status');
          appData.updateBotStatus(status);
        }
      } catch (e) {
        print('❌ Error parsing WebSocket message: $e');
      }
    },
    onError: (error) {
      print('❌ WebSocket error: $error');
    },
    onDone: () {
      print('❌ WebSocket connection closed');
    },
  );
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final prefs = await SharedPreferences.getInstance();
  final userId = prefs.getString('user_id');
  final appData = AppData();

  runApp(
    ChangeNotifierProvider<AppData>.value(
      value: appData,
      child: TradingBotApp(userId: userId),
    ),
  );
}

class TradingBotApp extends StatelessWidget {
  final String? userId;
  const TradingBotApp({super.key, this.userId});

  @override
  Widget build(BuildContext context) {
    // ✅ Initialize WebSocket only after context is available
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (userId != null && userId!.isNotEmpty) {
        startWebSocket(context, userId!);
      }
    });

    return MaterialApp(
      showPerformanceOverlay: false,
      debugShowCheckedModeBanner: false,
      title: 'Trading Bot',
      theme: ThemeData.dark(),
      home: const LoginPage(),
    );
  }
}
