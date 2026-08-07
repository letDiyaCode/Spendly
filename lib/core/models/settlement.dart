import 'package:flutter/material.dart';
import 'enums.dart';

class Settlement {
  final String id;
  final String fromUserId; // payer (owes money)
  final String toUserId;   // payee (receives money)
  final double amount;
  final SettlementStatus status;
  final DateTime createdAt;
  final String? transactionId;
  final String? proofUrl;
  /// Local file path for an optionally attached payment screenshot.
  final String? proofImagePath;
  final String? groupId;
  final String? rejectionReason;
  final int verificationAttempts;
  final List<String> approvals;
  final List<String> rejections;

  const Settlement({
    required this.id,
    required this.fromUserId,
    required this.toUserId,
    required this.amount,
    required this.status,
    required this.createdAt,
    this.transactionId,
    this.proofUrl,
    this.proofImagePath,
    this.groupId,
    this.rejectionReason,
    this.verificationAttempts = 0,
    this.approvals = const [],
    this.rejections = const [],
  });

  factory Settlement.fromJson(Map<String, dynamic> json, {String? id}) {
    final parsedProofUrl =
        json['proofUrl'] as String? ??
        json['proofImageUrl'] as String? ??
        json['imageUrl'] as String?;

    return Settlement(
      id: id ?? json['id'] as String? ?? '',
      fromUserId: json['fromUser'] as String? ?? json['fromUserId'] as String? ?? '',
      toUserId: json['toUser'] as String? ?? json['toUserId'] as String? ?? '',
      amount: (json['amount'] as num?)?.toDouble() ?? 0,
      status: SettlementStatus.values.firstWhere(
        (e) => e.name == (json['status'] as String?),
        orElse: () => SettlementStatus.verified, // Default to verified for global settlements if status missing
      ),
      createdAt: json['createdAt'] is int
          ? DateTime.fromMillisecondsSinceEpoch(json['createdAt'] as int)
          : (json['createdAt'] as dynamic)?.toDate() ?? DateTime.now(),
      transactionId: json['transactionId'] as String?,
      proofUrl: parsedProofUrl,
      groupId: json['groupId'] as String?,
      rejectionReason: json['rejectionReason'] as String?,
      verificationAttempts: (json['verificationAttempts'] as num?)?.toInt() ?? 0,
      approvals: List<String>.from(json['approvals'] ?? []),
      rejections: List<String>.from(json['rejections'] ?? []),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'fromUser': fromUserId,
      'toUser': toUserId,
      'amount': amount,
      'createdAt': createdAt.millisecondsSinceEpoch,
      'type': 'settlement',
      'status': status.name,
      if (transactionId != null) 'transactionId': transactionId,
      if (proofUrl != null) 'proofUrl': proofUrl,
      if (proofUrl != null) 'proofImageUrl': proofUrl,
      if (proofUrl != null) 'imageUrl': proofUrl,
      if (groupId != null) 'groupId': groupId,
      if (rejectionReason != null) 'rejectionReason': rejectionReason,
      'verificationAttempts': verificationAttempts,
      'approvals': approvals,
      'rejections': rejections,
    };
  }

  Settlement copyWith({
    String? id,
    String? fromUserId,
    String? toUserId,
    double? amount,
    SettlementStatus? status,
    DateTime? createdAt,
    String? transactionId,
    String? proofUrl,
    String? proofImagePath,
    String? groupId,
    String? rejectionReason,
    int? verificationAttempts,
    List<String>? approvals,
    List<String>? rejections,
    bool clearProofImage = false,
  }) {
    return Settlement(
      id: id ?? this.id,
      fromUserId: fromUserId ?? this.fromUserId,
      toUserId: toUserId ?? this.toUserId,
      amount: amount ?? this.amount,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      transactionId: transactionId ?? this.transactionId,
      proofUrl: proofUrl ?? this.proofUrl,
      proofImagePath:
          clearProofImage ? null : (proofImagePath ?? this.proofImagePath),
      groupId: groupId ?? this.groupId,
      rejectionReason: rejectionReason ?? this.rejectionReason,
      verificationAttempts: verificationAttempts ?? this.verificationAttempts,
      approvals: approvals ?? this.approvals,
      rejections: rejections ?? this.rejections,
    );
  }

  bool get isPending => status == SettlementStatus.pendingVerification;
  bool get isVerified => status == SettlementStatus.verified;
  bool get isRejected => status == SettlementStatus.rejected;

  String get statusLabel {
    switch (status) {
      case SettlementStatus.pendingVerification:
        return 'Pending Verification';
      case SettlementStatus.verified:
        return 'Verified';
      case SettlementStatus.rejected:
        return 'Rejected';
    }
  }

  Color get statusColor {
    switch (status) {
      case SettlementStatus.pendingVerification:
        return const Color(0xFFF59E0B); // warning
      case SettlementStatus.verified:
        return const Color(0xFF10B981); // success
      case SettlementStatus.rejected:
        return const Color(0xFFEF4444); // danger
    }
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is Settlement && other.id == id;

  @override
  int get hashCode => id.hashCode;
}

/// Represents a simplified debt recommendation from the algorithm
class DebtSuggestion {
  final String fromUserId;
  final String toUserId;
  final double amount;

  const DebtSuggestion({
    required this.fromUserId,
    required this.toUserId,
    required this.amount,
  });
}
