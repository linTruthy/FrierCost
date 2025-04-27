import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'dart:async';

Map<String, double> _ingredientsCache = {};
Map<String, double> _recipeCache = {};
Timer? _debounceTimer;

// Map<String, double> cachedIngredients() {
//   if (_ingredientsCache.isEmpty) {
//     FirebaseFirestore.instance.collection('ingredients').get().then((snapshot) {
//       _ingredientsCache = {
//         for (var doc in snapshot.docs)
//          doc['item']: double.parse(doc['unitCost']),
//       };
//     });
//   }
//   return _ingredientsCache;
// }
Map<String, double> cachedIngredients() {
  if (_ingredientsCache.isEmpty) {
    FirebaseFirestore.instance.collection('ingredients').get().then((snapshot) {
      _ingredientsCache = {
        for (var doc in snapshot.docs)
          doc['item']:
              doc['unitCost'] is int
                  ? (doc['unitCost'] as int).toDouble()
                  : double.parse(doc['unitCost'].toString()),
      };
    });
  }
  return _ingredientsCache;
}

// Map<String, double> cachedRecipes() {
//   if (_recipeCache.isEmpty) {
//     FirebaseFirestore.instance.collection('recipe_standards').get().then((
//       snapshot,
//     ) {
//       _recipeCache = {
//         for (var doc in snapshot.docs)
//         doc['item']: doc['quantityPerPiece'] is int
//               ? (doc['quantityPerPiece'] as int).toDouble()
//               : double.parse(doc['quantityPerPiece'].toString()),
//       };
//     });
//   }
//   return _recipeCache;
// }
Map<String, double> cachedRecipes() {
  if (_recipeCache.isEmpty) {
    FirebaseFirestore.instance.collection('recipe_standards').get().then((
      snapshot,
    ) {
      _recipeCache = {
        for (var doc in snapshot.docs)
          doc['item']: (doc['quantityPerPiece'] as num).toDouble(),
      };
    });
  }
  return _recipeCache;
}

void clearRecipeCache() {
  _recipeCache = {};
}

Map<String, List<Map<String, dynamic>>> groupLogsByDate(List logs) {
  var result = <String, List<Map<String, dynamic>>>{};
  for (var doc in logs) {
    var data = doc.data() as Map<String, dynamic>;
    var date = (data['date'] as Timestamp).toDate().toString().substring(0, 10);
    result[date] = result[date] ?? [];
    result[date]!.add(data);
  }
  return result;
}

Map<String, List<Map<String, dynamic>>> groupLogsByItem(List logs) {
  var result = <String, List<Map<String, dynamic>>>{};
  for (var doc in logs) {
    var data = doc.data() as Map<String, dynamic>;
    var item = data['item'];
    result[item] = result[item] ?? [];
    result[item]!.add(data);
  }
  return result;
}

void Function(String) debounced(
  void Function(String) callback, {
  Duration duration = const Duration(milliseconds: 300),
}) {
  return (value) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(duration, () => callback(value));
  };
}

List _cachedRecommendations = [];
List memoizedGenerateRecommendations({
  required List<Map<String, dynamic>> inventoryLogs,
  required Map<String, UsageData> usagePerPiece,
  required Map<String, double> consumed,
  required Map<String, double> ingredientCosts,
  required Map<String, double> recipeStandards,
  required double totalCost,
  required double avgDailySales,
}) {
  if (_cachedRecommendations.isNotEmpty) {
    return _cachedRecommendations;
  }
  List recommendations = []; // High waste items
  for (var log in inventoryLogs) {
    double wasteRatio = log['discarded'] / (log['opening'] + log['received']);
    if (wasteRatio > 0.05) {
      double monthlySavings =
          log['discarded'] * 0.5 * ingredientCosts[log['item']] * 30;
      recommendations.add(
        Recommendation(
          title: "Reduce ${log['item']} waste",
          details:
              "Current waste: ${(wasteRatio * 100).toStringAsFixed(1)}%. Aim for 50% reduction. Savings: ${monthlySavings.toStringAsFixed(2)}/month",
          savings: monthlySavings,
          difficulty: "Medium",
        ),
      );
    }
  } // Usage optimization
  for (var entry in usagePerPiece.entries) {
    double benchmark = recipeStandards[entry.key] ?? 0;
    if (benchmark > 0 && entry.value.usagePerPiece > benchmark * 1.1) {
      double excess = entry.value.usagePerPiece - benchmark;
      double savingsPerMonth =
          excess * avgDailySales * 30 * ingredientCosts[entry.key]!;
      recommendations.add(
        Recommendation(
          title: "Optimize ${entry.key} usage",
          details:
              "Current: ${entry.value.usagePerPiece.toStringAsFixed(4)} per piece. Target: ${benchmark.toStringAsFixed(4)}. Savings: ${savingsPerMonth.toStringAsFixed(2)}/month",
          savings: savingsPerMonth,
          difficulty: "Low",
        ),
      );
    }
  } // Bulk purchasing
  for (var entry in consumed.entries) {
    if (entry.value * ingredientCosts[entry.key]! > totalCost * 0.15) {
      double monthlySavings =
          entry.value * ingredientCosts[entry.key]! * 0.05 * 30;
      recommendations.add(
        Recommendation(
          title: "Bulk purchase ${entry.key}",
          details:
              "Negotiate 5% discount for bulk purchases. Savings: ${monthlySavings.toStringAsFixed(2)}/month",
          savings: monthlySavings,
          difficulty: "Low",
        ),
      );
    }
  }
  _cachedRecommendations = recommendations;
  return recommendations;
}

class ShimmerWidget extends StatelessWidget {
  final Widget child;

  const ShimmerWidget({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return child.animate().shimmer(
      duration: Duration(milliseconds: 1000),
      color: Colors.grey[300],
    );
  }
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

class UsageData {
  double usagePerPiece;
  double benchmark;
  double deviation;

  UsageData({
    required this.usagePerPiece,
    required this.benchmark,
    required this.deviation,
  });
}
