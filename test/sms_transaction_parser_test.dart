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
}
