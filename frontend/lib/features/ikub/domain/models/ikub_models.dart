class IkubGroupModel {
  const IkubGroupModel({
    required this.id,
    required this.idirId,
    required this.name,
    this.description,
    required this.contributionAmount,
    this.currency = 'ETB',
    required this.frequency,
    required this.startDate,
    this.endDate,
    required this.status,
    required this.totalRounds,
    required this.payoutRule,
    this.winnersPerRound = 1,
    this.drawMode = 'DIGITAL_LOTTERY',
    this.participants = const [],
    this.rounds = const [],
    this.currentRound,
    this.summary,
    this.participantsCount,
    this.roundsCount,
  });

  factory IkubGroupModel.fromJson(Map<String, dynamic> json) {
    final countMap = json['_count'] is Map<String, dynamic>
        ? json['_count'] as Map<String, dynamic>
        : null;

    return IkubGroupModel(
      id: json['id'] as String,
      idirId: json['idirId'] as String,
      name: json['name'] as String,
      description: json['description'] as String?,
      contributionAmount: (json['contributionAmount'] is num)
          ? (json['contributionAmount'] as num).toDouble()
          : double.tryParse(json['contributionAmount']?.toString() ?? '0') ?? 0.0,
      currency: (json['currency'] as String?) ?? 'ETB',
      frequency: (json['frequency'] as String?) ?? 'WEEKLY',
      startDate: DateTime.tryParse(json['startDate']?.toString() ?? '') ?? DateTime.now(),
      endDate: json['endDate'] != null ? DateTime.tryParse(json['endDate'].toString()) : null,
      status: (json['status'] as String?) ?? 'ACTIVE',
      totalRounds: (json['totalRounds'] as int?) ?? 10,
      payoutRule: (json['payoutRule'] as String?) ?? 'LOTTERY',
      winnersPerRound: (json['winnersPerRound'] as int?) ?? 1,
      drawMode: (json['drawMode'] as String?) ?? 'DIGITAL_LOTTERY',
      participants: (json['participants'] as List<dynamic>?)
              ?.map((e) => IkubParticipantModel.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      rounds: (json['rounds'] as List<dynamic>?)
              ?.map((e) => IkubRoundModel.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      currentRound: json['currentRound'] != null
          ? IkubRoundModel.fromJson(json['currentRound'] as Map<String, dynamic>)
          : null,
      summary: json['summary'] != null
          ? IkubSummaryModel.fromJson(json['summary'] as Map<String, dynamic>)
          : null,
      participantsCount: json['participantsCount'] as int? ??
          (countMap != null ? countMap['participants'] as int? : null),
      roundsCount: json['roundsCount'] as int? ??
          (countMap != null ? countMap['rounds'] as int? : null),
    );
  }

  final String id;
  final String idirId;
  final String name;
  final String? description;
  final double contributionAmount;
  final String currency;
  final String frequency; // 'WEEKLY', 'BIWEEKLY', 'MONTHLY'
  final DateTime startDate;
  final DateTime? endDate;
  final String status; // 'DRAFT', 'ACTIVE', 'COMPLETED', 'CANCELLED'
  final int totalRounds;
  final String payoutRule; // 'LOTTERY', 'FIXED_ORDER', 'NEED_BASED'
  final int winnersPerRound;
  final String drawMode; // 'DIGITAL_LOTTERY', 'PHYSICAL_RECORDED', 'NEED_BASED'
  final List<IkubParticipantModel> participants;
  final List<IkubRoundModel> rounds;
  final IkubRoundModel? currentRound;
  final IkubSummaryModel? summary;
  final int? participantsCount;
  final int? roundsCount;

  bool get isActive => status == 'ACTIVE';
  bool get isCompleted => status == 'COMPLETED';

  double get expectedPotPerRound =>
      contributionAmount * (participants.isNotEmpty ? participants.length : 1);

  double get expectedPotPerWinner =>
      expectedPotPerRound / (winnersPerRound > 0 ? winnersPerRound : 1);

  Map<String, dynamic> toJson() => {
        'id': id,
        'idirId': idirId,
        'name': name,
        'description': description,
        'contributionAmount': contributionAmount,
        'currency': currency,
        'frequency': frequency,
        'startDate': startDate.toIso8601String(),
        'endDate': endDate?.toIso8601String(),
        'status': status,
        'totalRounds': totalRounds,
        'payoutRule': payoutRule,
        'winnersPerRound': winnersPerRound,
        'drawMode': drawMode,
      };
}

class IkubParticipantModel {
  const IkubParticipantModel({
    required this.id,
    required this.ikubGroupId,
    required this.membershipId,
    this.payoutOrder,
    required this.status,
    required this.hasWonPayout,
    this.fullName,
    this.phoneNumber,
    required this.joinedAt,
  });

  factory IkubParticipantModel.fromJson(Map<String, dynamic> json) {
    String? name;
    String? phone;
    final membership = json['membership'] as Map<String, dynamic>?;
    if (membership != null) {
      final user = membership['user'] as Map<String, dynamic>?;
      if (user != null) {
        name = user['fullName'] as String?;
        phone = user['phoneNumber'] as String?;
      }
    }

    return IkubParticipantModel(
      id: json['id'] as String,
      ikubGroupId: json['ikubGroupId'] as String,
      membershipId: json['membershipId'] as String,
      payoutOrder: json['payoutOrder'] as int?,
      status: (json['status'] as String?) ?? 'ACTIVE',
      hasWonPayout: (json['hasWonPayout'] as bool?) ?? false,
      fullName: name ?? json['fullName'] as String?,
      phoneNumber: phone ?? json['phoneNumber'] as String?,
      joinedAt: DateTime.tryParse(json['joinedAt']?.toString() ?? '') ?? DateTime.now(),
    );
  }

  final String id;
  final String ikubGroupId;
  final String membershipId;
  final int? payoutOrder;
  final String status; // 'ACTIVE', 'DROPPED', 'COMPLETED'
  final bool hasWonPayout;
  final String? fullName;
  final String? phoneNumber;
  final DateTime joinedAt;

  Map<String, dynamic> toJson() => {
        'id': id,
        'ikubGroupId': ikubGroupId,
        'membershipId': membershipId,
        'payoutOrder': payoutOrder,
        'status': status,
        'hasWonPayout': hasWonPayout,
        'fullName': fullName,
        'phoneNumber': phoneNumber,
        'joinedAt': joinedAt.toIso8601String(),
      };
}

class IkubRoundModel {
  const IkubRoundModel({
    required this.id,
    required this.ikubGroupId,
    required this.roundNumber,
    required this.scheduledDate,
    this.recipientParticipantId,
    this.recipientName,
    required this.status,
    this.completedAt,
    this.drawnById,
    this.drawnAt,
    this.drawSeed,
    this.contributionsCount = 0,
    this.payouts = const [],
  });

  factory IkubRoundModel.fromJson(Map<String, dynamic> json) {
    String? winnerName;
    if (json['payouts'] is List && (json['payouts'] as List).isNotEmpty) {
      final firstPayout = (json['payouts'] as List).first as Map<String, dynamic>?;
      final recip = firstPayout?['recipientParticipant'] as Map<String, dynamic>?;
      final member = recip?['membership'] as Map<String, dynamic>?;
      final u = member?['user'] as Map<String, dynamic>?;
      winnerName = u?['fullName'] as String?;
    }

    final countMap = json['_count'] is Map<String, dynamic>
        ? json['_count'] as Map<String, dynamic>
        : null;

    return IkubRoundModel(
      id: json['id'] as String,
      ikubGroupId: json['ikubGroupId'] as String,
      roundNumber: (json['roundNumber'] as int?) ?? 1,
      scheduledDate: DateTime.tryParse(json['scheduledDate']?.toString() ?? '') ?? DateTime.now(),
      recipientParticipantId: json['recipientParticipantId'] as String?,
      recipientName: winnerName ?? json['recipientName'] as String?,
      status: (json['status'] as String?) ?? 'SCHEDULED',
      completedAt: json['completedAt'] != null
          ? DateTime.tryParse(json['completedAt'].toString())
          : null,
      drawnById: json['drawnById'] as String?,
      drawnAt: json['drawnAt'] != null
          ? DateTime.tryParse(json['drawnAt'].toString())
          : null,
      drawSeed: json['drawSeed'] as String?,
      contributionsCount: countMap != null
          ? (countMap['contributions'] as int? ?? 0)
          : (json['contributionsCount'] as int? ?? 0),
      payouts: (json['payouts'] as List<dynamic>?)
              ?.map((e) => IkubPayoutModel.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
    );
  }

  final String id;
  final String ikubGroupId;
  final int roundNumber;
  final DateTime scheduledDate;
  final String? recipientParticipantId;
  final String? recipientName;
  final String status; // 'SCHEDULED', 'IN_PROGRESS', 'COMPLETED', 'SKIPPED'
  final DateTime? completedAt;
  final String? drawnById;
  final DateTime? drawnAt;
  final String? drawSeed;
  final int contributionsCount;
  final List<IkubPayoutModel> payouts;

  bool get isCompleted => status == 'COMPLETED';
  bool get isInProgress => status == 'IN_PROGRESS';
  bool get isScheduled => status == 'SCHEDULED';

  Map<String, dynamic> toJson() => {
        'id': id,
        'ikubGroupId': ikubGroupId,
        'roundNumber': roundNumber,
        'scheduledDate': scheduledDate.toIso8601String(),
        'recipientParticipantId': recipientParticipantId,
        'status': status,
        'completedAt': completedAt?.toIso8601String(),
        'drawnById': drawnById,
        'drawnAt': drawnAt?.toIso8601String(),
        'drawSeed': drawSeed,
      };
}

class IkubPayoutModel {
  const IkubPayoutModel({
    required this.id,
    required this.roundId,
    required this.recipientParticipantId,
    this.recipientName,
    required this.amount,
    this.currency = 'ETB',
    required this.payoutDate,
    required this.status,
    this.paymentMethod = 'CASH',
    this.paymentReference,
  });

  factory IkubPayoutModel.fromJson(Map<String, dynamic> json) {
    String? name;
    final recip = json['recipientParticipant'] as Map<String, dynamic>?;
    final member = recip?['membership'] as Map<String, dynamic>?;
    final u = member?['user'] as Map<String, dynamic>?;
    name = u?['fullName'] as String?;

    return IkubPayoutModel(
      id: json['id'] as String,
      roundId: json['roundId'] as String,
      recipientParticipantId: json['recipientParticipantId'] as String,
      recipientName: name ?? json['recipientName'] as String?,
      amount: (json['amount'] is num)
          ? (json['amount'] as num).toDouble()
          : double.tryParse(json['amount']?.toString() ?? '0') ?? 0.0,
      currency: (json['currency'] as String?) ?? 'ETB',
      payoutDate: DateTime.tryParse(json['payoutDate']?.toString() ?? '') ?? DateTime.now(),
      status: (json['status'] as String?) ?? 'CONFIRMED',
      paymentMethod: (json['paymentMethod'] as String?) ?? 'CASH',
      paymentReference: json['paymentReference'] as String?,
    );
  }

  final String id;
  final String roundId;
  final String recipientParticipantId;
  final String? recipientName;
  final double amount;
  final String currency;
  final DateTime payoutDate;
  final String status;
  final String paymentMethod;
  final String? paymentReference;
}

class IkubSummaryModel {
  const IkubSummaryModel({
    required this.groupId,
    required this.name,
    this.currency = 'ETB',
    required this.activeParticipants,
    required this.completedRounds,
    required this.totalRounds,
    this.winnersPerRound = 1,
    required this.totalCollected,
    required this.totalPaidOut,
    required this.remainingPool,
  });

  factory IkubSummaryModel.fromJson(Map<String, dynamic> json) {
    final financials = json['financials'] as Map<String, dynamic>? ?? {};
    return IkubSummaryModel(
      groupId: json['groupId'] as String? ?? '',
      name: json['name'] as String? ?? '',
      currency: json['currency'] as String? ?? 'ETB',
      activeParticipants: (json['activeParticipants'] as int?) ?? 0,
      completedRounds: (json['completedRounds'] as int?) ?? 0,
      totalRounds: (json['totalRounds'] as int?) ?? 10,
      winnersPerRound: (json['winnersPerRound'] as int?) ?? 1,
      totalCollected: (financials['totalCollected'] is num)
          ? (financials['totalCollected'] as num).toDouble()
          : 0.0,
      totalPaidOut: (financials['totalPaidOut'] is num)
          ? (financials['totalPaidOut'] as num).toDouble()
          : 0.0,
      remainingPool: (financials['remainingPool'] is num)
          ? (financials['remainingPool'] as num).toDouble()
          : 0.0,
    );
  }

  final String groupId;
  final String name;
  final String currency;
  final int activeParticipants;
  final int completedRounds;
  final int totalRounds;
  final int winnersPerRound;
  final double totalCollected;
  final double totalPaidOut;
  final double remainingPool;
}

class IkubJoinRequestModel {
  const IkubJoinRequestModel({
    required this.id,
    required this.ikubGroupId,
    required this.membershipId,
    required this.status,
    this.note,
    this.fullName,
    this.phoneNumber,
    required this.requestedAt,
  });

  factory IkubJoinRequestModel.fromJson(Map<String, dynamic> json) {
    String? name;
    String? phone;
    final membership = json['membership'] as Map<String, dynamic>?;
    if (membership != null) {
      final user = membership['user'] as Map<String, dynamic>?;
      if (user != null) {
        name = user['fullName'] as String?;
        phone = user['phoneNumber'] as String?;
      }
    }

    return IkubJoinRequestModel(
      id: json['id'] as String,
      ikubGroupId: json['ikubGroupId'] as String,
      membershipId: json['membershipId'] as String,
      status: (json['status'] as String?) ?? 'PENDING',
      note: json['note'] as String?,
      fullName: name ?? json['fullName'] as String?,
      phoneNumber: phone ?? json['phoneNumber'] as String?,
      requestedAt: DateTime.tryParse(json['requestedAt']?.toString() ?? '') ?? DateTime.now(),
    );
  }

  final String id;
  final String ikubGroupId;
  final String membershipId;
  final String status; // 'PENDING', 'APPROVED', 'REJECTED'
  final String? note;
  final String? fullName;
  final String? phoneNumber;
  final DateTime requestedAt;
}
