import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';

import '../models/transaction_model.dart';
import '../services/category_service.dart';
import '../services/transaction_parser.dart';

class AddTransactionScreen extends StatefulWidget {
  const AddTransactionScreen({super.key});

  @override
  State<AddTransactionScreen> createState() => _AddTransactionScreenState();
}

class _AddTransactionScreenState extends State<AddTransactionScreen> {
  static const Color _backgroundColor = Color(0xFFF6F7FB);
  static const Color _surfaceColor = Colors.white;
  static const Color _heroColor = Color(0xFF16171D);
  static const Color _textColor = Color(0xFF14161F);
  static const Color _mutedTextColor = Color(0xFF8B90A0);
  static const Color _softBorderColor = Color(0xFFE9EBF2);
  static const Color _incomeColor = Color(0xFF22C55E);
  static const Color _expenseColor = Color(0xFFEF4444);

  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _merchantController = TextEditingController();
  final _noteController = TextEditingController();

  bool _isSaving = false;

  TransactionType _type = TransactionType.debit;
  DateTime _date = DateTime.now();
  String? _category;

  @override
  void dispose() {
    _amountController.dispose();
    _merchantController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final selected = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2018),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (selected != null) {
      setState(() {
        _date = selected;
      });
    }
  }

  Future<void> _saveTransaction() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isSaving = true;
    });

    final amount = double.parse(_amountController.text.trim());
    final merchant = _merchantController.text.trim();
    final suggestion = TransactionParser.suggestCategory(merchant);

    final transaction = TransactionModel(
      amount: amount,
      merchant: merchant,
      category: _type == TransactionType.debit
          ? (_category ?? suggestion)
          : null,
      date: _date,
      type: _type,
      note: _noteController.text.trim().isEmpty
          ? null
          : _noteController.text.trim(),
    );

    await Hive.box('transactions').add(transaction.toMap());

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

  Color _transactionTypeColor() {
    return _type == TransactionType.credit ? _incomeColor : _expenseColor;
  }

  String _heroCaption() {
    return _type == TransactionType.credit
        ? 'Enter incoming amount'
        : 'Enter expense amount';
  }

  Widget _buildHeroCard(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 22),
      decoration: BoxDecoration(
        color: _heroColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: <Widget>[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(999),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<TransactionType>(
                value: _type,
                icon: const Icon(Icons.expand_more_rounded, size: 16),
                borderRadius: BorderRadius.circular(16),
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: _transactionTypeColor(),
                  fontWeight: FontWeight.w700,
                ),
                items: <DropdownMenuItem<TransactionType>>[
                  DropdownMenuItem(
                    value: TransactionType.credit,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Icon(
                          Icons.arrow_downward_rounded,
                          size: 14,
                          color: _incomeColor,
                        ),
                        const SizedBox(width: 6),
                        const Text('Income'),
                      ],
                    ),
                  ),
                  DropdownMenuItem(
                    value: TransactionType.debit,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Icon(
                          Icons.arrow_upward_rounded,
                          size: 14,
                          color: _expenseColor,
                        ),
                        const SizedBox(width: 6),
                        const Text('Expense'),
                      ],
                    ),
                  ),
                ],
                onChanged: (value) {
                  if (value == null) {
                    return;
                  }
                  setState(() {
                    _type = value;
                    if (_type == TransactionType.credit) {
                      _category = null;
                    }
                  });
                },
              ),
            ),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _amountController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.displaySmall?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              letterSpacing: -1,
            ),
            validator: (value) {
              final parsed = double.tryParse((value ?? '').trim());
              if (parsed == null || parsed <= 0) {
                return 'Enter a valid amount';
              }
              return null;
            },
            decoration: InputDecoration(
              hintText: '0.00',
              hintStyle: Theme.of(context).textTheme.displaySmall?.copyWith(
                color: Colors.white.withValues(alpha: 0.4),
                fontWeight: FontWeight.w800,
                letterSpacing: -1,
              ),
              prefixText: '₹ ',
              prefixStyle: Theme.of(context).textTheme.displaySmall?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                letterSpacing: -1,
              ),
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              errorBorder: InputBorder.none,
              focusedErrorBorder: InputBorder.none,
              contentPadding: EdgeInsets.zero,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            _heroCaption(),
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Colors.white.withValues(alpha: 0.78),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard({
    required BuildContext context,
    required IconData icon,
    required String label,
    required Widget child,
    VoidCallback? onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Ink(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: _surfaceColor,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: _softBorderColor),
            boxShadow: const <BoxShadow>[
              BoxShadow(
                color: Color(0x080F172A),
                blurRadius: 14,
                offset: Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: const Color(0xFFF6F7FB),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 18, color: _textColor),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      label,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: _mutedTextColor,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    child,
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInlineTextField({
    required TextEditingController controller,
    required String hintText,
    int maxLines = 1,
    String? Function(String?)? validator,
    TextCapitalization textCapitalization = TextCapitalization.none,
  }) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      validator: validator,
      textCapitalization: textCapitalization,
      style: Theme.of(context).textTheme.titleMedium?.copyWith(
        color: _textColor,
        fontWeight: FontWeight.w700,
      ),
      decoration: InputDecoration(
        isDense: true,
        hintText: hintText,
        hintStyle: Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: _mutedTextColor,
          fontWeight: FontWeight.w500,
        ),
        border: InputBorder.none,
        enabledBorder: InputBorder.none,
        focusedBorder: InputBorder.none,
        errorBorder: InputBorder.none,
        focusedErrorBorder: InputBorder.none,
        contentPadding: EdgeInsets.zero,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final categories = CategoryService.getDropdownCategories();

    return Scaffold(
      backgroundColor: _backgroundColor,
      appBar: AppBar(
        backgroundColor: _backgroundColor,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleSpacing: 0,
        title: Text(
          'Add Transaction',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            color: _textColor,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(14, 8, 14, 24),
            children: <Widget>[
              _buildHeroCard(context),
              const SizedBox(height: 14),
              _buildInfoCard(
                context: context,
                icon: Icons.person_outline_rounded,
                label: 'PAYEE / MERCHANT',
                child: _buildInlineTextField(
                  controller: _merchantController,
                  hintText: 'Enter payee or merchant',
                  textCapitalization: TextCapitalization.words,
                  validator: (value) {
                    if ((value ?? '').trim().isEmpty) {
                      return 'Merchant is required';
                    }
                    return null;
                  },
                ),
              ),
              const SizedBox(height: 12),
              if (_type == TransactionType.debit) ...<Widget>[
                _buildInfoCard(
                  context: context,
                  icon: Icons.label_outline_rounded,
                  label: 'CATEGORY',
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: CategoryService.normalizeSelectedCategory(_category),
                      isExpanded: true,
                      icon: const Icon(
                        Icons.chevron_right_rounded,
                        color: _mutedTextColor,
                      ),
                      borderRadius: BorderRadius.circular(16),
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: _textColor,
                        fontWeight: FontWeight.w700,
                      ),
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
                  ),
                ),
                const SizedBox(height: 12),
              ],
              _buildInfoCard(
                context: context,
                icon: Icons.calendar_today_outlined,
                label: 'DATE OF TRANSACTION',
                onTap: _pickDate,
                child: Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        DateFormat('dd MMM yyyy').format(_date),
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: _textColor,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const Icon(
                      Icons.chevron_right_rounded,
                      color: _mutedTextColor,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              _buildInfoCard(
                context: context,
                icon: Icons.notes_rounded,
                label: 'NOTE / REFERENCE',
                child: _buildInlineTextField(
                  controller: _noteController,
                  hintText: 'Add note or reference',
                  maxLines: 3,
                  textCapitalization: TextCapitalization.sentences,
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                height: 54,
                child: FilledButton.icon(
                  onPressed: _isSaving ? null : _saveTransaction,
                  style: FilledButton.styleFrom(
                    backgroundColor: _heroColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    textStyle: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  icon: _isSaving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.check_rounded),
                  label: Text(_isSaving ? 'Saving...' : 'Save Transaction'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
