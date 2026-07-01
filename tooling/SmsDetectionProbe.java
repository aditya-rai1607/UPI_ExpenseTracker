import java.io.BufferedReader;
import java.io.IOException;
import java.io.InputStreamReader;
import java.nio.charset.StandardCharsets;
import java.text.DecimalFormat;
import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.List;
import java.util.Locale;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

/**
 * Standalone Java probe that mirrors the current Dart SMS detection/parsing logic.
 *
 * Usage:
 *   javac tooling/SmsDetectionProbe.java
 *   java -cp tooling SmsDetectionProbe
 *
 * Interactive mode lets you paste multiple SMS bodies to see whether they are
 * detected as bank SMS and, if detected, what amount, description, merchant,
 * category, and type would be extracted.
 */
public final class SmsDetectionProbe {
  private static final Pattern UPI_HANDLE_PATTERN = Pattern.compile(
      "[A-Za-z0-9._-]+@[A-Za-z0-9._-]+",
      Pattern.CASE_INSENSITIVE);

  private static final Pattern AMOUNT_PATTERN = Pattern.compile(
      "(?:Rs\\.?|INR|₹)\\s*([\\d,]+\\.?\\d*)",
      Pattern.CASE_INSENSITIVE);

  private static final Pattern BANK_BODY_PATTERN = Pattern.compile(
      "debited|credited|deducted|withdrawn|spent|received|refund|deposited|"
          + "UPI|NEFT|IMPS|RTGS|A/c|Acct|account",
      Pattern.CASE_INSENSITIVE);

  private static final Pattern AMOUNT_KEYWORD_PATTERN = Pattern.compile(
      "(?:INR|Rs\\.?|₹)\\s?[\\d,]+",
      Pattern.CASE_INSENSITIVE);

  private static final Pattern BANK_SENDER_PATTERN = Pattern.compile(
      "HDFCBK|HDFCBANK|SBIINB|SBISMS|ICICIB|ICICIBANK|AXISBK|AXISBANK|"
          + "KOTAKB|KOTAK|PNBSMS|BOIIND|CANBNK|SCBAND|INDBNK|UNIONB|CENTBK|"
          + "YESBNK|IDBIBK|FEDBK|RBLBNK|INDUSB|PAYTM|PHONEPE|GPAY|AMAZONPAY|"
          + "CITIBNK|BOBBK|DENABNK|VJYBNK",
      Pattern.CASE_INSENSITIVE);

  private static final Pattern DEBIT_PATTERN = Pattern.compile(
      "debited\\s+for|"
          + "is\\s+debited|"
          + "withdrawn|"
          + "deducted|"
          + "spent|"
          + "purchase|"
          + "upi\\s+payment|"
          + "\\bdr\\b|"
          + "\\bdebit\\b",
      Pattern.CASE_INSENSITIVE);

  private static final Pattern CREDIT_PATTERN = Pattern.compile(
      "is\\s+credited|"
          + "received|"
          + "deposited|"
          + "refund|"
          + "cashback|"
          + "reversal|"
          + "reversed|"
          + "\\bcr\\b|"
          + "\\bcredit\\b",
      Pattern.CASE_INSENSITIVE);

  private static final Pattern BLACKLIST_PATTERN = Pattern.compile(
      "bank|paid|via|crd|deb|ref|utr",
      Pattern.CASE_INSENSITIVE);

  private static final Pattern TO_AT_PATTERN = Pattern.compile(
      "(?:to|at|paid to)\\s([A-Za-z][A-Za-z\\s.&-]+)",
      Pattern.CASE_INSENSITIVE);

  private static final Pattern FROM_PATTERN = Pattern.compile(
      "\\bfrom\\s+([^\\n\\r.,;]+)",
      Pattern.CASE_INSENSITIVE);

  private static final Pattern ACCOUNT_TOKEN_PATTERN = Pattern.compile(
      "^(?:a/c|acct|account|ac|xx+|x+|\\d|no\\b)",
      Pattern.CASE_INSENSITIVE);

  private static final Pattern ONLY_SYMBOLS_OR_DIGITS_PATTERN = Pattern.compile("^[\\d\\W_]+$");
  private static final DecimalFormat AMOUNT_FORMAT = new DecimalFormat("0.00");

  private SmsDetectionProbe() {}

  public static void main(String[] args) throws IOException {
    if (args.length >= 2) {
      final String sender = args[0];
      final String body = joinRemaining(args, 1);
      printResult(sender, body);
      return;
    }

    runInteractive();
  }

