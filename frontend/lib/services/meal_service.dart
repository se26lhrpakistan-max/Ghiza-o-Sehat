import 'package:supabase_flutter/supabase_flutter.dart' as sb;

class MealLog {
  const MealLog({
    required this.id,
    required this.confirmedFood,
    required this.portionGrams,
    required this.calories,
    required this.createdAt,
    required this.predictedClass,
    required this.predictionConfidence,
    this.top3 = const [],
  });

  final String id;
  final String confirmedFood;
  final double portionGrams;
  final double calories;
  final DateTime createdAt;
  final String predictedClass;
  final double predictionConfidence;
  final List<dynamic> top3;

  factory MealLog.fromJson(Map<String, dynamic> json) => MealLog(
        id: json['id'] as String,
        confirmedFood: json['confirmed_food'] as String,
        portionGrams: (json['portion_grams'] as num).toDouble(),
        calories: (json['calories'] as num).toDouble(),
        createdAt: DateTime.parse(json['created_at'] as String),
        predictedClass: json['predicted_class'] as String? ?? '',
        predictionConfidence:
            (json['prediction_confidence'] as num?)?.toDouble() ?? 0.0,
        top3: json['top3'] as List<dynamic>? ?? const [],
      );
}

abstract class MealService {
  const MealService();

  Future<void> saveMeal({
    required String userId,
    required String confirmedFood,
    required double portionGrams,
    required double calories,
    String? predictedClass,
    double? predictionConfidence,
    List<dynamic>? top3,
  });

  Future<List<MealLog>> getMealLogs(String userId);

  Future<void> deleteMealLog(String id);
}

class SupabaseMealService extends MealService {
  SupabaseMealService([sb.SupabaseClient? client])
      : _client = client;

  final sb.SupabaseClient? _client;

  sb.SupabaseClient get client => _client ?? sb.Supabase.instance.client;

  @override
  Future<void> saveMeal({
    required String userId,
    required String confirmedFood,
    required double portionGrams,
    required double calories,
    String? predictedClass,
    double? predictionConfidence,
    List<dynamic>? top3,
  }) async {
    await client.from('meal_logs').insert({
      'user_id': userId,
      'confirmed_food': confirmedFood,
      'portion_grams': portionGrams,
      'calories': calories,
      'predicted_class': predictedClass ?? confirmedFood,
      'prediction_confidence': predictionConfidence ?? 100.0,
      'top3': top3 ?? [],
    });
  }

  @override
  Future<List<MealLog>> getMealLogs(String userId) async {
    final response = await client
        .from('meal_logs')
        .select()
        .eq('user_id', userId)
        .order('created_at', ascending: false);
    return (response as List)
        .map((row) => MealLog.fromJson(row as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<void> deleteMealLog(String id) async {
    await client.from('meal_logs').delete().eq('id', id);
  }
}

class MockMealService extends MealService {
  MockMealService({List<MealLog>? initialLogs})
      : _logs = List.of(initialLogs ?? []);

  final List<MealLog> _logs;

  @override
  Future<void> saveMeal({
    required String userId,
    required String confirmedFood,
    required double portionGrams,
    required double calories,
    String? predictedClass,
    double? predictionConfidence,
    List<dynamic>? top3,
  }) async {
    _logs.insert(
      0,
      MealLog(
        id: 'mock-${DateTime.now().millisecondsSinceEpoch}',
        confirmedFood: confirmedFood,
        portionGrams: portionGrams,
        calories: calories,
        createdAt: DateTime.now(),
        predictedClass: predictedClass ?? confirmedFood,
        predictionConfidence: predictionConfidence ?? 100.0,
        top3: top3 ?? const [],
      ),
    );
  }

  @override
  Future<List<MealLog>> getMealLogs(String userId) async {
    return List.unmodifiable(_logs);
  }

  @override
  Future<void> deleteMealLog(String id) async {
    _logs.removeWhere((log) => log.id == id);
  }
}
