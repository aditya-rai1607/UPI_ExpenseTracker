import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../models/transaction_model.dart';
import '../widgets/transaction_tile.dart';
import 'add_transaction_screen.dart';
import 'categorize_screen.dart';
import 'import_statement_screen.dart';

enum TransactionFilter { all, debit, credit, uncategorizedDebit }

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  TransactionFilter _filter = TransactionFilter.all;

  Future<void> _openAddTransaction() async {
    await Navigator.of(context).push(
      MaterialPageRoute<bool>(builder: (_) => const AddTransactionScreen()),
    );
  }

  Future<void> _openImportScreen() async {
    await Navigator.of(context).push(
      MaterialPageRoute<bool>(builder: (_) => const ImportStatementScreen()),
    );
  }

  Future<void> _openCategorizeScreen() async {
    await Navigator.of(
      context,
    ).push(MaterialPageRoute<bool>(builder: (_) => const CategorizeScreen()));
  }

  bool _matchesFilter(TransactionModel transaction) {
    switch (_filter) {
      case TransactionFilter.debit:
        return transaction.type == TransactionType.debit;
      case TransactionFilter.credit:
        return transaction.type == TransactionType.credit;
      case TransactionFilter.uncategorizedDebit:
        return transaction.type == TransactionType.debit &&
            transaction.needsCategory;
      case TransactionFilter.all:
        return true;
    }
  }

  List<TransactionModel> _readTransactions(Box<dynamic> box) {
    final all = <TransactionModel>[];
    for (var i = 0; i < box.length; i++) {
      final raw = box.getAt(i);
      if (raw is Map) {
        all.add(TransactionModel.fromMap(raw.cast<dynamic, dynamic>()));
      }
    }

    all.sort((a, b) => b.date.compareTo(a.date));
    return all.where(_matchesFilter).toList();
  }

  @override
  Widget build(BuildContext context) {
    final box = Hive.box('transactions');

    return Scaffold(
      appBar: AppBar(
        title: const Text('UPI Expense Tracker'),
        actions: <Widget>[
          IconButton(
            tooltip: 'Categorize Debits',
            onPressed: _openCategorizeScreen,
            icon: const Icon(Icons.category_outlined),
          ),
        ],
      ),
      body: ValueListenableBuilder(
        valueListenable: box.listenable(),
        builder: (context, Box<dynamic> box, _) {
          final transactions = _readTransactions(box);

          return Column(
            children: <Widget>[
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                child: Row(
                  children: <Widget>[
                    ChoiceChip(
                      label: const Text('All'),
                      selected: _filter == TransactionFilter.all,
                      onSelected: (_) =>
                          setState(() => _filter = TransactionFilter.all),
                    ),
                    const SizedBox(width: 8),
                    ChoiceChip(
                      label: const Text('Debits'),
                      selected: _filter == TransactionFilter.debit,
                      onSelected: (_) =>
                          setState(() => _filter = TransactionFilter.debit),
                    ),
                    const SizedBox(width: 8),
                    ChoiceChip(
                      label: const Text('Credits'),
                      selected: _filter == TransactionFilter.credit,
                      onSelected: (_) =>
                          setState(() => _filter = TransactionFilter.credit),
                    ),
                    const SizedBox(width: 8),
                    ChoiceChip(
                      label: const Text('Uncategorized Debits'),
                      selected: _filter == TransactionFilter.uncategorizedDebit,
                      onSelected: (_) => setState(
                        () => _filter = TransactionFilter.uncategorizedDebit,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: transactions.isEmpty
                    ? const Center(
                        child: Text('No transactions for this filter'),
                      )
                    : ListView.builder(
                        itemCount: transactions.length,
                        itemBuilder: (context, index) {
                          return TransactionTile(
                            transaction: transactions[index],
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: <Widget>[
          FloatingActionButton.extended(
            heroTag: 'import_btn',
            onPressed: _openImportScreen,
            label: const Text('Import XLSX'),
            icon: const Icon(Icons.upload_file),
          ),
          const SizedBox(height: 10),
          FloatingActionButton.extended(
            heroTag: 'add_btn',
            onPressed: _openAddTransaction,
            label: const Text('Add'),
            icon: const Icon(Icons.add),
          ),
        ],
      ),
    );
  }
}
