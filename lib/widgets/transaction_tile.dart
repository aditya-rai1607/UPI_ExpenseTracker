import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/transaction_model.dart';

class TransactionTile extends StatelessWidget {
  const TransactionTile({required this.transaction, this.onTap, super.key});

  final TransactionModel transaction;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final isDebit = transaction.type == TransactionType.debit;
    final signedSymbol = isDebit ? '-' : '+';
    final amountColor = isDebit ? Colors.red.shade700 : Colors.green.shade700;
    final title = transaction.merchant.trim() == 'N/A'
      ? (transaction.bankRemark ?? 'N/A')
      : transaction.merchant;
    final categoryLabel = isDebit
        ? (transaction.category == null || transaction.category!.trim().isEmpty
              ? 'Uncategorized'
              : transaction.category!)
        : 'Income';

    return Card(
      child: ListTile(
        onTap: onTap,
        leading: CircleAvatar(
          backgroundColor: isDebit
              ? Colors.red.shade100
              : Colors.green.shade100,
          child: Icon(
            isDebit ? Icons.arrow_upward : Icons.arrow_downward,
            color: isDebit ? Colors.red.shade700 : Colors.green.shade700,
          ),
        ),
        title: Text(title),
        subtitle: Text(
          '$categoryLabel • ${DateFormat('dd MMM yyyy').format(transaction.date)}',
        ),
        trailing: Text(
          '$signedSymbol₹${transaction.amount.toStringAsFixed(2)}',
          style: TextStyle(fontWeight: FontWeight.w600, color: amountColor),
        ),
      ),
    );
  }
}
