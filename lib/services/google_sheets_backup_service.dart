import 'package:hive_flutter/hive_flutter.dart';

import '../models/transaction_model.dart';
import 'app_settings_service.dart';
import 'google_sheets_backup_transport_stub.dart'
  if (dart.library.html) 'google_sheets_backup_transport_web.dart'
  as backup_transport;

class BackupResult {
  BackupResult({
    required this.success,
    required this.message,
    required this.exportedCount,
  });

  final bool success;
  final String message;
  final int exportedCount;
}

class GoogleSheetsBackupService {
  static Future<BackupResult> backupTransactions() async {
    final endpoint = AppSettingsService.getGoogleSheetsEndpoint();
    if (endpoint == null) {
      return BackupResult(
        success: false,
        message: 'Google Sheets backup URL is not configured.',
        exportedCount: 0,
      );
    }

    final box = Hive.box('transactions');
    final transactions = <TransactionModel>[];
    for (var i = 0; i < box.length; i++) {
      final raw = box.getAt(i);
      if (raw is Map) {
        transactions.add(
          TransactionModel.fromMap(raw.cast<dynamic, dynamic>()),
        );
      }
    }

    final payload = <String, dynamic>{
      'source': 'upi_expense_tracker',
      'exportedAt': DateTime.now().toIso8601String(),
      'transactions': transactions
          .map((transaction) => transaction.toMap())
          .toList(),
    };

    try {
      final response = await backup_transport.submitBackupRequest(
        endpoint: endpoint,
        payload: payload,
        transactionCount: transactions.length,
      );

      if (!response.success) {
        return BackupResult(
          success: false,
          message: response.message,
          exportedCount: 0,
        );
      }

      await AppSettingsService.setLastBackupAt(DateTime.now());
      return BackupResult(
        success: true,
        message: response.message,
        exportedCount: transactions.length,
      );
    } catch (error) {
      return BackupResult(
        success: false,
        message: 'Backup failed: $error',
        exportedCount: 0,
      );
    }
  }
}
