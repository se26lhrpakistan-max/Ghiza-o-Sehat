import 'package:flutter/material.dart';

import '../services/meal_service.dart';

class MealHistoryScreen extends StatefulWidget {
  const MealHistoryScreen({
    super.key,
    required this.mealService,
    required this.userId,
  });

  final MealService mealService;
  final String userId;

  @override
  State<MealHistoryScreen> createState() => _MealHistoryScreenState();
}

class _MealHistoryScreenState extends State<MealHistoryScreen> {
  List<MealLog> _logs = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadLogs();
  }

  Future<void> _loadLogs() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final logs = await widget.mealService.getMealLogs(widget.userId);
      if (mounted) {
        setState(() {
          _logs = logs;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Failed to load meal history. Please retry.';
          _loading = false;
        });
      }
    }
  }

  Future<void> _deleteLog(MealLog log) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Meal Log'),
        content: Text('Are you sure you want to delete this ${log.confirmedFood} log?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      try {
        await widget.mealService.deleteMealLog(log.id);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Meal deleted')),
          );
          _loadLogs();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to delete meal')),
          );
        }
      }
    }
  }

  String _label(String food) => food.replaceAll('_', ' ');

  String _formatDate(DateTime dt) {
    final local = dt.toLocal();
    final month = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ][local.month - 1];
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    return '$month ${local.day}, ${local.year} at $hour:$minute';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Meal History'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadLogs,
              child: _error != null
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                          const SizedBox(height: 12),
                          OutlinedButton(
                            onPressed: _loadLogs,
                            child: const Text('Retry'),
                          ),
                        ],
                      ),
                    )
                  : _logs.isEmpty
                      ? const Center(
                          child: Text(
                            'No meals logged yet.\nEstimate calories on a confirmed food to save meals here.',
                            textAlign: TextAlign.center,
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.all(16),
                          itemCount: _logs.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 12),
                          itemBuilder: (context, index) {
                            final log = _logs[index];
                            return Card(
                              elevation: 1,
                              child: ListTile(
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 8,
                                ),
                                title: Text(
                                  _label(log.confirmedFood),
                                  style: Theme.of(context).textTheme.titleMedium,
                                ),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const SizedBox(height: 4),
                                    Text(
                                      '${log.calories.toStringAsFixed(1)} kcal · ${log.portionGrams.toStringAsFixed(0)} g',
                                      style: TextStyle(
                                        color: Theme.of(context).colorScheme.primary,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      _formatDate(log.createdAt),
                                      style: Theme.of(context).textTheme.bodySmall,
                                    ),
                                  ],
                                ),
                                trailing: IconButton(
                                  icon: const Icon(Icons.delete_outline),
                                  tooltip: 'Delete meal log',
                                  onPressed: () => _deleteLog(log),
                                ),
                              ),
                            );
                          },
                        ),
            ),
    );
  }
}
