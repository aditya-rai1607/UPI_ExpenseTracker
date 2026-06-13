import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';

import '../models/transaction_model.dart';
import '../services/analytics_service.dart';

String _inrFormat(double amount, {int decimalDigits = 2}) {
  return NumberFormat.currency(
    locale: 'en_IN',
    symbol: '₹',
    decimalDigits: decimalDigits,
  ).format(amount);
}

class InsightsScreen extends StatefulWidget {
  final int initialTabIndex;
  const InsightsScreen({super.key, this.initialTabIndex = 0});

  @override
  State<InsightsScreen> createState() => _InsightsScreenState();
}

class _InsightsScreenState extends State<InsightsScreen>
    with SingleTickerProviderStateMixin {
  static const Color _successColor = Color(0xFF22C55E);
  static const Color _expenseColor = Color(0xFFEF4444);

  Color _backgroundColor(BuildContext context) =>
      Theme.of(context).scaffoldBackgroundColor;
  Color _surfaceColor(BuildContext context) => Theme.of(context).cardColor;
  Color _textColor(BuildContext context) =>
      Theme.of(context).colorScheme.onSurface;
  Color _mutedTextColor(BuildContext context) =>
      Theme.of(context).colorScheme.onSurfaceVariant;
  Color _softBorderColor(BuildContext context) =>
      Theme.of(context).dividerColor;
  Color _softAccentSurface(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? const Color(0xFF1A2233)
        : const Color(0xFFF8F9FD);
  }

  late final TabController _tabController;
  DateTime _selectedMonth = DateTime(DateTime.now().year, DateTime.now().month);

  @override
  void initState() {
    super.initState();
    final initial = (widget.initialTabIndex >= 0 && widget.initialTabIndex < 3)
        ? widget.initialTabIndex
        : 0;
    _tabController = TabController(
      length: 3,
      vsync: this,
      initialIndex: initial,
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _shiftMonth(int delta) {
    setState(() {
      _selectedMonth = DateTime(
        _selectedMonth.year,
        _selectedMonth.month + delta,
      );
    });
  }

  List<TransactionModel> _readTransactions(Box<dynamic> box) {
    final items = <TransactionModel>[];
    for (final raw in box.values) {
      if (raw is Map) {
        items.add(TransactionModel.fromMap(raw.cast<dynamic, dynamic>()));
      }
    }
    return items;
  }

  List<TransactionModel> _transactionsForTab(
    List<TransactionModel> transactions,
    int tabIndex,
  ) {
    switch (tabIndex) {
      case 0:
        return transactions
            .where((item) => item.type == TransactionType.debit)
            .toList(growable: false);
      case 1:
        return transactions
            .where((item) => item.type == TransactionType.credit)
            .toList(growable: false);
      case 2:
        return transactions
            .where((item) => item.type == TransactionType.investment)
            .toList(growable: false);
      default:
        return transactions;
    }
  }

  Color _accentForTab(int tabIndex) {
    if (tabIndex == 0) return _expenseColor;
    return _successColor;
  }

  String _labelForTab(int tabIndex) {
    switch (tabIndex) {
      case 0:
        return 'Expense';
      case 1:
        return 'Income';
      case 2:
        return 'Investment';
      default:
        return 'Insights';
    }
  }

  List<MerchantSpend> _topMerchantsForTransactions(
    List<TransactionModel> transactions,
  ) {
    final merchantTotals = <String, double>{};
    for (final transaction in transactions) {
      merchantTotals.update(
        transaction.merchant,
        (value) => value + transaction.amount,
        ifAbsent: () => transaction.amount,
      );
    }

    final topMerchants =
        merchantTotals.entries
            .map(
              (entry) => MerchantSpend(merchant: entry.key, total: entry.value),
            )
            .toList()
          ..sort((a, b) => b.total.compareTo(a.total));

    return topMerchants.take(5).toList(growable: false);
  }

  Widget _buildTabContent(
    BuildContext context,
    List<TransactionModel> allTransactions,
    int tabIndex,
  ) {
    final label = _labelForTab(tabIndex);
    final accentColor = _accentForTab(tabIndex);
    final tabTransactions = _transactionsForTab(allTransactions, tabIndex);

    final totalValue = tabTransactions.fold<double>(
      0,
      (sum, transaction) => sum + transaction.amount,
    );

    final categoryEntries = AnalyticsService.calculateAmountsByCategory(
      transactions: tabTransactions,
      month: _selectedMonth,
    ).entries.toList()..sort((a, b) => b.value.compareTo(a.value));

    final maxCategoryValue = categoryEntries.fold<double>(
      0,
      (max, entry) => entry.value > max ? entry.value : max,
    );

    final topMerchants = _topMerchantsForTransactions(tabTransactions);

    return ListView(
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 24),
      children: <Widget>[
        _InsightMetricCard(
          label: 'Total $label',
          value: totalValue,
          accent: accentColor,
        ),
        const SizedBox(height: 14),
        _InsightSection(
          title: '$label by Category',
          child: categoryEntries.isEmpty
              ? Text(
                  'No $label entries recorded for this month.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: _mutedTextColor(context),
                  ),
                )
              : Column(
                  children: categoryEntries
                      .map((entry) {
                        final ratio = maxCategoryValue == 0
                            ? 0.0
                            : entry.value / maxCategoryValue;
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 14),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: <Widget>[
                              SizedBox(
                                width: 96,
                                child: Text(
                                  entry.key,
                                  style: Theme.of(context).textTheme.bodyMedium
                                      ?.copyWith(
                                        color: _textColor(context),
                                        fontWeight: FontWeight.w600,
                                      ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(999),
                                  child: LinearProgressIndicator(
                                    value: ratio,
                                    minHeight: 14,
                                    backgroundColor: _softBorderColor(context),
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      accentColor,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Text(
                                _inrFormat(entry.value, decimalDigits: 0),
                                style: Theme.of(context).textTheme.bodyMedium
                                    ?.copyWith(
                                      color: _textColor(context),
                                      fontWeight: FontWeight.w700,
                                    ),
                              ),
                            ],
                          ),
                        );
                      })
                      .toList(growable: false),
                ),
        ),
        const SizedBox(height: 14),
        _InsightSection(
          title: 'Top Merchants',
          child: topMerchants.isEmpty
              ? Text(
                  'No merchant data available for this month.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: _mutedTextColor(context),
                  ),
                )
              : SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: topMerchants
                        .map((merchant) {
                          return Container(
                            margin: const EdgeInsets.only(right: 10),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 12,
                            ),
                            decoration: BoxDecoration(
                              color: _softAccentSurface(context),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Text(
                                  merchant.merchant,
                                  style: Theme.of(context).textTheme.bodyMedium
                                      ?.copyWith(
                                        color: _textColor(context),
                                        fontWeight: FontWeight.w600,
                                      ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  _inrFormat(merchant.total, decimalDigits: 0),
                                  style: Theme.of(context).textTheme.bodyMedium
                                      ?.copyWith(
                                        color: _textColor(context),
                                        fontWeight: FontWeight.w700,
                                      ),
                                ),
                              ],
                            ),
                          );
                        })
                        .toList(growable: false),
                  ),
                ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final box = Hive.box('transactions');

    return Scaffold(
      backgroundColor: _backgroundColor(context),
      appBar: AppBar(
        backgroundColor: _backgroundColor(context),
        elevation: 0,
        scrolledUnderElevation: 0,
        titleSpacing: 0,
        title: Text(
          'Insights',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            color: _textColor(context),
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: SafeArea(
        child: ValueListenableBuilder(
          valueListenable: box.listenable(),
          builder: (context, Box<dynamic> box, _) {
            final allTransactions = _readTransactions(box);

            return Column(
              children: <Widget>[
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 8, 14, 0),
                  child: Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: _surfaceColor(context),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: _softBorderColor(context)),
                    ),
                    child: Row(
                      children: <Widget>[
                        IconButton(
                          onPressed: () => _shiftMonth(-1),
                          icon: const Icon(Icons.chevron_left_rounded),
                        ),
                        Expanded(
                          child: Text(
                            DateFormat('MMMM yyyy').format(_selectedMonth),
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(
                                  color: _textColor(context),
                                  fontWeight: FontWeight.w700,
                                ),
                          ),
                        ),
                        IconButton(
                          onPressed: () => _shiftMonth(1),
                          icon: const Icon(Icons.chevron_right_rounded),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  child: Container(
                    decoration: BoxDecoration(
                      color: _surfaceColor(context),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: _softBorderColor(context)),
                    ),
                    child: TabBar(
                      controller: _tabController,
                      tabs: const <Tab>[
                        Tab(text: 'Expense'),
                        Tab(text: 'Income'),
                        Tab(text: 'Investment'),
                      ],
                      labelColor: _textColor(context),
                      unselectedLabelColor: _mutedTextColor(context),
                      indicatorColor: _expenseColor,
                      dividerColor: Colors.transparent,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: <Widget>[
                      _buildTabContent(context, allTransactions, 0),
                      _buildTabContent(context, allTransactions, 1),
                      _buildTabContent(context, allTransactions, 2),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _InsightMetricCard extends StatelessWidget {
  const _InsightMetricCard({
    required this.label,
    required this.value,
    required this.accent,
  });

  final String label;
  final double value;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _inrFormat(value),
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: accent,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _InsightSection extends StatelessWidget {
  const _InsightSection({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurface,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}
