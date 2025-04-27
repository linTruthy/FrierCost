
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frier_cost/metric_card.dart';

void main() {
  testWidgets('MetricCard shows title, value & icon', (WidgetTester tester) async {
    await tester.pumpWidget(MaterialApp(
      home: MetricCard(
        title: 'Test Title',
        value: '42',
        icon: Icons.access_alarm,
      ),
    ));

    expect(find.text('Test Title'), findsOneWidget);
    expect(find.text('42'), findsOneWidget);
    expect(find.byIcon(Icons.access_alarm), findsOneWidget);
  });

  testWidgets('MetricCard trend indicator down when negative', (WidgetTester tester) async {
    await tester.pumpWidget(MaterialApp(
      home: MetricCard(
        title: 'Trend',
        value: '10',
        showTrendIndicator: true,
        isPositive: false,
      ),
    ));

    // trending_down_rounded appears
    expect(find.byIcon(Icons.trending_down_rounded), findsOneWidget);
  });
}
