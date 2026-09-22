import 'package:flutter_test/flutter_test.dart';
import 'package:paisatrack/models/transaction.dart';
import 'package:paisatrack/services/sms_parser.dart';

void main() {
  group('SmsParser — real-world bank/UPI formats', () {
    test('HDFC UPI debit to a merchant', () {
      const body =
          'Rs.289.00 debited from a/c XX4021 on 20-09-26 to Zomato via UPI. '
          'Ref 123456. Not you? Call 18002586161';
      final p = SmsParser.parse(body)!;
      expect(p.type, TxnType.debit);
      expect(p.amount, 289.00);
      expect(p.merchant.toLowerCase(), contains('zomato'));
      expect(p.account, '••4021');
    });

    test('SBI credit / money received', () {
      const body =
          'Dear Customer, INR 42,000.00 credited to your A/c no. XXXXX0402 '
          'on 12/09/26. Avl Bal INR 55,480.00.';
      final p = SmsParser.parse(body)!;
      expect(p.type, TxnType.credit);
      expect(p.amount, 42000.00);
      expect(p.account, '••0402');
    });

    test('ICICI spent at a merchant', () {
      const body =
          'INR 745.00 spent on ICICI Card XX1234 at Apple Store on 23-Aug. '
          'Avl Lmt INR 90,000.';
      final p = SmsParser.parse(body)!;
      expect(p.type, TxnType.debit);
      expect(p.amount, 745.00);
      expect(p.merchant.toLowerCase(), contains('apple'));
    });

    test('UPI VPA is used as merchant when no name present', () {
      const body =
          'Rs 210 debited and paid to john.doe@okaxis. UPI Ref 998877.';
      final p = SmsParser.parse(body)!;
      expect(p.type, TxnType.debit);
      expect(p.amount, 210);
      expect(p.merchant.toLowerCase(), contains('john'));
    });

    test('amount with comma and decimals parses correctly', () {
      const body = 'Rs.1,234.56 debited from a/c XX0001 to BigBasket.';
      final p = SmsParser.parse(body)!;
      expect(p.amount, 1234.56);
    });

    test('OTP messages are ignored', () {
      const body =
          '123456 is your OTP for a txn of Rs.500 at Amazon. Do not share.';
      expect(SmsParser.parse(body), isNull);
    });

    test('promotional / non-transaction messages are ignored', () {
      const body =
          'Get a personal loan up to Rs.5,00,000 at low interest! Apply now.';
      expect(SmsParser.parse(body), isNull);
    });

    test('toTransaction auto-categorizes and tags source as sms', () {
      const body = 'Rs.199.00 debited from a/c XX4021 to Netflix via UPI.';
      final txn = SmsParser.toTransaction(body)!;
      expect(txn.source, TxnSource.sms);
      expect(txn.categoryId, 'entertainment');
      expect(txn.type, TxnType.debit);
      expect(txn.rawSms, body);
    });

    test('credit auto-categorizes to income by default', () {
      const body = 'INR 5,000 credited to a/c XX4021 from ACME PVT LTD.';
      final txn = SmsParser.toTransaction(body)!;
      expect(txn.type, TxnType.credit);
      expect(txn.categoryId, 'income');
    });
  });
}
