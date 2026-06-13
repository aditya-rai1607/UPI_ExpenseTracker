import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';

import '../models/transaction_model.dart';
import '../services/analytics_service.dart';
import '../services/app_settings_service.dart';
import '../services/native_sms_bridge.dart';
import '../widgets/transaction_tile.dart';
import 'add_transaction_screen.dart';
import 'all_transactions_screen.dart';
import 'categorize_screen.dart';
import 'import_statement_screen.dart';
import 'insights_screen.dart';
import 'more_screen.dart';
import 'transaction_detail_screen.dart';

String _inrFormat(double amount, {int decimalDigits = 2}) {
  return NumberFormat.currency(
    locale: 'en_IN',
    symbol: '₹',
    decimalDigits: decimalDigits,
  ).format(amount);
}

enum TransactionFilter { all, debit, credit, investment, uncategorizedDebit }

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  static const Color _primaryColor = Color(0xFF6C63FF);
  static const Color _expenseColor = Color(0xFFEF4444);
  static const Color _incomeColor = Color(0xFF16A34A);

  Color _secondaryTextColor(BuildContext context) =>
      Theme.of(context).colorScheme.onSurfaceVariant;
  Color _textColor(BuildContext context) =>
      Theme.of(context).colorScheme.onSurface;
  Color _surfaceColor(BuildContext context) => Theme.of(context).cardColor;
  Color _borderColor(BuildContext context) => Theme.of(context).dividerColor;
  Color _softAccentSurface(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? const Color(0xFF20263A)
        : const Color(0xFFEDEDFB);
  }

  Color _softIconSurface(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? const Color(0xFF1A2233)
        : const Color(0xFFF1F3FF);
  }

  Color _pillSurface(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? const Color(0xFF1A2233)
        : const Color(0xFFF7F8FC);
  }

  TransactionFilter _filter = TransactionFilter.all;
  DateTime _selectedMonth = DateTime(DateTime.now().year, DateTime.now().month);

  @override
  void initState() {
    super.initState();
    // Drain any pending native-queued transactions when the dashboard appears.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // use the shared helper to move native-queued transactions into Hive
      // and show categorization prompts.
      Future.microtask(
        () =>
            // ignore: discarded_futures
            NativeSmsBridge.drainPendingTransactions(),
      );
    });
  }

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
      case TransactionFilter.investment:
        return transaction.type == TransactionType.investment;
      case TransactionFilter.uncategorizedDebit:
        return transaction.needsCategory;
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
    return date.year == now.year &&
        date.month == now.month &&
        date.day == now.day;
  }

  Future<void> _openInsightsScreen() async {
    await Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => const InsightsScreen()));
  }

  Future<void> _openMoreScreen() async {
    await Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => const MoreScreen()));
  }

  Future<void> _openAllTransactionsScreen() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const AllTransactionsScreen()),
    );
  }

  double _displayExpenseTotal(MonthlyAnalytics analytics) {
    return analytics.totalExpense;
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
            final recentTransactions = todaysTransactions.isNotEmpty
                ? todaysTransactions
                : filteredTransactions.take(5).toList(growable: false);
            final isRecentFallbackUsed =
                todaysTransactions.isEmpty && recentTransactions.isNotEmpty;
            final uncategorizedCount = storedTransactions
                .where((item) => item.transaction.type == TransactionType.debit)
                .where((item) => item.transaction.needsCategory)
                .length;
            final analytics = AnalyticsService.calculateMonthlyAnalytics(
              transactions: transactions,
              month: _selectedMonth,
            );
            final totalInvestmentAllTime = transactions
                .where((item) => item.type == TransactionType.investment)
                .fold<double>(0, (sum, item) => sum + item.amount);
            final totalInvestmentByCategory = _buildInvestmentByCategory(
              transactions,
            );
            final monthInvestmentByCategory = _buildInvestmentByCategory(
              transactions,
              month: _selectedMonth,
            );

            return ListView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 112),
              children: <Widget>[
                _buildTopBar(),
                const SizedBox(height: 18),
                Divider(height: 1, color: _borderColor(context)),
                const SizedBox(height: 18),
                _buildHeroCopy(context, uncategorizedCount),
                const SizedBox(height: 20),
                _buildSummarySection(
                  context,
                  analytics,
                  totalInvestmentAllTime,
                  totalInvestmentByCategory,
                  monthInvestmentByCategory,
                  lastBackupAt,
                ),
                const SizedBox(height: 22),
                _buildCategoryChart(context, analytics),
                const SizedBox(height: 18),
                _buildMonthlyTrendChart(context, transactions),
                const SizedBox(height: 20),
                _buildFilterBar(context),
                const SizedBox(height: 18),
                _buildRecentActivityHeader(
                  context,
                  recentTransactions.length,
                  usingFallback: isRecentFallbackUsed,
                ),
                const SizedBox(height: 12),
                if (recentTransactions.isEmpty)
                  _buildEmptyState(context)
                else
                  ...recentTransactions.map(
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Row(
      children: <Widget>[
        Text(
          'logo',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: _textColor(context),
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(width: 10),
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1A2233) : _textColor(context),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            Icons.bolt_rounded,
            color: isDark ? _textColor(context) : Colors.white,
            size: 18,
          ),
        ),
        const Spacer(),
        CircleAvatar(
          radius: 18,
          backgroundColor: const Color(0xFFE8ECF8),
          child: ClipOval(
            child: Container(
              color: const Color(0xFFD7DCEB),
              alignment: Alignment.center,
              child: Icon(Icons.person, color: _textColor(context), size: 18),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHeroCopy(BuildContext context, int uncategorizedCount) {
    final subtitle = uncategorizedCount > 0
        ? 'You have some new uncategoried finances.'
        : 'Your finances are looking healthy.';

    return Row(
      children: <Widget>[
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                'Hey Aditya!',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: _secondaryTextColor(context),
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
              child: Icon(
                Icons.notifications_none_rounded,
                color: _textColor(context),
              ),
            ),
            if (uncategorizedCount > 0)
              Positioned(
                top: -4,
                right: -2,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: _expenseColor,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: Theme.of(context).scaffoldBackgroundColor,
                      width: 2,
                    ),
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

  Widget _buildSummarySection(
    BuildContext context,
    MonthlyAnalytics analytics,
    double totalInvestmentAllTime,
    Map<String, double> totalInvestmentByCategory,
    Map<String, double> monthInvestmentByCategory,
    DateTime? lastBackupAt,
  ) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final isCompact = screenWidth < 600;
    final isTablet = screenWidth >= 600 && screenWidth < 1100;
    if (isCompact) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          _buildExpenseCard(context, analytics, lastBackupAt),
          const SizedBox(height: 12),
          _buildInvestmentCard(
            context,
            totalInvestmentAllTime,
            analytics.totalInvestment,
            totalInvestmentByCategory,
            monthInvestmentByCategory,
          ),
        ],
      );
    }

    if (isTablet) {
      return IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Expanded(
              child: _buildExpenseCard(context, analytics, lastBackupAt),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildInvestmentCard(
                context,
                totalInvestmentAllTime,
                analytics.totalInvestment,
                totalInvestmentByCategory,
                monthInvestmentByCategory,
              ),
            ),
          ],
        ),
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Expanded(
          flex: 2,
          child: _buildExpenseCard(context, analytics, lastBackupAt),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: _buildInvestmentCard(
            context,
            totalInvestmentAllTime,
            analytics.totalInvestment,
            totalInvestmentByCategory,
            monthInvestmentByCategory,
          ),
        ),
      ],
    );
  }

  Widget _buildExpenseCard(
    BuildContext context,
    MonthlyAnalytics analytics,
    DateTime? lastBackupAt,
  ) {
    final displayExpenseTotal = _displayExpenseTotal(analytics);
    final savingsAmount = analytics.totalIncome - analytics.totalExpense;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        color: _softAccentSurface(context),
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
            'MONTH\'S EXPENSES',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: _secondaryTextColor(context),
              fontWeight: FontWeight.w700,
              letterSpacing: 1.0,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _inrFormat(displayExpenseTotal),
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              color: _expenseColor,
              fontSize: 28,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(
                child: _SummaryMetricCard(
                  icon: Icons.south_west_rounded,
                  label: 'INCOME',
                  value: analytics.totalIncome,
                  valueColor: _incomeColor,
                  labelColor: _textColor(context),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _SummaryMetricCard(
                  icon: Icons.savings_rounded,
                  label: 'SAVINGS',
                  value: savingsAmount,
                  valueColor: savingsAmount < 0
                      ? _expenseColor
                      : _textColor(context),
                  labelColor: const Color.fromARGB(255, 8, 118, 151),
                  showSigned: true,
                ),
              ),
            ],
          ),
          if (lastBackupAt != null) ...<Widget>[
            const SizedBox(height: 12),
            Text(
              'Last backup ${DateFormat('dd MMM, hh:mm a').format(lastBackupAt.toLocal())}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: _secondaryTextColor(context),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildInvestmentCard(
    BuildContext context,
    double totalInvestment,
    double monthInvestment,
    Map<String, double> totalInvestmentByCategory,
    Map<String, double> monthInvestmentByCategory,
  ) {
    final totalSummary = _buildInvestmentSummary(totalInvestmentByCategory);
    final monthSummary = _buildInvestmentSummary(monthInvestmentByCategory);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return InkWell(
      onTap: _openInsightsScreen,
      borderRadius: BorderRadius.circular(24),
      child: Ink(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          color: isDark ? const Color(0xFF18304A) : const Color(0xFFD6EEFF),
          boxShadow: const <BoxShadow>[
            BoxShadow(
              color: Color(0x120F172A),
              blurRadius: 16,
              offset: Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'TOTAL INVESTMENTS',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: _textColor(context),
                fontWeight: FontWeight.w700,
                letterSpacing: 1.0,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _inrFormat(totalInvestment),
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                color: _incomeColor,
                fontWeight: FontWeight.w700,
                fontSize: 28,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              totalSummary,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: _textColor(context),
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 10),
            Icon(
              Icons.north_east_rounded,
              color: _textColor(context),
              size: 26,
            ),
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0xFF274865)
                    : const Color(0xFFB7DEFF),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: <Widget>[
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          'Month\'s Investment',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: _textColor(context),
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.2,
                                height: 1.3,
                              ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          _inrFormat(monthInvestment),
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(
                                color: _incomeColor,
                                fontWeight: FontWeight.w700,
                                fontSize: 16,
                              ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          monthSummary,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: _textColor(context),
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                              ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      color: isDark
                          ? const Color(0xFFD7E6F3)
                          : const Color(0xFFEAF2FA),
                      borderRadius: BorderRadius.circular(7),
                    ),
                    child: Icon(
                      Icons.bar_chart_rounded,
                      color: isDark
                          ? const Color(0xFF24455C)
                          : const Color(0xFF4B728F),
                      size: 20,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: Text(
                'Click to view details',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: _textColor(context),
                  fontWeight: FontWeight.w600,
                  fontStyle: FontStyle.italic,
                  fontSize: 11,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _buildInvestmentSummary(Map<String, double> categories) {
    final normalized = <String, double>{
      'Stocks': 0,
      'Mutual Funds': 0,
      'Gold': 0,
      'Others': 0,
    };

    for (final entry in categories.entries) {
      final key = _normalizeInvestmentCategory(entry.key);
      normalized.update(
        key,
        (value) => value + entry.value,
        ifAbsent: () => entry.value,
      );
    }

    final f = NumberFormat('#,##,##0', 'en_IN');
    return 'Stocks: ${f.format(normalized['Stocks']!)}   '
        'Mutual Funds: ${f.format(normalized['Mutual Funds']!)}   '
        'Gold: ${f.format(normalized['Gold']!)}   '
        'Others: ${f.format(normalized['Others']!)}';
  }

  String _normalizeInvestmentCategory(String category) {
    final value = category.trim().toLowerCase();
    if (value.contains('stock')) {
      return 'Stocks';
    }
    if (value.contains('mutual')) {
      return 'Mutual Funds';
    }
    if (value.contains('gold')) {
      return 'Gold';
    }
    return 'Others';
  }

  Map<String, double> _buildInvestmentByCategory(
    List<TransactionModel> transactions, {
    DateTime? month,
  }) {
    final result = <String, double>{};
    for (final transaction in transactions) {
      if (transaction.type != TransactionType.investment) {
        continue;
      }
      if (month != null &&
          (transaction.date.year != month.year ||
              transaction.date.month != month.month)) {
        continue;
      }
      final category = (transaction.category ?? '').trim().isEmpty
          ? 'Uncategorized'
          : transaction.category!.trim();
      result.update(
        category,
        (value) => value + transaction.amount,
        ifAbsent: () => transaction.amount,
      );
    }
    return result;
  }

  Widget _buildCategoryChart(BuildContext context, MonthlyAnalytics analytics) {
    final breakdown = _buildCategoryBreakdown(analytics.expenseByCategory);
    final displayExpenseTotal = _displayExpenseTotal(analytics);

    return Card(
      elevation: 0,
      color: _surfaceColor(context),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
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
            if (analytics.expenseByCategory.isEmpty)
              SizedBox(
                height: 220,
                child: Center(
                  child: Text(
                    'No expense data for this month',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: _secondaryTextColor(context),
                    ),
                  ),
                ),
              )
            else
              _CategoryPieChart(
                breakdown: breakdown,
                totalExpenseLabel:
                    '₹${_formatCompactAmount(displayExpenseTotal)}',
                sectionBuilder: _buildCategorySections,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterBar(BuildContext context) {
    final isMobile = MediaQuery.sizeOf(context).width < 600;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: <Widget>[
          _buildFilterChip(context, TransactionFilter.all, 'All'),
          const SizedBox(width: 10),
          _buildFilterChip(context, TransactionFilter.credit, 'Credited'),
          const SizedBox(width: 10),
          _buildFilterChip(context, TransactionFilter.debit, 'Debited'),
          if (!isMobile) ...<Widget>[
            const SizedBox(width: 10),
            _buildFilterChip(
              context,
              TransactionFilter.investment,
              'Investments',
            ),
            const SizedBox(width: 10),
            _buildFilterChip(
              context,
              TransactionFilter.uncategorizedDebit,
              'Uncategorized',
            ),
          ],
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
      backgroundColor: _surfaceColor(context),
      selectedColor: _primaryColor,
      labelStyle: Theme.of(context).textTheme.bodySmall?.copyWith(
        color: selected ? Colors.white : _secondaryTextColor(context),
        fontWeight: FontWeight.w700,
      ),
      side: BorderSide(color: selected ? _primaryColor : _borderColor(context)),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
    );
  }

  Widget _buildRecentActivityHeader(
    BuildContext context,
    int count, {
    required bool usingFallback,
  }) {
    final subtitle = usingFallback
        ? 'Showing latest $count transactions'
        : '$count transactions today';
    return Row(
      children: <Widget>[
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                'Recent Activity',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: _secondaryTextColor(context),
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

  Widget _buildMonthlyTrendChart(
    BuildContext context,
    List<TransactionModel> transactions,
  ) {
    final trends = AnalyticsService.calculateMonthlyTrends(
      transactions: transactions,
      endMonth: _selectedMonth,
      monthCount: 5,
    );
    final maxValue = trends.fold<double>(
      0,
      (max, item) => math.max(max, math.max(item.income, item.expense)),
    );

    return Card(
      elevation: 0,
      color: _surfaceColor(context),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'Income vs Expense',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 6),
            Text(
              'Last 5 months',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: _secondaryTextColor(context),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 240,
              child: BarChart(
                BarChartData(
                  barTouchData: BarTouchData(
                    enabled: true,
                    touchTooltipData: BarTouchTooltipData(
                      tooltipBgColor: const Color(0xCC111827),
                      getTooltipItem: (group, groupIndex, rod, rodIndex) {
                        final label = rodIndex == 0 ? 'Income' : 'Expense';
                        return BarTooltipItem(
                          '$label\n₹${rod.toY.toStringAsFixed(0)}',
                          const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                        );
                      },
                    ),
                  ),
                  maxY: maxValue == 0 ? 100 : maxValue * 1.2,
                  alignment: BarChartAlignment.spaceAround,
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    horizontalInterval: maxValue == 0
                        ? 25
                        : (maxValue * 1.2) / 4,
                    getDrawingHorizontalLine: (_) =>
                        FlLine(color: _borderColor(context), strokeWidth: 1),
                  ),
                  borderData: FlBorderData(show: false),
                  titlesData: FlTitlesData(
                    topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 44,
                        getTitlesWidget: (value, meta) => Text(
                          '₹${(value / 1000).toStringAsFixed(value >= 1000 ? 0 : 1)}k',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: _secondaryTextColor(context)),
                        ),
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          final index = value.toInt();
                          if (index < 0 || index >= trends.length) {
                            return const SizedBox.shrink();
                          }
                          return Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              DateFormat('MMM').format(trends[index].month),
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(
                                    color: _secondaryTextColor(context),
                                    fontWeight: FontWeight.w600,
                                  ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  barGroups: List<BarChartGroupData>.generate(trends.length, (
                    index,
                  ) {
                    final trend = trends[index];
                    return BarChartGroupData(
                      x: index,
                      barsSpace: 6,
                      barRods: <BarChartRodData>[
                        BarChartRodData(
                          toY: trend.income,
                          width: 10,
                          color: _incomeColor,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        BarChartRodData(
                          toY: trend.expense,
                          width: 10,
                          color: _expenseColor,
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ],
                    );
                  }),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: <Widget>[
                _ChartLegendDot(color: _incomeColor, label: 'Income'),
                const SizedBox(width: 16),
                _ChartLegendDot(color: _expenseColor, label: 'Expense'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: _surfaceColor(context),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        children: <Widget>[
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: _softIconSurface(context),
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
              color: _secondaryTextColor(context),
            ),
          ),
        ],
      ),
    );
  }

  List<_CategoryBreakdownItem> _buildCategoryBreakdown(
    Map<String, double> expenseByCategory,
  ) {
    final sortedEntries = expenseByCategory.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final entries = sortedEntries.length <= 8
        ? sortedEntries
        : <MapEntry<String, double>>[
            ...sortedEntries.take(7),
            MapEntry<String, double>(
              'Other',
              sortedEntries
                  .skip(7)
                  .fold<double>(0, (sum, entry) => sum + entry.value),
            ),
          ];
    final total = entries.fold<double>(0, (sum, entry) => sum + entry.value);

    return List<_CategoryBreakdownItem>.generate(entries.length, (index) {
      final entry = entries[index];
      final percentage = total == 0
          ? 0.0
          : ((entry.value / total) * 100).toDouble();
      return _CategoryBreakdownItem(
        label: entry.key,
        value: entry.value,
        percentage: percentage,
        color: _chartColorForIndex(index),
      );
    });
  }

  List<PieChartSectionData> _buildCategorySections(
    List<_CategoryBreakdownItem> breakdown,
    double radius,
  ) {
    return List<PieChartSectionData>.generate(breakdown.length, (index) {
      final entry = breakdown[index];
      return PieChartSectionData(
        value: entry.value,
        color: entry.color,
        radius: radius,
        title: '',
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Ink(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1A2233) : Colors.white,
            borderRadius: BorderRadius.circular(19),
            border: Border.all(
              color: isDark ? const Color(0xFF2A3140) : const Color(0xFFE9EBF2),
            ),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final onSurface = Theme.of(context).colorScheme.onSurface;
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A2233) : const Color(0xFFF7F8FC),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: isDark ? const Color(0xFF2A3140) : const Color(0xFFE5E7EB),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          GestureDetector(
            onTap: onPrevious,
            child: Icon(Icons.chevron_left_rounded, size: 18, color: onSurface),
          ),
          const SizedBox(width: 4),
          Text(
            DateFormat('MMM yyyy').format(selectedMonth),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: onSurface,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(width: 4),
          GestureDetector(
            onTap: onNext,
            child: Icon(
              Icons.chevron_right_rounded,
              size: 18,
              color: onSurface,
            ),
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
    this.showSigned = false,
  });

  final IconData icon;
  final String label;
  final double value;
  final Color valueColor;
  final Color labelColor;
  final bool showSigned;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final displayValue = showSigned
        ? '${value > 0
              ? '+'
              : value < 0
              ? '-'
              : ''}${_inrFormat(value.abs())}'
        : _inrFormat(value.abs());
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark
            ? const Color(0xFF121827)
            : Colors.white.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark ? const Color(0xFF2A3140) : Colors.transparent,
        ),
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
                  letterSpacing: 0.2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            displayValue,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: valueColor,
              fontWeight: FontWeight.w700,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }
}

class _ChartLegendDot extends StatelessWidget {
  const _ChartLegendDot({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _CategoryBreakdownItem {
  const _CategoryBreakdownItem({
    required this.label,
    required this.value,
    required this.percentage,
    required this.color,
  });

  final String label;
  final double value;
  final double percentage;
  final Color color;
}

class _CategoryPieChart extends StatelessWidget {
  const _CategoryPieChart({
    required this.breakdown,
    required this.totalExpenseLabel,
    required this.sectionBuilder,
  });

  final List<_CategoryBreakdownItem> breakdown;
  final String totalExpenseLabel;
  final List<PieChartSectionData> Function(List<_CategoryBreakdownItem>, double)
  sectionBuilder;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 720;
        final chartSize = isCompact
            ? math.min(constraints.maxWidth * 0.56, 220.0)
            : math.min(constraints.maxWidth * 0.32, 210.0);
        final sectionRadius = chartSize * 0.34;

        final chart = SizedBox(
          width: chartSize,
          height: chartSize,
          child: Stack(
            alignment: Alignment.center,
            children: <Widget>[
              PieChart(
                PieChartData(
                  startDegreeOffset: -90,
                  sectionsSpace: 4,
                  centerSpaceRadius: chartSize * 0.26,
                  sections: sectionBuilder(breakdown, sectionRadius),
                ),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(
                    'TOTAL',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    totalExpenseLabel,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                ],
              ),
            ],
          ),
        );

        final details = _CategoryDetailsPanel(items: breakdown);

        if (isCompact) {
          return Column(
            children: <Widget>[
              Center(child: chart),
              const SizedBox(height: 18),
              details,
            ],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            chart,
            const SizedBox(width: 18),
            Expanded(child: details),
          ],
        );
      },
    );
  }
}

class _CategoryDetailsPanel extends StatelessWidget {
  const _CategoryDetailsPanel({required this.items});

  final List<_CategoryBreakdownItem> items;

  @override
  Widget build(BuildContext context) {
    final splitIndex = (items.length / 2).ceil();
    final leftColumnItems = items.take(splitIndex).toList(growable: false);
    final rightColumnItems = items.skip(splitIndex).toList(growable: false);

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark
            ? const Color(0xFF1A2233)
            : const Color(0xFFFBFBFE),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'DETAIL & PERCENTAGES',
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(
                child: Column(
                  children: leftColumnItems
                      .map(
                        (item) => Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: _CategoryMetricRow(item: item),
                        ),
                      )
                      .toList(growable: false),
                ),
              ),
              if (rightColumnItems.isNotEmpty) const SizedBox(width: 12),
              Expanded(
                child: Column(
                  children: rightColumnItems
                      .map(
                        (item) => Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: _CategoryMetricRow(item: item),
                        ),
                      )
                      .toList(growable: false),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Total Categories: ${items.length}',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _CategoryMetricRow extends StatelessWidget {
  const _CategoryMetricRow({required this.item});

  final _CategoryBreakdownItem item;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: <Widget>[
        Container(
          width: 22,
          height: 22,
          decoration: BoxDecoration(
            color: item.color.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(8),
          ),
          alignment: Alignment.center,
          child: Container(
            width: 9,
            height: 9,
            decoration: BoxDecoration(
              color: item.color,
              shape: BoxShape.circle,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      item.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurface,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '${item.percentage.toStringAsFixed(1)}%',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurface,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
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
        color: Theme.of(context).brightness == Brightness.dark
            ? const Color(0xFF1A2233)
            : const Color(0xFFF8F9FD),
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
      color: Theme.of(context).bottomAppBarTheme.color,
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
    final color = selected
        ? const Color(0xFF6C63FF)
        : Theme.of(context).colorScheme.onSurfaceVariant;
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
