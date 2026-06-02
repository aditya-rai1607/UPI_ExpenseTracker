class TransactionParser {
  static double extractAmount(String text) {
    final regex = RegExp(r'₹?\s?([\d,]+\.?\d*)');
    final match = regex.firstMatch(text);

    if (match != null) {
      final amountStr = match.group(1)!.replaceAll(',', '');
      return double.tryParse(amountStr) ?? 0;
    }

    return 0;
  }

  static String extractMerchant(String text) {
    final regex = RegExp(
      r'(?:to|at|paid to)\s([A-Za-z][A-Za-z\s.&-]+)',
      caseSensitive: false,
    );
    final match = regex.firstMatch(text);

    if (match != null) {
      return match.group(1)!.trim();
    }

    return "Unknown";
  }

  static String suggestCategory(String merchant) {
    merchant = merchant.toLowerCase();

    if (merchant.contains("swiggy") || merchant.contains("zomato")) {
      return "Food";
    }

    if (merchant.contains("uber") || merchant.contains("ola")) {
      return "Travel";
    }

    if (merchant.contains("amazon") ||
        merchant.contains("flipkart") ||
        merchant.contains("myntra")) {
      return "Shopping";
    }

    if (merchant.contains("electricity") ||
        merchant.contains("water") ||
        merchant.contains("gas") ||
        merchant.contains("broadband")) {
      return "Bills";
    }

    if (merchant.contains("pharmacy") ||
        merchant.contains("hospital") ||
        merchant.contains("clinic")) {
      return "Health";
    }

    return "Uncategorized";
  }
}
