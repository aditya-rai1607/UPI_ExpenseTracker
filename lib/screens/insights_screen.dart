import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';

import '../models/transaction_model.dart';
import '../services/analytics_service.dart';

String _inrFormat(double amount, {int decimalDigits = 2}) {
  return NumberFormat.currency(
    locale: 'en_IN',
    symbol: '₹',
    decimalDigits: decimalDigits,
  ).format(amount);
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

class InsightsScreen extends StatefulWidget {
  final int initialTabIndex;
  const InsightsScreen({super.key, this.initialTabIndex = 0});

  @override
  State<InsightsScreen> createState() => _InsightsScreenState();
}

enum _DateRangeOption { currentMonth, lastMonth, thisYear, allTime, custom }

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
  _DateRangeOption _selectedRange = _DateRangeOption.currentMonth;
  DateTimeRange? _customRange;
  String? _selectedCategory; // null = All categories
  OvertimeFrequency _selectedFrequency = OvertimeFrequency.daily;

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
    _tabController.addListener(() {
      if (_tabController.indexIsChanging) {
        setState(() {
          _selectedCategory = null;
        });
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _shiftMonth(int delta) {
    setState(() {
      // keep compatibility but do nothing when using range chips
    });
  }

  DateTimeRange _effectiveDateRange() {
    final now = DateTime.now();
    switch (_selectedRange) {
      case _DateRangeOption.currentMonth:
        return DateTimeRange(start: DateTime(now.year, now.month, 1), end: now);
      case _DateRangeOption.lastMonth:
        final prevMonth = DateTime(now.year, now.month - 1);
        final start = DateTime(prevMonth.year, prevMonth.month, 1);
        final end = DateTime(prevMonth.year, prevMonth.month + 1, 0);
        return DateTimeRange(start: start, end: end);
      case _DateRangeOption.thisYear:
        return DateTimeRange(start: DateTime(now.year, 1, 1), end: now);
      case _DateRangeOption.allTime:
        return DateTimeRange(start: DateTime(2000), end: now);
      case _DateRangeOption.custom:
        return _customRange ?? DateTimeRange(start: now, end: now);
    }
  }

  String _chipLabel(_DateRangeOption opt) {
    final now = DateTime.now();
    switch (opt) {
      case _DateRangeOption.currentMonth:
        return DateFormat('MMM').format(now);
      case _DateRangeOption.lastMonth:
        final prev = DateTime(now.year, now.month - 1);
        return DateFormat('MMM').format(prev);
      case _DateRangeOption.thisYear:
        return now.year.toString();
      case _DateRangeOption.allTime:
        return 'All-time';
      case _DateRangeOption.custom:
        if (_customRange == null) return 'Custom';
        final start = DateFormat('d MMM').format(_customRange!.start);
        final end = DateFormat('d MMM').format(_customRange!.end);
        return '$start–$end';
    }
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

    final range = _effectiveDateRange();
    final rangeFiltered = tabTransactions
        .where(
          (t) => !t.date.isBefore(range.start) && !t.date.isAfter(range.end),
        )
        .toList(growable: false);

    final totalValue = rangeFiltered.fold<double>(
      0,
      (sum, transaction) => sum + transaction.amount,
    );

    final categoryEntries = AnalyticsService.calculateAmountsByCategory(
      transactions: rangeFiltered,
      month: null,
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
        // Over time card
        Container(
          decoration: BoxDecoration(
            color: _surfaceColor(context),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: _softBorderColor(context)),
          ),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                'Over time',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 12),
              Builder(
                builder: (ctx) {
                  final chartTransactions = _selectedCategory == null
                      ? rangeFiltered
                      : rangeFiltered
                            .where(
                              (t) =>
                                  (t.category ?? '').trim() ==
                                  _selectedCategory,
                            )
                            .toList(growable: false);
                  final points = AnalyticsService.calculateOvertimeData(
                    transactions: chartTransactions,
                    start: range.start,
                    end: range.end,
                    frequency: _selectedFrequency,
                  );

                  if (points.isEmpty) {
                    return SizedBox(
                      height: 260,
                      child: Center(
                        child: Text(
                          'No data for this period',
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(color: _mutedTextColor(context)),
                        ),
                      ),
                    );
                  }

                  final spots = List<FlSpot>.generate(
                    points.length,
                    (i) => FlSpot(i.toDouble(), points[i].amount),
                  );
                  final maxY = points
                      .map((p) => p.amount)
                      .fold<double>(0.0, (a, b) => b > a ? b : a);
                  return TickerMode(
                    enabled: false,
                    child: SizedBox(
                      height: 260,
                      child: LineChart(
                        key: ValueKey(
                          '${_selectedCategory}_${_selectedFrequency}_${range.start}_${range.end}_${spots.length}',
                        ),
                        LineChartData(
                          gridData: FlGridData(
                            show: true,
                            drawVerticalLine: false,
                            horizontalInterval: maxY / 4 == 0 ? 1 : maxY / 4,
                          ),
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
                                reservedSize: 56,
                                getTitlesWidget: (value, meta) {
                                  if (value == meta.min || value == meta.max) {
                                    return const SizedBox.shrink();
                                  }
                                  return Text(
                                    _inrFormat(value, decimalDigits: 0),
                                    style: Theme.of(context).textTheme.bodySmall
                                        ?.copyWith(
                                          color: _mutedTextColor(context),
                                          fontSize: 9,
                                        ),
                                  );
                                },
                              ),
                            ),
                            bottomTitles: AxisTitles(
                              sideTitles: SideTitles(
                                showTitles: true,
                                reservedSize: 36,
                                getTitlesWidget: (value, meta) {
                                  final idx = value.toInt();
                                  if (idx < 0 || idx >= points.length) {
                                    return const SizedBox.shrink();
                                  }
                                  final d = points[idx].date;
                                  if (_selectedFrequency ==
                                      OvertimeFrequency.monthly) {
                                    return Padding(
                                      padding: const EdgeInsets.only(top: 6),
                                      child: Text(
                                        DateFormat('MMM').format(d),
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodySmall
                                            ?.copyWith(
                                              color: _mutedTextColor(context),
                                              fontSize: 9,
                                            ),
                                      ),
                                    );
                                  }
                                  final prevDate = idx > 0
                                      ? points[idx - 1].date
                                      : null;
                                  final showMonth =
                                      prevDate == null ||
                                      prevDate.month != d.month;
                                  return Padding(
                                    padding: const EdgeInsets.only(top: 4),
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          d.day.toString(),
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodySmall
                                              ?.copyWith(
                                                color: _mutedTextColor(context),
                                                fontSize: 9,
                                              ),
                                        ),
                                        if (showMonth)
                                          Text(
                                            DateFormat('MMM').format(d),
                                            style: Theme.of(context)
                                                .textTheme
                                                .bodySmall
                                                ?.copyWith(
                                                  color: _mutedTextColor(
                                                    context,
                                                  ),
                                                  fontSize: 8,
                                                ),
                                          )
                                        else
                                          const SizedBox(height: 10),
                                      ],
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),
                          borderData: FlBorderData(show: false),
                          lineBarsData: [
                            LineChartBarData(
                              spots: spots,
                              isCurved: true,
                              color: accentColor,
                              barWidth: 3,
                              dotData: FlDotData(show: spots.length <= 60),
                              belowBarData: BarAreaData(
                                show: true,
                                color: accentColor.withOpacity(0.12),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Text(
                    'Showing',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Builder(
                      builder: (ctx) {
                        final categories = categoryEntries
                            .map((e) => e.key)
                            .toList(growable: false);
                        return DropdownButton<String?>(
                          value: _selectedCategory,
                          isExpanded: true,
                          items: <DropdownMenuItem<String?>>[
                            const DropdownMenuItem(
                              value: null,
                              child: Text('All categories'),
                            ),
                            ...categories.map(
                              (c) => DropdownMenuItem(value: c, child: Text(c)),
                            ),
                          ],
                          onChanged: (v) =>
                              setState(() => _selectedCategory = v),
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  ToggleButtons(
                    isSelected: [
                      _selectedFrequency == OvertimeFrequency.daily,
                      _selectedFrequency == OvertimeFrequency.weekly,
                      _selectedFrequency == OvertimeFrequency.monthly,
                    ],
                    onPressed: (i) {
                      setState(() {
                        _selectedFrequency = OvertimeFrequency.values[i];
                      });
                    },
                    borderRadius: BorderRadius.circular(8),
                    children: const [
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 8),
                        child: Text('Daily'),
                      ),
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 8),
                        child: Text('Weekly'),
                      ),
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 8),
                        child: Text('Monthly'),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
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
                          child: InkWell(
                            onTap: () =>
                                setState(() => _selectedCategory = entry.key),
                            borderRadius: BorderRadius.circular(8),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: <Widget>[
                                SizedBox(
                                  width: 96,
                                  child: Text(
                                    entry.key,
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodyMedium
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
                                      backgroundColor: _softBorderColor(
                                        context,
                                      ),
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
                                const SizedBox(width: 8),
                                Icon(
                                  Icons.chevron_right_rounded,
                                  color: _mutedTextColor(context),
                                ),
                              ],
                            ),
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
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: _surfaceColor(context),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: _softBorderColor(context)),
                    ),
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: <Widget>[
                          for (final opt in _DateRangeOption.values)
                            Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: ChoiceChip(
                                label: Text(_chipLabel(opt)),
                                selected: _selectedRange == opt,
                                onSelected: (sel) async {
                                  if (!sel) return;
                                  if (opt == _DateRangeOption.custom) {
                                    final picked = await showDateRangePicker(
                                      context: context,
                                      firstDate: DateTime(2000),
                                      lastDate: DateTime.now(),
                                      initialDateRange: _customRange,
                                    );
                                    if (picked != null) {
                                      setState(() {
                                        _customRange = picked;
                                        _selectedRange = opt;
                                        _selectedCategory = null;
                                      });
                                    }
                                  } else {
                                    setState(() {
                                      _selectedRange = opt;
                                      _selectedCategory = null;
                                    });
                                  }
                                },
                                selectedColor: _expenseColor.withOpacity(0.12),
                                backgroundColor: _softAccentSurface(context),
                                labelStyle: Theme.of(context)
                                    .textTheme
                                    .bodyMedium
                                    ?.copyWith(
                                      color: _selectedRange == opt
                                          ? _textColor(context)
                                          : _mutedTextColor(context),
                                      fontWeight: FontWeight.w700,
                                    ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(999),
                                ),
                              ),
                            ),
                        ],
                      ),
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