  private static void runInteractive() throws IOException {
    final BufferedReader reader = new BufferedReader(
        new InputStreamReader(System.in, StandardCharsets.UTF_8));

    System.out.println("SMS Detection Probe");
    System.out.println("Enter sender and body. Submit a blank sender to exit.");
    System.out.println();

    while (true) {
      System.out.print("Sender: ");
      final String sender = reader.readLine();
      if (sender == null || sender.trim().isEmpty()) {
        System.out.println("Exiting.");
        return;
      }

      System.out.print("Body: ");
      final String body = reader.readLine();
      if (body == null || body.trim().isEmpty()) {
        System.out.println("Body is empty; skipping.");
        System.out.println();
        continue;
      }

      printResult(sender.trim(), body);
      System.out.println();
    }
  }

  private static void printResult(String sender, String body) {
    final boolean bankSms = isBankSms(body, sender);
    final ParsedSms parsed = parseTransaction(body);

    System.out.println("----------------------------------------");
    System.out.println("Sender     : " + sender);
    System.out.println("Detected   : " + bankSms);

    if (!bankSms) {
      System.out.println("Amount     : 0.00");
      System.out.println("Merchant   : Unknown");
      System.out.println("Description: Not parsed because SMS was not detected as bank SMS");
      return;
    }

    if (parsed == null) {
      System.out.println("Amount     : 0.00");
      System.out.println("Merchant   : Unknown");
      System.out.println("Description: Detected as bank SMS but amount could not be extracted");
      return;
    }

    System.out.println("Type       : " + parsed.type);
    System.out.println("Amount     : " + AMOUNT_FORMAT.format(parsed.amount));
    System.out.println("Merchant   : " + parsed.merchant);
    System.out.println("Category   : " + (parsed.category == null ? "null" : parsed.category));
    System.out.println("Description: " + parsed.description);
    System.out.println("Parsed At  : " + parsed.parsedAt);
  }

  static boolean isBankSms(String body, String sender) {
    final String safeBody = body == null ? "" : body;
    final String safeSender = sender == null ? "" : sender;

    if (BANK_SENDER_PATTERN.matcher(safeSender).find()) {
      return AMOUNT_KEYWORD_PATTERN.matcher(safeBody).find() || extractAmount(safeBody) > 0;
    }

    return BANK_BODY_PATTERN.matcher(safeBody).find() && extractAmount(safeBody) > 0;
  }

  static ParsedSms parseTransaction(String body) {
    final double amount = extractAmount(body);
    if (amount <= 0) {
      return null;
    }

    final String merchant = extractMerchant(body);
    final String normalizedMerchant = merchant.isEmpty() ? "Unknown" : merchant;
    final TransactionType type = inferType(body);
    final String category = type == TransactionType.DEBIT ? suggestCategory(merchant) : null;
    final String description = body.length() > 300 ? body.substring(0, 300) : body;

    return new ParsedSms(
        amount,
        normalizedMerchant,
        description,
        category,
        type,
        LocalDateTime.now().toString());
  }

  static double extractAmount(String text) {
    if (text == null || text.isEmpty()) {
      return 0;
    }

    final Matcher match = AMOUNT_PATTERN.matcher(text);
    if (match.find()) {
      final String amount = match.group(1).replace(",", "");
      try {
        return Double.parseDouble(amount);
      } catch (NumberFormatException ignored) {
        return 0;
      }
    }

    return 0;
  }

  static String extractMerchant(String text) {
    if (text == null) {
      return "";
    }

    final String raw = text.trim();
    if (raw.isEmpty()) {
      return "";
    }

    final String fromParty = extractCreditedFromParty(raw);
    if (!fromParty.isEmpty()) {
      return fromParty;
    }

    final List<String> parts = splitRemarkParts(raw);

    for (int i = 0; i < parts.size(); i++) {
      final String part = parts.get(i);
      if ("UPI".equalsIgnoreCase(part) && i + 1 < parts.size()) {
        final String merchant = parts.get(i + 1);
        if (i + 2 < parts.size()) {
          final Matcher handleMatch = UPI_HANDLE_PATTERN.matcher(parts.get(i + 2));
          if (handleMatch.find()) {
            return (merchant + "/" + handleMatch.group()).trim();
          }
        }
        return merchant;
      }
    }

    for (int i = 0; i < parts.size(); i++) {
      final Matcher handleMatch = UPI_HANDLE_PATTERN.matcher(parts.get(i));
      if (handleMatch.find()) {
        final String handle = handleMatch.group();
        final String prev = i > 0 ? parts.get(i - 1) : null;
        if (prev != null && !"upi".equalsIgnoreCase(prev)) {
          return (prev + "/" + handle).trim();
        }
        return handle;
      }
    }

    for (String token : parts) {
      if (!BLACKLIST_PATTERN.matcher(token).find() && token.length() >= 3) {
        return token;
      }
    }

    final Matcher match = TO_AT_PATTERN.matcher(raw);
    if (match.find()) {
      return match.group(1).trim();
    }

    return "";
  }

