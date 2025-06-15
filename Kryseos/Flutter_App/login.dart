import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';

import '../main/main.dart';
import 'mainPage.dart';
import '../data/appData.dart';
import '../widgets/accountSelection.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController apiKeyController = TextEditingController();
  final TextEditingController apiSecretController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _checkIfAlreadyLoggedIn();
  }

  Future<void> _checkIfAlreadyLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    final savedApiKey = prefs.getString('api_key');
    final savedApiSecret = prefs.getString('api_secret');
    final savedUserId = prefs.getString('user_id');
    final savedAccount = prefs.getString('account');

    if (savedApiKey != null &&
        savedApiSecret != null &&
        savedUserId != null &&
        savedAccount != null) {
      final appData = Provider.of<AppData>(context, listen: false);
      appData.closeChannel(); // ✅ Ensure old WebSocket is closed
      startWebSocket(context, savedUserId); // ✅ Start new one

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const MainPage()),
      );
    }
  }

  Future<void> _connect() async {
    final apiKey = apiKeyController.text.trim();
    final apiSecret = apiSecretController.text.trim();
    final accountUrl = AccountSelectionWidget.selectedAccount.trim();

    if (apiKey.isEmpty || apiSecret.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter both API Key and Secret')),
      );
      return;
    }

    try {
      final response = await http.post(
        Uri.parse('http://10.0.2.2:5004/login'),
        headers: {"Content-Type": "application/x-www-form-urlencoded"},
        body: {
          'api_key': apiKey,
          'api_secret': apiSecret,
          'account': accountUrl,
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        if (data['user_id'] != null) {
          final userId = data['user_id'];
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('api_key', apiKey);
          await prefs.setString('api_secret', apiSecret);
          await prefs.setString('user_id', userId);
          await prefs.setString('account', accountUrl);

          print('✅ Login successful. Saved user_id: $userId');

          final appData = Provider.of<AppData>(context, listen: false);
          appData.closeChannel(); // ✅ Close previous WebSocket if any
          startWebSocket(context, userId); // ✅ Open new one

          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const MainPage()),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Login failed: Missing user ID')),
          );
        }
      } else {
        final responseBody = jsonDecode(response.body);
        final message = responseBody['message'] ?? 'Login failed';
        if (message == "Invalid API keys. Please enter valid keys.") {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Enter valid API keys')),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(message)),
          );
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error connecting: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF191B20),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: IntrinsicHeight(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      const SizedBox(height: 60),
                      const Text(
                        'Kryseos',
                        style: TextStyle(
                          fontSize: 48,
                          fontFamily: 'Georgia',
                          fontWeight: FontWeight.bold,
                          color: Color(0xFFCAA464),
                        ),
                      ),
                      const SizedBox(height: 24),
                      const AccountSelectionWidget(),
                      const SizedBox(height: 40), // Increased spacing before the instruction
                      const Text(
                        'Enter your Alpaca APIs',
                        style: TextStyle(
                          fontSize: 20,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 20),
                      TextField(
                        controller: apiKeyController,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          hintText: 'API Key',
                          hintStyle: const TextStyle(color: Colors.white70),
                          filled: true,
                          fillColor: Color(0xFF2A2D35), // ✅ Updated background color
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      TextField(
                        controller: apiSecretController,
                        obscureText: true,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          hintText: 'API Secret',
                          hintStyle: const TextStyle(color: Colors.white70),
                          filled: true,
                          fillColor: Color(0xFF2A2D35), // ✅ Updated background color
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                      const SizedBox(height: 30),
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF0F4C4C),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          onPressed: _connect,
                          child: const Text(
                            'Connect',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
