import 'package:uuid/uuid.dart';

enum TransactionType { debit, credit, investment }

class TransactionModel {
  static const Object _unset = Object();

  TransactionModel({
    String? id,
    required this.amount,
    required this.merchant,
    this.bankRemark,
    this.category,
    required this.date,
    required this.type,
    this.note,
    DateTime? createdAt,
  }) : id = id ?? const Uuid().v4(),
       createdAt = createdAt ?? DateTime.now();

  final String id;
  final double amount;
  final String merchant;
  final String? bankRemark;
  final String? category;
  final DateTime date;
  final TransactionType type;
  final String? note;
  final DateTime createdAt;

  bool get needsCategory =>
      type != TransactionType.credit &&
      (category == null ||
          category!.trim().isEmpty ||
          category == 'Uncategorized');

  String get fingerprint {
    final normalizedRemark = _normalizeIdentityPart(bankRemark);
    final normalizedMerchant = _normalizeIdentityPart(merchant);
    final identityPart = normalizedRemark.isNotEmpty
        ? normalizedRemark
        : normalizedMerchant;
    return '${amount.toStringAsFixed(2)}|$identityPart';
  }

  static String _normalizeIdentityPart(String? value) {
    return (value ?? '')
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'\s+'), ' ');
  }

  TransactionModel copyWith({
    String? id,
    double? amount,
    String? merchant,
    String? bankRemark,
    Object? category = _unset,
    DateTime? date,
    TransactionType? type,
    String? note,
    DateTime? createdAt,
  }) {
    return TransactionModel(
      id: id ?? this.id,
      amount: amount ?? this.amount,
      merchant: merchant ?? this.merchant,
      bankRemark: bankRemark ?? this.bankRemark,
      category: identical(category, _unset) ? this.category : category as String?,
      date: date ?? this.date,
      type: type ?? this.type,
      note: note ?? this.note,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'amount': amount,
      'merchant': merchant,
      'bankRemark': bankRemark,
      'category': category,
      'date': date.toIso8601String(),
      'type': type.name,
      'note': note,
      'createdAt': createdAt.toIso8601String(),
      'fingerprint': fingerprint,
    };
  }

  static TransactionModel fromMap(Map<dynamic, dynamic> map) {
    final rawType = (map['type']?.toString().toLowerCase() ?? 'debit').trim();
    final parsedType = switch (rawType) {
      'credit' => TransactionType.credit,
      'investment' => TransactionType.investment,
      _ => TransactionType.debit,
    };

    final parsedDate =
        DateTime.tryParse(map['date']?.toString() ?? '') ?? DateTime.now();
    final parsedCreatedAt =
        DateTime.tryParse(map['createdAt']?.toString() ?? '') ?? DateTime.now();

    final rawAmount = map['amount'];
    final amount = rawAmount is num
        ? rawAmount.toDouble()
        : double.tryParse(rawAmount?.toString() ?? '') ?? 0;

    return TransactionModel(
      id: map['id']?.toString(),
      amount: amount,
      merchant: map['merchant']?.toString() ?? 'N/A',
      bankRemark: map['bankRemark']?.toString(),
      category: map['category']?.toString(),
      date: parsedDate,
      type: parsedType,
      note: map['note']?.toString(),
      createdAt: parsedCreatedAt,
    );
  }
}
