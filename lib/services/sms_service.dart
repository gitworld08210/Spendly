import 'package:another_telephony/telephony.dart';
import 'package:flutter/foundation.dart';

import '../repositories/transaction_repository.dart';
import 'sms_parser.dart';

/// Bridges the device SMS inbox to PaisaTrack's parser + repository.
///
/// Responsibilities:
///   * Request SMS permission.
///   * Backfill: scan existing inbox messages once, so history shows up
///     immediately after install.
///   * Listen: capture new bank/UPI alerts as they arrive and turn them into
///     transactions automatically — no manual entry needed.
///
/// All parsing happens on-device via [SmsParser]; raw SMS bodies never leave
/// the phone except as part of a transaction the user chose to sync.
class SmsService {
  SmsService._();
  static final SmsService instance = SmsService._();

  final Telephony _telephony = Telephony.instance;
  bool _listening = false;

  /// Ask the user for SMS permission. Returns true if granted.
  Future<bool> requestPermission() async {
    final granted = await _telephony.requestPhoneAndSmsPermissions;
    return granted ?? false;
  }

  /// Reads the existing inbox and imports any messages that parse as
  /// transactions. Safe to call repeatedly — the repository dedupes on the
  /// raw SMS body. Returns the number of new transactions imported.
  Future<int> backfillInbox({int maxMessages = 500}) async {
    var imported = 0;
    try {
      final messages = await _telephony.getInboxSms(
        columns: [SmsColumn.ADDRESS, SmsColumn.BODY, SmsColumn.DATE],
      );
      final slice = messages.take(maxMessages);
      for (final sms in slice) {
        final body = sms.body;
        if (body == null || body.isEmpty) continue;
        final received = sms.date != null
            ? DateTime.fromMillisecondsSinceEpoch(sms.date!)
            : DateTime.now();
        final txn = SmsParser.toTransaction(body, receivedAt: received);
        if (txn == null) continue;
        final added = await TransactionRepository.instance.addFromSms(txn);
        if (added) imported++;
      }
    } catch (e) {
      debugPrint('SmsService.backfillInbox failed: $e');
    }
    return imported;
  }

  /// Starts listening for incoming SMS. New transaction alerts are parsed and
  /// added to the repository in real time.
  void startListening() {
    if (_listening) return;
    _listening = true;
    try {
      _telephony.listenIncomingSms(
        onNewMessage: _handleIncoming,
        listenInBackground: false,
      );
    } catch (e) {
      _listening = false;
      debugPrint('SmsService.startListening failed: $e');
    }
  }

  void _handleIncoming(SmsMessage message) {
    final body = message.body;
    if (body == null || body.isEmpty) return;
    final txn = SmsParser.toTransaction(body);
    if (txn == null) return;
    // Fire-and-forget; repository handles dedupe + persistence.
    TransactionRepository.instance.addFromSms(txn);
  }
}
