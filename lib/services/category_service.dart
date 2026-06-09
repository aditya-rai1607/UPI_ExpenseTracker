import 'package:hive_flutter/hive_flutter.dart';

import '../models/transaction_model.dart';

class CategoryService {
  static const String categoriesBoxName = 'categories';
  static const String merchantRulesBoxName = 'merchant_category_rules';
  static const String expenseCategoriesKey = 'expense_items';
  static const String incomeCategoriesKey = 'income_items';
  static const String investmentCategoriesKey = 'investment_items';
  static const String legacyCategoriesKey = 'items';
  static const String uncategorized = 'Uncategorized';

  static const List<String> defaultExpenseCategories = <String>[
    'Cabs',
    'Cooking Gas',
    'Drinks',
    'Drinks Snacks',
    'Electricity',
    'Flights',
    'Food',
    'Fuel',
    'Get Back',
    'Groceries',
    'Hotels',
    'Insurance',
    'Lend',
    'Medical Bills',
    'Miscellaneous',
    'Movies',
    'Parking/Tolls',
    'Phone Bills',
    'Rent',
    'Repair',
    'Shopping',
    'Sports',
    'Subscriptions',
    'Tea/Coffee',
    'Train',
    uncategorized,
  ];

  static const List<String> defaultIncomeCategories = <String>[
    'Salary',
    'Settled',
    'Stocks',
  ];

  static const List<String> defaultInvestmentCategories = <String>[
    'Mutual Funds',
    'Stocks',
    'Gold',
    'Others',
  ];

  static Future<void> ensureDefaults() async {
    final categoriesBox = Hive.box(categoriesBoxName);
    await _ensureCategoryList(
      box: categoriesBox,
      key: expenseCategoriesKey,
      defaults: defaultExpenseCategories,
      legacyFallbackKey: legacyCategoriesKey,
    );
    await _ensureCategoryList(
      box: categoriesBox,
      key: incomeCategoriesKey,
      defaults: defaultIncomeCategories,
    );
    await _ensureCategoryList(
      box: categoriesBox,
      key: investmentCategoriesKey,
      defaults: defaultInvestmentCategories,
    );

    if (categoriesBox.containsKey(legacyCategoriesKey)) {
      await categoriesBox.delete(legacyCategoriesKey);
    }

    final merchantRulesBox = Hive.box(merchantRulesBoxName);
    if (merchantRulesBox.isEmpty) {
      await merchantRulesBox.putAll(<String, String>{
        'swiggy': 'Food',
        'zomato': 'Food',
        'uber': 'Travel',
        'ola': 'Travel',
        'amazon': 'Shopping',
      });
    }
  }

  static Future<void> _ensureCategoryList({
    required Box<dynamic> box,
    required String key,
    required List<String> defaults,
    String? legacyFallbackKey,
  }) async {
    final sourceItems = box.get(key) ?? (legacyFallbackKey == null ? null : box.get(legacyFallbackKey));
    if (sourceItems is! List) {
      await box.put(key, defaults);
      return;
    }

    final mergedCategories = <String>[];
    final seen = <String>{};

    for (final dynamic item in sourceItems) {
      final trimmed = item.toString().trim();
      if (trimmed.isEmpty || seen.contains(trimmed)) {
        continue;
      }
      seen.add(trimmed);
      mergedCategories.add(trimmed);
    }

    for (final category in defaults) {
      if (seen.contains(category)) {
        continue;
      }
      seen.add(category);
      mergedCategories.add(category);
    }

    await box.put(key, mergedCategories);
  }

  static List<String> _getCategoriesByKey(String key, List<String> defaults) {
    final categoriesBox = Hive.box(categoriesBoxName);
    final items = categoriesBox.get(key);
    if (items is List) {
      return items.map((dynamic item) => item.toString()).toList();
    }
    return defaults;
  }

  static List<String> getExpenseCategories() {
    return _getCategoriesByKey(expenseCategoriesKey, defaultExpenseCategories);
  }

  static List<String> getIncomeCategories() {
    return _getCategoriesByKey(incomeCategoriesKey, defaultIncomeCategories);
  }

  static List<String> getInvestmentCategories() {
    return _getCategoriesByKey(
      investmentCategoriesKey,
      defaultInvestmentCategories,
    );
  }

  static List<String> getCategoriesForType(TransactionType type) {
    return switch (type) {
      TransactionType.credit => getIncomeCategories(),
      TransactionType.investment => getInvestmentCategories(),
      TransactionType.debit => getExpenseCategories(),
    };
  }

