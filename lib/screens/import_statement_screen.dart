import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';

import '../models/transaction_model.dart';
import '../services/xlsx_import_service.dart';

class ImportStatementScreen extends StatefulWidget {
  const ImportStatementScreen({super.key});

  @override
  State<ImportStatementScreen> createState() => _ImportStatementScreenState();
}

class _ImportStatementScreenState extends State<ImportStatementScreen> {
  List<TransactionModel> _parsedTransactions = <TransactionModel>[];
  int _skippedRows = 0;
  int _failedRows = 0;
  bool _isParsing = false;
  bool _isImporting = false;
  String? _fileName;

  Future<void> _pickAndParseFile() async {
    setState(() {
      _isParsing = true;
    });

    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: <String>['xls', 'xlsx'],
        withData: true,
      );

      if (result == null || result.files.isEmpty) {
        return;
      }

      final PlatformFile file = result.files.first;
      final Uint8List? bytes = file.bytes;
      if (bytes == null) {
        _showMessage('Could not read selected file bytes.');
        return;
      }

      final parsed = XlsxImportService.parseBytes(bytes, fileName: file.name);

      setState(() {
        _fileName = file.name;
        _parsedTransactions = parsed.transactions;
        _skippedRows = parsed.skippedRows;
        _failedRows = parsed.failedRows;
      });
    } finally {
      if (mounted) {
        setState(() {
          _isParsing = false;
        });
      }
    }
  }

  Future<void> _importTransactions() async {
    if (_parsedTransactions.isEmpty) {
      _showMessage('No transactions to import.');
      return;
    }

    setState(() {
      _isImporting = true;
    });

    final box = Hive.box('transactions');
    final existingFingerprints = <String>{};

    for (final dynamic value in box.values) {
      if (value is Map) {
        final transaction = TransactionModel.fromMap(
          value.cast<dynamic, dynamic>(),
        );
        existingFingerprints.add(transaction.fingerprint);
      }
    }

    var imported = 0;
    var duplicates = 0;
    for (final transaction in _parsedTransactions) {
      if (existingFingerprints.contains(transaction.fingerprint)) {
        duplicates++;
        continue;
      }

      await box.add(transaction.toMap());
      existingFingerprints.add(transaction.fingerprint);
      imported++;
    }

    if (!mounted) {
      return;
    }

    setState(() {
      _isImporting = false;
    });

    _showMessage('Imported: $imported, Duplicates skipped: $duplicates');
    Navigator.of(context).pop(true);
  }

  void _showMessage(String message) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Import Bank Statement (.xls/.xlsx)')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            ElevatedButton.icon(
              onPressed: _isParsing ? null : _pickAndParseFile,
              icon: const Icon(Icons.upload_file),
              label: Text(_isParsing ? 'Parsing...' : 'Select XLS / XLSX File'),
            ),
            const SizedBox(height: 12),
            if (_fileName != null) Text('File: $_fileName'),
            const SizedBox(height: 12),
            Text('Parsed transactions: ${_parsedTransactions.length}'),
            Text('Skipped rows: $_skippedRows'),
            Text('Failed rows: $_failedRows'),
            const SizedBox(height: 12),
            Expanded(
              child: ListView.builder(
                itemCount: _parsedTransactions.length,
                itemBuilder: (context, index) {
                  final transaction = _parsedTransactions[index];
                  final signed = transaction.type == TransactionType.debit
                      ? '-'
                      : '+';
                  final title = transaction.merchant.trim() == 'N/A'
                      ? (transaction.bankRemark ?? 'N/A')
                      : transaction.merchant;
                  return Card(
                    child: ListTile(
                      title: Text(title),
                      subtitle: Text(
                        '${DateFormat('dd MMM yyyy').format(transaction.date)} • ${transaction.type.name.toUpperCase()}',
                      ),
                      trailing: Text(
                        '$signed₹${transaction.amount.toStringAsFixed(2)}',
                      ),
                    ),
                  );
                },
              ),
            ),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isImporting ? null : _importTransactions,
                child: Text(
                  _isImporting ? 'Importing...' : 'Save Imported Transactions',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
