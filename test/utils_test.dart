import 'package:flutter_test/flutter_test.dart';
import 'package:frier_cost/utils.dart';

void main() {
  group('Utils grouping', () {
    final sampleLogs = [
      {'item': 'Chicken', 'date': DateTime(2025,4,25), 'received': 10.0, 'discarded': 2.0, 'opening': 5.0, 'closing': 5.0},
      {'item': 'Lettuce', 'date': DateTime(2025,4,25), 'received':  4.0, 'discarded': 1.0, 'opening': 2.0, 'closing': 2.0},
      {'item': 'Chicken', 'date': DateTime(2025,4,26), 'received':  5.0, 'discarded': 0.5, 'opening': 3.0, 'closing': 2.5},
    ];

    test('groupLogsByDate partitions by YYYY-MM-DD', () {
      final byDate = groupLogsByDate(sampleLogs);
      expect(byDate.keys, containsAll(['2025-04-25','2025-04-26']));
      expect(byDate['2025-04-25']!.length, 2);
      expect(byDate['2025-04-26']!.length, 1);
    });

    test('groupLogsByItem partitions by item name', () {
      final byItem = groupLogsByItem(sampleLogs);
      expect(byItem.keys, containsAll(['Chicken','Lettuce']));
      expect(byItem['Chicken']!.length, 2);
      expect(byItem['Lettuce']!.length, 1);
    });
  });
}
