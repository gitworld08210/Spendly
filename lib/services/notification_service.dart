import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import '../models/transaction.dart';
import '../utils/formatters.dart';

/// Handles local (on-device) notifications: instant alerts when a spend is
/// captured, and a scheduled weekly summary. This is the core retention loop —
/// every alert is a reason to open Spendly.
class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  static const _txnChannelId = 'txn_alerts';
  static const _summaryChannelId = 'weekly_summary';

  Future<void> init() async {
    if (_initialized) return;
    try {
      tz.initializeTimeZones();

      const android = AndroidInitializationSettings('@mipmap/ic_launcher');
      const settings = InitializationSettings(android: android);
      await _plugin.initialize(settings);
      _initialized = true;
    } catch (e) {
      debugPrint('NotificationService.init failed: $e');
    }
  }

  /// Ask for the POST_NOTIFICATIONS permission (Android 13+). Returns true if
  /// granted (or not required on older Android).
  Future<bool> requestPermission() async {
    await init();
    try {
      final android = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      final granted = await android?.requestNotificationsPermission();
      return granted ?? true;
    } catch (e) {
      debugPrint('NotificationService.requestPermission failed: $e');
      return false;
    }
  }

  /// Fires an instant notification for a freshly-captured transaction.
  Future<void> showTransactionAlert(Transaction txn) async {
    await init();
    final isCredit = txn.isCredit;
    final title = isCredit ? 'Money received' : 'Spend tracked';
    final body =
        '${isCredit ? '+' : '-'}${Formatters.money(txn.amount)} · ${txn.title}';

    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        _txnChannelId,
        'Transaction alerts',
        channelDescription: 'Notifies you when a spend or credit is captured.',
        importance: Importance.high,
        priority: Priority.high,
        icon: '@mipmap/ic_launcher',
      ),
    );

    try {
      await _plugin.show(
        txn.id.hashCode & 0x7fffffff,
        title,
        body,
        details,
      );
    } catch (e) {
      debugPrint('showTransactionAlert failed: $e');
    }
  }

  /// Schedules (or reschedules) a weekly summary notification for Sunday 7 PM.
  Future<void> scheduleWeeklySummary(String message) async {
    await init();
    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        _summaryChannelId,
        'Weekly summary',
        channelDescription: 'Your weekly spending recap.',
        importance: Importance.defaultImportance,
        priority: Priority.defaultPriority,
        icon: '@mipmap/ic_launcher',
      ),
    );

    try {
      await _plugin.zonedSchedule(
        1001,
        'Your week with Spendly 📊',
        message,
        _nextInstanceOfSundayEvening(),
        details,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
      );
    } catch (e) {
      debugPrint('scheduleWeeklySummary failed: $e');
    }
  }

  Future<void> cancelWeeklySummary() async {
    try {
      await _plugin.cancel(1001);
    } catch (_) {}
  }

  tz.TZDateTime _nextInstanceOfSundayEvening() {
    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(tz.local, now.year, now.month, now.day, 19);
    // Advance to the coming Sunday (weekday 7).
    while (scheduled.weekday != DateTime.sunday || !scheduled.isAfter(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    return scheduled;
  }
}
