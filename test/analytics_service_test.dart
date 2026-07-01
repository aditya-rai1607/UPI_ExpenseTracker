import 'package:flutter_test/flutter_test.dart';
import 'package:upi_expense_tracker/models/transaction_model.dart';
import 'package:upi_expense_tracker/services/analytics_service.dart';

void main() {
  test('calculateMonthlyAnalytics aggregates selected month only', () {
    final transactions = <TransactionModel>[
      TransactionModel(
        amount: 120,
        merchant: 'Swiggy',
        category: 'Food',
        date: DateTime(2026, 6, 2),
        type: TransactionType.debit,
      ),
      TransactionModel(
        amount: 80,
        merchant: 'Uber',
        category: 'Travel',
        date: DateTime(2026, 6, 5),
        type: TransactionType.debit,
      ),
      TransactionModel(
        amount: 1000,
        merchant: 'Salary',
        category: null,
        date: DateTime(2026, 6, 1),
        type: TransactionType.credit,
      ),
      TransactionModel(
        amount: 250,
        merchant: 'Mutual Fund SIP',
        category: 'Mutual Funds',
        date: DateTime(2026, 6, 7),
        type: TransactionType.investment,
      ),
      TransactionModel(
        amount: 50,
        merchant: 'Old Month',
        category: 'Food',
        date: DateTime(2026, 5, 28),
        type: TransactionType.debit,
      ),
    ];

    final analytics = AnalyticsService.calculateMonthlyAnalytics(
      transactions: transactions,
      month: DateTime(2026, 6),
    );

    expect(analytics.totalExpense, 200);
    expect(analytics.totalIncome, 1000);
    expect(analytics.totalInvestment, 250);
    expect(analytics.netCashflow, 800);
    expect(analytics.expenseByCategory['Food'], 120);
    expect(analytics.expenseByCategory['Travel'], 80);
    expect(analytics.topMerchants.first.merchant, 'Swiggy');
    expect(analytics.topMerchants.first.total, 120);
  });

  test('calculateMonthlyTrends returns last five months in order', () {
    final transactions = <TransactionModel>[
      TransactionModel(
        amount: 1000,
        merchant: 'Salary',
        date: DateTime(2026, 2, 1),
        type: TransactionType.credit,
      ),
      TransactionModel(
        amount: 200,
        merchant: 'Groceries',
        category: 'Groceries',
        date: DateTime(2026, 2, 3),
        type: TransactionType.debit,
      ),
      TransactionModel(
        amount: 1200,
        merchant: 'Salary',
        date: DateTime(2026, 6, 1),
        type: TransactionType.credit,
      ),
      TransactionModel(
        amount: 300,
        merchant: 'Rent',
        category: 'Rent',
        date: DateTime(2026, 6, 5),
        type: TransactionType.debit,
      ),
    ];

    final trends = AnalyticsService.calculateMonthlyTrends(
      transactions: transactions,
      endMonth: DateTime(2026, 6),
    );

    expect(trends.length, 5);
    expect(trends.first.month, DateTime(2026, 2));
    expect(trends.first.income, 1000);
    expect(trends.first.expense, 200);
    expect(trends.last.month, DateTime(2026, 6));
    expect(trends.last.income, 1200);
    expect(trends.last.expense, 300);
  });

  test('calculateAmountsByCategory includes all categorized types', () {
    final transactions = <TransactionModel>[
      TransactionModel(
        amount: 100,
        merchant: 'Shop',
        category: 'Shopping',
        date: DateTime(2026, 6, 1),
        type: TransactionType.debit,
      ),
      TransactionModel(
        amount: 500,
        merchant: 'Salary',
        category: 'Salary',
        date: DateTime(2026, 6, 2),
        type: TransactionType.credit,
      ),
      TransactionModel(
        amount: 250,
        merchant: 'Fund',
        category: 'Mutual Funds',
        date: DateTime(2026, 6, 3),
        type: TransactionType.investment,
      ),
    ];

    final totals = AnalyticsService.calculateAmountsByCategory(
      transactions: transactions,
      month: DateTime(2026, 6),
    );

    expect(totals['Shopping'], 100);
    expect(totals['Salary'], 500);
    expect(totals['Mutual Funds'], 250);
  });

  test('investments do not affect income or expense totals', () {
    final transactions = <TransactionModel>[
      TransactionModel(
        amount: 900,
        merchant: 'Salary',
        category: 'Salary',
        date: DateTime(2026, 6, 1),
        type: TransactionType.credit,
      ),
      TransactionModel(
        amount: 300,
        merchant: 'Groceries',
        category: 'Groceries',
        date: DateTime(2026, 6, 2),
        type: TransactionType.debit,
      ),
      TransactionModel(
        amount: 150,
        merchant: 'Gold ETF',
        category: 'Gold',
        date: DateTime(2026, 6, 3),
        type: TransactionType.investment,
      ),
    ];

    final analytics = AnalyticsService.calculateMonthlyAnalytics(
      transactions: transactions,
      month: DateTime(2026, 6),
    );

    expect(analytics.totalIncome, 900);
    expect(analytics.totalExpense, 300);
    expect(analytics.totalInvestment, 150);
    expect(analytics.netCashflow, 600);
  });

  test('calculateOvertimeData produces daily buckets with zeros filled', () {
    final transactions = <TransactionModel>[
      TransactionModel(
        amount: 100,
        merchant: 'A',
        date: DateTime(2026, 6, 1),
        type: TransactionType.debit,
      ),
      TransactionModel(
        amount: 50,
        merchant: 'B',
        date: DateTime(2026, 6, 3),
        type: TransactionType.debit,
      ),
    ];

    final points = AnalyticsService.calculateOvertimeData(
      transactions: transactions,
      start: DateTime(2026, 6, 1),
      end: DateTime(2026, 6, 5),
      frequency: OvertimeFrequency.daily,
    );

    expect(points.length, 5);
    expect(points[0].amount, 100);
    expect(points[1].amount, 0);
    expect(points[2].amount, 50);
    expect(points[3].amount, 0);
    expect(points[4].amount, 0);
  });

  test('calculateOvertimeData produces monthly buckets', () {
    final transactions = <TransactionModel>[
      TransactionModel(
        amount: 100,
        merchant: 'A',
        date: DateTime(2026, 1, 5),
        type: TransactionType.debit,
      ),
      TransactionModel(
        amount: 200,
        merchant: 'B',
        date: DateTime(2026, 3, 10),
        type: TransactionType.debit,
      ),
    ];

    final points = AnalyticsService.calculateOvertimeData(
      transactions: transactions,
      start: DateTime(2026, 1, 1),
      end: DateTime(2026, 3, 31),
      frequency: OvertimeFrequency.monthly,
    );

    expect(points.length, 3);
    expect(points[0].amount, 100);
    expect(points[1].amount, 0);
    expect(points[2].amount, 200);
  });

  test('calculateOvertimeData keeps leading empty daily buckets', () {
    final transactions = <TransactionModel>[
      TransactionModel(
        amount: 75,
        merchant: 'Late bucket',
        date: DateTime(2026, 6, 4),
        type: TransactionType.debit,
      ),
    ];

    final points = AnalyticsService.calculateOvertimeData(
      transactions: transactions,
      start: DateTime(2026, 6, 1),
      end: DateTime(2026, 6, 5),
      frequency: OvertimeFrequency.daily,
    );

    expect(points.length, 5);
    expect(points[0].date, DateTime(2026, 6, 1));
    expect(points[0].amount, 0);
    expect(points[1].amount, 0);
    expect(points[2].amount, 0);
    expect(points[3].amount, 75);
    expect(points[4].amount, 0);
  });

  test('calculateOvertimeData keeps leading empty monthly buckets', () {
    final transactions = <TransactionModel>[
      TransactionModel(
        amount: 220,
        merchant: 'March merchant',
        date: DateTime(2026, 3, 12),
        type: TransactionType.debit,
      ),
    ];

    final points = AnalyticsService.calculateOvertimeData(
      transactions: transactions,
      start: DateTime(2026, 1, 1),
      end: DateTime(2026, 3, 31),
      frequency: OvertimeFrequency.monthly,
    );

    expect(points.length, 3);
    expect(points[0].date, DateTime(2026, 1));
    expect(points[0].amount, 0);
    expect(points[1].date, DateTime(2026, 2));
    expect(points[1].amount, 0);
    expect(points[2].date, DateTime(2026, 3));
    expect(points[2].amount, 220);
  });

  test(
    'calculateOvertimeData returns empty list for no transactions in range',
    () {
      final transactions = <TransactionModel>[];

      final points = AnalyticsService.calculateOvertimeData(
        transactions: transactions,
        start: DateTime(2026, 1, 1),
        end: DateTime(2026, 1, 31),
        frequency: OvertimeFrequency.daily,
      );

      expect(points, isEmpty);
    },
  );
}
