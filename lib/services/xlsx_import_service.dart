import 'dart:typed_data';

import 'package:excel/excel.dart';
import 'package:excel2003/excel2003.dart';
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
  static const List<String> _serialAliases = <String>[
    's no.',
    's no',
    'sr no.',
    'serial no.',
  ];
  static const List<String> _dateAliases = <String>[
    'date',
    'txn date',
    'transaction date',
    'value date',
  ];
  static const List<String> _narrationAliases = <String>[
    'narration',
    'description',
    'remarks',
    'particulars',
    'details',
    'transaction remarks',
  ];
  static const List<String> _debitAliases = <String>[
    'debit',
    'withdrawal',
    'withdraw',
    'dr amount',
    'debit amount',
    'withdrawal amount(inr)',
    'withdrawal amount',
  ];
  static const List<String> _creditAliases = <String>[
    'credit',
    'deposit',
    'cr amount',
    'credit amount',
    'deposit amount(inr)',
    'deposit amount',
  ];
  static const List<String> _amountAliases = <String>[
    'amount',
    'txn amount',
    'transaction amount',
  ];
  static const List<String> _referenceAliases = <String>[
    'chq./ref.no.',
    'ref no',
    'reference',
    'reference number',
    'utr',
  ];
  static const List<int> _xlsMagicHeader = <int>[
    0xD0,
    0xCF,
    0x11,
    0xE0,
    0xA1,
    0xB1,
    0x1A,
    0xE1,
  ];

  static ImportParseResult parseBytes(Uint8List bytes, {String? fileName}) {
    final rows = _isLegacyXls(bytes, fileName)
        ? _extractRowsFromXls(bytes)
        : _extractRowsFromXlsx(bytes);

    final transactions = <TransactionModel>[];
    var skippedRows = 0;
    var failedRows = 0;

    for (final row in rows) {
      if (_isRowEmpty(row)) {
        skippedRows++;
        continue;
      }

      try {
        final bankRemark = _readMappedValue(row, _narrationAliases);
        final date = _parseDate(_readMappedValue(row, _dateAliases));
        final debitValue = _parseAmount(_readMappedValue(row, _debitAliases));
        final creditValue = _parseAmount(_readMappedValue(row, _creditAliases));
        final fallbackAmount = _parseAmount(
          _readMappedValue(row, _amountAliases),
        );
        final reference = _readMappedValue(row, _referenceAliases);

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
              CategoryService.getMerchantCategorySuggestion(bankRemark ?? '') ??
              TransactionParser.suggestCategory(bankRemark ?? '');
        }

        transactions.add(
          TransactionModel(
            amount: amount,
            merchant: 'N/A',
            bankRemark: bankRemark,
            category: type == TransactionType.debit ? category : null,
            date: date,
            type: type,
            note: reference,
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

  static List<Map<String, dynamic>> _extractRowsFromXls(Uint8List bytes) {
    final reader = XlsReader.fromBytes(bytes);
    if (reader.sheetCount == 0) {
      return <Map<String, dynamic>>[];
    }

    final firstSheet = reader.sheet(0);
    return _rowsToMappedData(firstSheet.rows);
  }

  static List<Map<String, dynamic>> _extractRowsFromXlsx(Uint8List bytes) {
    final excel = Excel.decodeBytes(bytes);
    if (excel.tables.isEmpty) {
      return <Map<String, dynamic>>[];
    }

    final firstSheet = excel.tables.values.first;
    if (firstSheet.rows.isEmpty) {
      return <Map<String, dynamic>>[];
    }

    final rawRows = firstSheet.rows
        .map(
          (row) => row.map((Data? cell) => cell?.value).toList(growable: false),
        )
        .toList(growable: false);

    return _rowsToMappedData(rawRows);
  }

  static List<Map<String, dynamic>> _rowsToMappedData(
    List<List<dynamic>> rawRows,
  ) {
    if (rawRows.isEmpty) {
      return <Map<String, dynamic>>[];
    }

    final headerRowIndex = _findHeaderRowIndex(rawRows);
    if (headerRowIndex == null || headerRowIndex >= rawRows.length) {
      return <Map<String, dynamic>>[];
    }

    final headers = rawRows[headerRowIndex]
        .map((cell) => cell?.toString().trim() ?? '')
        .toList(growable: false);

    final rows = <Map<String, dynamic>>[];
    for (
      var rowIndex = headerRowIndex + 1;
      rowIndex < rawRows.length;
      rowIndex++
    ) {
      final row = rawRows[rowIndex];
      final mapped = <String, dynamic>{};
      for (var cellIndex = 0; cellIndex < headers.length; cellIndex++) {
        final header = headers[cellIndex].isEmpty
            ? 'Column$cellIndex'
            : headers[cellIndex];
        mapped[header] = cellIndex < row.length ? row[cellIndex] : null;
      }
      rows.add(mapped);
    }
    return rows;
  }

  static int? _findHeaderRowIndex(List<List<dynamic>> rawRows) {
    for (var rowIndex = 0; rowIndex < rawRows.length; rowIndex++) {
      final normalizedCells = rawRows[rowIndex]
          .map((cell) => _normalizeHeader(cell?.toString() ?? ''))
          .where((cell) => cell.isNotEmpty)
          .toSet();

      final hasSerial = _containsAnyAlias(normalizedCells, _serialAliases);
      final hasDate = _containsAnyAlias(normalizedCells, _dateAliases);
      final hasNarration = _containsAnyAlias(
        normalizedCells,
        _narrationAliases,
      );
      final hasDebitOrCredit =
          _containsAnyAlias(normalizedCells, _debitAliases) ||
          _containsAnyAlias(normalizedCells, _creditAliases);

      if (hasSerial && hasDate && hasNarration && hasDebitOrCredit) {
        return rowIndex;
      }
    }

    return null;
  }

  static bool _containsAnyAlias(
    Set<String> normalizedCells,
    List<String> aliases,
  ) {
    for (final alias in aliases) {
      if (normalizedCells.contains(_normalizeHeader(alias))) {
        return true;
      }
    }
    return false;
  }

  static String _normalizeHeader(String header) {
    return header.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
  }

  static bool _isLegacyXls(Uint8List bytes, String? fileName) {
    final name = (fileName ?? '').toLowerCase().trim();
    if (name.endsWith('.xls')) {
      return true;
    }
    if (bytes.length < _xlsMagicHeader.length) {
      return false;
    }
    for (var i = 0; i < _xlsMagicHeader.length; i++) {
      if (bytes[i] != _xlsMagicHeader[i]) {
        return false;
      }
    }
    return true;
  }

  static String? _readMappedValue(
    Map<String, dynamic> row,
    List<String> aliases,
  ) {
    final normalized = <String, dynamic>{};
    row.forEach((key, value) {
      normalized[_normalizeHeader(key)] = value;
    });

    for (final alias in aliases) {
      final value = normalized[_normalizeHeader(alias)];
      if (value == null) {
        continue;
      }
      final text = value.toString().trim();
      if (text.isNotEmpty) {
        return text;
      }
    }
    return null;
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
      DateFormat('dd,MM,yyyy'),
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

  static bool _isRowEmpty(Map<String, dynamic> row) {
    for (final value in row.values) {
      if ((value ?? '').toString().trim().isNotEmpty) {
        return false;
      }
    }
    return true;
  }
}
