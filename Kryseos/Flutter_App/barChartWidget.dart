import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';

class ProfitBarChart extends StatelessWidget {
  final List<double> profitRatios;
  final List<DateTime> history;

  const ProfitBarChart({
    super.key,
    required this.profitRatios,
    required this.history,
  });

  @override
  Widget build(BuildContext context) {
    final double chartWidth = profitRatios.length * 20;
    final double maxY = _getSmartMaxY();
    final double minY = _getSmartMinY();

    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF1C1F24),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Profit Ratio Chart',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 200,
            child: Row(
              children: [
                // Y-axis
                SizedBox(
                  width: 40,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: List.generate(5, (i) {
                      final value = (maxY - i * ((maxY - minY) / 4)).toStringAsFixed(3);
                      return Text(
                        value,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      );
                    }),
                  ),
                ),
                // Scrollable bar chart
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: SizedBox(
                      width: chartWidth,
                      child: BarChart(
                        BarChartData(
                          alignment: BarChartAlignment.start,
                          maxY: maxY,
                          minY: minY,
                          groupsSpace: 4,
                          barGroups: _buildBarGroups(),
                          gridData: FlGridData(show: false),
                          borderData: FlBorderData(show: false),
                          barTouchData: BarTouchData(
                            enabled: true,
                            touchTooltipData: BarTouchTooltipData(
                              tooltipBgColor: Colors.black.withOpacity(0.7),
                              getTooltipItem: (group, groupIndex, rod, rodIndex) {
                                if (group.x >= history.length) return null;
                                final date = history[group.x];
                                final dateStr = DateFormat('MMM d, y').format(date);
                                final timeStr = DateFormat('h:mm a').format(date);
                                return BarTooltipItem(
                                  'Profit: ${rod.toY.toStringAsFixed(4)}\n$dateStr at $timeStr',
                                  const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                  ),
                                );
                              },
                            ),
                          ),
                          titlesData: FlTitlesData(
                            leftTitles: AxisTitles(
                              sideTitles: SideTitles(showTitles: false),
                            ),
                            rightTitles: AxisTitles(
                              sideTitles: SideTitles(showTitles: false),
                            ),
                            topTitles: AxisTitles(
                              sideTitles: SideTitles(showTitles: false),
                            ),
                            bottomTitles: AxisTitles(
                              sideTitles: SideTitles(showTitles: false),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Align(
            alignment: Alignment.bottomRight,
            child: Padding(
              padding: EdgeInsets.only(top: 8, right: 12),
              child: Text(
                'time',
                style: TextStyle(
                  color: Colors.white60,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  double _getSmartMaxY() {
    if (profitRatios.isEmpty) return 1;
    final maxValue = profitRatios.reduce((a, b) => a > b ? a : b);
    return maxValue.abs() < 1 ? maxValue + 0.01 : maxValue + 0.1;
  }

  double _getSmartMinY() {
    if (profitRatios.isEmpty) return -1;
    final minValue = profitRatios.reduce((a, b) => a < b ? a : b);
    return minValue.abs() < 1 ? minValue - 0.01 : minValue - 0.1;
  }

  List<BarChartGroupData> _buildBarGroups() {
    return List.generate(profitRatios.length, (index) {
      final profit = profitRatios[index];
      final isWinning = profit >= 0;

      return BarChartGroupData(
        x: index,
        barRods: [
          BarChartRodData(
            toY: profit,
            width: 14,
            color: isWinning ? Colors.greenAccent : Colors.redAccent,
            borderRadius: BorderRadius.zero,
          ),
        ],
      );
    });
  }
}
