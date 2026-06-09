import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';

import '../models/transaction_model.dart';
import '../services/analytics_service.dart';

class InsightsScreen extends StatefulWidget {
  const InsightsScreen({super.key});

  @override
  State<InsightsScreen> createState() => _InsightsScreenState();
}

class _InsightsScreenState extends State<InsightsScreen> {
  static const Color _successColor = Color(0xFF22C55E);
  static const Color _expenseColor = Color(0xFFEF4444);

  Color _backgroundColor(BuildContext context) =>
      Theme.of(context).scaffoldBackgroundColor;
  Color _surfaceColor(BuildContext context) => Theme.of(context).cardColor;
  Color _textColor(BuildContext context) => Theme.of(context).colorScheme.onSurface;
  Color _mutedTextColor(BuildContext context) =>
      Theme.of(context).colorScheme.onSurfaceVariant;
  Color _softBorderColor(BuildContext context) => Theme.of(context).dividerColor;
  Color _softAccentSurface(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? const Color(0xFF1A2233)
        : const Color(0xFFF8F9FD);
  }

  DateTime _selectedMonth = DateTime(DateTime.now().year, DateTime.now().month);

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
            final analytics = AnalyticsService.calculateMonthlyAnalytics(
              transactions: _readTransactions(box),
              month: _selectedMonth,
            );
            final categoryEntries = AnalyticsService.calculateAmountsByCategory(
              transactions: _readTransactions(box),
              month: _selectedMonth,
            ).entries.toList()
              ..sort((a, b) => b.value.compareTo(a.value));
            final maxCategoryValue = categoryEntries.fold<double>(
              0,
              (max, entry) => entry.value > max ? entry.value : max,
            );

            return ListView(
              padding: const EdgeInsets.fromLTRB(14, 8, 14, 24),
              children: <Widget>[
                Container(
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
                const SizedBox(height: 14),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: _InsightMetricCard(
                        label: 'Expense',
                        value: analytics.totalExpense,
                        accent: _expenseColor,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _InsightMetricCard(
                        label: 'Income',
                        value: analytics.totalIncome,
                        accent: _successColor,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _InsightMetricCard(
                  label: 'Savings',
                  value: analytics.totalInvestment,
                  accent: _successColor,
                ),
                const SizedBox(height: 14),
                _InsightSection(
                  title: 'Category Graph',
                  child: categoryEntries.isEmpty
                      ? Text(
                          'No expenses recorded for this month.',
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(color: _mutedTextColor(context)),
                        )
                      : Column(
                          children: categoryEntries.map((entry) {
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
                                        backgroundColor: _softBorderColor(context),
                                        valueColor: AlwaysStoppedAnimation<Color>(
                                          _expenseColor,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Text(
                                    '₹${entry.value.toStringAsFixed(0)}',
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodyMedium
                                        ?.copyWith(
                                          color: _textColor(context),
                                          fontWeight: FontWeight.w700,
                                        ),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                        ),
                ),
                const SizedBox(height: 14),
                _InsightSection(
                  title: 'Top Merchants',
                  child: analytics.topMerchants.isEmpty
                      ? Text(
                          'No merchant data available for this month.',
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(color: _mutedTextColor(context)),
                        )
                      : SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: analytics.topMerchants.map((merchant) {
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
                                      '₹${merchant.total.toStringAsFixed(0)}',
                                      style: Theme.of(context).textTheme.bodyMedium
                                          ?.copyWith(
                                            color: _textColor(context),
                                            fontWeight: FontWeight.w700,
                                          ),
                                    ),
                                  ],
                                ),
                              );
                            }).toList(growable: false),
                          ),
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
            '₹${value.toStringAsFixed(2)}',
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
