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
  static const Color _backgroundColor = Color(0xFFF6F7FB);
  static const Color _surfaceColor = Colors.white;
  static const Color _successColor = Color(0xFF22C55E);
  static const Color _expenseColor = Color(0xFFEF4444);
  static const Color _textColor = Color(0xFF14161F);
  static const Color _mutedTextColor = Color(0xFF8B90A0);
  static const Color _softBorderColor = Color(0xFFE9EBF2);

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
      backgroundColor: _backgroundColor,
      appBar: AppBar(
        backgroundColor: _backgroundColor,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleSpacing: 0,
        title: Text(
          'Insights',
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
            final analytics = AnalyticsService.calculateMonthlyAnalytics(
              transactions: _readTransactions(box),
              month: _selectedMonth,
            );
            final categoryEntries = analytics.expenseByCategory.entries.toList()
              ..sort((a, b) => b.value.compareTo(a.value));

            return ListView(
              padding: const EdgeInsets.fromLTRB(14, 8, 14, 24),
              children: <Widget>[
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: _surfaceColor,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: _softBorderColor),
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
                                color: _textColor,
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
                  label: 'Net Cashflow',
                  value: analytics.netCashflow,
                  accent: analytics.netCashflow >= 0
                      ? _successColor
                      : _expenseColor,
                ),
                const SizedBox(height: 14),
                _InsightSection(
                  title: 'Category Breakdown',
                  child: categoryEntries.isEmpty
                      ? Text(
                          'No expenses recorded for this month.',
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(color: _mutedTextColor),
                        )
                      : Column(
                          children: categoryEntries.map((entry) {
                            final percentage = analytics.totalExpense == 0
                                ? 0
                                : (entry.value / analytics.totalExpense) * 100;
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: Row(
                                children: <Widget>[
                                  Expanded(
                                    child: Text(
                                      entry.key,
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodyMedium
                                          ?.copyWith(
                                            color: _textColor,
                                            fontWeight: FontWeight.w600,
                                          ),
                                    ),
                                  ),
                                  Text(
                                    '${percentage.toStringAsFixed(0)}%',
                                    style: Theme.of(context).textTheme.bodySmall
                                        ?.copyWith(
                                          color: _mutedTextColor,
                                          fontWeight: FontWeight.w700,
                                        ),
                                  ),
                                  const SizedBox(width: 10),
                                  Text(
                                    '₹${entry.value.toStringAsFixed(0)}',
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodyMedium
                                        ?.copyWith(
                                          color: _textColor,
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
                              ?.copyWith(color: _mutedTextColor),
                        )
                      : Column(
                          children: analytics.topMerchants.map((merchant) {
                            return ListTile(
                              contentPadding: EdgeInsets.zero,
                              title: Text(
                                merchant.merchant,
                                style: Theme.of(context).textTheme.bodyMedium
                                    ?.copyWith(
                                      color: _textColor,
                                      fontWeight: FontWeight.w600,
                                    ),
                              ),
                              trailing: Text(
                                '₹${merchant.total.toStringAsFixed(0)}',
                                style: Theme.of(context).textTheme.bodyMedium
                                    ?.copyWith(
                                      color: _textColor,
                                      fontWeight: FontWeight.w700,
                                    ),
                              ),
                            );
                          }).toList(),
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
        color: const Color(0xFFFFFFFF),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE9EBF2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: const Color(0xFF8B90A0),
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
        color: const Color(0xFFFFFFFF),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE9EBF2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: const Color(0xFF14161F),
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
