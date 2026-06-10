import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:telephony/telephony.dart';

import '../models/transaction_model.dart';
import 'notification_service.dart';
import 'sms_transaction_parser.dart';

// ---------------------------------------------------------------------------
// Background handler — top-level function, runs in a separate Dart isolate
// when the app is NOT in the foreground. Must be annotated with
// @pragma('vm:entry-point') so the tree-shaker keeps it.
// ---------------------------------------------------------------------------

@pragma('vm:entry-point')
Future<void> backgroundSmsHandler(SmsMessage message) async {
  // Flutter engine must be initialised before using any plugin in an isolate.
  WidgetsFlutterBinding.ensureInitialized();

  final body = message.body ?? '';
  final sender = message.address ?? '';

  if (!SmsTransactionParser.isBankSms(body, sender)) return;

  final transactions = SmsTransactionParser.parseTransactions(body);
  if (transactions.isEmpty) return;

  // Hive must be separately initialised in every isolate.
  await Hive.initFlutter();
  final box = await Hive.openBox('transactions');

  for (final transaction in transactions) {
    if (SmsTransactionParser.isDuplicate(transaction, box)) continue;

    final key = await box.add(transaction.toMap());

    // Notification should never block persistence.
    try {
      final plugin = FlutterLocalNotificationsPlugin();
      await plugin.initialize(
        const InitializationSettings(
          android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        ),
      );

      if (!transaction.needsCategory ||
          !await NotificationService.isNotificationPermissionGranted()) {
        continue;
      }

      final typeLabel = transaction.type == TransactionType.credit
          ? 'Credited'
          : 'Debited';
      final merchantLabel = transaction.merchant.isNotEmpty
          ? transaction.merchant
          : 'Unknown';

      await plugin.show(
        key.hashCode & 0x7FFFFFFF,
        '₹${transaction.amount.toStringAsFixed(2)} $typeLabel',
        '$merchantLabel — tap to categorize',
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'bank_txn',
            'Bank Transactions',
            channelDescription:
                'Alerts for bank transactions detected from incoming SMS',
            importance: Importance.high,
            priority: Priority.high,
            icon: '@mipmap/ic_launcher',
          ),
        ),
        payload: key.toString(),
      );
    } catch (_) {
      // Ignore notification failures in background isolate.
    }
  }
}

// ---------------------------------------------------------------------------
// Foreground service
// ---------------------------------------------------------------------------

/// Manages SMS listening and runtime permissions for the auto-detect feature.
class SmsListenerService {
  static final _telephony = Telephony.instance;

  /// Requests SMS runtime permission.
  static Future<bool> requestSmsPermission() async {
    if (!Platform.isAndroid) return false;

    final status = await Permission.sms.request();
    return status.isGranted;
  }

  /// Requests notification permission separately from SMS permission.
  static Future<bool> requestNotificationPermission() async {
    if (!Platform.isAndroid) return false;

    final status = await Permission.notification.request();
    return status.isGranted;
  }

  /// Backward-compatible helper.
  static Future<bool> requestPermissions() async {
    if (!Platform.isAndroid) return false;

    final smsGranted = await requestSmsPermission();
    if (!smsGranted) return false;

    await requestNotificationPermission();
    return true;
  }

  /// Returns `true` if the SMS permission is already granted (no prompt shown).
  static Future<bool> isPermissionGranted() async {
    if (!Platform.isAndroid) return false;
    return Permission.sms.isGranted;
  }

  /// Starts listening for incoming SMS messages, both in the foreground and
  /// background. Safe to call multiple times — `telephony` deduplicates.
  static void startListening() {
    if (!Platform.isAndroid) return;
    _telephony.listenIncomingSms(
      onNewMessage: _handleForegroundSms,
      listenInBackground: true,
      onBackgroundMessage: backgroundSmsHandler,
    );
  }

  /// Foreground handler — app is open.
  static Future<void> _handleForegroundSms(SmsMessage message) async {
    final body = message.body ?? '';
    final sender = message.address ?? '';

    if (!SmsTransactionParser.isBankSms(body, sender)) return;

    final transactions = SmsTransactionParser.parseTransactions(body);
    if (transactions.isEmpty) return;

    // Hive box is already open when the app is in the foreground.
    final box = Hive.box('transactions');

    for (final transaction in transactions) {
      if (SmsTransactionParser.isDuplicate(transaction, box)) continue;

      final key = await box.add(transaction.toMap());
      if (transaction.needsCategory) {
        await NotificationService.showCategorizationPrompt(transaction, key);
      }
    }
  }
}
