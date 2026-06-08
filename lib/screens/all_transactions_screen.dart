import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';

import '../models/transaction_model.dart';
import '../widgets/transaction_tile.dart';
import 'transaction_detail_screen.dart';

class AllTransactionsScreen extends StatelessWidget {
  const AllTransactionsScreen({super.key});

  static const Color _backgroundColor = Color(0xFFF6F7FB);
  static const Color _surfaceColor = Colors.white;
  static const Color _textColor = Color(0xFF14161F);
  static const Color _mutedTextColor = Color(0xFF8B90A0);
  static const Color _softBorderColor = Color(0xFFE9EBF2);

  List<_StoredTransaction> _readStoredTransactions(Box<dynamic> box) {
    final items = <_StoredTransaction>[];
    for (var index = 0; index < box.length; index++) {
      final raw = box.getAt(index);
      if (raw is Map) {
        items.add(
          _StoredTransaction(
            key: box.keyAt(index),
            transaction: TransactionModel.fromMap(raw.cast<dynamic, dynamic>()),
          ),
        );
      }
    }
    items.sort((a, b) => b.transaction.date.compareTo(a.transaction.date));
    return items;
  }

  Map<String, List<_StoredTransaction>> _groupByDate(
    List<_StoredTransaction> items,
  ) {
    final grouped = <String, List<_StoredTransaction>>{};
    for (final item in items) {
      final key = DateFormat('EEEE, dd MMM yyyy').format(item.transaction.date);
      grouped.putIfAbsent(key, () => <_StoredTransaction>[]).add(item);
    }
    return grouped;
  }

  Future<void> _openTransactionDetail(
    BuildContext context,
    _StoredTransaction storedTransaction,
  ) async {
    await Navigator.of(context).push(
      MaterialPageRoute<bool>(
        builder: (_) => TransactionDetailScreen(
          transaction: storedTransaction.transaction,
          transactionKey: storedTransaction.key,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final box = Hive.box('transactions');

    return Scaffold(
      backgroundColor: _backgroundColor,
      appBar: AppBar(
        backgroundColor: _backgroundColor,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleSpacing: 0,
        title: Text(
          'All Transactions',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            color: _textColor,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: SafeArea(
        child: ValueListenableBuilder(
          valueListenable: box.listenable(),
          builder: (context, Box<dynamic> box, _) {
            final transactions = _readStoredTransactions(box);
            if (transactions.isEmpty) {
              return Center(
                child: Container(
                  margin: const EdgeInsets.all(20),
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: _surfaceColor,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: _softBorderColor),
                  ),
                  child: Text(
                    'No transactions available yet.',
                    style: Theme.of(
                      context,
                    ).textTheme.bodyMedium?.copyWith(color: _mutedTextColor),
                  ),
                ),
              );
            }

            final grouped = _groupByDate(transactions);
            final orderedKeys = grouped.keys.toList();

            return ListView.builder(
              padding: const EdgeInsets.fromLTRB(14, 8, 14, 24),
              itemCount: orderedKeys.length,
              itemBuilder: (context, index) {
                final dateKey = orderedKeys[index];
                final items = grouped[dateKey]!;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: Text(
                          dateKey,
                          style: Theme.of(context).textTheme.titleSmall
                              ?.copyWith(
                                color: _textColor,
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      ...items.map(
                        (item) => Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: TransactionTile(
                            transaction: item.transaction,
                            onTap: () => _openTransactionDetail(context, item),
                          ),
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

class _StoredTransaction {
  _StoredTransaction({required this.key, required this.transaction});

  final dynamic key;
  final TransactionModel transaction;
}
