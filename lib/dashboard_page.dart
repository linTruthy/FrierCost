import 'dart:ui' as ui;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:frier_cost/currency_formatter.dart';
import 'package:frier_cost/metric_card.dart';
import 'package:flutter/services.dart';

import 'utils.dart';

// State providers for dashboard
final themeProvider = StateProvider<ThemeMode>((ref) => ThemeMode.system);
final timeRangeProvider = StateProvider<int>((ref) => 7); // days
final dashboardLayoutProvider = StateProvider<DashboardLayout>(
  (ref) => DashboardLayout.standard,
);

enum DashboardLayout { standard, compact, expanded }

class DashboardPage extends ConsumerStatefulWidget {
  const DashboardPage({super.key});

  @override
  ConsumerState<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends ConsumerState<DashboardPage>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  final ScrollController _scrollController = ScrollController();
  bool _isRefreshing = false;
  late Future<SharedPreferences> _prefs;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _prefs = SharedPreferences.getInstance();
    _loadSettings();
    _animationController.forward();

    // Haptic feedback on load
    HapticFeedback.mediumImpact();
  }

  Future<void> _loadSettings() async {
    final prefs = await _prefs;
    final themeMode = prefs.getString('themeMode') ?? 'system';
    final timeRange = prefs.getInt('timeRange') ?? 7;
    final layout = prefs.getString('dashboardLayout') ?? 'standard';

    ref.read(themeProvider.notifier).state =
        themeMode == 'dark'
            ? ThemeMode.dark
            : themeMode == 'light'
            ? ThemeMode.light
            : ThemeMode.system;

    ref.read(timeRangeProvider.notifier).state = timeRange;

    ref.read(dashboardLayoutProvider.notifier).state =
        layout == 'compact'
            ? DashboardLayout.compact
            : layout == 'expanded'
            ? DashboardLayout.expanded
            : DashboardLayout.standard;
  }

  Future<void> _saveSettings() async {
    final prefs = await _prefs;
    final themeMode = ref.read(themeProvider);
    final timeRange = ref.read(timeRangeProvider);
    final layout = ref.read(dashboardLayoutProvider);

    await prefs.setString(
      'themeMode',
      themeMode == ThemeMode.dark
          ? 'dark'
          : themeMode == ThemeMode.light
          ? 'light'
          : 'system',
    );

    await prefs.setInt('timeRange', timeRange);

    await prefs.setString(
      'dashboardLayout',
      layout == DashboardLayout.compact
          ? 'compact'
          : layout == DashboardLayout.expanded
          ? 'expanded'
          : 'standard',
    );
  }

  Future<void> _refreshData() async {
    setState(() => _isRefreshing = true);

    // Simulating data refresh
    await Future.delayed(const Duration(milliseconds: 1500));

    setState(() => _isRefreshing = false);

    // Success feedback
    HapticFeedback.lightImpact();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(themeProvider);
    final timeRange = ref.watch(timeRangeProvider);
    final layout = ref.watch(dashboardLayoutProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
      child: Scaffold(
        appBar: AppBar(
          title: Row(
            children: [
              Hero(
                tag: 'dashboard_icon',
                child: Icon(
                      Icons.dashboard_rounded,
                      color: Theme.of(context).colorScheme.primary,
                    )
                    .animate(controller: _animationController)
                    .rotate(duration: 600.ms, begin: 0.5, end: 0)
                    .scale(duration: 600.ms, begin: Offset(0.8, 0.8)),
              ),
              const SizedBox(width: 12),
              Text(
                    'Dashboard',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  )
                  .animate(controller: _animationController)
                  .fadeIn(duration: 400.ms)
                  .slideX(begin: -0.2, end: 0),
            ],
          ),
          elevation: 0,
          scrolledUnderElevation: 4,
          backgroundColor: Theme.of(
            context,
          ).colorScheme.surface.withOpacity(0.85),
          actions: [
            IconButton(
              tooltip: 'Change time range',
              icon: Stack(
                alignment: Alignment.center,
                children: [
                  Icon(Icons.calendar_today),
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Container(
                      padding: EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primary,
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        '$timeRange',
                        style: TextStyle(
                          fontSize: 8,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.onPrimary,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              onPressed: () {
                _showTimeRangeDialog(context);
              },
            ),
            IconButton(
              tooltip: 'Change layout',
              icon: Icon(
                layout == DashboardLayout.standard
                    ? Icons.dashboard_outlined
                    : layout == DashboardLayout.compact
                    ? Icons.view_compact_rounded
                    : Icons.view_agenda_outlined,
              ),
              onPressed: () {
                _showLayoutDialog(context);
              },
            ),
            IconButton(
              tooltip: 'Change theme',
              icon: Icon(
                themeMode == ThemeMode.dark
                    ? Icons.dark_mode
                    : themeMode == ThemeMode.light
                    ? Icons.light_mode
                    : Icons.brightness_auto,
              ),
              onPressed: () {
                _showThemeDialog(context);
              },
            ),
          ],
        ),
        body: RefreshIndicator(
          onRefresh: _refreshData,
          child: StreamBuilder(
            stream:
                FirebaseFirestore.instance
                    .collection('sales')
                    .orderBy('date', descending: true)
                    .limit(timeRange)
                    .snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return _buildShimmerLoader(context);
              }
              var salesDocs = snapshot.data!.docs;
              return StreamBuilder(
                stream:
                    FirebaseFirestore.instance
                        .collection('inventory_logs')
                        .where(
                          'date',
                          isGreaterThanOrEqualTo: Timestamp.fromDate(
                            DateTime.now().subtract(Duration(days: timeRange)),
                          ),
                        )
                        .snapshots(),
                builder: (context, invSnapshot) {
                  if (!invSnapshot.hasData) {
                    return _buildShimmerLoader(context);
                  }
                  var invLogs = invSnapshot.data!.docs;
                  var metrics = _calculateMetrics(salesDocs, invLogs);
                  var highWaste = _calculateHighWaste(invLogs);
                  var usageDeviations = _calculateUsageDeviations(
                    salesDocs,
                    invLogs,
                  );

                  // Calculate trends
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

                  // Calculate sales trends
                  var previousDaySales =
                      salesDocs.length > 1
                          ? salesDocs[1]['piecesSold'] as int
                          : 0;
                  var todaySales =
                      salesDocs.isNotEmpty
                          ? salesDocs.first['piecesSold'] as int
                          : 0;
                  bool dailySalesTrend = todaySales >= previousDaySales;

                  return _buildDashboardContent(
                    context: context,
                    metrics: metrics,
                    highWaste: highWaste,
                    usageDeviations: usageDeviations,
                    costTrend: costTrend,
                    marginTrend: marginTrend,
                    dailySalesTrend: dailySalesTrend,
                    salesDocs: salesDocs,
                    layout: layout,
                  );
                },
              );
            },
          ),
        ),
        floatingActionButton:
            _isRefreshing
                ? null
                : FloatingActionButton(
                      onPressed: _refreshData,
                      tooltip: 'Refresh data',
                      child: Icon(Icons.refresh),
                    )
                    .animate()
                    .scale(duration: 300.ms, curve: Curves.easeOut)
                    .fadeIn(),
      ),
    );
  }

  void _showTimeRangeDialog(BuildContext context) {
    // final timeRange = ref.read(timeRangeProvider);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder:
          (context) => Container(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            padding: EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Select Time Range',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 16),
                _buildTimeRangeSelector(),
                const SizedBox(height: 24),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    minimumSize: Size(double.infinity, 50),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text('Apply'),
                  onPressed: () {
                    _saveSettings();
                    Navigator.pop(context);
                  },
                ),
              ],
            ),
          ).animate().slideY(
            begin: 1,
            end: 0,
            duration: 400.ms,
            curve: Curves.easeOutQuart,
          ),
    );
  }

  Widget _buildTimeRangeSelector() {
    final timeRange = ref.watch(timeRangeProvider);

    return Column(
      children: [
        Slider(
          value: timeRange.toDouble(),
          min: 3,
          max: 30,
          divisions: 27,
          label: timeRange.toString(),
          onChanged: (value) {
            ref.read(timeRangeProvider.notifier).state = value.toInt();
            HapticFeedback.selectionClick();
          },
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [Text('3 days'), Text('$timeRange days'), Text('30 days')],
        ),
      ],
    );
  }

  void _showLayoutDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder:
          (context) => Container(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            padding: EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Select Dashboard Layout',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 24),
                _buildLayoutOptions(),
                const SizedBox(height: 24),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    minimumSize: Size(double.infinity, 50),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text('Apply'),
                  onPressed: () {
                    _saveSettings();
                    Navigator.pop(context);
                  },
                ),
              ],
            ),
          ).animate().slideY(
            begin: 1,
            end: 0,
            duration: 400.ms,
            curve: Curves.easeOutQuart,
          ),
    );
  }

  Widget _buildLayoutOptions() {
    final layout = ref.watch(dashboardLayoutProvider);

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _buildLayoutOption(
          context,
          Icons.dashboard_outlined,
          'Standard',
          DashboardLayout.standard,
          layout == DashboardLayout.standard,
        ),
        _buildLayoutOption(
          context,
          Icons.view_compact_rounded,
          'Compact',
          DashboardLayout.compact,
          layout == DashboardLayout.compact,
        ),
        _buildLayoutOption(
          context,
          Icons.view_agenda_outlined,
          'Expanded',
          DashboardLayout.expanded,
          layout == DashboardLayout.expanded,
        ),
      ],
    );
  }

  Widget _buildLayoutOption(
    BuildContext context,
    IconData icon,
    String label,
    DashboardLayout layoutValue,
    bool isSelected,
  ) {
    return GestureDetector(
      onTap: () {
        ref.read(dashboardLayoutProvider.notifier).state = layoutValue;
        HapticFeedback.selectionClick();
      },
      child: AnimatedContainer(
        duration: Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
          color:
              isSelected
                  ? Theme.of(context).colorScheme.primaryContainer
                  : Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color:
                isSelected
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).colorScheme.outline.withOpacity(0.3),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              size: 32,
              color:
                  isSelected
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color:
                    isSelected
                        ? Theme.of(context).colorScheme.primary
                        : Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showThemeDialog(BuildContext context) {
    final themeMode = ref.read(themeProvider);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder:
          (context) => Container(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            padding: EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Select Theme',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildThemeOption(
                      context,
                      Icons.brightness_auto,
                      'System',
                      ThemeMode.system,
                      themeMode == ThemeMode.system,
                    ),
                    _buildThemeOption(
                      context,
                      Icons.light_mode,
                      'Light',
                      ThemeMode.light,
                      themeMode == ThemeMode.light,
                    ),
                    _buildThemeOption(
                      context,
                      Icons.dark_mode,
                      'Dark',
                      ThemeMode.dark,
                      themeMode == ThemeMode.dark,
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    minimumSize: Size(double.infinity, 50),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text('Apply'),
                  onPressed: () {
                    _saveSettings();
                    Navigator.pop(context);
                  },
                ),
              ],
            ),
          ).animate().slideY(
            begin: 1,
            end: 0,
            duration: 400.ms,
            curve: Curves.easeOutQuart,
          ),
    );
  }

  Widget _buildThemeOption(
    BuildContext context,
    IconData icon,
    String label,
    ThemeMode themeValue,
    bool isSelected,
  ) {
    return GestureDetector(
      onTap: () {
        ref.read(themeProvider.notifier).state = themeValue;
        HapticFeedback.selectionClick();
      },
      child: AnimatedContainer(
        duration: Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
          color:
              isSelected
                  ? Theme.of(context).colorScheme.primaryContainer
                  : Theme.of(context).colorScheme.surfaceVariant,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color:
                isSelected
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).colorScheme.outline.withOpacity(0.3),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              size: 32,
              color:
                  isSelected
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color:
                    isSelected
                        ? Theme.of(context).colorScheme.primary
                        : Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildShimmerLoader(BuildContext context) {
    return AnimationLimiter(
      child: ListView.builder(
        itemCount: 5,
        padding: EdgeInsets.all(16),
        itemBuilder: (context, index) {
          return AnimationConfiguration.staggeredList(
            position: index,
            duration: const Duration(milliseconds: 500),
            child: SlideAnimation(
              verticalOffset: 50.0,
              child: FadeInAnimation(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 16.0),
                  child: ShimmerWidget(
                    child: Container(
                      height:
                          index == 0
                              ? 100
                              : index % 2 == 0
                              ? 200
                              : 120,
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildDashboardContent({
    required BuildContext context,
    required List metrics,
    required Map<String, double> highWaste,
    required Map<String, double> usageDeviations,
    required bool costTrend,
    required bool marginTrend,
    required bool dailySalesTrend,
    required dynamic salesDocs,
    required DashboardLayout layout,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final bool isTablet = constraints.maxWidth > 600;

        // Define card sizes based on layout
        final double cardWidth =
            layout == DashboardLayout.compact
                ? constraints.maxWidth / (isTablet ? 4 : 2) - 20
                : constraints.maxWidth;

        final double cardHeight = layout == DashboardLayout.compact ? 160 : 120;

        final double chartHeight =
            layout == DashboardLayout.expanded ? 400 : 320;

        return AnimationLimiter(
          child: SingleChildScrollView(
            controller: _scrollController,
            padding: EdgeInsets.all(16.0),
            physics: const AlwaysScrollableScrollPhysics(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: AnimationConfiguration.toStaggeredList(
                duration: const Duration(milliseconds: 600),
                childAnimationBuilder:
                    (widget) => SlideAnimation(
                      verticalOffset: 50.0,
                      child: FadeInAnimation(child: widget),
                    ),
                children: [
                  // Summary section with animation
                  _buildSummarySection(context, metrics),

                  // Metric cards section
                  const SizedBox(height: 24),
                  _buildMetricCardsSection(
                    context: context,
                    metrics: metrics,
                    costTrend: costTrend,
                    marginTrend: marginTrend,
                    dailySalesTrend: dailySalesTrend,
                    salesDocs: salesDocs,
                    layout: layout,
                    cardWidth: cardWidth,
                    cardHeight: cardHeight,
                  ),

                  // Alert cards
                  if (highWaste.isNotEmpty) const SizedBox(height: 24),
                  if (highWaste.isNotEmpty)
                    _buildHighWasteCard(context, highWaste),

                  if (usageDeviations.isNotEmpty) const SizedBox(height: 24),
                  if (usageDeviations.isNotEmpty)
                    _buildUsageDeviationsCard(context, usageDeviations),

                  // Charts section
                  const SizedBox(height: 32),
                  _buildChartSection(
                    context: context,
                    title: 'Cost per Piece',
                    subtitle:
                        'Showing cost per piece trends over the past ${ref.read(timeRangeProvider)} days',
                    metrics: metrics,
                    isMargin: false,
                    color: Colors.amber[700]!,
                    height: chartHeight,
                  ),

                  const SizedBox(height: 32),
                  _buildChartSection(
                    context: context,
                    title: 'Profit Margin',
                    subtitle:
                        'Showing profit margin trends over the past ${ref.read(timeRangeProvider)} days',
                    metrics: metrics,
                    isMargin: true,
                    color: Colors.green[700]!,
                    height: chartHeight,
                  ),

                  // Hint text at bottom
                  const SizedBox(height: 40),
                  Center(
                    child: Semantics(
                      label: 'Swipe down to refresh data',
                      child: Text(
                        'Pull down to refresh data',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(
                            context,
                          ).colorScheme.onSurface.withOpacity(0.5),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 80), // Space for FAB
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildSummarySection(BuildContext context, List metrics) {
    // Calculate summary values
    final totalRevenue = _calculateWeeklyRevenue(metrics);
    final totalCost = metrics.fold(
      0.0,
      (total, metric) => total + metric.totalCost,
    );
    final profitMargin =
        totalRevenue > 0
            ? ((totalRevenue - totalCost) / totalRevenue) * 100
            : 0;
    final totalPieces = metrics.fold(
      0.0,
      (total, metric) => total + metric.piecesSold,
    );

    return Container(
          width: double.infinity,
          padding: EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Theme.of(context).colorScheme.primary,
                Theme.of(context).colorScheme.primary.withOpacity(0.8),
              ],
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Theme.of(context).colorScheme.primary.withOpacity(0.3),
                blurRadius: 10,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.analytics_rounded,
                    color: Theme.of(context).colorScheme.onPrimary,
                  ),
                  SizedBox(width: 8),
                  Text(
                    '${ref.read(timeRangeProvider)}-Day Summary',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onPrimary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              IntrinsicHeight(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildSummaryMetric(
                      context,
                      'Revenue',
                      CurrencyFormatter().format(totalRevenue),
                      Icons.attach_money_rounded,
                    ),
                    VerticalDivider(
                      thickness: 1,
                      width: 32,
                      color: Theme.of(
                        context,
                      ).colorScheme.onPrimary.withOpacity(0.3),
                    ),
                    _buildSummaryMetric(
                      context,
                      'Profit Margin',
                      '${profitMargin.toStringAsFixed(1)}%',
                      Icons.trending_up_rounded,
                    ),
                    VerticalDivider(
                      thickness: 1,
                      width: 32,
                      color: Theme.of(
                        context,
                      ).colorScheme.onPrimary.withOpacity(0.3),
                    ),
                    _buildSummaryMetric(
                      context,
                      'Total Pieces',
                      totalPieces.toString(),
                      Icons.shopping_bag_rounded,
                    ),
                  ],
                ),
              ),
            ],
          ),
        )
        .animate()
        .fadeIn(duration: 600.ms)
        .scale(begin: Offset(0.95, 0.95), end: Offset(1, 1));
  }

  Widget _buildSummaryMetric(
    BuildContext context,
    String label,
    String value,
    IconData icon,
  ) {
    return Column(
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16,
              color: Theme.of(context).colorScheme.onPrimary.withOpacity(0.8),
            ),
            SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onPrimary.withOpacity(0.8),
                fontSize: 12,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            color: Theme.of(context).colorScheme.onPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildMetricCardsSection({
    required BuildContext context,
    required List metrics,
    required bool costTrend,
    required bool marginTrend,
    required bool dailySalesTrend,
    required dynamic salesDocs,
    required DashboardLayout layout,
    required double cardWidth,
    required double cardHeight,
  }) {
    // Calculate weekly revenue
    final weeklyRevenue = _calculateWeeklyRevenue(metrics);

    Widget buildMetricCardWrapper(Widget child) {
      if (layout == DashboardLayout.compact) {
        return SizedBox(width: cardWidth, height: cardHeight, child: child);
      }
      return child;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4.0, bottom: 16.0),
          child: Text(
            'Today\'s Performance',
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            semanticsLabel: 'Today\'s Performance Metrics',
          ),
        ),
        layout == DashboardLayout.compact
            ? Wrap(
              spacing: 16,
              runSpacing: 16,
              children: [
                buildMetricCardWrapper(
                  MetricCard(
                    title: 'Cost/Piece',
                    value:
                        metrics.isNotEmpty
                            ? CurrencyFormatter().format(
                              metrics.last.costPerPiece,
                            )
                            : '\$0.00',
                    icon: Icons.attach_money_rounded,
                    accentColor: Colors.amber[700]!,
                    isPositive: costTrend,
                    showTrendIndicator: metrics.length > 1,
                    animationDuration: 600.ms,
                    semanticsLabel: 'Cost per piece metric',
                  ),
                ),
                buildMetricCardWrapper(
                  MetricCard(
                    title: 'Margin/Piece',
                    value:
                        metrics.isNotEmpty
                            ? CurrencyFormatter().format(
                              metrics.last.marginPerPiece,
                            )
                            : '\$0.00',
                    icon: Icons.trending_up_rounded,
                    accentColor: Colors.green[700]!,
                    isPositive: marginTrend,
                    showTrendIndicator: metrics.length > 1,
                    animationDuration: 700.ms,
                    semanticsLabel: 'Margin per piece metric',
                  ),
                ),
                buildMetricCardWrapper(
                  MetricCard(
                    title: 'Daily Sales',
                    value:
                        salesDocs.isNotEmpty
                            ? '${salesDocs.first['piecesSold']} pieces'
                            : '0 pieces',
                    icon: Icons.shopping_cart_rounded,
                    accentColor: Colors.blue[700]!,
                    isPositive: dailySalesTrend,
                    showTrendIndicator: salesDocs.length > 1,
                    animationDuration: 800.ms,
                    semanticsLabel: 'Daily sales metric',
                  ),
                ),
                buildMetricCardWrapper(
                  MetricCard(
                    title: 'Weekly Revenue',
                    value: CurrencyFormatter().format(weeklyRevenue),
                    icon: Icons.account_balance_wallet_rounded,
                    accentColor: Colors.purple[700]!,
                    isPositive: true,
                    showTrendIndicator: false,
                    animationDuration: 900.ms,
                    semanticsLabel: 'Weekly revenue metric',
                  ),
                ),
              ],
            )
            : Column(
              children: [
                MetricCard(
                  title: 'Cost/Piece',
                  value:
                      metrics.isNotEmpty
                          ? CurrencyFormatter().format(
                            metrics.last.costPerPiece,
                          )
                          : '\$0.00',
                  icon: Icons.attach_money_rounded,
                  accentColor: Colors.amber[700]!,
                  isPositive: costTrend,
                  showTrendIndicator: metrics.length > 1,
                  animationDuration: 600.ms,
                  semanticsLabel: 'Cost per piece metric',
                ),
                SizedBox(height: 16),
                MetricCard(
                  title: 'Margin/Piece',
                  value:
                      metrics.isNotEmpty
                          ? CurrencyFormatter().format(
                            metrics.last.marginPerPiece,
                          )
                          : '\$0.00',
                  icon: Icons.trending_up_rounded,
                  accentColor: Colors.green[700]!,
                  isPositive: marginTrend,
                  showTrendIndicator: metrics.length > 1,
                  animationDuration: 700.ms,
                  semanticsLabel: 'Margin per piece metric',
                ),
                SizedBox(height: 16),
                MetricCard(
                  title: 'Daily Sales',
                  value:
                      salesDocs.isNotEmpty
                          ? '${salesDocs.first['piecesSold']} pieces'
                          : '0 pieces',
                  icon: Icons.shopping_cart_rounded,
                  accentColor: Colors.blue[700]!,
                  isPositive: dailySalesTrend,
                  showTrendIndicator: salesDocs.length > 1,
                  animationDuration: 800.ms,
                  semanticsLabel: 'Daily sales metric',
                ),
                SizedBox(height: 16),
                MetricCard(
                  title: 'Weekly Revenue',
                  value: CurrencyFormatter().format(weeklyRevenue),
                  icon: Icons.account_balance_wallet_rounded,
                  accentColor: Colors.purple[700]!,
                  isPositive: true,
                  showTrendIndicator: false,
                  animationDuration: 900.ms,
                  semanticsLabel: 'Weekly revenue metric',
                ),
              ],
            ),
      ],
    );
  }

  Widget _buildHighWasteCard(
    BuildContext context,
    Map<String, double> highWaste,
  ) {
    return Card(
      elevation: 4,
      shadowColor: Color(0xFFD32F2F).withOpacity(0.3),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Color(0xFFD32F2F).withOpacity(0.3), width: 1),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter:
              Theme.of(context).brightness == Brightness.dark
                  ? ui.ImageFilter.blur(sigmaX: 0, sigmaY: 0)
                  : ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Color(0xFFD32F2F).withOpacity(0.08),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _buildPulsingIcon(
                      context,
                      Icons.warning_amber_rounded,
                      Color(0xFFD32F2F),
                    ),
                    SizedBox(width: 12),
                    Text(
                      'High Waste Alert',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: Color(0xFFD32F2F),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Spacer(),
                    Tooltip(
                      message: 'Items with waste above 5% of total received',
                      child: Icon(
                        Icons.info_outline,
                        size: 18,
                        color: Theme.of(
                          context,
                        ).colorScheme.onSurface.withOpacity(0.6),
                      ),
                    ),
                  ],
                ),
                Divider(height: 24),
                ...highWaste.entries.map(
                  (e) => Padding(
                    padding: const EdgeInsets.only(bottom: 12.0),
                    child: Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color:
                                e.value > 0.1
                                    ? Color(0xFFD32F2F)
                                    : Color(0xFFD32F2F).withOpacity(0.7),
                          ),
                        ),
                        SizedBox(width: 12),
                        Expanded(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                e.key,
                                style: TextStyle(
                                  fontWeight:
                                      e.value > 0.1
                                          ? FontWeight.bold
                                          : FontWeight.normal,
                                ),
                              ),
                              Text(
                                '${(e.value * 100).toStringAsFixed(1)}% waste',
                                style: TextStyle(
                                  fontWeight:
                                      e.value > 0.1
                                          ? FontWeight.bold
                                          : FontWeight.normal,
                                  color:
                                      e.value > 0.1
                                          ? Color(0xFFD32F2F)
                                          : Theme.of(
                                            context,
                                          ).colorScheme.onSurface,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                SizedBox(height: 8),
                Center(
                  child: TextButton.icon(
                    icon: Icon(Icons.remove_red_eye),
                    label: Text('View Waste Details'),
                    onPressed: () {
                      // Would navigate to detailed waste report
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Waste details would open here'),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ).animate().fadeIn(duration: 600.ms).slideY(begin: 0.2, end: 0);
  }

  Widget _buildPulsingIcon(BuildContext context, IconData icon, Color color) {
    return Container(
          padding: EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color, size: 24),
        )
        .animate(onPlay: (controller) => controller.repeat())
        .scale(
          begin: Offset(1, 1),
          end: Offset(1.2, 1.2),
          duration: 1000.ms,
          curve: Curves.easeInOut,
        )
        .then()
        .scale(
          begin: Offset(1.2, 1.2),
          end: Offset(1, 1),
          duration: 1000.ms,
          curve: Curves.easeInOut,
        );
  }

  Widget _buildUsageDeviationsCard(
    BuildContext context,
    Map<String, double> usageDeviations,
  ) {
    return Card(
          elevation: 4,
          shadowColor: Colors.orange[700]!.withOpacity(0.3),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(
              color: Colors.orange[700]!.withOpacity(0.3),
              width: 1,
            ),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: BackdropFilter(
              filter:
                  Theme.of(context).brightness == Brightness.dark
                      ? ui.ImageFilter.blur(sigmaX: 0, sigmaY: 0)
                      : ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.orange[700]!.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.orange[700]!.withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.analytics_rounded,
                            color: Colors.orange[700],
                            size: 24,
                          ),
                        ),
                        SizedBox(width: 12),
                        Text(
                          'Usage Deviations',
                          style: Theme.of(
                            context,
                          ).textTheme.titleMedium?.copyWith(
                            color: Colors.orange[700],
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Spacer(),
                        Tooltip(
                          message: 'Items exceeding expected usage benchmarks',
                          child: Icon(
                            Icons.info_outline,
                            size: 18,
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurface.withOpacity(0.6),
                          ),
                        ),
                      ],
                    ),
                    Divider(height: 24),
                    ...usageDeviations.entries.map(
                      (e) => Padding(
                        padding: const EdgeInsets.only(bottom: 12.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 8,
                                  height: 8,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color:
                                        e.value > 0.2
                                            ? Colors.orange[700]
                                            : Colors.orange[700]!.withOpacity(
                                              0.7,
                                            ),
                                  ),
                                ),
                                SizedBox(width: 12),
                                Text(
                                  e.key,
                                  style: TextStyle(
                                    fontWeight:
                                        e.value > 0.2
                                            ? FontWeight.bold
                                            : FontWeight.normal,
                                  ),
                                ),
                                Spacer(),
                                Text(
                                  '${(e.value * 100).toStringAsFixed(1)}% over',
                                  style: TextStyle(
                                    fontWeight:
                                        e.value > 0.2
                                            ? FontWeight.bold
                                            : FontWeight.normal,
                                    color:
                                        e.value > 0.2
                                            ? Colors.orange[700]
                                            : Theme.of(
                                              context,
                                            ).colorScheme.onSurface,
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: 4),
                            // Progress indicator for visual reference
                            ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                value: e.value.clamp(0.0, 1.0),
                                backgroundColor: Colors.orange[100],
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  e.value > 0.5
                                      ? Colors.orange[900]!
                                      : e.value > 0.3
                                      ? Colors.orange[800]!
                                      : Colors.orange[700]!,
                                ),
                                minHeight: 6,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    SizedBox(height: 8),
                    Center(
                      child: TextButton.icon(
                        icon: Icon(Icons.tune),
                        label: Text('Adjust Benchmarks'),
                        onPressed: () {
                          // Would navigate to benchmark adjustment screen
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                'Benchmark adjustments would open here',
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        )
        .animate()
        .fadeIn(duration: 600.ms, delay: 200.ms)
        .slideY(begin: 0.2, end: 0);
  }

  Widget _buildChartSection({
    required BuildContext context,
    required String title,
    required String subtitle,
    required List metrics,
    required bool isMargin,
    required Color color,
    required double height,
  }) {
    return Card(
      elevation: 4,
      shadowColor: color.withOpacity(0.3),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                      semanticsLabel: '$title chart',
                    ),
                    SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(
                          context,
                        ).textTheme.bodyMedium?.color?.withOpacity(0.7),
                      ),
                    ),
                  ],
                ),
                _buildChartLegend(context, color, isMargin),
              ],
            ),
            SizedBox(height: 16),
            metrics.isEmpty
                ? _buildEmptyChartPlaceholder(context, height)
                : _buildInteractiveChart(
                  context: context,
                  metrics: metrics,
                  isMargin: isMargin,
                  color: color,
                  height: height,
                ),
            //   if (metrics.isNotEmpty)
            //    _buildChartAnalysis(context, metrics, isMargin),
          ],
        ),
      ),
    ).animate().fadeIn(duration: 800.ms).slideY(begin: 0.2, end: 0);
  }

  Widget _buildChartLegend(BuildContext context, Color color, bool isMargin) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          SizedBox(width: 6),
          Text(
            isMargin ? 'Profit' : 'Cost',
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyChartPlaceholder(BuildContext context, double height) {
    return Container(
      height: height,
      alignment: Alignment.center,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.bar_chart,
            size: 64,
            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.2),
          ),
          SizedBox(height: 16),
          Text(
            'No data available for chart',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
            ),
          ),
          SizedBox(height: 8),
          ElevatedButton(onPressed: _refreshData, child: Text('Refresh Data')),
        ],
      ),
    );
  }

  Widget _buildInteractiveChart({
    required BuildContext context,
    required List metrics,
    required bool isMargin,
    required Color color,
    required double height,
  }) {
    return SizedBox(
      height: height,
      child: MergeSemantics(
        child: Semantics(
          label:
              'Line chart showing ${isMargin ? "profit margin" : "cost per piece"} over ${metrics.length} days',
          child: LineChart(
            LineChartData(
              lineTouchData: LineTouchData(
                touchTooltipData: LineTouchTooltipData(
                  // tooltipBgColor: Theme.of(context).cardColor.withOpacity(0.8),
                  tooltipRoundedRadius: 8,
                  tooltipPadding: EdgeInsets.all(8),
                  tooltipHorizontalAlignment: FLHorizontalAlignment.right,
                  getTooltipItems: (touchedSpots) {
                    return touchedSpots.map((spot) {
                      int index = spot.x.toInt();
                      if (index >= 0 && index < metrics.length) {
                        String date = DateFormat(
                          'MMM dd',
                        ).format(metrics[index].date);
                        double value =
                            isMargin
                                ? metrics[index].marginPerPiece
                                : metrics[index].costPerPiece;
                        return LineTooltipItem(
                          '$date: ${CurrencyFormatter().formatWithPrecision(value, 2)}',
                          TextStyle(
                            color: Theme.of(context).textTheme.bodyLarge?.color,
                            fontWeight: FontWeight.bold,
                          ),
                        );
                      }
                      return null;
                    }).toList();
                  },
                ),
                handleBuiltInTouches: true,
                touchCallback: (event, touchResponse) {
                  if (event is FlTapUpEvent) {
                    // Optional: Show more details when tapping on a point
                    if (touchResponse?.lineBarSpots?.isNotEmpty ?? false) {
                      int index = touchResponse!.lineBarSpots!.first.x.toInt();
                      if (index >= 0 && index < metrics.length) {
                        HapticFeedback.selectionClick();
                        // Show detailed information about this data point
                        _showDetailedMetricDialog(
                          context,
                          metrics[index],
                          isMargin,
                        );
                      }
                    }
                  }
                },
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
                  preventCurveOverShooting: true,
                  gradient: LinearGradient(
                    colors: [color.withOpacity(0.7), color],
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
                    checkToShowDot: (spot, barData) {
                      // Show dots for first, last, min and max values
                      int index = spot.x.toInt();
                      if (index == 0 || index == metrics.length - 1) {
                        return true;
                      }

                      // Find min and max
                      double min = double.infinity;
                      double max = double.negativeInfinity;
                      int minIndex = 0;
                      int maxIndex = 0;

                      for (int i = 0; i < metrics.length; i++) {
                        double val =
                            isMargin
                                ? metrics[i].marginPerPiece
                                : metrics[i].costPerPiece;
                        if (val < min) {
                          min = val;
                          minIndex = i;
                        }
                        if (val > max) {
                          max = val;
                          maxIndex = i;
                        }
                      }

                      return index == minIndex || index == maxIndex;
                    },
                  ),
                  belowBarData: BarAreaData(
                    show: true,
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [color.withOpacity(0.3), color.withOpacity(0.0)],
                    ),
                  ),
                ),
              ],
              minY: _getMinY(metrics, isMargin) * 0.95,
              maxY: _getMaxY(metrics, isMargin) * 1.05,
              titlesData: FlTitlesData(
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    getTitlesWidget: (value, meta) {
                      int index = value.toInt();
                      if (index >= 0 && index < metrics.length) {
                        // Only show some dates to avoid overcrowding
                        if (metrics.length > 7 &&
                            index % 2 != 0 &&
                            index != metrics.length - 1) {
                          return const SizedBox.shrink();
                        }

                        return Padding(
                          padding: const EdgeInsets.only(top: 8.0),
                          child: Text(
                            DateFormat('MM/dd').format(metrics[index].date),
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
                  bottom: BorderSide(color: Theme.of(context).dividerColor),
                  left: BorderSide(color: Theme.of(context).dividerColor),
                ),
              ),
              gridData: FlGridData(
                show: true,
                drawHorizontalLine: true,
                horizontalInterval: _getGridInterval(metrics, isMargin),
                getDrawingHorizontalLine:
                    (value) => FlLine(
                      color: Theme.of(context).dividerColor.withOpacity(0.3),
                      strokeWidth: 1,
                      dashArray: [5, 5],
                    ),
              ),
            ),
          ),
        ),
      ),
    ).animate().fadeIn(duration: 600.ms).slideY(begin: 0.2, end: 0);
  }

  void _showDetailedMetricDialog(
    BuildContext context,
    dynamic metric,
    bool isMargin,
  ) {
    showDialog(
      context: context,
      builder:
          (context) => Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Details for ${DateFormat('MMMM dd, yyyy').format(metric.date)}',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  Divider(height: 24),
                  _buildMetricDetailRow(
                    context,
                    'Cost per Piece',
                    CurrencyFormatter().format(metric.costPerPiece),
                    Icons.attach_money,
                  ),
                  SizedBox(height: 12),
                  _buildMetricDetailRow(
                    context,
                    'Margin per Piece',
                    CurrencyFormatter().format(metric.marginPerPiece),
                    Icons.trending_up,
                  ),
                  SizedBox(height: 12),
                  _buildMetricDetailRow(
                    context,
                    'Pieces Sold',
                    '${metric.piecesSold}',
                    Icons.shopping_cart,
                  ),
                  SizedBox(height: 12),
                  _buildMetricDetailRow(
                    context,
                    'Total Revenue',
                    CurrencyFormatter().format(metric.totalRevenue),
                    Icons.account_balance_wallet,
                  ),
                  SizedBox(height: 12),
                  _buildMetricDetailRow(
                    context,
                    'Total Cost',
                    CurrencyFormatter().format(metric.totalCost),
                    Icons.receipt_long,
                  ),
                  SizedBox(height: 24),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      child: Text('Close'),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ),
                ],
              ),
            ),
          ),
    );
  }

  Widget _buildMetricDetailRow(
    BuildContext context,
    String label,
    String value,
    IconData icon,
  ) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Theme.of(context).colorScheme.primary),
        SizedBox(width: 8),
        Text(
          '$label:',
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
          ),
        ),
        SizedBox(width: 8),
        Text(value, style: TextStyle(fontWeight: FontWeight.bold)),
      ],
    );
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
    var totalReceived = logs.fold(0.0, (total, log) => total + log['received']);
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

