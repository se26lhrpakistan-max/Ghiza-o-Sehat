import 'package:flutter/material.dart';

class CurryDisambiguationCard extends StatelessWidget {
  const CurryDisambiguationCard({
    super.key,
    required this.onSelectDish,
    required this.onSearchOther,
  });

  final ValueChanged<String> onSelectDish;
  final VoidCallback onSearchOther;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      color: theme.colorScheme.errorContainer.withValues(alpha: 0.25),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: theme.colorScheme.primary.withValues(alpha: 0.4)),
      ),
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.info_outline, color: theme.colorScheme.primary, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Specific Dish Confirmation',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            const Text(
              'Butter Chicken and Chicken Tikka Masala look visually indistinguishable in photos. Please confirm your specific dish:',
              style: TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                ActionChip(
                  avatar: const Icon(Icons.restaurant, size: 16),
                  label: const Text('Butter Chicken'),
                  onPressed: () => onSelectDish('butter_chicken'),
                ),
                ActionChip(
                  avatar: const Icon(Icons.restaurant_menu, size: 16),
                  label: const Text('Chicken Tikka Masala'),
                  onPressed: () => onSelectDish('chicken_tikka_masala'),
                ),
                ActionChip(
                  avatar: const Icon(Icons.search, size: 16),
                  label: const Text('Other / Search'),
                  onPressed: onSearchOther,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
