import 'package:flutter_test/flutter_test.dart';
import 'package:upi_expense_tracker/services/transaction_parser.dart';

void main() {
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

  test('returns empty for unknown remark', () {
    final remark = 'Payment from bank transfer 12345';
    final merchant = TransactionParser.extractMerchant(remark);
    expect(merchant, equals(''));
  });
}