  private static String extractCreditedFromParty(String raw) {
    final String lower = raw.toLowerCase(Locale.ROOT);
    if (!lower.contains("credited")) {
      return "";
    }

    final Matcher fromMatch = FROM_PATTERN.matcher(raw);
    if (!fromMatch.find()) {
      return "";
    }

    String candidate = fromMatch.group(1) == null ? "" : fromMatch.group(1).trim();
    if (candidate.isEmpty()) {
      return "";
    }

    candidate = candidate
        .replaceAll("(?i)\\bUPI\\b.*$", "")
        .replaceAll("(?i)\\bIMPS\\b.*$", "")
        .replaceAll("(?i)\\bNEFT\\b.*$", "")
        .replaceAll("(?i)\\bRTGS\\b.*$", "")
        .replaceAll("(?i)\\bRef\\b.*$", "")
        .replaceAll("\\s+", " ")
        .trim();

    if (candidate.isEmpty()) {
      return "";
    }

    final boolean looksLikeAccountToken = ACCOUNT_TOKEN_PATTERN.matcher(candidate).find();
    final boolean onlySymbolsOrDigits = ONLY_SYMBOLS_OR_DIGITS_PATTERN.matcher(candidate).matches();

    if (looksLikeAccountToken || onlySymbolsOrDigits) {
      return "";
    }

    return candidate;
  }

  private static List<String> splitRemarkParts(String raw) {
    final String[] split = raw.split("[/|\\\\-]+");
    final List<String> parts = new ArrayList<>();
    for (String value : split) {
      final String trimmed = value.trim();
      if (!trimmed.isEmpty()) {
        parts.add(trimmed);
      }
    }
    return parts;
  }

  private static TransactionType inferType(String body) {
    if (DEBIT_PATTERN.matcher(body).find()) {
      return TransactionType.DEBIT;
    }

    if (CREDIT_PATTERN.matcher(body).find()) {
      return TransactionType.CREDIT;
    }

    final String lower = body.toLowerCase(Locale.ROOT);

    if (lower.contains("debited")
        || lower.contains("withdrawn")
        || lower.contains("deducted")
        || lower.contains("spent")) {
      return TransactionType.DEBIT;
    }

    if (lower.contains("credited")
        || lower.contains("received")
        || lower.contains("refund")
        || lower.contains("deposited")) {
      return TransactionType.CREDIT;
    }

    return TransactionType.DEBIT;
  }

  private static String suggestCategory(String merchant) {
    final String value = merchant == null ? "" : merchant.toLowerCase(Locale.ROOT);

    if (value.contains("swiggy") || value.contains("zomato")) {
      return "Food";
    }

    if (value.contains("uber") || value.contains("ola")) {
      return "Travel";
    }

    if (value.contains("amazon") || value.contains("flipkart") || value.contains("myntra")) {
      return "Shopping";
    }

    if (value.contains("electricity")
        || value.contains("water")
        || value.contains("gas")
        || value.contains("broadband")) {
      return "Bills";
    }

    if (value.contains("pharmacy")
        || value.contains("hospital")
        || value.contains("clinic")) {
      return "Health";
    }

    return "Uncategorized";
  }

  private static String joinRemaining(String[] args, int start) {
    final StringBuilder builder = new StringBuilder();
    for (int i = start; i < args.length; i++) {
      if (i > start) {
        builder.append(' ');
      }
      builder.append(args[i]);
    }
    return builder.toString();
  }

  enum TransactionType {
    DEBIT,
    CREDIT
  }

  static final class ParsedSms {
    final double amount;
    final String merchant;
    final String description;
    final String category;
    final TransactionType type;
    final String parsedAt;

    ParsedSms(
        double amount,
        String merchant,
        String description,
        String category,
        TransactionType type,
        String parsedAt) {
      this.amount = amount;
      this.merchant = merchant;
      this.description = description;
      this.category = category;
      this.type = type;
      this.parsedAt = parsedAt;
    }
  }
}