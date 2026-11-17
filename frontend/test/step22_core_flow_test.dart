import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ghiza_o_sehat/widgets/curry_disambiguation_card.dart';
import 'package:ghiza_o_sehat/widgets/food_search_dialog.dart';
import 'package:ghiza_o_sehat/widgets/portion_helper.dart';

void main() {
  testWidgets('PortionGuideWidget renders chips and triggers callback',
      (tester) async {
    double? selectedGrams;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PortionGuideWidget(
            food: 'chapati',
            onSelectGrams: (grams) => selectedGrams = grams,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Small (~40g)'), findsOneWidget);
    expect(find.text('Medium (~50g)'), findsOneWidget);
    expect(find.text('Large (~60g)'), findsOneWidget);
    expect(find.text('2 Chapatis (~100g)'), findsOneWidget);

    await tester.tap(find.text('Medium (~50g)'));
    await tester.pumpAndSettle();

    expect(selectedGrams, 50.0);
  });

  testWidgets('CurryDisambiguationCard offers Butter Chicken and Tikka Masala',
      (tester) async {
    String? selectedDish;
    var searchTapped = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CurryDisambiguationCard(
            onSelectDish: (dish) => selectedDish = dish,
            onSearchOther: () => searchTapped = true,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Specific Dish Confirmation'), findsOneWidget);
    expect(find.text('Butter Chicken'), findsOneWidget);
    expect(find.text('Chicken Tikka Masala'), findsOneWidget);

    await tester.tap(find.text('Butter Chicken'));
    await tester.pumpAndSettle();
    expect(selectedDish, 'butter_chicken');

    await tester.tap(find.text('Other / Search'));
    await tester.pumpAndSettle();
    expect(searchTapped, isTrue);
  });

  testWidgets('FoodSearchDialog filters food classes in real time',
      (tester) async {
    String? result;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () async {
              result = await FoodSearchDialog.show(
                context,
                classes: ['chapati', 'biryani', 'dal_makhani'],
              );
            },
            child: const Text('Open Search'),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Open Search'));
    await tester.pumpAndSettle();

    expect(find.text('Search & Select Food'), findsOneWidget);
    expect(find.text('Chapati'), findsOneWidget);
    expect(find.text('Biryani'), findsOneWidget);
    expect(find.text('Dal Makhani'), findsOneWidget);

    // Filter by 'dal'
    await tester.enterText(find.byType(TextField), 'dal');
    await tester.pumpAndSettle();

    expect(find.text('Chapati'), findsNothing);
    expect(find.text('Biryani'), findsNothing);
    expect(find.text('Dal Makhani'), findsOneWidget);

    // Tap Dal Makhani
    await tester.tap(find.text('Dal Makhani'));
    await tester.pumpAndSettle();

    expect(result, 'dal_makhani');
  });
}
