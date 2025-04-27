import 'dart:math';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:frier_cost/metric_card.dart';
import 'currency_formatter.dart';
import 'utils.dart';

class AnalysisPage extends StatefulWidget {
  const AnalysisPage({super.key});

  @override
  State<AnalysisPage> createState() => _AnalysisPageState();
}

class _AnalysisPageState extends State<AnalysisPage> {
  DateTimeRange selectedRange = DateTimeRange(
    start: DateTime.now().subtract(Duration(days: 7)),
    end: DateTime.now(),
  );
  List metrics = [];
  Map<String, UsageData> usageData = {};
  Map<String, WasteData> wasteData = {};
  List recommendations = [];
  bool isLoading = false;
  final int pageSize = 50;
  int currentPage = 1;
  Map<String, double> ingredientsMap = {};
  @override
  void initState() {
    super.initState();
    fetchData();
  }

  Future fetchData({bool loadMore = false}) async {
    setState(() {
      isLoading = true;
    });
    var start = Timestamp.fromDate(selectedRange.start);
    var end = Timestamp.fromDate(
      selectedRange.end.add(Duration(days: 1)).subtract(Duration(seconds: 1)),
    );

    var salesQuery = FirebaseFirestore.instance
        .collection('sales')
        .where('date', isGreaterThanOrEqualTo: start)
        .where('date', isLessThanOrEqualTo: end)
        .orderBy('date')
        .limit(pageSize * currentPage);

    var invLogsQuery = FirebaseFirestore.instance
        .collection('inventory_logs')
        .where('date', isGreaterThanOrEqualTo: start)
        .where('date', isLessThanOrEqualTo: end)
        .limit(pageSize * currentPage);

    var salesSnapshot = await salesQuery.get();
    var invLogsSnapshot = await invLogsQuery.get();
    var ingredientsSnapshot =
        await FirebaseFirestore.instance.collection('ingredients').get();
    var recipeSnapshot =
        await FirebaseFirestore.instance.collection('recipe_standards').get();

    ingredientsMap = <String, double>{
      for (var doc in ingredientsSnapshot.docs)
        doc['item'] as String:
            doc['unitCost'] is int
                ? (doc['unitCost'] as int).toDouble()
                : double.parse(doc['unitCost'].toString()),
    };
    var recipeMap = <String, double>{
      for (var doc in recipeSnapshot.docs)
        doc['item'] as String:
            doc['quantityPerPiece'] is int
                ? (doc['quantityPerPiece'] as int).toDouble()
                : double.parse(doc['quantityPerPiece'].toString()),
    };

    var invLogsByDate = {};
    for (var doc in invLogsSnapshot.docs) {
      var data = doc.data();
      var date = (data['date'] as Timestamp).toDate().toString().substring(
        0,
        10,
      );
      invLogsByDate[date] = invLogsByDate[date] ?? [];
      invLogsByDate[date].add(data);
    }

    List<DailyMetrics> metricsList = [];
    Map<String, double> totalConsumed = {};
    Map<String, double> totalDiscarded = {};
    for (var salesDoc in salesSnapshot.docs) {
      var salesData = salesDoc.data();
      var date = (salesData['date'] as Timestamp).toDate().toString().substring(
        0,
        10,
      );
      var piecesSold = salesData['piecesSold'];
      var totalRevenue =
          salesData['totalRevenue'] is int
              ? salesData['totalRevenue'].toDouble()
              : double.parse(salesData['totalRevenue'].toString());
      if (invLogsByDate.containsKey(date)) {
        var logs = invLogsByDate[date];
        double totalCost = 0;
        for (var log in logs) {
          var item = log['item'];
          var opening = log['opening'];
          var received = log['received'];
          var closing = log['closing'];
          var discarded = log['discarded'];
          var consumed = opening + received - closing - discarded;
          var unitCost = ingredientsMap[item] ?? 0;
          totalCost += consumed * unitCost;
          totalConsumed[item] = (totalConsumed[item] ?? 0) + consumed;
          totalDiscarded[item] = (totalDiscarded[item] ?? 0) + discarded;
        }
        var costPerPiece = piecesSold > 0 ? totalCost / piecesSold : 0.0;
        var sellingPricePerPiece =
            piecesSold > 0 ? totalRevenue / piecesSold : 0.0;
        var marginPerPiece = sellingPricePerPiece - costPerPiece;
        metricsList.add(
          DailyMetrics(
            date: (salesData['date'] as Timestamp).toDate(),
            costPerPiece: costPerPiece,
            marginPerPiece: marginPerPiece,
            totalCost: totalCost,
            totalRevenue: totalRevenue,
            piecesSold: piecesSold,
          ),
        );
      }
    }

    // Usage Analysis
    Map<String, UsageData> usage = {};
    for (var entry in totalConsumed.entries) {
      var item = entry.key;
      var consumed = entry.value;
      var piecesSold = metricsList.fold(0, (total, m) => total + m.piecesSold);
      var usagePerPiece = piecesSold > 0 ? consumed / piecesSold : 0.0;
      var benchmark = recipeMap[item] ?? 0;
      var deviation = benchmark > 0 ? (usagePerPiece / benchmark) - 1 : 0.0;
      usage[item] = UsageData(
        usagePerPiece: usagePerPiece,
        benchmark: benchmark,
        deviation: deviation,
      );
    }

    // Waste Analysis
    Map<String, WasteData> waste = {};
    for (var entry in totalDiscarded.entries) {
      var item = entry.key;
      var discarded = entry.value;
      var received = invLogsByDate.values
          .expand((logs) => logs)
          .where((log) => log['item'] == item)
          .fold(0.0, (total, log) => total + log['received']);
      var wastePercentage = received > 0 ? discarded / received : 0.0;
      var wasteCost = discarded * (ingredientsMap[item] ?? 0);
      waste[item] = WasteData(
        quantity: discarded,
        cost: wasteCost,
        percentage: wastePercentage,
      );
    }
    List<Map<String, dynamic>> logs =
        invLogsByDate.values
            .expand((logs) => logs)
            .toList()
            .cast<Map<String, dynamic>>();
    // Recommendations
    var recs = memoizedGenerateRecommendations(
      inventoryLogs: logs,
      usagePerPiece: usage,
      consumed: totalConsumed,
      ingredientCosts: ingredientsMap,
      recipeStandards: recipeMap,
      totalCost: metricsList.fold(0, (total, m) => total + m.totalCost.toInt()),
      avgDailySales:
          metricsList.isNotEmpty
              ? metricsList.fold(0, (total, m) => total + m.piecesSold) /
                  metricsList.length
              : 0,
    );
    setState(() {
      metrics = metricsList;
      usageData = usage;
      wasteData = waste;
      recommendations = recs;
      isLoading = false;
      if (loadMore) currentPage++;
    });
  }

