import 'package:equatable/equatable.dart';

enum ExpenseCategory {
  payout,
  administrative,
  hallRental,
  funeralEquipment,
  other,
}

extension ExpenseCategoryX on ExpenseCategory {
  String get name => switch (this) {
        ExpenseCategory.payout => 'payout',
        ExpenseCategory.administrative => 'administrative',
        ExpenseCategory.hallRental => 'hallRental',
        ExpenseCategory.funeralEquipment => 'funeralEquipment',
        ExpenseCategory.other => 'other',
      };

  static ExpenseCategory fromString(String? s) => switch (s?.toLowerCase()) {
        'payout' => ExpenseCategory.payout,
        'administrative' => ExpenseCategory.administrative,
        'hallrental' => ExpenseCategory.hallRental,
        'funeralequipment' => ExpenseCategory.funeralEquipment,
        _ => ExpenseCategory.other,
      };
}

class Expense extends Equatable {
  const Expense({
    required this.id,
    required this.voucherNumber,
    required this.category,
    required this.amount,
    required this.description,
    this.claimId,
    this.isReversal = false,
    this.reversalOfId,
    this.reversalReason,
    this.isReversed = false,
    required this.recordedByUid,
    required this.recordedByName,
    required this.createdAt,
  });

  factory Expense.fromMap(String id, Map<String, dynamic> map) {
    return Expense(
      id: id,
      voucherNumber: map['voucherNumber'] as String? ?? 'EXP-001',
      category: ExpenseCategoryX.fromString(map['category'] as String?),
      amount: (map['amount'] as num?)?.toDouble() ?? 0.0,
      description: map['description'] as String? ?? '',
      claimId: map['claimId'] as String?,
      isReversal: map['isReversal'] as bool? ?? false,
      reversalOfId: map['reversalOfId'] as String?,
      reversalReason: map['reversalReason'] as String?,
      isReversed: map['isReversed'] as bool? ?? false,
      recordedByUid: map['recordedByUid'] as String? ?? '',
      recordedByName: map['recordedByName'] as String? ?? '',
      createdAt: map['createdAt'] != null
          ? DateTime.tryParse(map['createdAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  final String id;
  final String voucherNumber;
  final ExpenseCategory category;
  final double amount;
  final String description;
  final String? claimId;
  final bool isReversal;
  final String? reversalOfId;
  final String? reversalReason;
  final bool isReversed;
  final String recordedByUid;
  final String recordedByName;
  final DateTime createdAt;

  Expense copyWith({
    String? id,
    String? voucherNumber,
    ExpenseCategory? category,
    double? amount,
    String? description,
    String? claimId,
    bool? isReversal,
    String? reversalOfId,
    String? reversalReason,
    bool? isReversed,
    String? recordedByUid,
    String? recordedByName,
    DateTime? createdAt,
  }) {
    return Expense(
      id: id ?? this.id,
      voucherNumber: voucherNumber ?? this.voucherNumber,
      category: category ?? this.category,
      amount: amount ?? this.amount,
      description: description ?? this.description,
      claimId: claimId ?? this.claimId,
      isReversal: isReversal ?? this.isReversal,
      reversalOfId: reversalOfId ?? this.reversalOfId,
      reversalReason: reversalReason ?? this.reversalReason,
      isReversed: isReversed ?? this.isReversed,
      recordedByUid: recordedByUid ?? this.recordedByUid,
      recordedByName: recordedByName ?? this.recordedByName,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toMap() => {
        'voucherNumber': voucherNumber,
        'category': category.name,
        'amount': amount,
        'description': description,
        if (claimId != null) 'claimId': claimId,
        'isReversal': isReversal,
        if (reversalOfId != null) 'reversalOfId': reversalOfId,
        if (reversalReason != null) 'reversalReason': reversalReason,
        'isReversed': isReversed,
        'recordedByUid': recordedByUid,
        'recordedByName': recordedByName,
        'createdAt': createdAt.toIso8601String(),
      };

  @override
  List<Object?> get props => [
        id,
        voucherNumber,
        category,
        amount,
        description,
        claimId,
        isReversal,
        reversalOfId,
        reversalReason,
        isReversed,
        recordedByUid,
        recordedByName,
        createdAt,
      ];
}
