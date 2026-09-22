import 'package:another_telephony/telephony.dart';
import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';

import '../repositories/transaction_repository.dart';
import 'app_prefs.dart';
import 'notification_service.dart';
import 'sms_parser.dart';

/// Outcome of asking for SMS permission, so the UI can react precisely.
enum SmsPermissionResult {
  granted,

  /// User tapped "Deny" — can ask again.
  denied,

  /// User selected "Don't ask again" / OS restricted — must open Settings.
  permanentlyDenied,
}

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

  /// Ask the user for SMS permission.
  ///
  /// Uses `permission_handler` (not the telephony plugin's own request) because
  /// it reliably shows the system dialog across OEM skins like MIUI/One UI,
  /// where the plugin's request sometimes silently no-ops. We request both
  /// READ_SMS and RECEIVE_SMS so backfill and live capture both work.
  Future<SmsPermissionResult> requestPermission() async {
    // Requesting the READ_SMS runtime permission covers reading the inbox;
    // RECEIVE_SMS is a manifest/broadcast permission granted in the same group.
    final statuses = await [Permission.sms].request();
    final status = statuses[Permission.sms] ?? PermissionStatus.denied;

    if (status.isGranted) return SmsPermissionResult.granted;
    if (status.isPermanentlyDenied || status.isRestricted) {
      return SmsPermissionResult.permanentlyDenied;
    }
    return SmsPermissionResult.denied;
  }

  /// Whether SMS permission is already granted (no prompt shown).
  Future<bool> hasPermission() async {
    final status = await Permission.sms.status;
    return status.isGranted;
  }

  /// Opens the OS app-settings page so the user can grant SMS manually
  /// (used when the permission was permanently denied).
  Future<void> openSettings() => openAppSettings();

  /// Reads the inbox and imports messages that parse as transactions —
  /// **only those received at or after the cutoff** (when the user first
  /// enabled capture), so pre-existing/old bank SMS are never pulled in.
  ///
  /// Safe to call repeatedly — the repository dedupes on the raw SMS body.
  /// Returns the number of new transactions imported.
  Future<int> backfillInbox({int maxMessages = 500}) async {
    var imported = 0;
    try {
      final cutoff = await AppPrefs.ensureSmsCutoff();
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
        // Skip anything from before the user started using Spendly.
        if (received.isBefore(cutoff)) continue;
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

  Future<void> _handleIncoming(SmsMessage message) async {
    final body = message.body;
    if (body == null || body.isEmpty) return;
    // Incoming messages arrive "now", which is always at/after the cutoff, but
    // establish the cutoff if capture was enabled without a backfill first.
    await AppPrefs.ensureSmsCutoff();
    final txn = SmsParser.toTransaction(body);
    if (txn == null) return;
    // Repository handles dedupe + persistence; notify only if newly added.
    final added = await TransactionRepository.instance.addFromSms(txn);
    if (added) {
      await NotificationService.instance.showTransactionAlert(txn);
    }
  }
}
