import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';

import '../models/transaction_model.dart';
import '../widgets/transaction_tile.dart';
import 'transaction_detail_screen.dart';

enum _TransactionViewFilter {
  all,
  credited,
  debited,
  investment,
  uncategorized,
}

class AllTransactionsScreen extends StatefulWidget {
  const AllTransactionsScreen({super.key});

  static const Color _primaryColor = Color(0xFF6C63FF);

  @override
  State<AllTransactionsScreen> createState() => _AllTransactionsScreenState();
}

class _AllTransactionsScreenState extends State<AllTransactionsScreen> {
  _TransactionViewFilter _filter = _TransactionViewFilter.all;
  Set<String> _selectedCategories = <String>{};
  DateTime? _fromDate;
  DateTime? _toDate;

  Color _backgroundColor(BuildContext context) =>
      Theme.of(context).scaffoldBackgroundColor;
  Color _surfaceColor(BuildContext context) => Theme.of(context).cardColor;
  Color _textColor(BuildContext context) =>
      Theme.of(context).colorScheme.onSurface;
  Color _mutedTextColor(BuildContext context) =>
      Theme.of(context).colorScheme.onSurfaceVariant;
  Color _softBorderColor(BuildContext context) =>
      Theme.of(context).dividerColor;

  List<_StoredTransaction> _readStoredTransactions(Box<dynamic> box) {
    final items = <_StoredTransaction>[];
    for (var index = 0; index < box.length; index++) {
      final raw = box.getAt(index);
      if (raw is Map) {
        items.add(
          _StoredTransaction(
            key: box.keyAt(index),
            transaction: TransactionModel.fromMap(raw.cast<dynamic, dynamic>()),
          ),
        );
      }
    }
    items.sort((a, b) => b.transaction.date.compareTo(a.transaction.date));
    return items;
  }

  Map<String, List<_StoredTransaction>> _groupByDate(
    List<_StoredTransaction> items,
  ) {
    final grouped = <String, List<_StoredTransaction>>{};
    for (final item in items) {
      final key = DateFormat('EEEE, dd MMM yyyy').format(item.transaction.date);
      grouped.putIfAbsent(key, () => <_StoredTransaction>[]).add(item);
    }
    return grouped;
  }

  List<String> _availableCategories(List<_StoredTransaction> items) {
    final categories =
        items
            .map((item) => item.transaction.category?.trim() ?? '')
            .where((value) => value.isNotEmpty)
            .toSet()
            .toList()
          ..sort();
    return categories;
  }

  List<_StoredTransaction> _applyFilters(List<_StoredTransaction> items) {
    return items
        .where((item) {
          final transaction = item.transaction;

          final filterMatches = switch (_filter) {
            _TransactionViewFilter.all => true,
            _TransactionViewFilter.credited =>
              transaction.type == TransactionType.credit,
            _TransactionViewFilter.debited =>
              transaction.type == TransactionType.debit,
            _TransactionViewFilter.investment =>
              transaction.type == TransactionType.investment,
            _TransactionViewFilter.uncategorized => transaction.needsCategory,
          };

          if (!filterMatches) {
            return false;
          }

          if (_selectedCategories.isNotEmpty) {
            final category = transaction.category?.trim() ?? '';
            if (!_selectedCategories.contains(category)) {
              return false;
            }
          }

          if (_fromDate != null) {
            final from = DateTime(
              _fromDate!.year,
              _fromDate!.month,
              _fromDate!.day,
            );
            final txDate = DateTime(
              transaction.date.year,
              transaction.date.month,
              transaction.date.day,
            );
            if (txDate.isBefore(from)) {
              return false;
            }
          }

          if (_toDate != null) {
            final to = DateTime(
              _toDate!.year,
              _toDate!.month,
              _toDate!.day,
              23,
              59,
              59,
            );
            if (transaction.date.isAfter(to)) {
              return false;
            }
          }

          return true;
        })
        .toList(growable: false);
  }

  Future<void> _openTransactionDetail(
    _StoredTransaction storedTransaction,
  ) async {
    await Navigator.of(context).push(
      MaterialPageRoute<bool>(
        builder: (_) => TransactionDetailScreen(
          transaction: storedTransaction.transaction,
          transactionKey: storedTransaction.key,
        ),
      ),
    );
  }

  Future<void> _pickDate({required bool isFromDate}) async {
    final initialDate = (isFromDate ? _fromDate : _toDate) ?? DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );

    if (picked == null) {
      return;
    }

