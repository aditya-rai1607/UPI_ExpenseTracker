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
}
