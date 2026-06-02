import 'dart:typed_data';

import 'package:excel/excel.dart';
import 'package:intl/intl.dart';

import '../models/transaction_model.dart';
import 'category_service.dart';
import 'transaction_parser.dart';

class ImportParseResult {
  ImportParseResult({
    required this.transactions,
    required this.skippedRows,
    required this.failedRows,
  });

  final List<TransactionModel> transactions;
  final int skippedRows;
  final int failedRows;
}

class XlsxImportService {
  static ImportParseResult parseBytes(Uint8List bytes) {
    final excel = Excel.decodeBytes(bytes);
    if (excel.tables.isEmpty) {
      return ImportParseResult(
        transactions: <TransactionModel>[],
        skippedRows: 0,
        failedRows: 0,
      );
    }

    final firstSheet = excel.tables.values.first;
    if (firstSheet.rows.isEmpty) {
      return ImportParseResult(
        transactions: <TransactionModel>[],
        skippedRows: 0,
        failedRows: 0,
      );
    }

    final headerRow = firstSheet.rows.first;
    final headers = headerRow
        .map(
          (Data? cell) => (cell?.value ?? '').toString().trim().toLowerCase(),
        )
        .toList();

    final dateIndex = _findIndex(headers, <String>[
      'date',
      'txn date',
      'transaction date',
      'value date',
    ]);
    final narrationIndex = _findIndex(headers, <String>[
      'narration',
      'description',
      'remarks',
      'particulars',
    ]);
    final debitIndex = _findIndex(headers, <String>[
      'debit',
      'withdrawal',
      'withdraw',
      'dr amount',
    ]);
    final creditIndex = _findIndex(headers, <String>[
      'credit',
      'deposit',
      'cr amount',
    ]);
    final amountIndex = _findIndex(headers, <String>[
      'amount',
      'txn amount',
      'transaction amount',
    ]);

    final List<TransactionModel> transactions = <TransactionModel>[];
    var skippedRows = 0;
    var failedRows = 0;

    for (var rowIndex = 1; rowIndex < firstSheet.rows.length; rowIndex++) {
      final row = firstSheet.rows[rowIndex];
      if (_isRowEmpty(row)) {
        skippedRows++;
        continue;
      }

      try {
        final narration = _readValue(row, narrationIndex) ?? 'Unknown';
        final date = _parseDate(_readValue(row, dateIndex));

        final debitValue = _parseAmount(_readValue(row, debitIndex));
        final creditValue = _parseAmount(_readValue(row, creditIndex));
        final fallbackAmount = _parseAmount(_readValue(row, amountIndex));

        final TransactionType type;
        final double amount;

        if (debitValue > 0) {
          type = TransactionType.debit;
          amount = debitValue;
        } else if (creditValue > 0) {
          type = TransactionType.credit;
          amount = creditValue;
        } else if (fallbackAmount > 0) {
          type = TransactionType.debit;
          amount = fallbackAmount;
        } else {
          skippedRows++;
          continue;
        }

        String? category;
        if (type == TransactionType.debit) {
          category =
              CategoryService.getMerchantCategorySuggestion(narration) ??
              TransactionParser.suggestCategory(narration);
        }

        transactions.add(
          TransactionModel(
            amount: amount,
            merchant: narration,
            category: type == TransactionType.debit ? category : null,
            date: date,
            type: type,
          ),
        );
      } catch (_) {
        failedRows++;
      }
    }

    return ImportParseResult(
      transactions: transactions,
      skippedRows: skippedRows,
      failedRows: failedRows,
    );
  }

  static int _findIndex(List<String> headers, List<String> aliases) {
    for (var i = 0; i < headers.length; i++) {
      for (final alias in aliases) {
        if (headers[i] == alias) {
          return i;
        }
      }
    }
    return -1;
  }

  static String? _readValue(List<Data?> row, int index) {
    if (index < 0 || index >= row.length) {
      return null;
    }
    final cellValue = row[index]?.value;
    if (cellValue == null) {
      return null;
    }
    final value = cellValue.toString().trim();
    return value.isEmpty ? null : value;
  }

  static DateTime _parseDate(String? input) {
    if (input == null || input.trim().isEmpty) {
      return DateTime.now();
    }

    final raw = input.trim();

    final parsedDirect = DateTime.tryParse(raw);
    if (parsedDirect != null) {
      return parsedDirect;
    }

    final formats = <DateFormat>[
      DateFormat('dd/MM/yyyy'),
      DateFormat('dd-MM-yyyy'),
      DateFormat('MM/dd/yyyy'),
      DateFormat('dd MMM yyyy'),
      DateFormat('dd-MMM-yyyy'),
    ];

    for (final format in formats) {
      try {
        return format.parseStrict(raw);
      } catch (_) {
        continue;
      }
    }

    final serial = double.tryParse(raw);
    if (serial != null) {
      final excelEpoch = DateTime(1899, 12, 30);
      return excelEpoch.add(Duration(days: serial.toInt()));
    }

    return DateTime.now();
  }

  static double _parseAmount(String? input) {
    if (input == null) {
      return 0;
    }

    var value = input
        .replaceAll(',', '')
        .replaceAll('₹', '')
        .replaceAll('Rs.', '')
        .replaceAll('CR', '')
        .replaceAll('DR', '')
        .trim();

    if (value.startsWith('(') && value.endsWith(')')) {
      value = '-${value.substring(1, value.length - 1)}';
    }

    return double.tryParse(value) ?? 0;
  }

  static bool _isRowEmpty(List<Data?> row) {
    for (final cell in row) {
      if ((cell?.value ?? '').toString().trim().isNotEmpty) {
        return false;
      }
    }
    return true;
  }
}
