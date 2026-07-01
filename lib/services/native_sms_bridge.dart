import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../models/transaction_model.dart';
import 'sms_transaction_parser.dart';
import 'notification_service.dart';

class NativeSmsBridge {
  static const MethodChannel _channel = MethodChannel('sms_native_bridge');

  static Future<List<Map<String, dynamic>>> getPendingTransactions() async {
    try {
      final res = await _channel.invokeMethod<String>('getPendingTransactions');
      if (res == null || res.isEmpty) return [];
      final List decoded = json.decode(res) as List;
      return decoded.map((e) => Map<String, dynamic>.from(e)).toList();
    } catch (e) {
      return [];
    }
  }

  /// Returns true if RECEIVE_SMS permission is granted (no dialog shown).
  static Future<bool> hasSmsPermission() async {
    try {
      final result = await _channel.invokeMethod<bool>('hasSmsPermission');
      return result == true;
    } catch (_) {
      return false;
    }
  }

  /// Returns raw SMS messages queued by the native NativeSmsReceiver while
  /// the Dart background isolate was not yet registered. Clears the queue.
  static Future<List<Map<String, dynamic>>> getPendingSmsMessages() async {
    try {
      final res = await _channel.invokeMethod<String>('getPendingSms');
      if (res == null || res.isEmpty) return [];
      final List decoded = json.decode(res) as List;
      return decoded.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    } catch (_) {
      return [];
    }
  }

  /// Drains the native pending queue into Hive and shows categorization prompts.
  /// This is safe to call from UI startup (post frame) and is idempotent.
  static Future<void> drainPendingTransactions() async {
    try {
      final pending = await getPendingTransactions();
      // debug trace for runtime verification
      try {
        print(
          'NativeSmsBridge: drainPendingTransactions called, pending=${pending.length}',
        );
      } catch (_) {}
      if (pending.isEmpty) return;

      final box = Hive.box('transactions');

      for (final map in pending) {
        try {
          final txn = TransactionModel.fromMap(Map<String, dynamic>.from(map));
          try {
            print(
              'NativeSmsBridge: draining txn amount=${txn.amount} type=${txn.type}',
            );
          } catch (_) {}
          if (SmsTransactionParser.isDuplicate(txn, box)) continue;

          final key = await box.add(txn.toMap());
          await NotificationService.showCategorizationPrompt(txn, key);
        } catch (_) {
          // ignore malformed entries
        }
      }
      try {
        print('NativeSmsBridge: drainPendingTransactions complete');
      } catch (_) {}
    } catch (_) {
      // best-effort
    }
  }
}
