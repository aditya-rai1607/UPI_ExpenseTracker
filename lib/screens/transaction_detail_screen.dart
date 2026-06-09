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
  late final TextEditingController _amountController;
  late final TextEditingController _bankRemarkController;
  late final TextEditingController _merchantController;
  late final TextEditingController _noteController;

  late TransactionType _type;
  late DateTime _date;
  String? _category;
  bool _isSaving = false;
  bool _isDeleting = false;

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
      note: _noteController.text.trim().isEmpty ? null : _noteController.text.trim(),
      category: _category,
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

  void _handleCategorySelection(String? value) {
    setState(() {
      _category = value;
    });
  }

  String _transactionTypeLabel() {
    return switch (_type) {
      TransactionType.credit => 'Income',
      TransactionType.investment => 'Investment',
      TransactionType.debit => 'Expense',
    };
  }

  Color _transactionTypeColor() {
    return switch (_type) {
      TransactionType.credit => _incomeColor,
      TransactionType.investment => _investmentColor,
      TransactionType.debit => _expenseColor,
    };
  }

  String _amountLabel() {
    return switch (_type) {
      TransactionType.credit => 'Income Amount',
      TransactionType.investment => 'Investment Amount',
      TransactionType.debit => 'Expense Amount',
    };
  }

  String _bankRemarkText() {
    final value = _bankRemarkController.text.trim();
    return value.isEmpty ? 'No bank remark available' : value;
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
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Icon(
                  _type == TransactionType.credit
                      ? Icons.arrow_downward_rounded
                      : Icons.arrow_upward_rounded,
                  size: 14,
                  color: _transactionTypeColor(),
                ),
                const SizedBox(width: 6),
                Text(
                  _transactionTypeLabel(),
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: _transactionTypeColor(),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Text(
            NumberFormat.currency(
              locale: 'en_IN',
              symbol: '₹',
              decimalDigits: 2,
            ).format(widget.transaction.amount),
            style: Theme.of(context).textTheme.displaySmall?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              letterSpacing: -1,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            _amountLabel(),
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
    bool showChevron = false,
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
              if (showChevron)
                Padding(
                  padding: EdgeInsets.only(left: 12, top: 14),
                  child: Icon(
                    Icons.chevron_right_rounded,
                    color: _mutedTextColor(context),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPrimaryValue(BuildContext context, String value) {
    return Text(
      value,
      style: Theme.of(context).textTheme.titleMedium?.copyWith(
        color: _textColor(context),
        fontWeight: FontWeight.w700,
      ),
    );
  }

  Widget _buildSupportingValue(BuildContext context, String value) {
    return Text(
      value,
      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
        color: _textColor(context),
        height: 1.45,
        fontWeight: FontWeight.w500,
      ),
    );
  }

  Widget _buildInlineTextField({
    required TextEditingController controller,
    required String hintText,
    int maxLines = 1,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
    TextCapitalization textCapitalization = TextCapitalization.none,
  }) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
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
          'Transaction Details',
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
                    value: CategoryService.normalizeSelectedCategory(
                      _category,
                    ),
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
                child: _buildPrimaryValue(
                  context,
                  DateFormat('dd MMM yyyy').format(_date),
                ),
              ),
              const SizedBox(height: 12),
              _buildInfoCard(
                context: context,
                icon: Icons.account_balance_wallet_outlined,
                label: 'BANK REMARKS',
                child: _buildSupportingValue(context, _bankRemarkText()),
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
                  onPressed: _isSaving ? null : _save,
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
                  label: Text(_isSaving ? 'Saving...' : 'Save Changes'),
                ),
              ),
              const SizedBox(height: 12),
              TextButton.icon(
                onPressed: _isDeleting ? null : _delete,
                style: TextButton.styleFrom(
                  foregroundColor: _expenseColor,
                  textStyle: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                icon: _isDeleting
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.delete_outline_rounded),
                label: Text(
                  _isDeleting ? 'Deleting...' : 'Delete Transaction',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
