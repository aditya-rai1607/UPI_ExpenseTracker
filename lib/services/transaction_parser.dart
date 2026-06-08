class TransactionParser {
  static final RegExp _upiHandlePattern = RegExp(
    r'[A-Za-z0-9._-]+@[A-Za-z0-9._-]+',
    caseSensitive: false,
  );

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
    if (text == null) return '';
    final raw = text.trim();
    if (raw.isEmpty) return '';

    // Common separators in bank remarks
    final parts = raw
        .split(RegExp(r"[\/|\\-]+"))
        .map((p) => p.trim())
        .where((p) => p.isNotEmpty)
        .toList(growable: false);

    // Pattern: UPI/<MERCHANT>/<UPI_ID>/... -> prefer MERCHANT/UPI_ID
    for (var i = 0; i < parts.length; i++) {
      final p = parts[i];
      if (p.toUpperCase() == 'UPI' && i + 1 < parts.length) {
        final merchant = parts[i + 1];
        if (i + 2 < parts.length) {
          final handleMatch = _upiHandlePattern.firstMatch(parts[i + 2]);
          if (handleMatch != null) {
            return '${merchant}/${handleMatch.group(0)!}'.trim();
          }
        }
        return merchant;
      }
    }

    // If a token contains an @ (likely a UPI handle), prefer it and include previous token if available
    for (var i = 0; i < parts.length; i++) {
      final handleMatch = _upiHandlePattern.firstMatch(parts[i]);
      if (handleMatch != null) {
        final handle = handleMatch.group(0)!;
        final prev = (i - 1) >= 0 ? parts[i - 1] : null;
        if (prev != null && prev.toLowerCase() != 'upi') {
          return '${prev}/${handle}'.trim();
        }
        return handle;
      }
    }

    // Heuristic: pick the first token that looks like a merchant name (not keywords like bank, paid, crd)
    final blacklist = RegExp(r'bank|paid|via|crd|deb|ref|utr', caseSensitive: false);
    for (final token in parts) {
      if (!blacklist.hasMatch(token) && token.length >= 3) {
        return token;
      }
    }

    // Fallback: try the older "to/at/paid to" pattern
    final regex = RegExp(r'(?:to|at|paid to)\s([A-Za-z][A-Za-z\s.&-]+)', caseSensitive: false);
    final match = regex.firstMatch(raw);
    if (match != null) {
      return match.group(1)!.trim();
    }

    return '';
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
