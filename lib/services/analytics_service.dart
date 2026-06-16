import '../models/transaction_model.dart';

class MerchantSpend {
  MerchantSpend({required this.merchant, required this.total});

  final String merchant;
  final double total;
}

class MonthlyTrendSnapshot {
  MonthlyTrendSnapshot({
    required this.month,
    required this.income,
    required this.expense,
  });

  final DateTime month;
  final double income;
  final double expense;
}

enum OvertimeFrequency { daily, weekly, monthly }

class OvertimeDataPoint {
  OvertimeDataPoint({required this.date, required this.amount});

  final DateTime date;
  final double amount;
}

class MonthlyAnalytics {
  MonthlyAnalytics({
    required this.month,
    required this.totalExpense,
    required this.totalIncome,
    required this.totalInvestment,
    required this.netCashflow,
    required this.expenseByCategory,
    required this.topMerchants,
  });

  final DateTime month;
  final double totalExpense;
  final double totalIncome;
  final double totalInvestment;
  final double netCashflow;
  final Map<String, double> expenseByCategory;
  final List<MerchantSpend> topMerchants;
}

class AnalyticsService {
  static MonthlyAnalytics calculateMonthlyAnalytics({
    required List<TransactionModel> transactions,
    required DateTime month,
  }) {
    final monthlyTransactions = transactions.where(
      (transaction) =>
          transaction.date.year == month.year &&
          transaction.date.month == month.month,
    );

    var totalExpense = 0.0;
    var totalIncome = 0.0;
    var totalInvestment = 0.0;
    final expenseByCategory = <String, double>{};
    final merchantTotals = <String, double>{};

    for (final transaction in monthlyTransactions) {
      if (transaction.type == TransactionType.debit) {
        totalExpense += transaction.amount;
        final category =
            (transaction.category == null ||
                transaction.category!.trim().isEmpty)
            ? 'Uncategorized'
            : transaction.category!;
        expenseByCategory.update(
          category,
          (value) => value + transaction.amount,
          ifAbsent: () => transaction.amount,
        );
        merchantTotals.update(
          transaction.merchant,
          (value) => value + transaction.amount,
          ifAbsent: () => transaction.amount,
        );
      } else if (transaction.type == TransactionType.credit) {
        totalIncome += transaction.amount;
      } else {
        totalInvestment += transaction.amount;
      }
    }

    final topMerchants =
        merchantTotals.entries
            .map(
              (entry) => MerchantSpend(merchant: entry.key, total: entry.value),
            )
            .toList()
          ..sort((a, b) => b.total.compareTo(a.total));

    return MonthlyAnalytics(
      month: DateTime(month.year, month.month),
      totalExpense: totalExpense,
      totalIncome: totalIncome,
      totalInvestment: totalInvestment,
      netCashflow: totalIncome - totalExpense,
      expenseByCategory: expenseByCategory,
      topMerchants: topMerchants.take(5).toList(),
    );
  }

  static List<MonthlyTrendSnapshot> calculateMonthlyTrends({
    required List<TransactionModel> transactions,
    required DateTime endMonth,
    int monthCount = 5,
  }) {
    final results = <MonthlyTrendSnapshot>[];
    for (var offset = monthCount - 1; offset >= 0; offset--) {
      final month = DateTime(endMonth.year, endMonth.month - offset);
      final analytics = calculateMonthlyAnalytics(
        transactions: transactions,
        month: month,
      );
      results.add(
        MonthlyTrendSnapshot(
          month: month,
          income: analytics.totalIncome,
          expense: analytics.totalExpense,
        ),
      );
    }
    return results;
  }

  static Map<String, double> calculateAmountsByCategory({
    required List<TransactionModel> transactions,
    DateTime? month,
  }) {
    final amounts = <String, double>{};
    final filteredTransactions = month == null
        ? transactions
        : transactions.where(
            (transaction) =>
                transaction.date.year == month.year &&
                transaction.date.month == month.month,
          );

    for (final transaction in filteredTransactions) {
      final category = (transaction.category ?? '').trim();
      if (category.isEmpty) {
        continue;
      }
      amounts.update(
        category,
        (value) => value + transaction.amount,
        ifAbsent: () => transaction.amount,
      );
    }

    return amounts;
  }

  static List<OvertimeDataPoint> calculateOvertimeData({
    required List<TransactionModel> transactions,
    required DateTime start,
    required DateTime end,
    required OvertimeFrequency frequency,
  }) {
    final filtered = transactions
        .where((t) {
          final d = t.date;
          return !d.isBefore(start) && !d.isAfter(end);
        })
        .toList(growable: false);

    if (filtered.isEmpty) return <OvertimeDataPoint>[];

    DateTime bucketKey(DateTime d) {
      switch (frequency) {
        case OvertimeFrequency.daily:
          return DateTime(d.year, d.month, d.day);
        case OvertimeFrequency.weekly:
          // Use Monday as week start
          final monday = d.subtract(Duration(days: d.weekday - 1));
          return DateTime(monday.year, monday.month, monday.day);
        case OvertimeFrequency.monthly:
          return DateTime(d.year, d.month);
      }
    }

    final totals = <DateTime, double>{};
    for (final t in filtered) {
      final key = bucketKey(t.date);
      totals.update(key, (v) => v + t.amount, ifAbsent: () => t.amount);
    }

    // Determine the first bucket to emit: use the earliest bucket present in totals
    final firstBucket = totals.keys.reduce((a, b) => a.isBefore(b) ? a : b);

    DateTime iterateNext(DateTime current) {
      switch (frequency) {
        case OvertimeFrequency.daily:
          return current.add(const Duration(days: 1));
        case OvertimeFrequency.weekly:
          return current.add(const Duration(days: 7));
        case OvertimeFrequency.monthly:
          final nextMonth = current.month == 12 ? 1 : current.month + 1;
          final year = current.month == 12 ? current.year + 1 : current.year;
          return DateTime(year, nextMonth);
      }
    }

    final endBucket = bucketKey(end);
    final points = <OvertimeDataPoint>[];
    var cursor = firstBucket;
    while (!cursor.isAfter(endBucket)) {
      final value = totals[cursor] ?? 0.0;
      points.add(OvertimeDataPoint(date: cursor, amount: value));
      cursor = iterateNext(cursor);
    }

    points.sort((a, b) => a.date.compareTo(b.date));
    return points;
  }
}
