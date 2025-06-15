import 'package:flutter/material.dart';

class AccountSelectionWidget extends StatefulWidget {
  static String selectedAccount = 'https://paper-api.alpaca.markets'; // Default to demo

  const AccountSelectionWidget({super.key});

  @override
  State<AccountSelectionWidget> createState() => _AccountSelectionWidgetState();
}

class _AccountSelectionWidgetState extends State<AccountSelectionWidget> {
  bool isDemoSelected = true;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: _buildAccountCard(
            title: 'Demo Account',
            isSelected: isDemoSelected,
            onTap: () {
              setState(() {
                isDemoSelected = true;
                AccountSelectionWidget.selectedAccount = 'https://paper-api.alpaca.markets';
              });
            },
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildAccountCard(
            title: 'Real Account',
            isSelected: !isDemoSelected,
            onTap: () {
              setState(() {
                isDemoSelected = false;
                AccountSelectionWidget.selectedAccount = 'https://live-api.alpaca.markets';
              });
            },
          ),
        ),
      ],
    );
  }

  Widget _buildAccountCard({
    required String title,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    final backgroundColor = isSelected ? const Color(0xFF2A2D35) : const Color(0xFF191B20);
    final borderColor = const Color(0xFF2A2D35);
    final dotColor = const Color(0xFFCAA464);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: borderColor,
            width: 1.2,
          ),
        ),
        child: Center(
          child: Row(
            mainAxisSize: MainAxisSize.min, // Center content inside card
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              if (isSelected)
                Container(
                  width: 14,
                  height: 14,
                  margin: const EdgeInsets.only(right: 10),
                  decoration: BoxDecoration(
                    color: dotColor,
                    shape: BoxShape.circle,
                  ),
                ),
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 17,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
