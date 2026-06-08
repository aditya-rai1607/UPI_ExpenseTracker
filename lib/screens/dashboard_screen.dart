import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';

import '../models/transaction_model.dart';
import '../services/analytics_service.dart';
import '../services/app_settings_service.dart';
import '../widgets/transaction_tile.dart';
import 'add_transaction_screen.dart';
import 'all_transactions_screen.dart';
import 'categorize_screen.dart';
import 'import_statement_screen.dart';
import 'insights_screen.dart';
import 'more_screen.dart';
import 'transaction_detail_screen.dart';

enum TransactionFilter { all, debit, credit, uncategorizedDebit }

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  static const Color _primaryColor = Color(0xFF6C63FF);
  static const Color _expenseColor = Color(0xFFEF4444);
  static const Color _secondaryTextColor = Color(0xFF6B7280);
  static const Color _textColor = Color(0xFF111827);

  TransactionFilter _filter = TransactionFilter.all;
  DateTime _selectedMonth = DateTime(DateTime.now().year, DateTime.now().month);

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
    for (var index = 0; index < box.length; index++) {
      final raw = box.getAt(index);
      if (raw is Map) {
        all.add(
          _StoredTransaction(
            key: box.keyAt(index),
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

  bool _isToday(DateTime date) {
    final now = DateTime.now();
    return date.year == now.year && date.month == now.month && date.day == now.day;
  }

  Future<void> _openInsightsScreen() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const InsightsScreen()),
    );
  }

  Future<void> _openMoreScreen() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const MoreScreen()),
    );
  }

  Future<void> _openAllTransactionsScreen() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const AllTransactionsScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final box = Hive.box('transactions');
    final lastBackupAt = AppSettingsService.getLastBackupAt();

    return Scaffold(
      body: SafeArea(
        child: ValueListenableBuilder(
          valueListenable: box.listenable(),
          builder: (context, Box<dynamic> box, _) {
            final storedTransactions = _readStoredTransactions(box);
            final transactions = storedTransactions
                .map((item) => item.transaction)
                .toList();
            final filteredTransactions = storedTransactions
                .where((item) => _matchesFilter(item.transaction))
                .toList();
            final todaysTransactions = filteredTransactions
              .where((item) => _isToday(item.transaction.date))
              .toList();
            final uncategorizedCount = storedTransactions
              .where((item) => item.transaction.type == TransactionType.debit)
              .where((item) => item.transaction.needsCategory)
              .length;
            final analytics = AnalyticsService.calculateMonthlyAnalytics(
              transactions: transactions,
              month: _selectedMonth,
            );

            return ListView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 112),
              children: <Widget>[
                _buildTopBar(),
                const SizedBox(height: 18),
                const Divider(height: 1, color: Color(0xFFF0F1F6)),
                const SizedBox(height: 18),
                _buildHeroCopy(context, uncategorizedCount),
                const SizedBox(height: 20),
                _buildSummaryCard(context, analytics, lastBackupAt),
                const SizedBox(height: 22),
                _buildCategoryChart(context, analytics),
                const SizedBox(height: 20),
                _buildFilterBar(context),
                const SizedBox(height: 18),
                _buildRecentActivityHeader(
                  context,
                  todaysTransactions.length,
                ),
                const SizedBox(height: 12),
                if (todaysTransactions.isEmpty)
                  _buildEmptyState(context)
                else
                  ...todaysTransactions.map(
                    (item) => Padding(
                      padding: const EdgeInsets.only(bottom: 14),
                      child: TransactionTile(
                        transaction: item.transaction,
                        onTap: () => _openTransactionDetail(item),
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endDocked,
      floatingActionButton: FloatingActionButton(
        heroTag: 'add_btn',
        onPressed: _openAddTransaction,
        backgroundColor: _primaryColor,
        foregroundColor: Colors.white,
        elevation: 12,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        child: const Icon(Icons.add, size: 28),
      ),
      bottomNavigationBar: _DashboardBottomBar(
        onInsightsTap: _openInsightsScreen,
        onImportTap: _openImportScreen,
        onMoreTap: _openMoreScreen,
      ),
    );
  }

  Widget _buildTopBar() {
    return Row(
      children: <Widget>[
        Text(
          'logo',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: _textColor,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(width: 10),
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: _textColor,
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(Icons.bolt_rounded, color: Colors.white, size: 18),
        ),
        const Spacer(),
        CircleAvatar(
          radius: 18,
          backgroundColor: const Color(0xFFE8ECF8),
          child: ClipOval(
            child: Container(
              color: const Color(0xFFD7DCEB),
              alignment: Alignment.center,
              child: const Icon(Icons.person, color: _textColor, size: 18),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHeroCopy(BuildContext context, int uncategorizedCount) {
    return Row(
      children: <Widget>[
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text('Hey Aditya!', style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 4),
              Text(
                'Your finances are looking healthy.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: _secondaryTextColor,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Stack(
          clipBehavior: Clip.none,
          children: <Widget>[
            _TopActionButton(
              onTap: _openCategorizeScreen,
              tooltip: 'Review uncategorized transactions',
              child: const Icon(
                Icons.notifications_none_rounded,
                color: _textColor,
              ),
            ),
            if (uncategorizedCount > 0)
              Positioned(
                top: -4,
                right: -2,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: _expenseColor,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                  child: Text(
                    uncategorizedCount > 9 ? '9+' : '$uncategorizedCount',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildSummaryCard(
    BuildContext context,
    MonthlyAnalytics analytics,
    DateTime? lastBackupAt,
  ) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        color: const Color(0xFFEDEDFB),
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: Color(0x140F172A),
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'TOTAL EXPENSES',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: const Color(0xFF7378AF),
              fontWeight: FontWeight.w700,
              letterSpacing: 1.0,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            '₹${analytics.totalExpense.toStringAsFixed(2)}',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              color: _textColor,
              fontSize: 34,
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: <Widget>[
              Expanded(
                child: _SummaryMetricCard(
                  icon: Icons.south_west_rounded,
                  label: 'INCOME',
                  value: analytics.totalIncome,
                  valueColor: _textColor,
                  labelColor: _secondaryTextColor,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: _SummaryMetricCard(
                  icon: Icons.north_east_rounded,
                  label: 'CASHFLOW',
                  value: analytics.netCashflow,
                  valueColor: _textColor,
                  labelColor: _expenseColor,
                ),
              ),
            ],
          ),
          if (lastBackupAt != null) ...<Widget>[
            const SizedBox(height: 16),
            Text(
              'Last backup ${DateFormat('dd MMM, hh:mm a').format(lastBackupAt.toLocal())}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: _secondaryTextColor,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCategoryChart(BuildContext context, MonthlyAnalytics analytics) {
    final sortedEntries = analytics.expenseByCategory.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(22, 22, 22, 26),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    'Spend by Category',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                _MonthPill(
                  selectedMonth: _selectedMonth,
                  onPrevious: () => _shiftMonth(-1),
                  onNext: () => _shiftMonth(1),
                ),
              ],
            ),
            const SizedBox(height: 18),
            SizedBox(
              height: 250,
              child: analytics.expenseByCategory.isEmpty
                  ? Center(
                      child: Text(
                        'No expense data for this month',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: _secondaryTextColor,
                        ),
                      ),
                    )
                  : Stack(
                      alignment: Alignment.center,
                      children: <Widget>[
                        PieChart(
                          PieChartData(
                            sectionsSpace: 6,
                            centerSpaceRadius: 68,
                            sections: _buildCategorySections(
                              analytics.expenseByCategory,
                            ),
                          ),
                        ),
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            Text(
                              'TOTAL',
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(
                                    color: _secondaryTextColor,
                                    fontWeight: FontWeight.w700,
                                  ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '₹${_formatCompactAmount(analytics.totalExpense)}',
                              style: Theme.of(context).textTheme.titleLarge
                                  ?.copyWith(color: _textColor),
                            ),
                          ],
                        ),
                      ],
                    ),
            ),
            if (sortedEntries.isNotEmpty) ...<Widget>[
              const SizedBox(height: 20),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: List<Widget>.generate(sortedEntries.length, (index) {
                  final entry = sortedEntries[index];
                  return _LegendChip(
                    label: entry.key,
                    color: _chartColorForIndex(index),
                  );
                }),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildFilterBar(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: <Widget>[
          _buildFilterChip(context, TransactionFilter.all, 'All'),
          const SizedBox(width: 10),
          _buildFilterChip(context, TransactionFilter.debit, 'Debits'),
          const SizedBox(width: 10),
          _buildFilterChip(context, TransactionFilter.credit, 'Credits'),
          const SizedBox(width: 10),
          _buildFilterChip(
            context,
            TransactionFilter.uncategorizedDebit,
            'Uncategorized',
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(
    BuildContext context,
    TransactionFilter filter,
    String label,
  ) {
    final selected = _filter == filter;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      showCheckmark: false,
      onSelected: (_) {
        setState(() {
          _filter = filter;
        });
      },
      backgroundColor: Colors.white,
      selectedColor: _primaryColor,
      labelStyle: Theme.of(context).textTheme.bodySmall?.copyWith(
        color: selected ? Colors.white : _secondaryTextColor,
        fontWeight: FontWeight.w700,
      ),
      side: BorderSide(
        color: selected ? _primaryColor : const Color(0xFFE5E7EB),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
    );
  }

  Widget _buildRecentActivityHeader(BuildContext context, int count) {
    return Row(
      children: <Widget>[
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text('Recent Activity', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 4),
              Text(
                '$count transactions today',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: _secondaryTextColor,
                ),
              ),
            ],
          ),
        ),
        TextButton(
          onPressed: _openAllTransactionsScreen,
          child: Text(
            'View All',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: _primaryColor,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        children: <Widget>[
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: const Color(0xFFF1F3FF),
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Icon(Icons.receipt_long_rounded, color: _primaryColor),
          ),
          const SizedBox(height: 14),
          Text(
            'No transactions for today',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 6),
          Text(
            'Try another filter or check View All for older activity.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: _secondaryTextColor,
            ),
          ),
        ],
      ),
    );
  }

  List<PieChartSectionData> _buildCategorySections(
    Map<String, double> expenseByCategory,
  ) {
    final entries = expenseByCategory.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final total = entries.fold<double>(0, (sum, entry) => sum + entry.value);
    return List<PieChartSectionData>.generate(entries.length, (index) {
      final entry = entries[index];
      final percentage = total == 0 ? 0 : (entry.value / total) * 100;
      return PieChartSectionData(
        value: entry.value,
        color: _chartColorForIndex(index),
        radius: 58,
        title: '${percentage.round()}%',
        titlePositionPercentageOffset: 0.72,
        titleStyle: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
      );
    });
  }

  Color _chartColorForIndex(int index) {
    const palette = <Color>[
      Color(0xFF6C63FF),
      Color(0xFF22C55E),
      Color(0xFFF59E0B),
      Color(0xFF06B6D4),
      Color(0xFFEF4444),
      Color(0xFFEC4899),
    ];
    return palette[index % palette.length];
  }

  String _formatCompactAmount(double amount) {
    if (amount >= 100000) {
      return '${(amount / 100000).toStringAsFixed(1)}L';
    }
    if (amount >= 1000) {
      return '${(amount / 1000).toStringAsFixed(1)}k';
    }
    return amount.toStringAsFixed(0);
  }
}

class _TopActionButton extends StatelessWidget {
  const _TopActionButton({
    required this.onTap,
    required this.tooltip,
    required this.child,
  });

  final VoidCallback? onTap;
  final String tooltip;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Ink(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(19),
          ),
          child: Center(child: child),
        ),
      ),
    );
  }
}

class _MonthPill extends StatelessWidget {
  const _MonthPill({
    required this.selectedMonth,
    required this.onPrevious,
    required this.onNext,
  });

  final DateTime selectedMonth;
  final VoidCallback onPrevious;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF7F8FC),
        borderRadius: BorderRadius.circular(999),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          GestureDetector(
            onTap: onPrevious,
            child: const Icon(Icons.chevron_left_rounded, size: 18),
          ),
          const SizedBox(width: 4),
          Text(
            DateFormat('MMM yyyy').format(selectedMonth),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: const Color(0xFF6B7280),
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(width: 4),
          GestureDetector(
            onTap: onNext,
            child: const Icon(Icons.chevron_right_rounded, size: 18),
          ),
        ],
      ),
    );
  }
}

class _SummaryMetricCard extends StatelessWidget {
  const _SummaryMetricCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.valueColor,
    required this.labelColor,
  });

  final IconData icon;
  final String label;
  final double value;
  final Color valueColor;
  final Color labelColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(icon, size: 14, color: labelColor),
              const SizedBox(width: 6),
              Text(
                label,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: labelColor,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            '₹${value.toStringAsFixed(2)}',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: valueColor,
              fontSize: 18,
            ),
          ),
        ],
      ),
    );
  }
}

