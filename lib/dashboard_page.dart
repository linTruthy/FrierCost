import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:frier_cost/currency_formatter.dart';
import 'package:frier_cost/metric_card.dart';

import 'utils.dart';

class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Dashboard')),

      body: Row(
        children: [
          Expanded(
            child: StreamBuilder(
              stream:
                  FirebaseFirestore.instance
                      .collection('sales')
                      .orderBy('date', descending: true)
                      .limit(7)
                      .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return ShimmerWidget(
                    child: Column(
                      children: [
                        Container(height: 100, color: Colors.grey[300]),
                        SizedBox(height: 20),
                        Container(height: 300, color: Colors.grey[300]),
                      ],
                    ),
                  );
                }
                var salesDocs = snapshot.data!.docs;
                return StreamBuilder(
                  stream:
                      FirebaseFirestore.instance
                          .collection('inventory_logs')
                          .where(
                            'date',
                            isGreaterThanOrEqualTo: Timestamp.fromDate(
                              DateTime.now().subtract(Duration(days: 7)),
                            ),
                          )
                          .snapshots(),
                  builder: (context, invSnapshot) {
                    if (!invSnapshot.hasData) {
                      return ShimmerWidget(
                        child: Column(
                          children: [
                            Container(height: 100, color: Colors.grey[300]),
                            SizedBox(height: 20),
                            Container(height: 300, color: Colors.grey[300]),
                          ],
                        ),
                      );
                    }
                    var invLogs = invSnapshot.data!.docs;
                    var metrics = _calculateMetrics(salesDocs, invLogs);
                    var highWaste = _calculateHighWaste(invLogs);
                    var usageDeviations = _calculateUsageDeviations(
                      salesDocs,
                      invLogs,
                    );

                    // Calculate trends to determine if metrics are improving
                    bool costTrend =
                        metrics.length > 1
                            ? metrics.last.costPerPiece <=
                                metrics[metrics.length - 2].costPerPiece
                            : true;
                    bool marginTrend =
                        metrics.length > 1
                            ? metrics.last.marginPerPiece >=
                                metrics[metrics.length - 2].marginPerPiece
                            : true;
                    // bool salesTrend =
                    //     metrics.length > 1
                    //         ? metrics.last.piecesSold >=
                    //             metrics[metrics.length - 2].piecesSold
                    //         : true;

                    // Calculate previous day sales to see if today is higher/lower
                    var previousDaySales =
                        salesDocs.length > 1
                            ? salesDocs[1]['piecesSold'] as int
                            : 0;
                    var todaySales =
                        salesDocs.isNotEmpty
                            ? salesDocs.first['piecesSold'] as int
                            : 0;
                    bool dailySalesTrend = todaySales >= previousDaySales;

                    return SingleChildScrollView(
                      padding: EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                                'Today\'s Performance',
                                style: Theme.of(context).textTheme.headlineSmall
                                    ?.copyWith(fontWeight: FontWeight.bold),
                              )
                              .animate()
                              .fadeIn(duration: 400.ms)
                              .slideX(begin: -0.2, end: 0),
                          SizedBox(height: 16),
                          Wrap(
                            spacing: 16,
                            runSpacing: 16,
                            children: [
                              MetricCard(
                                title: 'Cost/Piece',
                                value:
                                    metrics.isNotEmpty
                                        ? CurrencyFormatter().format(
                                          metrics.last.costPerPiece,
                                        )
                                        : '0.00',
                                icon: Icons.attach_money_rounded,
                                accentColor: Colors.amber[700],
                                isPositive: costTrend,
                                showTrendIndicator: metrics.length > 1,
                              ),
                              MetricCard(
                                title: 'Margin/Piece',
                                value:
                                    metrics.isNotEmpty
                                        ? CurrencyFormatter().format(
                                          metrics.last.marginPerPiece,
                                        )
                                        : '\$0.00',
                                icon: Icons.trending_up_rounded,
                                accentColor: Colors.green[700],
                                isPositive: marginTrend,
                                showTrendIndicator: metrics.length > 1,
                              ),
                              MetricCard(
                                title: 'Daily Sales',
                                value:
                                    salesDocs.isNotEmpty
                                        ? '${salesDocs.first['piecesSold']} pieces'
                                        : '0 pieces',
                                icon: Icons.shopping_cart_rounded,
                                accentColor: Colors.blue[700],
                                isPositive: dailySalesTrend,
                                showTrendIndicator: salesDocs.length > 1,
                              ),
                              MetricCard(
                                title: 'Weekly Revenue',
                                value: CurrencyFormatter().format(
                                  _calculateWeeklyRevenue(metrics),
                                ),
                                icon: Icons.account_balance_wallet_rounded,
                                accentColor: Colors.purple[700],
                                isPositive: true,
                              ),
                            ],
                          ),
                          SizedBox(height: 32),
                          if (highWaste.isNotEmpty)
                            Card(
                                  elevation: 3,
                                  color: Color(
                                    0xFFD32F2F,
                                  ).withValues(alpha: 0.08),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    side: BorderSide(
                                      color: Color(
                                        0xFFD32F2F,
                                      ).withValues(alpha: 0.3),
                                      width: 1,
                                    ),
                                  ),
                                  child: Padding(
                                    padding: EdgeInsets.all(16.0),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Icon(
                                              Icons.warning_amber_rounded,
                                              color: Color(0xFFD32F2F),
                                            ),
                                            SizedBox(width: 8),
                                            Text(
                                              'High Waste Alert',
                                              style: Theme.of(
                                                context,
                                              ).textTheme.titleMedium?.copyWith(
                                                color: Color(0xFFD32F2F),
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ],
                                        ),
                                        SizedBox(height: 12),
                                        ...highWaste.entries.map(
                                          (e) => Padding(
                                            padding: const EdgeInsets.only(
                                              bottom: 8.0,
                                            ),
                                            child: Row(
                                              children: [
                                                Icon(
                                                  Icons.circle,
                                                  size: 8,
                                                  color: Color(0xFFD32F2F),
                                                ),
                                                SizedBox(width: 8),
                                                Text(
                                                  '${e.key}: ${(e.value * 100).toStringAsFixed(1)}% waste',
                                                  style: TextStyle(
                                                    fontWeight:
                                                        e.value > 0.1
                                                            ? FontWeight.bold
                                                            : FontWeight.normal,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                )
                                .animate()
                                .fadeIn(duration: 500.ms)
                                .scale(begin: Offset(0.95, 0.95)),
                          SizedBox(height: 24),
                          if (usageDeviations.isNotEmpty)
                            Card(
                                  elevation: 3,
                                  color: Colors.orange[700]!.withValues(
                                    alpha: 0.08,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    side: BorderSide(
                                      color: Colors.orange[700]!.withValues(
                                        alpha: 0.3,
                                      ),
                                      width: 1,
                                    ),
                                  ),
                                  child: Padding(
                                    padding: EdgeInsets.all(16.0),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Icon(
                                              Icons.analytics_rounded,
                                              color: Colors.orange[700],
                                            ),
                                            SizedBox(width: 8),
                                            Text(
                                              'Usage Deviations',
                                              style: Theme.of(
                                                context,
                                              ).textTheme.titleMedium?.copyWith(
                                                color: Colors.orange[700],
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ],
                                        ),
                                        SizedBox(height: 12),
                                        ...usageDeviations.entries.map(
                                          (e) => Padding(
                                            padding: const EdgeInsets.only(
                                              bottom: 8.0,
                                            ),
                                            child: Row(
                                              children: [
                                                Icon(
                                                  Icons.circle,
                                                  size: 8,
                                                  color: Colors.orange[700],
                                                ),
                                                SizedBox(width: 8),
                                                Text(
                                                  '${e.key}: ${(e.value * 100).toStringAsFixed(1)}% over benchmark',
                                                  style: TextStyle(
                                                    fontWeight:
                                                        e.value > 0.2
                                                            ? FontWeight.bold
                                                            : FontWeight.normal,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                )
                                .animate()
                                .fadeIn(duration: 500.ms)
                                .scale(
                                  delay: 200.ms,
                                  begin: Offset(0.95, 0.95),
                                ),
                          SizedBox(height: 32),
                          _buildChartSection(
                            context: context,
                            title: 'Cost per Piece (7 Days)',
                            metrics: metrics,
                            isMargin: false,
                            color: Colors.amber[700]!,
                          ),
                          SizedBox(height: 32),
                          _buildChartSection(
                            context: context,
                            title: 'Profit Margin (7 Days)',
                            metrics: metrics,
                            isMargin: true,
                            color: Colors.green[700]!,
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChartSection({
    required BuildContext context,
    required String title,
    required List metrics,
    required bool isMargin,
    required Color color,
  }) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Text(
              isMargin
                  ? 'Showing profit margin trends over the past week'
                  : 'Showing cost per piece trends over the past week',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(
                  context,
                ).textTheme.bodyMedium?.color?.withValues(alpha: 0.7),
              ),
            ),
            SizedBox(height: 24),
            SizedBox(
              height: 300,
              child: Semantics(
                label:
                    'Line chart showing ${isMargin ? "profit margin" : "cost per piece"} over 7 days',
                child: LineChart(
                  LineChartData(
                    lineTouchData: LineTouchData(
                      touchTooltipData: LineTouchTooltipData(
                        // tooltipBgColor: Theme.of(context).cardColor,
                        getTooltipItems: (touchedSpots) {
                          return touchedSpots.map((spot) {
                            int index = spot.x.toInt();
                            if (index >= 0 && index < metrics.length) {
                              String date = metrics[index].date
                                  .toString()
                                  .substring(5, 10);
                              double value =
                                  isMargin
                                      ? metrics[index].marginPerPiece
                                      : metrics[index].costPerPiece;
                              return LineTooltipItem(
                                '$date: ${CurrencyFormatter().formatWithPrecision(value, 1)}',
                                TextStyle(
                                  color:
                                      Theme.of(
                                        context,
                                      ).textTheme.bodyLarge?.color,
                                  fontWeight: FontWeight.bold,
                                ),
                              );
                            }
                            return null;
                          }).toList();
                        },
                      ),
                      handleBuiltInTouches: true,
                    ),
                    lineBarsData: [
                      LineChartBarData(
                        spots:
                            metrics
                                .asMap()
                                .entries
                                .map(
                                  (e) => FlSpot(
                                    e.key.toDouble(),
                                    isMargin
                                        ? e.value.marginPerPiece
                                        : e.value.costPerPiece,
                                  ),
                                )
                                .toList(),
                        isCurved: true,
                        gradient: LinearGradient(
                          colors: [color.withValues(alpha: 0.7), color],
                        ),
                        barWidth: 4,
                        isStrokeCapRound: true,
                        dotData: FlDotData(
                          show: true,
                          getDotPainter: (spot, percent, barData, index) {
                            return FlDotCirclePainter(
                              radius: 6,
                              color: color,
                              strokeWidth: 2,
                              strokeColor: Theme.of(context).cardColor,
                            );
                          },
                        ),
                        belowBarData: BarAreaData(
                          show: true,
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              color.withValues(alpha: 0.3),
                              color.withValues(alpha: 0.0),
                            ],
                          ),
                        ),
                      ),
                    ],
                    minY: _getMinY(metrics, isMargin),
                    maxY: _getMaxY(metrics, isMargin),
                    titlesData: FlTitlesData(
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          getTitlesWidget: (value, meta) {
                            int index = value.toInt();
                            if (index >= 0 && index < metrics.length) {
                              return Padding(
                                padding: const EdgeInsets.only(top: 8.0),
                                child: Text(
                                  metrics[index].date.toString().substring(
                                    5,
                                    10,
                                  ),
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              );
                            }
                            return const SizedBox.shrink();
                          },
                          reservedSize: 30,
                        ),
                      ),
                      leftTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          getTitlesWidget: (value, meta) {
                            return Padding(
                              padding: const EdgeInsets.only(right: 8.0),
                              child: Text(
                                CurrencyFormatter().formatWithoutSymbol(value),
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            );
                          },
                          reservedSize: 40,
                        ),
                      ),
                      topTitles: AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                      rightTitles: AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                    ),
                    borderData: FlBorderData(
                      show: true,
                      border: Border(
                        bottom: BorderSide(
                          color: Theme.of(context).dividerColor,
                        ),
                        left: BorderSide(color: Theme.of(context).dividerColor),
                      ),
                    ),
                    gridData: FlGridData(
                      show: true,
                      drawHorizontalLine: true,
                      horizontalInterval: _getGridInterval(metrics, isMargin),
                      getDrawingHorizontalLine:
                          (value) => FlLine(
                            color: Theme.of(
                              context,
                            ).dividerColor.withValues(alpha: 0.3),
                            strokeWidth: 1,
                            dashArray: [5, 5],
                          ),
                    ),
                  ),
                ),
              ),
            ).animate().fadeIn(duration: 600.ms).slideY(begin: 0.2, end: 0),
          ],
        ),
      ),
    ).animate().fadeIn(duration: 500.ms).scale(begin: Offset(0.98, 0.98));
  }

  // Helper methods for chart configuration
  double _getMinY(List metrics, bool isMargin) {
    if (metrics.isEmpty) return 0;
    double min = double.infinity;
    for (var metric in metrics) {
      double value = isMargin ? metric.marginPerPiece : metric.costPerPiece;
      if (value < min) min = value;
    }
    return (min * 0.9).clamp(
      0,
      double.infinity,
    ); // Set min Y to 90% of minimum value but not less than 0
  }

  double _getMaxY(List metrics, bool isMargin) {
    if (metrics.isEmpty) return 10;
    double max = 0;
    for (var metric in metrics) {
      double value = isMargin ? metric.marginPerPiece : metric.costPerPiece;
      if (value > max) max = value;
    }
    return max * 1.1; // Set max Y to 110% of maximum value
  }

  double _getGridInterval(List metrics, bool isMargin) {
    double range = _getMaxY(metrics, isMargin) - _getMinY(metrics, isMargin);
    if (range <= 5) return 1;
    if (range <= 10) return 2;
    if (range <= 20) return 4;
    return 5;
  }

  double _calculateWeeklyRevenue(List metrics) {
    if (metrics.isEmpty) return 0;
    return metrics.fold(0.0, (total, metric) => total + metric.totalRevenue);
  }

  List _calculateMetrics(List salesDocs, List invLogs) {
    var ingredientsMap = cachedIngredients();
    var invLogsByDate = groupLogsByDate(invLogs);
    List metrics = [];
    for (var salesDoc in salesDocs) {
      var salesData = salesDoc.data() as Map<String, dynamic>;
      var date = (salesData['date'] as Timestamp).toDate().toString().substring(
        0,
        10,
      );
      var piecesSold = salesData['piecesSold'];
      var totalRevenue =
          salesData['totalRevenue'] is int
              ? (salesData['totalRevenue'] as int).toDouble()
              : double.parse(salesData['totalRevenue'].toString());
      if (invLogsByDate.containsKey(date)) {
        var logs = invLogsByDate[date]!;
        double totalCost = 0;
        for (var log in logs) {
          var item = log['item'];
          var consumed =
              log['opening'] +
              log['received'] -
              log['closing'] -
              log['discarded'];
          var unitCost = ingredientsMap[item] ?? 5.0;
          totalCost += consumed * unitCost;
        }
        var costPerPiece = piecesSold > 0 ? totalCost / piecesSold : 0.0;
        var sellingPrice = totalRevenue / piecesSold;
        var margin = sellingPrice - costPerPiece;
        metrics.add(
          DailyMetrics(
            date: (salesData['date'] as Timestamp).toDate(),
            costPerPiece: costPerPiece,
            marginPerPiece: margin,
            totalCost: totalCost,
            totalRevenue: totalRevenue,
            piecesSold: piecesSold,
          ),
        );
      }
    }
    return metrics;
  }

  Map<String, double> _calculateHighWaste(List invLogs) {
    var result = <String, double>{};
    var grouped = groupLogsByItem(invLogs);
    for (var entry in grouped.entries) {
      var item = entry.key;
      var logs = entry.value;
      var totalDiscarded = logs.fold(
        0.0,
        (total, log) => total + log['discarded'],
      );
      var totalReceived = logs.fold(
        0.0,
        (total, log) => total + log['received'],
      );
      var wasteRatio = totalReceived > 0 ? totalDiscarded / totalReceived : 0.0;
      if (wasteRatio > 0.05) result[item] = wasteRatio;
    }
    return result;
  }

  Map<String, double> _calculateUsageDeviations(List salesDocs, List invLogs) {
    var recipeMap = cachedRecipes();
    var groupedLogs = groupLogsByItem(invLogs);
    var salesByDate = {
      for (var doc in salesDocs)
        (doc['date'] as Timestamp).toDate().toString().substring(0, 10):
            doc['piecesSold'] as int,
    };
    var result = <String, double>{};
    for (var entry in groupedLogs.entries) {
      var item = entry.key;
      var logs = entry.value;
      double totalConsumed = logs.fold(
        0.0,
        (total, log) =>
            total +
            (log['opening'] +
                log['received'] -
                log['closing'] -
                log['discarded']),
      );
      // Calculate total pieces sold for the dates corresponding to the logs
      int totalPiecesSold = logs.fold(0, (total, log) {
        var date = (log['date'] as Timestamp).toDate().toString().substring(
          0,
          10,
        );
        return total + (salesByDate[date] ?? 0);
      });

      double usagePerPiece =
          totalPiecesSold > 0 ? totalConsumed / totalPiecesSold : 0;
      double benchmark = recipeMap[item] ?? 0;
      if (benchmark > 0 && usagePerPiece > benchmark * 1.1) {
        double deviation = (usagePerPiece / benchmark) - 1;
        result[item] = deviation;
      }
    }
    return result;
  }
}

class DailyMetrics {
  DateTime date;
  double costPerPiece;
  double marginPerPiece;
  double totalCost;
  double totalRevenue;
  int piecesSold;

  DailyMetrics({
    required this.date,
    required this.costPerPiece,
    required this.marginPerPiece,
    required this.totalCost,
    required this.totalRevenue,
    required this.piecesSold,
  });
}
