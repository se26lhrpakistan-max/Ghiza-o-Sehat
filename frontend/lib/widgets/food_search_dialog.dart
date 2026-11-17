import 'package:flutter/material.dart';

class FoodSearchDialog extends StatefulWidget {
  const FoodSearchDialog({
    super.key,
    required this.classes,
    this.selected,
  });

  final List<String> classes;
  final String? selected;

  static Future<String?> show(
    BuildContext context, {
    required List<String> classes,
    String? selected,
  }) {
    return showDialog<String>(
      context: context,
      builder: (ctx) => FoodSearchDialog(
        classes: classes,
        selected: selected,
      ),
    );
  }

  @override
  State<FoodSearchDialog> createState() => _FoodSearchDialogState();
}

class _FoodSearchDialogState extends State<FoodSearchDialog> {
  final _searchController = TextEditingController();
  late List<String> _filtered;

  @override
  void initState() {
    super.initState();
    _filtered = widget.classes;
    _searchController.addListener(_onSearchChanged);
  }

  void _onSearchChanged() {
    final query = _searchController.text.trim().toLowerCase();
    setState(() {
      if (query.isEmpty) {
        _filtered = widget.classes;
      } else {
        _filtered = widget.classes.where((food) {
          final label = food.replaceAll('_', ' ').toLowerCase();
          return label.contains(query) || food.toLowerCase().contains(query);
        }).toList();
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  String _formatName(String food) {
    return food
        .split('_')
        .map((w) => w.isEmpty ? '' : '${w[0].toUpperCase()}${w.substring(1)}')
        .join(' ');
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Search & Select Food'),
      content: SizedBox(
        width: double.maxFinite,
        height: 400,
        child: Column(
          children: [
            TextField(
              controller: _searchController,
              autofocus: true,
              decoration: InputDecoration(
                hintText: 'Search food (e.g., chapati, biryani)',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () => _searchController.clear(),
                      )
                    : null,
                border: const OutlineInputBorder(),
                isDense: true,
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: _filtered.isEmpty
                  ? const Center(
                      child: Text('No matching foods found.'),
                    )
                  : ListView.builder(
                      itemCount: _filtered.length,
                      itemBuilder: (ctx, index) {
                        final food = _filtered[index];
                        final isSelected = food == widget.selected;
                        return ListTile(
                          title: Text(
                            _formatName(food),
                            style: TextStyle(
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                              color: isSelected ? Theme.of(context).colorScheme.primary : null,
                            ),
                          ),
                          trailing: isSelected
                              ? Icon(
                                  Icons.check,
                                  color: Theme.of(context).colorScheme.primary,
                                )
                              : null,
                          onTap: () => Navigator.of(ctx).pop(food),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
      ],
    );
  }
}
