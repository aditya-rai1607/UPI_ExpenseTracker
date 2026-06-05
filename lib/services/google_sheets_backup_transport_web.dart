// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:async';
import 'dart:convert';
import 'dart:html' as html;

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
  final body = html.document.body;
  if (body == null) {
    return const BackupTransportResult(
      success: false,
      message: 'Backup failed: browser document body is unavailable.',
    );
  }

  final frameName =
      'googleSheetsBackup_${DateTime.now().microsecondsSinceEpoch}';
  final iframe = html.IFrameElement()
    ..name = frameName
    ..style.display = 'none';
  final form = html.FormElement()
    ..method = 'POST'
    ..action = endpoint
    ..target = frameName
    ..style.display = 'none'
    ..acceptCharset = 'utf-8';
  final payloadField = html.TextAreaElement()
    ..name = 'payload'
    ..value = jsonEncode(payload)
    ..style.display = 'none';

  form.children.add(payloadField);
  body.children.add(iframe);
  body.children.add(form);

  try {
    form.submit();
    return BackupTransportResult(
      success: true,
      message:
          'Backup request sent to Google Sheets for $transactionCount transactions. Check the sheet to confirm sync.',
    );
  } catch (error) {
    return BackupTransportResult(
      success: false,
      message: 'Backup failed: $error',
    );
  } finally {
    unawaited(Future<void>.delayed(const Duration(seconds: 2), () {
      form.remove();
      iframe.remove();
    }));
  }
}