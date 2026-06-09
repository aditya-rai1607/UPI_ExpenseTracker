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
    final amount = TransactionParser.extractAmount(body);
    if (amount <= 0) return null;

    final merchant = TransactionParser.extractMerchant(body);
    final type = _inferType(body);
    final category = type == TransactionType.debit
        ? TransactionParser.suggestCategory(merchant)
        : null;

    return TransactionModel(
      amount: amount,
      merchant: merchant.isNotEmpty ? merchant : 'Unknown',
      bankRemark: body.length > 300 ? body.substring(0, 300) : body,
      category: category,
      date: DateTime.now(),
      type: type,
    );
  }

  /// Returns `true` if a transaction with the same fingerprint already exists
  /// in the [box], preventing duplicates from the same SMS being stored twice.
  static bool isDuplicate(TransactionModel transaction, Box<dynamic> box) {
    for (var i = 0; i < box.length; i++) {
      final raw = box.getAt(i);
      if (raw is! Map) continue;
      try {
        final existing = TransactionModel.fromMap(raw.cast<dynamic, dynamic>());
        if (existing.fingerprint == transaction.fingerprint) return true;
      } catch (_) {
        // skip malformed entries
      }
    }
    return false;
  }

  /// Infers [TransactionType] from keywords in the SMS [body].
  static TransactionType _inferType(String body) {
    final lower = body.toLowerCase();
    if (lower.contains('credited') ||
        lower.contains('received') ||
        lower.contains('refund') ||
        lower.contains('deposited')) {
      return TransactionType.credit;
    }
    return TransactionType.debit;
  }
}
