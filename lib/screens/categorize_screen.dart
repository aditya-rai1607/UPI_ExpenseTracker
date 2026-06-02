import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../models/transaction_model.dart';
import '../services/category_service.dart';

class CategorizeScreen extends StatefulWidget {
  const CategorizeScreen({super.key});

  @override
  State<CategorizeScreen> createState() => _CategorizeScreenState();
}

class _CategorizeScreenState extends State<CategorizeScreen> {
  final Map<dynamic, String> _selectedCategoryByKey = <dynamic, String>{};

  List<_CategorizeItem> _loadUncategorizedDebits() {
    final box = Hive.box('transactions');
    final items = <_CategorizeItem>[];

    for (var i = 0; i < box.length; i++) {
      final key = box.keyAt(i);
      final raw = box.getAt(i);
      if (raw is! Map) {
        continue;
      }

      final transaction = TransactionModel.fromMap(
        raw.cast<dynamic, dynamic>(),
      );
      if (transaction.type == TransactionType.debit &&
          transaction.needsCategory) {
        items.add(_CategorizeItem(key: key, transaction: transaction));
      }
    }

    return items;
  }

  Future<void> _saveCategories(List<_CategorizeItem> items) async {
    final box = Hive.box('transactions');
    var updated = 0;

    for (final item in items) {
      final category = _selectedCategoryByKey[item.key];
      if (category == null || category.trim().isEmpty) {
        continue;
      }

      final updatedTransaction = item.transaction.copyWith(category: category);
      await box.put(item.key, updatedTransaction.toMap());
      await CategoryService.learnMerchantCategory(
        merchant: item.transaction.merchant,
        category: category,
      );
      updated++;
    }

    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Updated categories for $updated transactions')),
    );

    Navigator.of(context).pop(true);
  }

  Future<void> _handleCategorySelection(dynamic itemKey, String? value) async {
    if (value == null) {
      return;
    }

    if (value == CategoryService.customCategoryOption) {
      final customCategory = await _showCustomCategoryDialog();
      if (customCategory == null) {
        return;
      }

      await CategoryService.addCategory(customCategory);
      if (!mounted) {
        return;
      }

      setState(() {
        _selectedCategoryByKey[itemKey] = customCategory;
      });
      return;
    }

    setState(() {
      _selectedCategoryByKey[itemKey] = value;
    });
  }

  Future<String?> _showCustomCategoryDialog() async {
    final controller = TextEditingController();

    final result = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Add Custom Category'),
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
              onPressed: () {
                Navigator.of(context).pop(controller.text.trim());
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );

    controller.dispose();

    final normalized = result?.trim();
    if (normalized == null || normalized.isEmpty) {
      return null;
    }
    return normalized;
  }

  @override
  Widget build(BuildContext context) {
    final categories = CategoryService.getDropdownCategories();

    final items = _loadUncategorizedDebits();

    return Scaffold(
      appBar: AppBar(title: const Text('Categorize Expenses')),
      body: items.isEmpty
          ? const Center(child: Text('No uncategorized expenses found'))
          : Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: <Widget>[
                  Expanded(
                    child: ListView.builder(
                      itemCount: items.length,
                      itemBuilder: (context, index) {
                        final item = items[index];
                        final selectedCategory =
                            _selectedCategoryByKey[item.key];

                        return Card(
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Text(
                                  item.transaction.merchant,
                                  style: Theme.of(
                                    context,
                                  ).textTheme.titleMedium,
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  '₹${item.transaction.amount.toStringAsFixed(2)}',
                                ),
                                const SizedBox(height: 12),
                                DropdownButtonFormField<String>(
                                  initialValue: selectedCategory,
                                  hint: const Text('Select category'),
                                  items: categories
                                      .map(
                                        (category) => DropdownMenuItem<String>(
                                          value: category,
                                          child: Text(category),
                                        ),
                                      )
                                      .toList(),
                                  onChanged: (value) =>
                                      _handleCategorySelection(item.key, value),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => _saveCategories(items),
                      child: const Text('Save Categories'),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

class _CategorizeItem {
  _CategorizeItem({required this.key, required this.transaction});

  final dynamic key;
  final TransactionModel transaction;
}
