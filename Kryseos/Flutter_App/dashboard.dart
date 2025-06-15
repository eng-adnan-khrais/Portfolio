import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../data/appData.dart';
import '../widgets/barChartWidget.dart';
import '../widgets/lineChartWidget.dart';

class DashboardTab extends StatelessWidget {
  const DashboardTab({super.key});

  Widget buildInfoCard(String label, String value, {Color? valueColor}) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1C1F24),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white10),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: Colors.white54, fontSize: 14)),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              color: valueColor ?? Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  //real
  @override
  Widget build(BuildContext context) {
    final appData = Provider.of<AppData>(context);

    final Color botStatusColor = appData.botStatus.toLowerCase() == 'running'
        ? const Color(0xFF26A69A)
        : const Color(0xFFEF5350);

    return Container(
      color: const Color(0xFF191B20),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              buildInfoCard('Bot Status', appData.botStatus, valueColor: botStatusColor),
              const SizedBox(height: 12),
              EquityCurveChart(
                equityPoints: Provider.of<AppData>(context).equityWithHistory,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: buildInfoCard('Profit', '\$${appData.profit.toStringAsFixed(1)}'),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: buildInfoCard(
                      'Profit %',
                      '${appData.profitRatio.toStringAsFixed(1)}%',
                      valueColor: const Color(0xFF4AC9B0),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ProfitBarChart(
                profitRatios: appData.profitRatios,
                history: appData.history,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: buildInfoCard('Total Trades', appData.numTrades.toString()),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: buildInfoCard('Win Rate', '${appData.winningRate.toStringAsFixed(1)}%'),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: buildInfoCard('Risk Ratio', appData.riskRatio.toStringAsFixed(1)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: buildInfoCard('Strategy Name', appData.strategy),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              buildInfoCard('Symbol', appData.symbol),
            ],
          ),
        ),
      ),
    );
  }
}
