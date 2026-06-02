import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';

import '../models/transaction_model.dart';
import '../services/category_service.dart';

class TransactionDetailScreen extends StatefulWidget {
  const TransactionDetailScreen({
    required this.transaction,
    required this.transactionKey,
    super.key,
  });

  final TransactionModel transaction;
  final dynamic transactionKey;

  @override
  State<TransactionDetailScreen> createState() =>
      _TransactionDetailScreenState();
}

class _TransactionDetailScreenState extends State<TransactionDetailScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _amountController;
  late final TextEditingController _bankRemarkController;
  late final TextEditingController _merchantController;
  late final TextEditingController _noteController;

  late TransactionType _type;
  late DateTime _date;
  String? _category;
  bool _isSaving = false;
  bool _isDeleting = false;

  InputDecoration _readOnlyDecoration(String label) {
    return InputDecoration(
      labelText: label,
      filled: true,
      fillColor: Colors.grey.shade100,
      border: const OutlineInputBorder(),
    );
  }

  @override
  void initState() {
    super.initState();
    _amountController = TextEditingController(
      text: widget.transaction.amount.toStringAsFixed(2),
    );
    _bankRemarkController = TextEditingController(
      text: widget.transaction.bankRemark ?? '',
    );
    _merchantController = TextEditingController(
      text: widget.transaction.merchant,
    );
    _noteController = TextEditingController(
      text: widget.transaction.note ?? '',
    );
    _type = widget.transaction.type;
    _date = widget.transaction.date;
    _category = CategoryService.normalizeSelectedCategory(
      widget.transaction.category,
    );
  }

  @override
  void dispose() {
    _amountController.dispose();
    _bankRemarkController.dispose();
    _merchantController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isSaving = true;
    });

    final updated = widget.transaction.copyWith(
      merchant: _merchantController.text.trim(),
      category: widget.transaction.type == TransactionType.debit ? _category : null,
    );

    await Hive.box('transactions').put(widget.transactionKey, updated.toMap());

    if (!mounted) {
      return;
    }

    Navigator.of(context).pop(true);
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Delete Transaction'),
          content: const Text('This transaction will be removed permanently.'),
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

    setState(() {
      _isDeleting = true;
    });

    await Hive.box('transactions').delete(widget.transactionKey);

    if (!mounted) {
      return;
    }

    Navigator.of(context).pop(true);
  }

  Future<void> _handleCategorySelection(String? value) async {
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
        _category = customCategory;
      });
      return;
    }

    setState(() {
      _category = value;
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

    return Scaffold(
      appBar: AppBar(title: const Text('Transaction Details')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: ListView(
            children: <Widget>[
              TextFormField(
                controller: _amountController,
                readOnly: true,
                decoration: _readOnlyDecoration('Amount'),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _merchantController,
                decoration: const InputDecoration(
                  labelText: 'Merchant / Description',
                ),
                validator: (value) {
                  if ((value ?? '').trim().isEmpty) {
                    return 'Merchant is required';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _bankRemarkController,
                readOnly: true,
                maxLines: 3,
                decoration: _readOnlyDecoration('Bank Remark'),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<TransactionType>(
                initialValue: _type,
                decoration: _readOnlyDecoration('Type'),
                items: const <DropdownMenuItem<TransactionType>>[
                  DropdownMenuItem(
                    value: TransactionType.debit,
                    child: Text('Debit (Expense)'),
                  ),
                  DropdownMenuItem(
                    value: TransactionType.credit,
                    child: Text('Credit (Income)'),
                  ),
                ],
                onChanged: null,
              ),
              const SizedBox(height: 12),
              InputDecorator(
                decoration: _readOnlyDecoration('Date'),
                child: Row(
                  children: <Widget>[
                    const Icon(Icons.calendar_month, color: Colors.grey),
                    const SizedBox(width: 12),
                    Text(DateFormat('dd MMM yyyy').format(_date)),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              if (widget.transaction.type == TransactionType.debit) ...<Widget>[
                DropdownButtonFormField<String>(
                  initialValue: CategoryService.normalizeSelectedCategory(
                    _category,
                  ),
                  decoration: const InputDecoration(labelText: 'Category'),
                  items: categories
                      .map(
                        (category) => DropdownMenuItem<String>(
                          value: category,
                          child: Text(category),
                        ),
                      )
                      .toList(),
                  onChanged: _handleCategorySelection,
                ),
                const SizedBox(height: 12),
              ],
              TextFormField(
                controller: _noteController,
                readOnly: true,
                maxLines: 2,
                decoration: _readOnlyDecoration('Note / Reference'),
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: _isSaving ? null : _save,
                child: Text(_isSaving ? 'Saving...' : 'Save Changes'),
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: _isDeleting ? null : _delete,
                child: Text(_isDeleting ? 'Deleting...' : 'Delete Transaction'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
