import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../data/appData.dart'; // make sure this import is correct

class MySliderWidget extends StatefulWidget {
  static double riskPercentage = 0.01;

  @override
  _MySliderWidgetState createState() => _MySliderWidgetState();
}

class _MySliderWidgetState extends State<MySliderWidget> {
  double _riskPercentage = 0.01;

  Color _getGradientColor(double risk) {
    // Map risk from 0.01–0.5 to 0–1 range
    double t = (risk - 0.01) / (0.5 - 0.01);
    if (t < 0.5) {
      return Color.lerp(const Color(0xFF0F4C4C), Colors.yellow, t * 2)!;
    } else {
      return Color.lerp(Colors.yellow, Colors.red, (t - 0.5) * 2)!;
    }
  }

  @override
  Widget build(BuildContext context) {
    final appData = Provider.of<AppData>(context, listen: false);
    final backgroundColor = const Color(0xFF191B20);
    final gradientColor = _getGradientColor(_riskPercentage);

    return Container(
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            width: 72,
            height: 72,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: gradientColor,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: gradientColor.withOpacity(0.6),
                  blurRadius: 12,
                  spreadRadius: 2,
                )
              ],
            ),
            child: Text(
              '${(_riskPercentage * 100).toStringAsFixed(0)}%',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(height: 24),

          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 4,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
            ),
            child: Slider(
              value: _riskPercentage,
              min: 0.01,
              max: 0.5,
              divisions: 49,
              label: '${(_riskPercentage * 100).toStringAsFixed(0)}%',
              activeColor: gradientColor,
              inactiveColor: Colors.white30,
              onChanged: (value) {
                setState(() {
                  _riskPercentage = value;
                  MySliderWidget.riskPercentage = value;
                  appData.setRiskRatio(value); // ✅ update riskRatio in appData
                });
              },
            ),
          ),
        ],
      ),
    );
  }
}