    setState(() {
      if (isFromDate) {
        _fromDate = picked;
      } else {
        _toDate = picked;
      }
    });
  }

  Future<void> _openAdvancedFilters(List<String> categories) async {
    final tempCategories = _selectedCategories.toSet();
    DateTime? tempFromDate = _fromDate;
    DateTime? tempToDate = _toDate;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            Future<void> pickModalDate(bool isFromDate) async {
              final initialDate =
                  (isFromDate ? tempFromDate : tempToDate) ?? DateTime.now();
              final picked = await showDatePicker(
                context: context,
                initialDate: initialDate,
                firstDate: DateTime(2020),
                lastDate: DateTime.now().add(const Duration(days: 365)),
              );
              if (picked == null) {
                return;
              }
              setModalState(() {
                if (isFromDate) {
                  tempFromDate = picked;
                } else {
                  tempToDate = picked;
                }
              });
            }

            return SafeArea(
              child: Padding(
                padding: EdgeInsets.only(
                  left: 16,
                  right: 16,
                  bottom: MediaQuery.of(context).viewInsets.bottom + 16,
                  top: 16,
                ),
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: _surfaceColor(context),
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        'Filters',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(
                              color: _textColor(context),
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Categories',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: categories
                            .map(
                              (category) => FilterChip(
                                label: Text(category),
                                selected: tempCategories.contains(category),
                                onSelected: (selected) {
                                  setModalState(() {
                                    if (selected) {
                                      tempCategories.add(category);
                                    } else {
                                      tempCategories.remove(category);
                                    }
                                  });
                                },
                                selectedColor: AllTransactionsScreen
                                    ._primaryColor
                                    .withValues(alpha: 0.14),
                                labelStyle: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(
                                      color: tempCategories.contains(category)
                                          ? AllTransactionsScreen._primaryColor
                                          : _textColor(context),
                                      fontWeight: FontWeight.w600,
                                    ),
                                side: BorderSide(
                                  color: tempCategories.contains(category)
                                      ? AllTransactionsScreen._primaryColor
                                      : _softBorderColor(context),
                                ),
                              ),
                            )
                            .toList(growable: false),
                      ),
                      const SizedBox(height: 18),
                      Text(
                        'Date range',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: <Widget>[
                          Expanded(
                            child: _FilterDateField(
                              label: 'From',
                              value: tempFromDate,
                              onTap: () => pickModalDate(true),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _FilterDateField(
                              label: 'To',
                              value: tempToDate,
                              onTap: () => pickModalDate(false),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      Row(
                        children: <Widget>[
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () {
                                setState(() {
                                  _selectedCategories = <String>{};
                                  _fromDate = null;
                                  _toDate = null;
                                });
                                Navigator.of(context).pop();
                              },
                              child: const Text('Reset'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: FilledButton(
                              onPressed: () {
                                setState(() {
                                  _selectedCategories = tempCategories;
                                  _fromDate = tempFromDate;
                                  _toDate = tempToDate;
                                });
                                Navigator.of(context).pop();
                              },
                              style: FilledButton.styleFrom(
                                backgroundColor:
                                    AllTransactionsScreen._primaryColor,
                              ),
                              child: const Text('Apply'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final box = Hive.box('transactions');

    return Scaffold(
      backgroundColor: _backgroundColor(context),
      appBar: AppBar(
        backgroundColor: _backgroundColor(context),
        elevation: 0,
        scrolledUnderElevation: 0,
        titleSpacing: 0,
        title: Text(
          'All Transactions',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            color: _textColor(context),
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: SafeArea(
        child: ValueListenableBuilder(
          valueListenable: box.listenable(),
          builder: (context, Box<dynamic> box, _) {
            final allTransactions = _readStoredTransactions(box);
            final categories = _availableCategories(allTransactions);
            final transactions = _applyFilters(allTransactions);

            if (allTransactions.isEmpty) {
              return Center(
                child: Container(
                  margin: const EdgeInsets.all(20),
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: _surfaceColor(context),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: _softBorderColor(context)),
                  ),
                  child: Text(
                    'No transactions available yet.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: _mutedTextColor(context),
                    ),
                  ),
                ),
              );
            }

            final grouped = _groupByDate(transactions);
            final orderedKeys = grouped.keys.toList();

            return Column(
              children: <Widget>[
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 8, 14, 12),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: <Widget>[
                        _FilterChip(
                          label: 'All',
                          selected: _filter == _TransactionViewFilter.all,
                          mutedTextColor: _mutedTextColor(context),
                          surfaceColor: _surfaceColor(context),
                          borderColor: _softBorderColor(context),
                          onTap: () => setState(
                            () => _filter = _TransactionViewFilter.all,
                          ),
                        ),
                        const SizedBox(width: 10),
                        _FilterChip(
                          label: 'Credited',
                          selected: _filter == _TransactionViewFilter.credited,
                          mutedTextColor: _mutedTextColor(context),
                          surfaceColor: _surfaceColor(context),
                          borderColor: _softBorderColor(context),
                          onTap: () => setState(
                            () => _filter = _TransactionViewFilter.credited,
                          ),
                        ),
                        const SizedBox(width: 10),
                        _FilterChip(
                          label: 'Investment',
                          selected:
                              _filter == _TransactionViewFilter.investment,
                          mutedTextColor: _mutedTextColor(context),
                          surfaceColor: _surfaceColor(context),
                          borderColor: _softBorderColor(context),
                          onTap: () => setState(
                            () => _filter = _TransactionViewFilter.investment,
                          ),
                        ),
                        const SizedBox(width: 10),
                        _FilterChip(
                          label: 'Debited',
                          selected: _filter == _TransactionViewFilter.debited,
                          mutedTextColor: _mutedTextColor(context),
                          surfaceColor: _surfaceColor(context),
                          borderColor: _softBorderColor(context),
                          onTap: () => setState(
                            () => _filter = _TransactionViewFilter.debited,
                          ),
                        ),
                        const SizedBox(width: 10),
                        _FilterChip(
                          label: 'Uncategorized',
                          selected:
                              _filter == _TransactionViewFilter.uncategorized,
                          mutedTextColor: _mutedTextColor(context),
                          surfaceColor: _surfaceColor(context),
                          borderColor: _softBorderColor(context),
                          onTap: () => setState(
                            () =>
                                _filter = _TransactionViewFilter.uncategorized,
                          ),
                        ),
                        const SizedBox(width: 10),
                        _FilterChip(
                          label: 'Filters',
                          icon: Icons.filter_alt_outlined,
                          mutedTextColor: _mutedTextColor(context),
                          surfaceColor: _surfaceColor(context),
                          borderColor: _softBorderColor(context),
                          selected:
                              _selectedCategories.isNotEmpty ||
                              _fromDate != null ||
                              _toDate != null,
                          onTap: () => _openAdvancedFilters(categories),
                        ),
                      ],
                    ),
                  ),
                ),
                if (transactions.isEmpty)
                  Expanded(
                    child: Center(
                      child: Container(
                        margin: const EdgeInsets.all(20),
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: _surfaceColor(context),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: _softBorderColor(context)),
                        ),
                        child: Text(
                          'No transactions match your filters.',
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(color: _mutedTextColor(context)),
                        ),
                      ),
                    ),
                  )
                else
                  Expanded(
                    child: ListView.builder(
                      padding: const EdgeInsets.fromLTRB(14, 0, 14, 24),
                      itemCount: orderedKeys.length,
                      itemBuilder: (context, index) {
                        final dateKey = orderedKeys[index];
                        final items = grouped[dateKey]!;
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 18),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 4,
                                ),
                                child: Text(
                                  dateKey,
                                  style: Theme.of(context).textTheme.titleSmall
                                      ?.copyWith(
                                        color: _textColor(context),
                                        fontWeight: FontWeight.w700,
                                      ),
                                ),
                              ),
                              const SizedBox(height: 10),
                              ...items.map(
                                (item) => Padding(
                                  padding: const EdgeInsets.only(bottom: 12),
                                  child: TransactionTile(
                                    transaction: item.transaction,
                                    onTap: () => _openTransactionDetail(item),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
    required this.mutedTextColor,
    required this.surfaceColor,
    required this.borderColor,
    this.icon,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Color mutedTextColor;
  final Color surfaceColor;
  final Color borderColor;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final color = selected
        ? AllTransactionsScreen._primaryColor
        : mutedTextColor;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: selected
              ? AllTransactionsScreen._primaryColor.withValues(alpha: 0.12)
              : surfaceColor,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected ? AllTransactionsScreen._primaryColor : borderColor,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            if (icon != null) ...<Widget>[
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 6),
            ],
            Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: color,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FilterDateField extends StatelessWidget {
  const _FilterDateField({
    required this.label,
    required this.value,
    required this.onTap,
  });

  final String label;
  final DateTime? value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final mutedTextColor = Theme.of(context).colorScheme.onSurfaceVariant;
    final textColor = Theme.of(context).colorScheme.onSurface;
    final borderColor = Theme.of(context).dividerColor;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Ink(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: borderColor),
        ),
        child: Row(
          children: <Widget>[
            Icon(
              Icons.calendar_today_outlined,
              size: 16,
              color: mutedTextColor,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                value == null
                    ? label
                    : DateFormat('dd MMM yyyy').format(value!),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: value == null ? mutedTextColor : textColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StoredTransaction {
  _StoredTransaction({required this.key, required this.transaction});

  final dynamic key;
  final TransactionModel transaction;
}
