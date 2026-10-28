import 'package:equatable/equatable.dart';

enum PaymentMethod { cash, telebirr, cbeBirr, bankTransfer }

extension PaymentMethodX on PaymentMethod {
  String get name => switch (this) {
        PaymentMethod.cash => 'cash',
        PaymentMethod.telebirr => 'telebirr',
        PaymentMethod.cbeBirr => 'cbe_birr',
        PaymentMethod.bankTransfer => 'bank_transfer',
      };

  static PaymentMethod fromString(String? s) => switch (s?.toLowerCase()) {
        'telebirr' => PaymentMethod.telebirr,
        'cbe_birr' || 'cbebirr' => PaymentMethod.cbeBirr,
        'bank_transfer' || 'bank' => PaymentMethod.bankTransfer,
        _ => PaymentMethod.cash,
      };
}

class Contribution extends Equatable {
  const Contribution({
    required this.id,
    required this.receiptNumber,
    required this.memberId,
    required this.memberName,
    required this.amount,
    required this.date,
    required this.recordedByUid,
    required this.recordedByName,
    required this.paymentMethod,
    required this.periodMonth,
    required this.periodYear,
    this.notes = '',
    this.purpose,
    this.status,
    this.isReversal = false,
    this.reversalOfId,
    this.reversalReason,
    this.isReversed = false,
    required this.createdAt,
  });

  factory Contribution.fromMap(String docId, Map<String, dynamic> map) {
    DateTime parseDate(dynamic value) {
      if (value == null) return DateTime.now();
      if (value is DateTime) return value;
      try {
        return (value as dynamic).toDate() as DateTime;
      } catch (_) {
        return DateTime.tryParse(value.toString()) ?? DateTime.now();
      }
    }

    return Contribution(
      id: docId,
      receiptNumber: map['receiptNumber'] as String? ?? '',
      memberId: map['memberId'] as String? ?? '',
      memberName: map['memberName'] as String? ?? '',
      amount: (map['amount'] as num?)?.toDouble() ?? 0.0,
      date: parseDate(map['date']),
      recordedByUid: map['recordedByUid'] as String? ?? '',
      recordedByName: map['recordedByName'] as String? ?? '',
      paymentMethod:
          PaymentMethodX.fromString(map['paymentMethod'] as String?),
      periodMonth: (map['periodMonth'] as num?)?.toInt() ?? DateTime.now().month,
      periodYear: (map['periodYear'] as num?)?.toInt() ?? DateTime.now().year,
      notes: map['notes'] as String? ?? '',
      purpose: map['purpose'] as String? ?? map['notes'] as String?,
      status: map['status'] as String?,
      isReversal: map['isReversal'] as bool? ?? false,
      reversalOfId: map['reversalOfId'] as String?,
      reversalReason: map['reversalReason'] as String?,
      isReversed: map['isReversed'] as bool? ?? false,
      createdAt: parseDate(map['createdAt']),
    );
  }

  final String id;
  final String receiptNumber;
  final String memberId;
  final String memberName;
  final double amount;
  final DateTime date;
  final String recordedByUid;
  final String recordedByName;
  final PaymentMethod paymentMethod;
  final int periodMonth;
  final int periodYear;
  final String notes;
  final String? purpose;
  final String? status;
  final bool isReversal;
  final String? reversalOfId;
  final String? reversalReason;
  final bool isReversed;
  final DateTime createdAt;

  bool get isVerified =>
      !isReversal &&
      !isReversed &&
      (status == null ||
          status!.toUpperCase() == 'CONFIRMED' ||
          status!.toUpperCase() == 'VERIFIED' ||
          status!.toUpperCase() == 'PAID');

  bool get isPendingVerification =>
      !isReversal && !isReversed && status?.toUpperCase() == 'PENDING';

  Contribution copyWith({
    String? id,
    String? receiptNumber,
    String? memberId,
    String? memberName,
    double? amount,
    DateTime? date,
    String? recordedByUid,
    String? recordedByName,
    PaymentMethod? paymentMethod,
    int? periodMonth,
    int? periodYear,
    String? notes,
    bool? isReversal,
    String? reversalOfId,
    String? reversalReason,
    bool? isReversed,
    DateTime? createdAt,
  }) {
    return Contribution(
      id: id ?? this.id,
      receiptNumber: receiptNumber ?? this.receiptNumber,
      memberId: memberId ?? this.memberId,
      memberName: memberName ?? this.memberName,
      amount: amount ?? this.amount,
      date: date ?? this.date,
      recordedByUid: recordedByUid ?? this.recordedByUid,
      recordedByName: recordedByName ?? this.recordedByName,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      periodMonth: periodMonth ?? this.periodMonth,
      periodYear: periodYear ?? this.periodYear,
      notes: notes ?? this.notes,
      isReversal: isReversal ?? this.isReversal,
      reversalOfId: reversalOfId ?? this.reversalOfId,
      reversalReason: reversalReason ?? this.reversalReason,
      isReversed: isReversed ?? this.isReversed,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toMap() => {
        'receiptNumber': receiptNumber,
        'memberId': memberId,
        'memberName': memberName,
        'amount': amount,
        'date': date.toIso8601String(),
        'recordedByUid': recordedByUid,
        'recordedByName': recordedByName,
        'paymentMethod': paymentMethod.name,
        'periodMonth': periodMonth,
        'periodYear': periodYear,
        'notes': notes,
        'isReversal': isReversal,
        'reversalOfId': reversalOfId,
        'reversalReason': reversalReason,
        'isReversed': isReversed,
        'createdAt': createdAt.toIso8601String(),
      };

  @override
  List<Object?> get props => [
        id,
        receiptNumber,
        memberId,
        memberName,
        amount,
        date,
        recordedByUid,
        recordedByName,
        paymentMethod,
        periodMonth,
        periodYear,
        notes,
        isReversal,
        reversalOfId,
        reversalReason,
        isReversed,
        createdAt,
      ];
}
