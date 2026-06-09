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
  static const Color _heroColor = Color(0xFF16171D);
  static const Color _incomeColor = Color(0xFF22C55E);
  static const Color _expenseColor = Color(0xFFEF4444);
  static const Color _investmentColor = Color(0xFFD97706);

  Color _backgroundColor(BuildContext context) =>
      Theme.of(context).scaffoldBackgroundColor;
  Color _surfaceColor(BuildContext context) => Theme.of(context).cardColor;
  Color _textColor(BuildContext context) => Theme.of(context).colorScheme.onSurface;
  Color _mutedTextColor(BuildContext context) =>
      Theme.of(context).colorScheme.onSurfaceVariant;
  Color _softBorderColor(BuildContext context) => Theme.of(context).dividerColor;
  Color _softIconSurface(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? const Color(0xFF1A2233)
        : const Color(0xFFF6F7FB);
  }

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
    final resolvedCategory = _type == TransactionType.debit
        ? (_category ?? suggestion)
        : _category;

    final transaction = TransactionModel(
      amount: amount,
      merchant: merchant,
      category: resolvedCategory,
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

  void _handleCategorySelection(String? value) {
    setState(() {
      _category = value;
    });
  }

  Color _transactionTypeColor() {
    return switch (_type) {
      TransactionType.credit => _incomeColor,
      TransactionType.investment => _investmentColor,
      TransactionType.debit => _expenseColor,
    };
  }

  String _heroCaption() {
    return switch (_type) {
      TransactionType.credit => 'Enter incoming amount',
      TransactionType.investment => 'Track your investment amount',
      TransactionType.debit => 'Enter expense amount',
    };
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
                  DropdownMenuItem(
                    value: TransactionType.investment,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Icon(
                          Icons.trending_up_rounded,
                          size: 14,
                          color: _investmentColor,
                        ),
                        const SizedBox(width: 6),
                        const Text('Investment'),
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
                    _category = null;
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
            color: _surfaceColor(context),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: _softBorderColor(context)),
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
                  color: _softIconSurface(context),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 18, color: _textColor(context)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      label,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: _mutedTextColor(context),
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
        color: _textColor(context),
        fontWeight: FontWeight.w700,
      ),
      decoration: InputDecoration(
        isDense: true,
        hintText: hintText,
        hintStyle: Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: _mutedTextColor(context),
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
    final categories = CategoryService.getDropdownCategoriesForType(_type);

    return Scaffold(
      backgroundColor: _backgroundColor(context),
      appBar: AppBar(
        backgroundColor: _backgroundColor(context),
        elevation: 0,
        scrolledUnderElevation: 0,
        titleSpacing: 0,
        title: Text(
          'Add Transaction',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            color: _textColor(context),
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
              _buildInfoCard(
                context: context,
                icon: Icons.label_outline_rounded,
                label: 'CATEGORY',
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: CategoryService.normalizeSelectedCategory(_category),
                    isExpanded: true,
                    icon: Icon(
                      Icons.chevron_right_rounded,
                      color: _mutedTextColor(context),
                    ),
                    borderRadius: BorderRadius.circular(16),
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: _textColor(context),
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
                          color: _textColor(context),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    Icon(
                      Icons.chevron_right_rounded,
                      color: _mutedTextColor(context),
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