double _calculateWeeklyRevenue(List metrics) {
  if (metrics.isEmpty) return 0;
  return metrics.fold(0.0, (total, metric) => total + metric.totalRevenue);
}
  
  // Widget _buildChartAnalysis(BuildContext context, List metrics, bool isMargin) {
  //   if (metrics.length < 2) return SizedBox.shrink();
    
  //   // Calculate trend statistics
  //   double current = isMargin 
  //       ? metrics.last.marginPerPiece 
  //       : metrics.last.costPerPiece;
  //   double previous = isMargin 
  //       ? metrics[metrics.length - 2].marginPerPiece 
  //       : metrics[metrics.length - 2].costPerPiece;
    
  //   double changeAmount = current - previous;
  //   double changePercent = previous != 0 ? (changeAmount / previous) * 100 : 0;
    
  //   // Determine if the change is positive based on what we're measuring
  //   // For cost, lower is better. For margin, higher is better.
  //   bool isPositive = isMargin ? changeAmount > 0 : changeAmount < 0;
    
  //   String trendMessage = isMargin
  //       ? (isPositive
  //           ? 'Profit margin is improving!'
  //           : 'Profit margin has decreased.')
  //       : (isPositive
  //           ? 'Cost per piece is decreasing!'
  //           : 'Cost per piece