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
  static const Color _backgroundColor = Color(0xFFF6F7FB);
  static const Color _surfaceColor = Colors.white;
  static const Color _heroColor = Color(0xFF16171D);
  static const Color _primaryColor = Color(0xFF6C63FF);
  static const Color _expenseColor = Color(0xFFEF4444);
  static const Color _successColor = Color(0xFF22C55E);
  static const Color _warningColor = Color(0xFFF59E0B);
  static const Color _secondaryTextColor = Color(0xFF6B7280);
  static const Color _textColor = Color(0xFF14161F);
  static const Color _mutedTextColor = Color(0xFF8B90A0);
  static const Color _softBorderColor = Color(0xFFE9EBF2);

  List<TransactionModel> _parsedTransactions = <TransactionModel>[];
  int _skippedRows = 0;
  int _failedRows = 0;
  int _duplicateRows = 0;
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
      final existingFingerprints = _loadExistingFingerprints();
      var duplicateRows = 0;
      for (final transaction in parsed.transactions) {
        if (existingFingerprints.contains(transaction.fingerprint)) {
          duplicateRows++;
        }
      }

      setState(() {
        _fileName = file.name;
        _parsedTransactions = parsed.transactions;
        _skippedRows = parsed.skippedRows;
        _failedRows = parsed.failedRows;
        _duplicateRows = duplicateRows;
      });
    } finally {
      if (mounted) {
        setState(() {
          _isParsing = false;
        });
      }
    }
  }

  Set<String> _loadExistingFingerprints() {
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

    return existingFingerprints;
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
    final existingFingerprints = _loadExistingFingerprints();

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

  int get _processedCount => _parsedTransactions.length;

  bool get _hasParsedFile => _fileName != null;

  bool get _hasSuccessfulParse =>
      _hasParsedFile && _processedCount > 0 && !_isParsing;

  double get _statusProgress {
    if (_isParsing) {
      return 0;
    }
    if (_hasParsedFile) {
      return 1;
    }
    return 0;
  }

  String get _statusText {
    if (_isParsing) {
      return 'Parsing statement...';
    }
    if (_fileName == null) {
      return 'Waiting for file...';
    }
    if (_hasSuccessfulParse) {
      return 'Parsing complete';
    }
    return 'Review parsing result';
  }

  String get _qualityLabel {
    if (_fileName == null) {
      return '0%';
    }
    if (_isParsing) {
      return 'Parsing';
    }
    return '100%';
  }

  String _fileSubtitle() {
    if (_fileName == null) {
      return 'Upload an Excel statement to preview parsing quality.';
    }
    return 'Last updated ${DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.now())}';
  }

  String get _successSummary {
    if (!_hasParsedFile) {
      return 'Choose a statement file to begin parsing.';
    }
    if (_hasSuccessfulParse) {
      return '$_processedCount transactions are ready for import.';
    }
    if (_isParsing) {
      return 'We are checking the statement structure and extracting transactions.';
    }
    return 'The file was parsed with warnings. Review skipped and failed rows below.';
  }

  Widget _buildSectionCard({required Widget child, EdgeInsets? padding}) {
    return Container(
      padding: padding ?? const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _surfaceColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _softBorderColor),
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: Color(0x080F172A),
            blurRadius: 14,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _buildUploadSection(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          'Upload File',
          style: textTheme.titleSmall?.copyWith(
            color: _textColor,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 12),
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 340),
            child: InkWell(
              onTap: _isParsing ? null : _pickAndParseFile,
              borderRadius: BorderRadius.circular(18),
              child: Ink(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 22),
                decoration: BoxDecoration(
                  color: const Color(0xFFD8D8DB),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: <Widget>[
                    Container(
                      width: 54,
                      height: 54,
                      decoration: const BoxDecoration(
                        color: Color(0xFFBBBBBF),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.upload_file_outlined,
                        color: _heroColor,
                        size: 28,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      _isParsing ? 'Parsing file...' : 'Select XLS / XLSX File',
                      textAlign: TextAlign.center,
                      style: textTheme.titleSmall?.copyWith(
                        color: _heroColor,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _fileName ?? 'Maximum file size: 10MB',
                      textAlign: TextAlign.center,
                      style: textTheme.bodySmall?.copyWith(
                        color: const Color(0xFF494C55),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F2F5),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        'Supported files: XLS, XLSX',
                        style: textTheme.labelSmall?.copyWith(
                          color: _secondaryTextColor,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStatusSection(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Text(
              'Processing Status',
              style: textTheme.titleSmall?.copyWith(
                color: _textColor,
                fontWeight: FontWeight.w700,
              ),
            ),
            const Spacer(),
            Icon(
              _isParsing
                  ? Icons.autorenew_rounded
                  : _hasParsedFile
                  ? Icons.check_circle_rounded
                  : Icons.timelapse_rounded,
              size: 14,
              color: _isParsing
                  ? _secondaryTextColor
                  : _hasParsedFile
                  ? _successColor
                  : _secondaryTextColor,
            ),
            const SizedBox(width: 4),
            Text(
              _statusText,
              style: textTheme.labelSmall?.copyWith(
                color: _isParsing
                    ? _secondaryTextColor
                    : _hasParsedFile
                    ? _successColor
                    : _secondaryTextColor,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _buildSectionCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          _fileName ?? 'Bank_Statement_May_2026.xlsx',
                          style: textTheme.titleSmall?.copyWith(
                            color: _textColor,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _fileSubtitle(),
                          style: textTheme.bodySmall?.copyWith(
                            color: _secondaryTextColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    _qualityLabel,
                    style: textTheme.titleSmall?.copyWith(
                      color: _hasParsedFile ? _successColor : _textColor,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: LinearProgressIndicator(
                  value: _isParsing ? null : _statusProgress,
                  minHeight: 7,
                  backgroundColor: const Color(0xFFF1F2F5),
                  valueColor: AlwaysStoppedAnimation<Color>(
                    _hasParsedFile ? _successColor : _primaryColor,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: _hasParsedFile
                      ? const Color(0xFFEFFAF3)
                      : const Color(0xFFF8F9FD),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _hasParsedFile
                        ? const Color(0xFFC9EDD3)
                        : const Color(0xFFE9EBF2),
                  ),
                ),
                child: Row(
                  children: <Widget>[
                    Icon(
                      _hasParsedFile
                          ? Icons.task_alt_rounded
                          : Icons.info_outline_rounded,
                      size: 18,
                      color: _hasParsedFile ? _successColor : _secondaryTextColor,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _successSummary,
                        style: textTheme.bodySmall?.copyWith(
                          color: _hasParsedFile
                              ? const Color(0xFF166534)
                              : _secondaryTextColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: <Widget>[
                  Expanded(
                    child: _ImportMetricTile(
                      icon: Icons.check_circle_outline_rounded,
                      label: 'Parsed',
                      value: '$_processedCount',
                      accent: _primaryColor,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _ImportMetricTile(
                      icon: Icons.content_cut_rounded,
                      label: 'Skipped',
                      value: '$_skippedRows',
                      accent: _warningColor,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _ImportMetricTile(
                      icon: Icons.error_outline_rounded,
                      label: 'Failed',
                      value: '$_failedRows',
                      accent: _expenseColor,
                    ),
                  ),
                ],
              ),
              if (_duplicateRows > 0) ...<Widget>[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF6E8),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: <Widget>[
                      const Icon(
                        Icons.copy_all_rounded,
                        size: 16,
                        color: _warningColor,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '$_duplicateRows possible duplicates will be skipped during import.',
                          style: textTheme.bodySmall?.copyWith(
                            color: const Color(0xFF8A5A00),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildHowToImport(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return _buildSectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'HOW TO IMPORT',
            style: textTheme.labelMedium?.copyWith(
              color: _mutedTextColor,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.7,
            ),
          ),
          const SizedBox(height: 16),
          const _InstructionStep(
            index: '1',
            title: 'Download Statement',
            description:
                'Export your bank transactions as an Excel or XLSX file from your banking app.',
          ),
          const SizedBox(height: 14),
          const _InstructionStep(
            index: '2',
            title: 'Upload & Parse',
            description:
                'Drop the file here. AppFinance will automatically categorize your expenses.',
          ),
          const SizedBox(height: 14),
          const _InstructionStep(
            index: '3',
            title: 'Review & Confirm',
            description:
                'Check the summary below and save the transactions to your dashboard.',
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _backgroundColor,
      appBar: AppBar(
        backgroundColor: _backgroundColor,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleSpacing: 0,
        title: Text(
          'Import Statement',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            color: _textColor,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: <Widget>[
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(14, 8, 14, 12),
                children: <Widget>[
                  _buildUploadSection(context),
                  const SizedBox(height: 14),
                  _buildStatusSection(context),
                  const SizedBox(height: 14),
                  _buildHowToImport(context),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(14, 8, 14, 16),
              decoration: const BoxDecoration(
                color: _backgroundColor,
                border: Border(top: BorderSide(color: Color(0xFFEDEEF4))),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: FilledButton.icon(
                      onPressed: _isImporting ? null : _importTransactions,
                      style: FilledButton.styleFrom(
                        backgroundColor: _heroColor,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        textStyle: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      icon: _isImporting
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.file_upload_outlined),
                      label: Text(
                        _isImporting
                            ? 'Importing...'
                            : 'Save Imported Transactions',
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextButton(
                    onPressed: _isImporting ? null : () => Navigator.of(context).maybePop(),
                    style: TextButton.styleFrom(foregroundColor: _secondaryTextColor),
                    child: const Text('Cancel and Return to Dashboard'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ImportMetricTile extends StatelessWidget {
  const _ImportMetricTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.accent,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F9FD),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(icon, size: 16, color: accent),
          const SizedBox(height: 8),
          Text(
            value,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: const Color(0xFF14161F),
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: const Color(0xFF8B90A0),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _InstructionStep extends StatelessWidget {
  const _InstructionStep({
    required this.index,
    required this.title,
    required this.description,
  });

  final String index;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Container(
          width: 22,
          height: 22,
          alignment: Alignment.center,
          decoration: const BoxDecoration(
            color: Color(0xFF16171D),
            shape: BoxShape.circle,
          ),
          child: Text(
            index,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                title,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: const Color(0xFF14161F),
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                description,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: const Color(0xFF6B7280),
                  height: 1.45,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
