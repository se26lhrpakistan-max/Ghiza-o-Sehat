import 'package:flutter/material.dart';

class PortionOption {
  const PortionOption({required this.label, required this.grams});
  final String label;
  final double grams;
}

class PortionGuideWidget extends StatelessWidget {
  const PortionGuideWidget({
    super.key,
    required this.food,
    required this.onSelectGrams,
    this.currentGrams,
  });

  final String food;
  final ValueChanged<double> onSelectGrams;
  final double? currentGrams;

  List<PortionOption> _getOptionsForFood(String food) {
    switch (food) {
      case 'chapati':
      case 'naan':
        return const [
          PortionOption(label: 'Small (~40g)', grams: 40),
          PortionOption(label: 'Medium (~50g)', grams: 50),
          PortionOption(label: 'Large (~60g)', grams: 60),
          PortionOption(label: '2 Chapatis (~100g)', grams: 100),
        ];
      case 'biryani':
      case 'aloo_gobi':
      case 'aloo_matar':
      case 'bhindi_masala':
      case 'chana_masala':
      case 'creamy_chicken_curry':
        return const [
          PortionOption(label: 'Small Bowl (~150g)', grams: 150),
          PortionOption(label: 'Plate (~250g)', grams: 250),
          PortionOption(label: 'Large Portion (~350g)', grams: 350),
        ];
      case 'dal_makhani':
      case 'dal_tadka':
        return const [
          PortionOption(label: 'Small Cup (~120g)', grams: 120),
          PortionOption(label: 'Standard Bowl (~180g)', grams: 180),
          PortionOption(label: 'Large Bowl (~250g)', grams: 250),
        ];
      case 'chicken_tikka':
      case 'kofta':
        return const [
          PortionOption(label: '2 Pieces (~80g)', grams: 80),
          PortionOption(label: '3-4 Pieces (~120g)', grams: 120),
          PortionOption(label: 'Full Serving (~180g)', grams: 180),
        ];
      case 'jalebi':
      case 'gulab_jamun':
      case 'ras_malai':
      case 'gajar_ka_halwa':
      case 'sheer_korma':
        return const [
          PortionOption(label: '1 Piece (~40g)', grams: 40),
          PortionOption(label: '2 Pieces (~80g)', grams: 80),
          PortionOption(label: 'Standard Serving (~120g)', grams: 120),
        ];
      default:
        return const [
          PortionOption(label: 'Light (~50g)', grams: 50),
          PortionOption(label: 'Moderate (~100g)', grams: 100),
          PortionOption(label: 'Standard (~150g)', grams: 150),
          PortionOption(label: 'Hearty (~250g)', grams: 250),
        ];
    }
  }

  String _getHelperText(String food) {
    switch (food) {
      case 'chapati':
        return 'Standard plain wheat chapati: small ~40g, medium ~50g, large ~60g. Select a common estimate or enter your measured weight:';
      case 'naan':
        return 'Tandoori naan: small ~80g, medium ~120g, large ~160g.';
      case 'biryani':
        return 'Cooked biryani: small bowl ~150g, medium lunch plate ~250g, large ~350g.';
      case 'dal_makhani':
      case 'dal_tadka':
        return 'Cooked dal: tea cup ~120g, regular katori/bowl ~180g, soup bowl ~250g.';
      case 'chicken_tikka':
      case 'kofta':
        return 'Pieces/serving: 2 pieces ~80g, 3-4 pieces ~120g, restaurant serving ~180g.';
      case 'jalebi':
      case 'gulab_jamun':
        return 'Sweet pieces: 1 standard piece ~40g, 2 pieces ~80g, 3 pieces ~120g.';
      default:
        return 'Common portion estimates (cooked grams). You can also type your exact measured grams below:';
    }
  }

  @override
  Widget build(BuildContext context) {
    final options = _getOptionsForFood(food);
    final helper = _getHelperText(food);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 6),
        Text(
          helper,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.grey.shade700,
              ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: options.map((opt) {
            final isSelected = currentGrams == opt.grams;
            return ChoiceChip(
              label: Text(opt.label),
              selected: isSelected,
              onSelected: (_) => onSelectGrams(opt.grams),
            );
          }).toList(),
        ),
      ],
    );
  }
}
