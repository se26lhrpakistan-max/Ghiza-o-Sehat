import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ghiza_o_sehat/screens/meal_history_screen.dart';
import 'package:ghiza_o_sehat/services/meal_service.dart';

void main() {
  testWidgets('MealHistoryScreen shows empty state when no meals logged',
      (tester) async {
    final mealService = MockMealService(initialLogs: []);

    await tester.pumpWidget(
      MaterialApp(
        home: MealHistoryScreen(
          mealService: mealService,
          userId: 'test-user-123',
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Meal History'), findsOneWidget);
    expect(find.textContaining('No meals logged yet'), findsOneWidget);
  });

  testWidgets('MealHistoryScreen displays logs and handles deletion',
      (tester) async {
    final log = MealLog(
      id: 'log-1',
      confirmedFood: 'chapati',
      portionGrams: 50.0,
      calories: 129.5,
      createdAt: DateTime(2026, 11, 17, 12, 0),
      predictedClass: 'chapati',
      predictionConfidence: 95.0,
    );
    final mealService = MockMealService(initialLogs: [log]);

    await tester.pumpWidget(
      MaterialApp(
        home: MealHistoryScreen(
          mealService: mealService,
          userId: 'test-user-123',
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('chapati'), findsOneWidget);
    expect(find.text('129.5 kcal · 50 g'), findsOneWidget);

    // Tap delete button
    await tester.tap(find.byIcon(Icons.delete_outline));
    await tester.pumpAndSettle();

    expect(find.text('Delete Meal Log'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
    await tester.pumpAndSettle();

    expect(find.textContaining('No meals logged yet'), findsOneWidget);
  });
}