  static List<String> getSelectableCategoriesForType(TransactionType type) {
    final seen = <String>{};
    final categories = <String>[];

    for (final category in getCategoriesForType(type)) {
      final trimmed = category.trim();
      if (trimmed.isEmpty ||
          trimmed == uncategorized ||
          seen.contains(trimmed)) {
        continue;
      }
      seen.add(trimmed);
      categories.add(trimmed);
    }

    return categories;
  }

  static List<String> getDropdownCategoriesForType(TransactionType type) {
    return getSelectableCategoriesForType(type);
  }

  static String? normalizeSelectedCategory(String? category) {
    final trimmed = category?.trim();
    if (trimmed == null || trimmed.isEmpty || trimmed == uncategorized) {
      return null;
    }
    return trimmed;
  }

  static Future<void> addCategoryForType(
    TransactionType type,
    String category,
  ) async {
    final trimmed = category.trim();
    if (trimmed.isEmpty) {
      return;
    }

    final key = _keyForType(type);
    final categories = getCategoriesForType(type);
    if (!categories.contains(trimmed)) {
      categories.add(trimmed);
      await Hive.box(categoriesBoxName).put(key, categories);
    }
  }

  static Future<void> updateCategoryForType(
    TransactionType type,
    String oldCategory,
    String newCategory,
  ) async {
    final trimmedOld = oldCategory.trim();
    final trimmedNew = newCategory.trim();
    if (trimmedOld.isEmpty || trimmedNew.isEmpty || trimmedOld == trimmedNew) {
      return;
    }

    final categories = getCategoriesForType(type);
    final oldIndex = categories.indexOf(trimmedOld);
    if (oldIndex == -1) {
      return;
    }

    if (categories.contains(trimmedNew)) {
      categories.removeAt(oldIndex);
    } else {
      categories[oldIndex] = trimmedNew;
    }

    await Hive.box(categoriesBoxName).put(_keyForType(type), categories);
    await _replaceTransactionCategory(
      type: type,
      fromCategory: trimmedOld,
      toCategory: trimmedNew,
    );
  }

  static Future<void> deleteCategoryForType(
    TransactionType type,
    String category,
  ) async {
    final trimmed = category.trim();
    if (trimmed.isEmpty || trimmed == uncategorized) {
      return;
    }

    final categories = getCategoriesForType(type)
        .where((item) => item.trim() != trimmed)
        .toList();
    await Hive.box(categoriesBoxName).put(_keyForType(type), categories);
    await _replaceTransactionCategory(
      type: type,
      fromCategory: trimmed,
      toCategory: type == TransactionType.debit ? uncategorized : null,
    );
  }

  static String _keyForType(TransactionType type) {
    return switch (type) {
      TransactionType.credit => incomeCategoriesKey,
      TransactionType.investment => investmentCategoriesKey,
      TransactionType.debit => expenseCategoriesKey,
    };
  }

  static Future<void> _replaceTransactionCategory({
    required TransactionType type,
    required String fromCategory,
    required String? toCategory,
  }) async {
    final transactionsBox = Hive.box('transactions');
    for (var index = 0; index < transactionsBox.length; index++) {
      final raw = transactionsBox.getAt(index);
      if (raw is! Map) {
        continue;
      }

      final transaction = TransactionModel.fromMap(raw.cast<dynamic, dynamic>());
      if (transaction.type != type || transaction.category?.trim() != fromCategory) {
        continue;
      }

      await transactionsBox.put(
        transactionsBox.keyAt(index),
        transaction.copyWith(category: toCategory).toMap(),
      );
    }
  }

  static String? getMerchantCategorySuggestion(String merchant) {
    final normalized = merchant.toLowerCase().trim();
    if (normalized.isEmpty) {
      return null;
    }

    final rulesBox = Hive.box(merchantRulesBoxName);
    for (final dynamic key in rulesBox.keys) {
      final keyword = key.toString().toLowerCase();
      if (normalized.contains(keyword)) {
        return rulesBox.get(key)?.toString();
      }
    }

    return null;
  }

  static Future<void> learnMerchantCategory({
    required String merchant,
    required String category,
  }) async {
    final trimmedMerchant = merchant.trim().toLowerCase();
    final trimmedCategory = category.trim();
    if (trimmedMerchant.isEmpty || trimmedCategory.isEmpty) {
      return;
    }

    await Hive.box(merchantRulesBoxName).put(trimmedMerchant, trimmedCategory);
  }
}
