import 'package:flutter_test/flutter_test.dart';
import 'package:upi_expense_tracker/services/transaction_parser.dart';

void main() {
  test('extracts amount only with currency prefix', () {
    expect(TransactionParser.extractAmount('Rs. 1.00 credited'), equals(1.0));
    expect(
      TransactionParser.extractAmount('INR 2,345 debited'),
      equals(2345.0),
    );
    expect(
      TransactionParser.extractAmount('₹500 paid to merchant'),
      equals(500.0),
    );
  });

  test('ignores bare numbers without currency prefix', () {
    expect(
      TransactionParser.extractAmount('A/c 3205 credited on 10-06-2026'),
      equals(0),
    );
    expect(TransactionParser.extractAmount('Payment of 250 done'), equals(0));
  });

  test('extracts merchant and upi handle from UPI remark', () {
    final remark =
        'UPI/SWIGGY/upiswiggy@icic/Paid via C/ICICI Bank/652017616822/crdEA262E6D87CA46E68951C34913815688/';

    final merchant = TransactionParser.extractMerchant(remark);

    expect(merchant, equals('SWIGGY/upiswiggy@icic'));
  });

  test('extracts handle even without UPI prefix', () {
    final remark = 'SWIGGY/upiswiggy@icic Paid via';
    final merchant = TransactionParser.extractMerchant(remark);
    expect(merchant, equals('SWIGGY/upiswiggy@icic'));
  });

  test('extracts payer name from credited message after from', () {
    final remark =
        'Dear Customer, Acct XX791 is credited with Rs 4000.00 on 17-Nov-25 from KAMNI D O SHIV . UPI:095392166027-ICICI Bank.';
    final merchant = TransactionParser.extractMerchant(remark);
    expect(merchant, equals('KAMNI D O SHIV'));
  });

  test('does not use account tokens after from as merchant', () {
    final remark =
        'Your a/c no. XXXXXXX3205 is credited for Rs. 1.00 and debited from a/c no. XXXXXXXX8791';
    final merchant = TransactionParser.extractMerchant(remark);
    expect(merchant, isNot('a/c no'));
  });

  test('returns empty for unknown remark', () {
    final remark = 'Payment from bank transfer 12345';
    final merchant = TransactionParser.extractMerchant(remark);
    expect(merchant, equals(''));
  });
}
