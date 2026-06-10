class TransactionParser {
  static final RegExp _upiHandlePattern = RegExp(
    r'[A-Za-z0-9._-]+@[A-Za-z0-9._-]+',
    caseSensitive: false,
  );

  static double extractAmount(String text) {
    final regex = RegExp(
      r'(?:Rs\.?|INR|₹)\s*([\d,]+\.?\d*)',
      caseSensitive: false,
    );
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

    final fromParty = _extractCreditedFromParty(raw);
    if (fromParty.isNotEmpty) return fromParty;

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
    final blacklist = RegExp(
      r'bank|paid|via|crd|deb|ref|utr',
      caseSensitive: false,
    );
    for (final token in parts) {
      if (!blacklist.hasMatch(token) && token.length >= 3) {
        return token;
      }
    }

    // Fallback: try the older "to/at/paid to" pattern
    final regex = RegExp(
      r'(?:to|at|paid to)\s([A-Za-z][A-Za-z\s.&-]+)',
      caseSensitive: false,
    );
    final match = regex.firstMatch(raw);
    if (match != null) {
      return match.group(1)!.trim();
    }

    return '';
  }

  static String _extractCreditedFromParty(String raw) {
    final lower = raw.toLowerCase();
    if (!lower.contains('credited')) return '';

    final fromMatch = RegExp(
      r'\bfrom\s+([^\n\r.,;]+)',
      caseSensitive: false,
    ).firstMatch(raw);
    if (fromMatch == null) return '';

    var candidate = fromMatch.group(1)?.trim() ?? '';
    if (candidate.isEmpty) return '';

    candidate = candidate
        .replaceAll(RegExp(r'\bUPI\b.*$', caseSensitive: false), '')
        .replaceAll(RegExp(r'\bIMPS\b.*$', caseSensitive: false), '')
        .replaceAll(RegExp(r'\bNEFT\b.*$', caseSensitive: false), '')
        .replaceAll(RegExp(r'\bRTGS\b.*$', caseSensitive: false), '')
        .replaceAll(RegExp(r'\bRef\b.*$', caseSensitive: false), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

    if (candidate.isEmpty) return '';

    final looksLikeAccountToken = RegExp(
      r'^(?:a\/c|acct|account|ac|xx+|x+|\d|no\b)',
      caseSensitive: false,
    ).hasMatch(candidate);
    final onlySymbolsOrDigits = RegExp(r'^[\d\W_]+$').hasMatch(candidate);

    if (looksLikeAccountToken || onlySymbolsOrDigits) return '';

    return candidate;
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
