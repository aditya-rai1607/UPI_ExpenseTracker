import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';

import '../models/transaction_model.dart';
import '../services/app_settings_service.dart';
import '../services/analytics_service.dart';
import '../services/google_sheets_backup_service.dart';
import '../widgets/transaction_tile.dart';
import 'add_transaction_screen.dart';
import 'categorize_screen.dart';
import 'import_statement_screen.dart';
import 'transaction_detail_screen.dart';

enum TransactionFilter { all, debit, credit, uncategorizedDebit }

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  TransactionFilter _filter = TransactionFilter.all;
  DateTime _selectedMonth = DateTime(DateTime.now().year, DateTime.now().month);
  bool _isBackingUp = false;

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

  Future<void> _openTransactionDetail(
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

  Future<void> _backupToGoogleSheets() async {
    final configuredEndpoint = await _ensureBackupEndpoint();
    if (!configuredEndpoint) {
      return;
    }

    setState(() {
      _isBackingUp = true;
    });

    final result = await GoogleSheetsBackupService.backupTransactions();

    if (!mounted) {
      return;
    }

    setState(() {
      _isBackingUp = false;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(result.message)),
    );
  }

  Future<bool> _ensureBackupEndpoint() async {
    final existing = AppSettingsService.getGoogleSheetsEndpoint();
    if (existing != null) {
      return true;
    }

    final controller = TextEditingController();
    final endpoint = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Google Sheets Backup URL'),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: const InputDecoration(
              labelText: 'Apps Script Web App URL',
              hintText: 'https://script.google.com/macros/s/.../exec',
            ),
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

    final normalized = endpoint?.trim();
    if (normalized == null || normalized.isEmpty) {
      return false;
    }

    await AppSettingsService.setGoogleSheetsEndpoint(normalized);
    return true;
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

  List<_StoredTransaction> _readStoredTransactions(Box<dynamic> box) {
    final all = <_StoredTransaction>[];
    for (var i = 0; i < box.length; i++) {
      final raw = box.getAt(i);
      if (raw is Map) {
        all.add(
          _StoredTransaction(
            key: box.keyAt(i),
            transaction: TransactionModel.fromMap(raw.cast<dynamic, dynamic>()),
          ),
        );
      }
    }
    all.sort((a, b) => b.transaction.date.compareTo(a.transaction.date));
    return all;
  }

  void _shiftMonth(int delta) {
    setState(() {
      _selectedMonth = DateTime(
        _selectedMonth.year,
        _selectedMonth.month + delta,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final box = Hive.box('transactions');
    final lastBackupAt = AppSettingsService.getLastBackupAt();

    return Scaffold(
      appBar: AppBar(
        title: const Text('UPI Expense Tracker'),
        actions: <Widget>[
          IconButton(
            tooltip: 'Backup to Google Sheets',
            onPressed: _isBackingUp ? null : _backupToGoogleSheets,
            icon: _isBackingUp
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.cloud_upload_outlined),
          ),
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
          final storedTransactions = _readStoredTransactions(box);
          final transactions = storedTransactions
              .map((item) => item.transaction)
              .toList();
          final filteredTransactions = storedTransactions
              .where((item) => _matchesFilter(item.transaction))
              .toList();
          final analytics = AnalyticsService.calculateMonthlyAnalytics(
            transactions: transactions,
            month: _selectedMonth,
          );

          return ListView(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 100),
            children: <Widget>[
              Card(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  child: Row(
                    children: <Widget>[
                      IconButton(
                        onPressed: () => _shiftMonth(-1),
                        icon: const Icon(Icons.chevron_left),
                      ),
                      Expanded(
                        child: Column(
                          children: <Widget>[
                            Text(
                              DateFormat('MMMM yyyy').format(_selectedMonth),
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Monthly analytics',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                            if (lastBackupAt != null)
                              Text(
                                'Last backup: ${DateFormat('dd MMM, hh:mm a').format(lastBackupAt.toLocal())}',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () => _shiftMonth(1),
                        icon: const Icon(Icons.chevron_right),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Card(
                color: Colors.green.shade50,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        'Total Expense',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '₹${analytics.totalExpense.toStringAsFixed(2)}',
                        style: Theme.of(context).textTheme.headlineMedium
                            ?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: Colors.red.shade700,
                            ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: <Widget>[
                          Expanded(
                            child: _MetricStat(
                              label: 'Income',
                              value: analytics.totalIncome,
                              color: Colors.green.shade700,
                            ),
                          ),
                          Expanded(
                            child: _MetricStat(
                              label: 'Net Cashflow',
                              value: analytics.netCashflow,
                              color: analytics.netCashflow >= 0
                                  ? Colors.green.shade700
                                  : Colors.red.shade700,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        'Spend by Category',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        height: 220,
                        child: analytics.expenseByCategory.isEmpty
                            ? const Center(
                                child: Text('No expense data for this month'),
                              )
                            : PieChart(
                                PieChartData(
                                  sectionsSpace: 2,
                                  centerSpaceRadius: 42,
                                  sections: _buildCategorySections(
                                    analytics.expenseByCategory,
                                  ),
                                ),
                              ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        'Top Merchants',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 12),
                      if (analytics.topMerchants.isEmpty)
                        const Text('No merchant spend data for this month')
                      else
                        ...analytics.topMerchants.map(
                          (merchant) => Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: Row(
                              children: <Widget>[
                                Expanded(child: Text(merchant.merchant)),
                                Text('₹${merchant.total.toStringAsFixed(2)}'),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
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
              const SizedBox(height: 12),
              if (filteredTransactions.isEmpty)
                const Card(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(
                      child: Text('No transactions for this filter'),
                    ),
                  ),
                )
              else
                ...filteredTransactions.map(
                  (item) => TransactionTile(
                    transaction: item.transaction,
                    onTap: () => _openTransactionDetail(item),
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
            label: const Text('Import Sheet'),
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

  List<PieChartSectionData> _buildCategorySections(
    Map<String, double> expenseByCategory,
  ) {
    final colors = <Color>[
      Colors.green.shade600,
      Colors.orange.shade600,
      Colors.blue.shade600,
      Colors.red.shade600,
      Colors.teal.shade600,
      Colors.purple.shade600,
    ];
    final entries = expenseByCategory.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return List<PieChartSectionData>.generate(entries.length, (index) {
      final entry = entries[index];
      return PieChartSectionData(
        value: entry.value,
        color: colors[index % colors.length],
        radius: 70,
        title: '${entry.key}\n₹${entry.value.toStringAsFixed(0)}',
        titleStyle: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
      );
    });
  }
}

class _MetricStat extends StatelessWidget {
  const _MetricStat({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final double value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(label, style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 4),
        Text(
          '₹${value.toStringAsFixed(2)}',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
      ],
    );
  }
}

class _StoredTransaction {
  _StoredTransaction({required this.key, required this.transaction});

  final dynamic key;
  final TransactionModel transaction;
}