class _LegendChip extends StatelessWidget {
  const _LegendChip({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F9FD),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Text(label, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}

class _StoredTransaction {
  _StoredTransaction({required this.key, required this.transaction});

  final dynamic key;
  final TransactionModel transaction;
}

class _DashboardBottomBar extends StatelessWidget {
  const _DashboardBottomBar({
    required this.onInsightsTap,
    required this.onImportTap,
    required this.onMoreTap,
  });

  final VoidCallback onInsightsTap;
  final VoidCallback onImportTap;
  final VoidCallback onMoreTap;

  @override
  Widget build(BuildContext context) {
    return BottomAppBar(
      elevation: 14,
      shadowColor: const Color(0x140F172A),
      color: Colors.white,
      shape: const CircularNotchedRectangle(),
      notchMargin: 8,
      child: SizedBox(
        height: 66,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: <Widget>[
            const _BottomBarItem(
              icon: Icons.grid_view_rounded,
              label: 'Home',
              selected: true,
            ),
            _BottomBarItem(
              icon: Icons.insights_rounded,
              label: 'Insights',
              onTap: onInsightsTap,
            ),
            const SizedBox(width: 36),
            _BottomBarItem(
              icon: Icons.file_upload_outlined,
              label: 'Import',
              onTap: onImportTap,
            ),
            _BottomBarItem(
              icon: Icons.menu_rounded,
              label: 'More',
              onTap: onMoreTap,
            ),
          ],
        ),
      ),
    );
  }
}

class _BottomBarItem extends StatelessWidget {
  const _BottomBarItem({
    required this.icon,
    required this.label,
    this.selected = false,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? const Color(0xFF6C63FF) : const Color(0xFF6B7280);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Icon(icon, size: 20, color: color),
            const SizedBox(height: 4),
            Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: color,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
