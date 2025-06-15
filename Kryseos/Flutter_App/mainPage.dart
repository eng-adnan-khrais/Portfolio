import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import 'package:web_socket_channel/web_socket_channel.dart'; // ✅ Required import
import '../data/appData.dart';
import 'dashboard.dart';
import 'login.dart';
import '../main/main.dart'; // ✅ Assuming 'channel' is defined here
import 'market.dart';
import 'trade.dart';

class MainPage extends StatefulWidget {
  const MainPage({super.key});

  @override
  State<MainPage> createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> {
  int _currentIndex = 0;
  late final List<Widget> _pages;

  @override
  void initState() {
    super.initState();
    _pages = [
      TradeTab(onStartSuccess: () => setState(() => _currentIndex = 1)),
      DashboardTab(),
      MarketTab(),
    ];
  }

  Future<void> logout() async {
    final appData = Provider.of<AppData>(context, listen: false);

    try {
      final response = await http.post(
        Uri.parse('http://10.0.2.2:5004/logout'), // ✅ Replace with actual server if needed
        body: {'user_id': appData.id},
      );

      if (response.statusCode == 200) {
        debugPrint("✅ Logout successful on server");
      } else {
        debugPrint("⚠️ Server logout failed: ${response.body}");
      }
    } catch (e) {
      debugPrint("❌ Logout request error: $e");
    }

    // ✅ Close WebSocket connection
    try {
      appData.closeChannel();
      // ✅ Assumes `channel` is imported from main.dart
      debugPrint("🔌 WebSocket closed");
    } catch (e) {
      debugPrint("⚠️ Error closing WebSocket: $e");
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('api_key');
    await prefs.remove('api_secret');

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => const LoginPage()),
          (Route<dynamic> route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final appData = Provider.of<AppData>(context);
    return Scaffold(
      backgroundColor: const Color(0xFF191B20),
      body: Stack(
        children: [
          Positioned.fill(
            child: Opacity(
              opacity: 0.25,
            ),
          ),
          IndexedStack(
            index: _currentIndex,
            children: _pages,
          ),
        ],
      ),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'Kryseos',
          style: TextStyle(
            fontSize: 24,
            fontFamily: 'Georgia',
            fontWeight: FontWeight.bold,
            color: Color(0xFFCAA464),
          ),
        ),
        centerTitle: true,
        leading: Builder(
          builder: (BuildContext context) {
            return IconButton(
              icon: const Icon(Icons.menu, color: Color(0xFFCAA464)),
              onPressed: () => Scaffold.of(context).openDrawer(),
            );
          },
        ),
      ),
      drawer: Drawer(
        backgroundColor: const Color(0xFF191B20),
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              decoration: const BoxDecoration(color: Color(0xFF191B20)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Color(0xFFCAA464),
                    ),
                    child: const Center(
                      child: Text(
                        'K',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF191B20),
                          fontFamily: 'Georgia',
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text('User ID: ${appData.id.toString()}',
                      style: const TextStyle(color: Colors.white70, fontSize: 16)),
                  const SizedBox(height: 4),
                  Text('Currency: ${appData.currency.toString()}',
                      style: const TextStyle(color: Colors.white54, fontSize: 14)),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("Account Info",
                      style: TextStyle(
                        color: Color(0xFFCAA464),
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      )),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text("Cash:",
                          style: TextStyle(color: Colors.white70, fontSize: 14)),
                      Text("\$${appData.cash.toStringAsFixed(2)}",
                          style: const TextStyle(color: Colors.white54)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text("Equity:",
                          style: TextStyle(color: Colors.white70, fontSize: 14)),
                      Text(
                          "\$${appData.equity.isNotEmpty ? appData.equity.last.toStringAsFixed(2) : '0.00'}",
                          style: const TextStyle(color: Colors.white54)),
                    ],
                  ),
                ],
              ),
            ),
            const Divider(color: Colors.white24, height: 32),
            ListTile(
              leading: const Icon(Icons.logout, color: Color(0xFFCAA464)),
              title: const Text('Logout',
                  style: TextStyle(
                    color: Colors.white70,
                    fontWeight: FontWeight.w500,
                  )),
              onTap: logout,
            ),
          ],
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        backgroundColor: const Color(0xFF1C1F24),
        selectedItemColor: const Color(0xFFCAA464),
        unselectedItemColor: Colors.white70,
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.swap_horiz),
            label: 'Trade',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.dashboard),
            label: 'Dashboard',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.candlestick_chart),
            label: 'Market',
          ),
        ],
      ),
    );
  }
}
