import 'dart:convert';

import 'package:http/http.dart' as http;

class BackupTransportResult {
  const BackupTransportResult({
    required this.success,
    required this.message,
  });

  final bool success;
  final String message;
}

Future<BackupTransportResult> submitBackupRequest({
  required String endpoint,
  required Map<String, dynamic> payload,
  required int transactionCount,
}) async {
  final response = await http.post(
    Uri.parse(endpoint),
    body: <String, String>{
      'payload': jsonEncode(payload),
    },
  );

  if (response.statusCode < 200 || response.statusCode >= 300) {
    return BackupTransportResult(
      success: false,
      message: 'Backup failed with status ${response.statusCode}.',
    );
  }

  return BackupTransportResult(
    success: true,
    message: 'Backed up $transactionCount transactions to Google Sheets.',
  );
}