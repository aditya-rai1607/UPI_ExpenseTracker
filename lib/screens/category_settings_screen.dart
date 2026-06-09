import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../models/transaction_model.dart';
import '../services/category_service.dart';

class CategorySettingsScreen extends StatefulWidget {
  const CategorySettingsScreen({
    required this.title,
    required this.type,
    super.key,
  });

  final String title;
  final TransactionType type;

  @override
  State<CategorySettingsScreen> createState() => _CategorySettingsScreenState();
}

class _CategorySettingsScreenState extends State<CategorySettingsScreen> {
  Color _surfaceColor(BuildContext context) => Theme.of(context).cardColor;
  Color _textColor(BuildContext context) => Theme.of(context).colorScheme.onSurface;
  Color _mutedTextColor(BuildContext context) =>
      Theme.of(context).colorScheme.onSurfaceVariant;
  Color _borderColor(BuildContext context) => Theme.of(context).dividerColor;

  bool _canModifyCategory(String category) {
    return category.trim() != CategoryService.uncategorized;
  }

  Future<void> _showAddCategoryDialog(BuildContext context) async {
    final controller = TextEditingController();

    final result = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Add Category'),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: const InputDecoration(labelText: 'Category name'),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(controller.text.trim()),
              child: const Text('Save'),
            ),
          ],
        );
      },
    );

    controller.dispose();

    if (result == null || result.trim().isEmpty) {
      return;
    }

    await CategoryService.addCategoryForType(widget.type, result.trim());
  }

  Future<void> _showEditCategoryDialog(
    BuildContext context,
    String currentCategory,
  ) async {
    final controller = TextEditingController(text: currentCategory);

    final result = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Edit Category'),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: const InputDecoration(labelText: 'Category name'),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(controller.text.trim()),
              child: const Text('Save'),
            ),
          ],
        );
      },
    );

    controller.dispose();

    if (result == null || result.trim().isEmpty) {
      return;
    }

    await CategoryService.updateCategoryForType(
      widget.type,
      currentCategory,
      result.trim(),
    );
  }

  Future<void> _deleteCategory(BuildContext context, String category) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Delete Category'),
          content: Text(
            'Delete "$category"? Existing transactions will be updated automatically.',
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) {
      return;
    }

    await CategoryService.deleteCategoryForType(widget.type, category);
  }

  @override
  Widget build(BuildContext context) {
    final box = Hive.box(CategoryService.categoriesBoxName);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text(
          widget.title,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            color: _textColor(context),
            fontWeight: FontWeight.w700,
          ),
        ),
        actions: <Widget>[
          IconButton(
            onPressed: () => _showAddCategoryDialog(context),
            icon: const Icon(Icons.add_rounded),
          ),
        ],
      ),
      body: SafeArea(
        child: ValueListenableBuilder(
          valueListenable: box.listenable(),
          builder: (context, Box<dynamic> box, _) {
            final items = CategoryService.getCategoriesForType(widget.type)
                .where((item) => item.trim().isNotEmpty)
                .toList(growable: false);

            return ListView.separated(
              padding: const EdgeInsets.fromLTRB(14, 8, 14, 24),
              itemCount: items.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final category = items[index];
                final canModify = _canModifyCategory(category);
                return Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 16,
                  ),
                  decoration: BoxDecoration(
                    color: _surfaceColor(context),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: _borderColor(context)),
                  ),
                  child: Row(
                    children: <Widget>[
                      Expanded(
                        child: Text(
                          category,
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: _textColor(context),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      if (!canModify)
                        Text(
                          'System',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: _mutedTextColor(context),
                            fontWeight: FontWeight.w600,
                          ),
                        )
                      else
                        PopupMenuButton<String>(
                          onSelected: (value) {
                            if (value == 'edit') {
                              _showEditCategoryDialog(context, category);
                              return;
                            }
                            _deleteCategory(context, category);
                          },
                          itemBuilder: (context) => const <PopupMenuEntry<String>>[
                            PopupMenuItem<String>(
                              value: 'edit',
                              child: Text('Edit'),
                            ),
                            PopupMenuItem<String>(
                              value: 'delete',
                              child: Text('Delete'),
                            ),
                          ],
                          icon: Icon(
                            Icons.more_horiz_rounded,
                            color: _mutedTextColor(context),
                          ),
                        ),
                    ],
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