  @override
  Widget build(BuildContext context) {
    double totalCosts = metrics.fold(0, (total, m) => total + m.totalCost);
    double totalRevenue = metrics.fold(0, (total, m) => total + m.totalRevenue);
    int totalPiecesSold = metrics.fold(
      0,
      (total, m) => (total + m.piecesSold).toInt(),
    );
    double avgCostPerPiece =
        totalPiecesSold > 0 ? totalCosts / totalPiecesSold : 0;
    double avgMarginPerPiece =
        totalPiecesSold > 0 ? (totalRevenue - totalCosts) / totalPiecesSold : 0;
    double grossMarginPercent =
        totalRevenue > 0
            ? (avgMarginPerPiece * totalPiecesSold / totalRevenue) * 100
            : 0;
    return Scaffold(
      appBar: AppBar(title: Text('Analysis')),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Date Range: ${selectedRange.start.toString().substring(0, 10)} - ${selectedRange.end.toString().substring(0, 10)}',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                IconButton(
                  icon: Icon(Icons.calendar_today),
                  onPressed: () async {
                    var newRange = await showDateRangePicker(
                      context: context,
                      firstDate: DateTime(2000),
                      lastDate: DateTime(2100),
                      initialDateRange: selectedRange,
                    );
                    if (newRange != null) {
                      setState(() {
                        selectedRange = newRange;
                        currentPage = 1;
                      });
                      fetchData();
                    }
                  },
                ),
              ],
            ),
            SizedBox(height: 20),

            // In the AnalysisPage widget build method, replace the existing Wrap of MetricCards with this:
            if (!isLoading && metrics.isNotEmpty)
              Wrap(
                    spacing: 12,
                    runSpacing: 16,
                    children: [
                      MetricCard(
                        title: 'Total Costs',
                        value: CurrencyFormatter().format(totalCosts),
                        icon: Icons.money_off,
                        accentColor: Colors.indigo,
                        showTrendIndicator: false,
                      ),
                      MetricCard(
                        title: 'Total Revenue',

                        value: CurrencyFormatter().format(totalRevenue),
                        icon: Icons.attach_money,
                        accentColor: Colors.green[700],
                        showTrendIndicator: false,
                      ),
                      MetricCard(
                        title: 'Avg Cost/Piece',

                        value: CurrencyFormatter().format(avgCostPerPiece),
                        icon: Icons.shopping_cart,
                        accentColor: Colors.orange,
                        showTrendIndicator: metrics.length > 1,
                        isPositive:
                            metrics.length > 1
                                ? metrics.last.costPerPiece <=
                                    metrics.first.costPerPiece
                                : true,
                      ),
                      MetricCard(
                        title: 'Gross Margin',
                        value: '${grossMarginPercent.toStringAsFixed(1)}%',
                        icon: Icons.trending_up,
                        accentColor:
                            grossMarginPercent >= 30
                                ? Colors.green[700]
                                : grossMarginPercent >= 20
                                ? Colors.amber[700]
                                : Colors.red[700],
                        showTrendIndicator: metrics.length > 1,
                        isPositive:
                            metrics.length > 1
                                ? metrics.last.marginPerPiece >=
                                    metrics.first.marginPerPiece
                                : true,
                      ),
                      MetricCard(
                        title: 'Pieces Sold',
                        value: '$totalPiecesSold',
                        icon: Icons.inventory_2,
                        accentColor: Colors.blue,
                        showTrendIndicator: metrics.length > 1,
                        isPositive:
                            metrics.length > 1
                                ? metrics.last.piecesSold >=
                                    metrics.first.piecesSold
                                : true,
                      ),
                      MetricCard(
                        title: 'Avg Margin/Piece',
                        //value: '\$${avgMarginPerPiece.toStringAsFixed(1)}',
                        value: avgMarginPerPiece.toUgx(),
                        icon: Icons.trending_up,
                        accentColor: Colors.teal,
                        showTrendIndicator: metrics.length > 1,
                        isPositive:
                            metrics.length > 1
                                ? metrics.last.marginPerPiece >=
                                    metrics.first.marginPerPiece
                                : true,
                      ),
                    ],
                  )
                  .animate()
                  .fadeIn(duration: 400.ms)
                  .slideY(
                    begin: 0.1,
                    end: 0,
                    duration: 500.ms,
                    curve: Curves.easeOutQuad,
                  ),
            SizedBox(height: 20),
            if (!isLoading && metrics.isNotEmpty)
              Card(
                    elevation: 4,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Cost Breakdown by Ingredient',
                                style: Theme.of(context).textTheme.titleLarge
                                    ?.copyWith(fontWeight: FontWeight.bold),
                              ),
                              Tooltip(
                                message:
                                    'Shows the percentage of total cost contributed by each ingredient',
                                child: Icon(
                                  Icons.info_outline,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                              ),
                            ],
                          ),
                          Divider(height: 24),
                          SizedBox(
                            height: 320,
                            child: Row(
                              children: [
                                Expanded(
                                  flex: 3,
                                  child: Semantics(
                                    label:
                                        'Pie chart showing cost breakdown by ingredient',
                                    child: PieChart(
                                      PieChartData(
                                        sectionsSpace: 2,
                                        centerSpaceRadius: 40,

                                        sections: _buildPieChartSections(),
                                        pieTouchData: PieTouchData(
                                          touchCallback: (
                                            FlTouchEvent event,
                                            pieTouchResponse,
                                          ) {
                                            // Handle touch events if needed
                                          },
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                Expanded(
                                  flex: 2,
                                  child: Padding(
                                    padding: const EdgeInsets.only(left: 16.0),
                                    child: _buildLegend(),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                          _buildCostInsights(),
                        ],
                      ),
                    ),
                  )
                  .animate()
                  .fadeIn(duration: 400.ms)
                  .slideY(
                    begin: 0.2,
                    end: 0,
                    duration: 500.ms,
                    curve: Curves.easeOutQuad,
                  ),
            SizedBox(height: 20),
            if (!isLoading && metrics.isNotEmpty)
              Column(
                children: [
                  Text(
                    'Usage per Piece',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  SizedBox(height: 10),
                  DataTable(
                    columns: [
                      DataColumn(label: Text('Ingredient')),
                      DataColumn(label: Text('Usage/Piece')),
                      DataColumn(label: Text('Benchmark')),
                      DataColumn(label: Text('Deviation')),
                    ],
                    rows:
                        usageData.entries.map((e) {
                          return DataRow(
                            cells: [
                              DataCell(Text(e.key)),
                              DataCell(
                                Text(e.value.usagePerPiece.toStringAsFixed(4)),
                              ),
                              DataCell(
                                Text(e.value.benchmark.toStringAsFixed(4)),
                              ),
                              DataCell(
                                Text(
                                  '${(e.value.deviation * 100).toStringAsFixed(1)}%',
                                  style: TextStyle(
                                    color:
                                        e.value.deviation > 0.1
                                            ? Colors.red[700]
                                            : Colors.green[700],
                                  ),
                                ),
                              ),
                            ],
                          );
                        }).toList(),
                  ),
                ],
              ).animate().fadeIn(duration: 300.ms),
            SizedBox(height: 20),
            if (!isLoading && metrics.isNotEmpty)
              Column(
                children: [
                  Text(
                    'Waste Analysis',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  SizedBox(height: 10),
                  DataTable(
                    columns: [
                      DataColumn(label: Text('Ingredient')),
                      DataColumn(label: Text('Quantity')),
                      DataColumn(label: Text('Cost')),
                      DataColumn(label: Text('Percentage')),
                    ],
                    rows:
                        wasteData.entries.map((e) {
                          return DataRow(
                            cells: [
                              DataCell(Text(e.key)),
                              DataCell(
                                Text(e.value.quantity.toStringAsFixed(1)),
                              ),
                              DataCell(Text(e.value.cost.toUgx())),
                              DataCell(
                                Text(
                                  '${(e.value.percentage * 100).toStringAsFixed(1)}%',
                                ),
                              ),
                            ],
                          );
                        }).toList(),
                  ),
                ],
              ).animate().fadeIn(duration: 300.ms),
            SizedBox(height: 20),
            if (!isLoading && recommendations.isNotEmpty)
              Column(
                children: [
                  Text(
                    'Recommendations',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  SizedBox(height: 10),
                  ...recommendations.map(
                    (rec) => Card(
                      elevation: 2,
                      child: ListTile(
                        title: Text(rec.title),
                        subtitle: Text(
                          'Details: ${rec.details}\nSavings: ${rec.savings.toStringAsFixed(2)}/month\nDifficulty: ${rec.difficulty}',
                        ),
                        trailing: ElevatedButton(
                          onPressed: () {
                            // Implement action (e.g., adjust recipe or supplier)
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('${rec.title} action initiated'),
                              ),
                            );
                          },
                          child: Text('Implement'),
                        ),
                      ),
                    ),
                  ),
                ],
              ).animate().fadeIn(duration: 300.ms),
            if (!isLoading && metrics.length >= pageSize * currentPage)
              ElevatedButton(
                onPressed: () => fetchData(loadMore: true),
                child: Text('Load More'),
              ),
            if (isLoading)
              ShimmerWidget(
                child: Column(
                  children: [
                    Container(height: 300, color: Colors.grey[300]),
                    SizedBox(height: 20),
                    Container(height: 100, color: Colors.grey[300]),
                  ],
                ),
              ),
            if (!isLoading && metrics.isEmpty)
              Center(child: Text('No data for the selected period')),
          ],
        ),
      ),
    );
  }

  List<PieChartSectionData> _buildPieChartSections() {
    double totalCost = usageData.entries.fold(0.0, (total, entry) {
      return total +
          entry.value.usagePerPiece *
              metrics.fold(0, (total, m) => total + m.piecesSold) *
              (ingredientsMap[entry.key] ?? 0);
    });

    return usageData.entries.map((entry) {
      String item = entry.key;
      double cost =
          entry.value.usagePerPiece *
          metrics.fold(0, (total, m) => total + m.piecesSold) *
          (ingredientsMap[item] ?? 0);

      double percentage = (cost / totalCost) * 100;

      Color sectionColor =
          Colors.primaries[usageData.keys.toList().indexOf(item) %
              Colors.primaries.length];

      return PieChartSectionData(
        value: cost,
        title: percentage >= 5 ? '${percentage.toStringAsFixed(1)}%' : '',
        titleStyle: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: Colors.white,
          shadows: [Shadow(color: Colors.black, blurRadius: 2)],
        ),
        radius: 100,
        color: sectionColor,
        badgeWidget:
            percentage < 5
                ? null
                : badge(sectionColor: sectionColor, percentage: percentage),
        badgePositionPercentageOffset: 0.98,
      );
    }).toList();
  }

  Widget badge({required Color sectionColor, required double percentage}) {
    return AnimatedContainer(
      duration: Duration(milliseconds: 300),
      decoration: BoxDecoration(
        color: sectionColor,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2),
        boxShadow: [
          BoxShadow(color: Colors.black26, blurRadius: 3, offset: Offset(0, 1)),
        ],
      ),
      padding: EdgeInsets.all(5),
      child: Center(
        child: Text(
          '${percentage.toStringAsFixed(0)}%',
          style: TextStyle(
            color: Colors.white,
            fontSize: 10,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    ).animate().scale(
      delay: 300.ms,
      duration: 600.ms,
      curve: Curves.elasticOut,
    );
  }

  Widget _buildLegend() {
    List<MapEntry<String, UsageData>> sortedEntries =
        usageData.entries.toList()..sort((a, b) {
          double costA =
              a.value.usagePerPiece *
              metrics.fold(0, (total, m) => total + m.piecesSold) *
              (ingredientsMap[a.key] ?? 0);
          double costB =
              b.value.usagePerPiece *
              metrics.fold(0, (total, m) => total + m.piecesSold) *
              (ingredientsMap[b.key] ?? 0);
          return costB.compareTo(costA); // Sort descending
        });

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Ingredients by Cost',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        SizedBox(height: 12),
        Expanded(
          child: ListView.builder(
            itemCount: min(sortedEntries.length, 10), // Show top 10 ingredients
            itemBuilder: (context, index) {
              String item = sortedEntries[index].key;
              double cost =
                  sortedEntries[index].value.usagePerPiece *
                  metrics.fold(0, (total, m) => total + m.piecesSold) *
                  (ingredientsMap[item] ?? 0);

              Color itemColor =
                  Colors.primaries[usageData.keys.toList().indexOf(item) %
                      Colors.primaries.length];

              return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4.0),
                    child: Row(
                      children: [
                        Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                            color: itemColor,
                            shape: BoxShape.circle,
                          ),
                        ),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            item,
                            style: TextStyle(fontSize: 13),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Text(
                          CurrencyFormatter().format(cost),
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  )
                  .animate()
                  .fadeIn(
                    delay: Duration(milliseconds: 100 * index),
                    duration: 300.ms,
                  )
                  .slideX(
                    begin: 0.2,
                    end: 0,
                    delay: Duration(milliseconds: 100 * index),
                    duration: 300.ms,
                  );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildCostInsights() {
    // Calculate top contributor
    String? topIngredient;
    double topCost = 0;

    // Calculate highest deviation
    String? highestDeviationIngredient;
    double highestDeviation = 0;

    for (var entry in usageData.entries) {
      String item = entry.key;
      double cost =
          entry.value.usagePerPiece *
          metrics.fold(0, (total, m) => total + m.piecesSold) *
          (ingredientsMap[item] ?? 0);

      if (cost > topCost) {
        topCost = cost;
        topIngredient = item;
      }

      if (entry.value.deviation.abs() > highestDeviation) {
        highestDeviation = entry.value.deviation.abs();
        highestDeviationIngredient = item;
      }
    }

    return Container(
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(
          context,
        ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Insights',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _insightCard(
                  context: context,
                  icon: Icons.trending_up,
                  title: 'Top Cost Driver',
                  subtitle: topIngredient ?? 'N/A',

                  value: topCost > 0 ? topCost.toUgx() : 'N/A',
                ),
              ),
              SizedBox(width: 16),
              Expanded(
                child: _insightCard(
                  context: context,
                  icon: Icons.compare_arrows,
                  title: 'Highest Deviation',
                  subtitle: highestDeviationIngredient ?? 'N/A',
                  value:
                      highestDeviation > 0
                          ? '${(highestDeviation * 100).toStringAsFixed(1)}%'
                          : 'N/A',
                ),
              ),
            ],
          ),
        ],
      ),
    ).animate().fadeIn(delay: 600.ms, duration: 400.ms);
  }

  Widget _insightCard({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String subtitle,
    required String value,
  }) {
    return Container(
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 2,
            offset: Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                icon,
                size: 16,
                color: Theme.of(context).colorScheme.primary,
              ),
              SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          SizedBox(height: 8),
          Text(subtitle, style: TextStyle(fontSize: 12)),
          SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
        ],
      ),
    );
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

class WasteData {
  double quantity;
  double cost;
  double percentage;

  WasteData({
    required this.quantity,
    required this.cost,
    required this.percentage,
  });
}

class Recommendation {
  String title;
  String details;
  double savings;
  String difficulty;

  Recommendation({
    required this.title,
    required this.details,
    required this.savings,
    required this.difficulty,
  });
}
