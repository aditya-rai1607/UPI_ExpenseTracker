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
    expect(analytics.netCashflow, 800);
    expect(analytics.expenseByCategory['Food'], 120);
    expect(analytics.expenseByCategory['Travel'], 80);
    expect(analytics.topMerchants.first.merchant, 'Swiggy');
    expect(analytics.topMerchants.first.total, 120);
  });
}
