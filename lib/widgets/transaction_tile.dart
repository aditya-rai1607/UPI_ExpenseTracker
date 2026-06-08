import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/transaction_model.dart';

class TransactionTile extends StatelessWidget {
  const TransactionTile({required this.transaction, this.onTap, super.key});

  static const Color _incomeColor = Color(0xFF22C55E);
  static const Color _expenseColor = Color(0xFFEF4444);
  static const Color _textColor = Color(0xFF111827);
  static const Color _secondaryTextColor = Color(0xFF6B7280);
  static const Color _primaryColor = Color(0xFF6C63FF);

  final TransactionModel transaction;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final isDebit = transaction.type == TransactionType.debit;
    final signedSymbol = isDebit ? '-' : '+';
    final amountColor = isDebit ? _expenseColor : _incomeColor;
    final title = transaction.merchant.trim() == 'N/A'
        ? (transaction.bankRemark ?? 'N/A')
        : transaction.merchant;
    final categoryLabel = isDebit
        ? (transaction.category == null || transaction.category!.trim().isEmpty
              ? 'Uncategorized'
              : transaction.category!)
        : 'Income';

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Ink(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(22),
            boxShadow: const <BoxShadow>[
              BoxShadow(
                color: Color(0x120F172A),
                blurRadius: 22,
                offset: Offset(0, 10),
              ),
            ],
          ),
          child: Row(
            children: <Widget>[
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  color: _avatarBackground(categoryLabel),
                ),
                child: Icon(
                  _categoryIcon(categoryLabel, isDebit),
                  color: isDebit ? _primaryColor : _incomeColor,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontSize: 16, color: _textColor),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          '$signedSymbol₹${transaction.amount.toStringAsFixed(0)}',
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(
                                color: amountColor,
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: <Widget>[
                        Flexible(
                          child: Text(
                            '$categoryLabel • ${DateFormat('d MMM').format(transaction.date)}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  fontSize: 12,
                                  color: _secondaryTextColor,
                                ),
                          ),
                        ),
                        if ((transaction.bankRemark ?? '').trim().isNotEmpty &&
                            transaction.merchant.trim() != 'N/A') ...<Widget>[
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              transaction.bankRemark!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(color: _secondaryTextColor),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _avatarBackground(String categoryLabel) {
    if (categoryLabel == 'Income') {
      return const Color(0xFFEAFBF0);
    }
    return const Color(0xFFF1F3FF);
  }

  IconData _categoryIcon(String categoryLabel, bool isDebit) {
    final normalized = categoryLabel.toLowerCase();
    if (!isDebit) {
      return Icons.south_west_rounded;
    }
    if (normalized.contains('food') || normalized.contains('coffee')) {
      return Icons.local_cafe_outlined;
    }
    if (normalized.contains('travel') ||
        normalized.contains('train') ||
        normalized.contains('cab') ||
        normalized.contains('flight')) {
      return Icons.directions_car_filled_outlined;
    }
    if (normalized.contains('shopping')) {
      return Icons.shopping_bag_outlined;
    }
    if (normalized.contains('bill') || normalized.contains('electricity')) {
      return Icons.receipt_long_outlined;
    }
    if (normalized.contains('fuel')) {
      return Icons.local_gas_station_outlined;
    }
    if (normalized.contains('medical') || normalized.contains('health')) {
      return Icons.favorite_border_rounded;
    }
    return Icons.account_balance_wallet_outlined;
  }
}
