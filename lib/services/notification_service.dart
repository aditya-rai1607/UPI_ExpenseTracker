import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:permission_handler/permission_handler.dart';

import '../models/transaction_model.dart';
import '../screens/transaction_detail_screen.dart';

/// Manages local push notifications for auto-detected bank transactions.
///
/// Call [init] once at app startup (foreground). The background SMS handler
/// uses [showFromBackground] which initialises its own plugin instance.
class NotificationService {
  static final _plugin = FlutterLocalNotificationsPlugin();
  static GlobalKey<NavigatorState>? _navigatorKey;

  static const _channelId = 'bank_txn';
  static const _channelName = 'Bank Transactions';
  static const _channelDesc =
      'Alerts for bank transactions detected from incoming SMS';

  static Future<bool> isNotificationPermissionGranted() async {
    final status = await Permission.notification.status;
    return status.isGranted;
  }

  /// Full initialisation for the foreground app. Sets up navigation so that
  /// tapping a notification opens the relevant [TransactionDetailScreen].
  static Future<void> init(GlobalKey<NavigatorState> navigatorKey) async {
    _navigatorKey = navigatorKey;

    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );
    const initSettings = InitializationSettings(android: androidSettings);

    await _plugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTap,
    );

    // Create the Android notification channel (idempotent).
    const channel = AndroidNotificationChannel(
      _channelId,
      _channelName,
      description: _channelDesc,
      importance: Importance.high,
      playSound: true,
    );
    await _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(channel);
  }

  /// Shows a notification prompting the user to categorise a new transaction.
  ///
  /// [hiveKey] is used both as the notification ID seed and as the payload so
  /// that [_onNotificationTap] can look up the correct record.
  static Future<void> showCategorizationPrompt(
    TransactionModel transaction,
    dynamic hiveKey,
  ) async {
    if (!await isNotificationPermissionGranted()) return;

    final typeLabel = transaction.type == TransactionType.credit
        ? 'Credited'
        : 'Debited';
    final merchantLabel = transaction.merchant.isNotEmpty
        ? transaction.merchant
        : 'Unknown';

    const androidDetails = AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: _channelDesc,
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
    );

    try {
      await _plugin.show(
        hiveKey.hashCode & 0x7FFFFFFF, // keep within int32 range
        '₹${transaction.amount.toStringAsFixed(2)} $typeLabel',
        '$merchantLabel — tap to categorize',
        const NotificationDetails(android: androidDetails),
        payload: hiveKey.toString(),
      );
    } catch (_) {
      // Best-effort notification; transaction is already persisted.
    }
  }

  /// Handles a notification tap by navigating to [TransactionDetailScreen].
  static void _onNotificationTap(NotificationResponse response) {
    final keyStr = response.payload;
    if (keyStr == null) return;

    final nav = _navigatorKey?.currentState;
    if (nav == null) return;

    final box = Hive.box('transactions');
    // Hive auto-increment keys are ints; fall back to string for manual keys.
    final dynamic key = int.tryParse(keyStr) ?? keyStr;
    final raw = box.get(key);
    if (raw is! Map) return;

    try {
      final transaction = TransactionModel.fromMap(
        raw.cast<dynamic, dynamic>(),
      );
      nav.push(
        MaterialPageRoute<bool>(
          builder: (_) => TransactionDetailScreen(
            transaction: transaction,
            transactionKey: key,
          ),
        ),
      );
    } catch (_) {
      // Malformed stored data — nothing to navigate to.
    }
  }
}
