import 'package:hive_flutter/hive_flutter.dart';

class CategoryService {
  static const String categoriesBoxName = 'categories';
  static const String merchantRulesBoxName = 'merchant_category_rules';
  static const String uncategorized = 'Uncategorized';
  static const String customCategoryOption = 'Custom...';

  static const List<String> defaultCategories = <String>[
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

  static Future<void> ensureDefaults() async {
    final categoriesBox = Hive.box(categoriesBoxName);
    if (categoriesBox.isEmpty) {
      await categoriesBox.put('items', defaultCategories);
    } else {
      final mergedCategories = <String>[];
      final seen = <String>{};

      for (final category in getCategories()) {
        final trimmed = category.trim();
        if (trimmed.isEmpty || seen.contains(trimmed)) {
          continue;
        }
        seen.add(trimmed);
        mergedCategories.add(trimmed);
      }

      for (final category in defaultCategories) {
        if (seen.contains(category)) {
          continue;
        }
        seen.add(category);
        mergedCategories.add(category);
      }

      await categoriesBox.put('items', mergedCategories);
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

  static List<String> getCategories() {
    final categoriesBox = Hive.box(categoriesBoxName);
    final items = categoriesBox.get('items');
    if (items is List) {
      return items.map((dynamic item) => item.toString()).toList();
    }
    return defaultCategories;
  }

  static List<String> getSelectableCategories() {
    final seen = <String>{};
    final categories = <String>[];

    for (final category in getCategories()) {
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

  static List<String> getDropdownCategories() {
    return <String>[...getSelectableCategories(), customCategoryOption];
  }

  static String? normalizeSelectedCategory(String? category) {
    final trimmed = category?.trim();
    if (trimmed == null || trimmed.isEmpty || trimmed == uncategorized) {
      return null;
    }
    return trimmed;
  }

  static Future<void> addCategory(String category) async {
    final trimmed = category.trim();
    if (trimmed.isEmpty) {
      return;
    }

    final categories = getCategories();
    if (!categories.contains(trimmed)) {
      categories.add(trimmed);
      await Hive.box(categoriesBoxName).put('items', categories);
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
