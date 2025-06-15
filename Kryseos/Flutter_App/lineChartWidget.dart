import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';

class EquityCurveChart extends StatelessWidget {
  final List<MapEntry<DateTime, double>> equityPoints;

  const EquityCurveChart({super.key, required this.equityPoints});

  @override
  Widget build(BuildContext context) {
    if (equityPoints.isEmpty) {
      return _noDataMessage();
    }

    final double chartWidth = equityPoints.length * 40;
    final double lastEquity = equityPoints.last.value;

    return Container(
      padding: const EdgeInsets.fromLTRB(4, 16, 4, 8),
      margin: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF1C1F24),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title + Last Equity
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Equity Curve (Profit)',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'Last: ${lastEquity.toStringAsFixed(2)}',
                  style: const TextStyle(
                    color: Colors.greenAccent,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Chart with Y-Axis and scrollable X-Axis
          SizedBox(
            height: 200,
            child: Row(
              children: [
                _buildYAxis(),
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: SizedBox(
                      width: chartWidth,
                      child: LineChart(
                        LineChartData(
                          minY: _getMinY(),
                          maxY: _getMaxY(),
                          backgroundColor: Colors.transparent,
                          gridData: FlGridData(show: false),
                          borderData: FlBorderData(show: false),
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
                          lineTouchData: LineTouchData(
                            touchTooltipData: LineTouchTooltipData(
                              tooltipBgColor: Colors.black.withOpacity(0.7),
                              getTooltipItems: (List<LineBarSpot> touchedSpots) {
                                return touchedSpots.map((spot) {
                                  final index = spot.x.toInt();
                                  if (index < 0 || index >= equityPoints.length) return null;
                                  final point = equityPoints[index];
                                  final dateStr = DateFormat('MMM d').format(point.key);
                                  final timeStr = DateFormat('h:mm a').format(point.key);
                                  return LineTooltipItem(
                                    'Equity: ${point.value.toStringAsFixed(2)}\n$dateStr at $timeStr',
                                    const TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                    ),
                                  );
                                }).toList();
                              },
                            ),
                          ),
                          lineBarsData: [
                            LineChartBarData(
                              isCurved: true,
                              color: Colors.greenAccent,
                              barWidth: 3,
                              dotData: FlDotData(show: false),
                              belowBarData: BarAreaData(
                                show: true,
                                color: Colors.greenAccent.withOpacity(0.1),
                              ),
                              spots: List.generate(
                                equityPoints.length,
                                    (index) => FlSpot(
                                  index.toDouble(),
                                  equityPoints[index].value,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Fixed Bottom Right "time" label
          const Align(
            alignment: Alignment.bottomRight,
            child: Padding(
              padding: EdgeInsets.only(right: 12, top: 8),
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

  Widget _buildYAxis() {
    return Padding(
      padding: const EdgeInsets.only(right: 4),
      child: SizedBox(
        width: 40,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: List.generate(5, (i) {
            final value = (_getMaxY() -
                i * ((_getMaxY() - _getMinY()) / 4))
                .toStringAsFixed(0);
            return Text(
              value,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.right,
            );
          }),
        ),
      ),
    );
  }

  Widget _noDataMessage() {
    return Container(
      padding: const EdgeInsets.fromLTRB(4, 16, 4, 16),
      margin: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF1C1F24),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10),
      ),
      child: const Center(
        child: Text(
          'No equity data available',
          style: TextStyle(color: Colors.white70, fontSize: 14),
        ),
      ),
    );
  }
//real
  double _getMaxY() {
    if (equityPoints.isEmpty) return 10;
    return equityPoints.map((e) => e.value).reduce((a, b) => a > b ? a : b) + 5;
  }

  double _getMinY() {
    if (equityPoints.isEmpty) return 0;
    return equityPoints.map((e) => e.value).reduce((a, b) => a < b ? a : b) - 5;
  }
}
