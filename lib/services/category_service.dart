import 'package:hive_flutter/hive_flutter.dart';

class CategoryService {
  static const String categoriesBoxName = 'categories';
  static const String merchantRulesBoxName = 'merchant_category_rules';

  static const List<String> defaultCategories = <String>[
    'Food',
    'Travel',
    'Shopping',
    'Bills',
    'Transfer',
    'Health',
    'Others',
    'Uncategorized',
  ];

  static Future<void> ensureDefaults() async {
    final categoriesBox = Hive.box(categoriesBoxName);
    if (categoriesBox.isEmpty) {
      await categoriesBox.put('items', defaultCategories);
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
