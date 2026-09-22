import 'package:flutter/foundation.dart' hide Category;

import 'category.dart';

/// Whether money came in or went out.
enum TxnType { debit, credit }

/// How this transaction entered the app.
enum TxnSource { sms, manual }

/// A single money movement. Immutable with [copyWith] + id-based equality.
@immutable
class Transaction {
  const Transaction({
    required this.id,
    required this.title,
    required this.amount,
    required this.type,
    required this.categoryId,
    required this.date,
    this.source = TxnSource.manual,
    this.account,
    this.rawSms,
    this.note,
  });

  final String id;

  /// Merchant / payee name shown in the list (e.g. "Zomato", "Dribbble Pro").
  final String title;

  /// Always a positive magnitude; direction is carried by [type].
  final double amount;
  final TxnType type;
  final String categoryId;
  final DateTime date;
  final TxnSource source;

  /// e.g. "HDFC ••4021" or a UPI handle.
  final String? account;

  /// Original SMS body (kept for auditability / re-parsing).
  final String? rawSms;
  final String? note;

  Category get category => Categories.byId(categoryId);

  bool get isCredit => type == TxnType.credit;

  /// Amount signed for math: negative when it leaves your account.
  double get signedAmount => isCredit ? amount : -amount;

  Transaction copyWith({
    String? id,
    String? title,
    double? amount,
    TxnType? type,
    String? categoryId,
    DateTime? date,
    TxnSource? source,
    String? account,
    String? rawSms,
    String? note,
  }) {
    return Transaction(
      id: id ?? this.id,
      title: title ?? this.title,
      amount: amount ?? this.amount,
      type: type ?? this.type,
      categoryId: categoryId ?? this.categoryId,
      date: date ?? this.date,
      source: source ?? this.source,
      account: account ?? this.account,
      rawSms: rawSms ?? this.rawSms,
      note: note ?? this.note,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'amount': amount,
        'type': type.name,
        'category_id': categoryId,
        'date': date.toIso8601String(),
        'source': source.name,
        'account': account,
        'raw_sms': rawSms,
        'note': note,
      };

  factory Transaction.fromJson(Map<String, dynamic> json) {
    return Transaction(
      id: json['id'] as String,
      title: json['title'] as String,
      amount: (json['amount'] as num).toDouble(),
      type: TxnType.values.byName(json['type'] as String),
      categoryId: json['category_id'] as String,
      date: DateTime.parse(json['date'] as String),
      source: TxnSource.values
          .byName((json['source'] as String?) ?? TxnSource.manual.name),
      account: json['account'] as String?,
      rawSms: json['raw_sms'] as String?,
      note: json['note'] as String?,
    );
  }

  @override
  bool operator ==(Object other) => other is Transaction && other.id == id;

  @override
  int get hashCode => id.hashCode;
}
