import 'package:hive_flutter/hive_flutter.dart';

import '../models/transaction_model.dart';
import 'transaction_parser.dart';

/// Parses incoming SMS messages into [TransactionModel] instances and checks
/// for duplicates against the local Hive store.
class SmsTransactionParser {
  // Matches the body text of typical bank/payment SMS messages.
  static final RegExp _bankBodyPattern = RegExp(
    r'debited|credited|deducted|withdrawn|spent|received|refund|deposited|'
    r'UPI|NEFT|IMPS|RTGS|A\/c|Acct|account',
    caseSensitive: false,
  );

  // Matches an amount expressed with a currency symbol or keyword.
  static final RegExp _amountKeywordPattern = RegExp(
    r'(?:INR|Rs\.?|₹)\s?[\d,]+',
    caseSensitive: false,
  );

  // Known bank/payment-app sender IDs (the "From" field in SMS).
  static final RegExp _bankSenderPattern = RegExp(
    r'HDFCBK|HDFCBANK|SBIINB|SBISMS|ICICIB|ICICIBANK|AXISBK|AXISBANK|'
    r'KOTAKB|KOTAK|PNBSMS|BOIIND|CANBNK|SCBAND|INDBNK|UNIONB|CENTBK|'
    r'YESBNK|IDBIBK|FEDBK|RBLBNK|INDUSB|PAYTM|PHONEPE|GPAY|AMAZONPAY|'
    r'CITIBNK|BOBBK|DENABNK|VJYBNK',
    caseSensitive: false,
  );

  // Explicit debit patterns
  static final RegExp _debitPattern = RegExp(
    r'debited\s+for|'
    r'is\s+debited|'
    r'withdrawn|'
    r'deducted|'
    r'spent|'
    r'purchase|'
    r'upi\s+payment|'
    r'\bdr\b|'
    r'\bdebit\b',
    caseSensitive: false,
  );

  // Explicit credit patterns
  static final RegExp _creditPattern = RegExp(
    r'is\s+credited|'
    r'received|'
    r'deposited|'
    r'refund|'
    r'cashback|'
    r'reversal|'
    r'reversed|'
    r'\bcr\b|'
    r'\bcredit\b',
    caseSensitive: false,
  );

  /// Returns `true` if the SMS is likely a bank or payment notification.
  ///
  /// Matches on either the [sender] ID (e.g. `HDFCBK`) or the [body] text
  /// containing both transaction keywords and an amount.
  static bool isBankSms(String body, String sender) {
    if (_bankSenderPattern.hasMatch(sender)) {
      return _amountKeywordPattern.hasMatch(body) ||
          TransactionParser.extractAmount(body) > 0;
    }

    return _bankBodyPattern.hasMatch(body) &&
        TransactionParser.extractAmount(body) > 0;
  }

  /// Parses the [body] of a bank SMS into a [TransactionModel].
  ///
  /// Returns `null` if no valid amount can be extracted.
  static TransactionModel? parseTransaction(String body) {
    final parsed = parseTransactions(body);
    if (parsed.isEmpty) return null;
    return parsed.first;
  }

  /// Parses the [body] into one or more transactions.
  static List<TransactionModel> parseTransactions(String body) {
    final amount = TransactionParser.extractAmount(body);
    if (amount <= 0) return const [];

    final merchant = TransactionParser.extractMerchant(body);
    final normalizedMerchant = merchant.isNotEmpty ? merchant : 'Unknown';
    final now = DateTime.now();

    final type = _inferType(body);

    final category = type == TransactionType.debit
        ? TransactionParser.suggestCategory(merchant)
        : null;

    return [
      TransactionModel(
        amount: amount,
        merchant: normalizedMerchant,
        bankRemark: body.length > 300 ? body.substring(0, 300) : body,
        category: category,
        date: now,
        type: type,
      ),
    ];
  }

  /// Returns `true` if a transaction with the same fingerprint already exists
  /// in the [box], preventing duplicates from the same SMS being stored twice.
  static bool isDuplicate(TransactionModel transaction, Box<dynamic> box) {
    for (var i = 0; i < box.length; i++) {
      final raw = box.getAt(i);

      if (raw is! Map) continue;

      try {
        final existing = TransactionModel.fromMap(raw.cast<dynamic, dynamic>());

        if (existing.fingerprint == transaction.fingerprint) {
          return true;
        }
      } catch (_) {
        // Skip malformed entries
      }
    }

    return false;
  }

  /// Infers [TransactionType] from the SMS body using banking-specific regex.
  static TransactionType _inferType(String body) {
    // Debit gets priority because many debit SMS mention
    // the merchant being credited.
    if (_debitPattern.hasMatch(body)) {
      return TransactionType.debit;
    }

    if (_creditPattern.hasMatch(body)) {
      return TransactionType.credit;
    }

    // Fallback checks for uncommon formats.
    final lower = body.toLowerCase();

    if (lower.contains('debited') ||
        lower.contains('withdrawn') ||
        lower.contains('deducted') ||
        lower.contains('spent')) {
      return TransactionType.debit;
    }

    if (lower.contains('credited') ||
        lower.contains('received') ||
        lower.contains('refund') ||
        lower.contains('deposited')) {
      return TransactionType.credit;
    }

    // Default to debit for unknown transaction messages.
    return TransactionType.debit;
  }
}
