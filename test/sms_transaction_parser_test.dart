import 'package:flutter_test/flutter_test.dart';
import 'package:upi_expense_tracker/models/transaction_model.dart';
import 'package:upi_expense_tracker/services/sms_transaction_parser.dart';

void main() {
  test('parses credited plus debited-from message as single credit entry', () {
    const sms =
        'Your a/c no. XXXXXXX3205 is credited for Rs. 1.00 on 10-06-2026 11:34 and debited from a/c no. XXXXXXXX8791 (UPI Ref no 652711707765)';

    final parsed = SmsTransactionParser.parseTransactions(sms);

    expect(parsed.length, 1);
    expect(parsed.first.type, TransactionType.credit);
    expect(parsed.first.amount, 1.0);
  });

  test('parses normal credit SMS as single entry', () {
    const sms = 'INR 5000 credited to your account via IMPS';

    final parsed = SmsTransactionParser.parseTransactions(sms);

    expect(parsed.length, 1);
    expect(parsed.first.type, TransactionType.credit);
    expect(parsed.first.amount, 5000.0);
  });

  group('isBankSms', () {
    test('known sender with amount keyword matches', () {
      const sender = 'HDFCBK';
      const body = 'INR 500 debited via UPI to your account';

      final ok = SmsTransactionParser.isBankSms(body, sender);
      expect(ok, isTrue);
    });

    test('known sender uses extractAmount fallback', () {
      // body intentionally contains amount with currency prefix that still
      // exercises the extractAmount fallback path.
      const sender = 'HDFCBK';
      const body = 'Your a/c is credited for Rs. 1.00 on 10-06-2026';

      final ok = SmsTransactionParser.isBankSms(body, sender);
      expect(ok, isTrue);
    });

    test('known sender without amount or keyword does not match', () {
      const sender = 'HDFCBK';
      const body = 'A generic notification from bank without amounts';

      final ok = SmsTransactionParser.isBankSms(body, sender);
      expect(ok, isFalse);
    });

    test('unknown sender with bank keywords and prefixed amount matches', () {
      const sender = 'AD-ALERTS';
      const body = 'INR 1000 debited to your account via IMPS';

      final ok = SmsTransactionParser.isBankSms(body, sender);
      expect(ok, isTrue);
    });

    test(
      'unknown sender with keywords but no currency prefix does not match',
      () {
        const sender = 'AD-ALERTS';
        const body = 'debited 500 rupees from your a/c';

        final ok = SmsTransactionParser.isBankSms(body, sender);
        expect(ok, isFalse);
      },
    );

    test(
      'unknown sender without bank keyword does not match even with amount',
      () {
        const sender = 'AD-ALERTS';
        const body = 'INR 500 transfer completed';

        final ok = SmsTransactionParser.isBankSms(body, sender);
        expect(ok, isFalse);
      },
    );
  });
}
