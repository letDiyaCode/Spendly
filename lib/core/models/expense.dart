import 'enums.dart';

class Expense {
  final String id;
  final ExpenseType type;
  final String? groupId;
  final List<String> participants;
  final String paidById;
  final double amount;
  final Map<String, double> splitDetails; // userId -> amount they owe
  final SplitType splitType;
  final ExpenseCategory category;
  final DateTime date;
  final String description;
  final String? notes;
  final String? imageUrl;
  final PaymentMethod? paymentMethod;
  final List<String> approvals;
  final List<String> rejections;

  const Expense({
    required this.id,
    required this.type,
    this.groupId,
    required this.participants,
    required this.paidById,
    required this.amount,
    required this.splitDetails,
    required this.splitType,
    required this.category,
    required this.date,
    required this.description,
    this.notes,
    this.imageUrl,
    this.paymentMethod,
    this.approvals = const [],
    this.rejections = const [],
  });

  factory Expense.fromJson(Map<String, dynamic> json, {String? id}) {
    final rawSplit = json['splitDetails'] as Map<String, dynamic>? ?? {};
    final parsedImageUrl =
        json['imageUrl'] as String? ??
        json['receiptUrl'] as String? ??
        json['proofUrl'] as String? ??
        json['proofImageUrl'] as String?;
    return Expense(
      id: id ?? json['id'] as String? ?? '',
      type: ExpenseType.values.firstWhere(
        (e) => e.name == json['type'],
        orElse: () => ExpenseType.personal,
      ),
      groupId: json['groupId'] as String?,
      participants: List<String>.from(json['participants'] ?? []),
      paidById: json['paidById'] as String? ?? '',
      amount: (json['amount'] as num?)?.toDouble() ?? 0,
      splitDetails: rawSplit.map((k, v) => MapEntry(k, (v as num).toDouble())),
      splitType: SplitType.values.firstWhere(
        (e) => e.name == json['splitType'],
        orElse: () => SplitType.equal,
      ),
      category: ExpenseCategory.values.firstWhere(
        (e) => e.name == json['category'],
        orElse: () => ExpenseCategory.other,
      ),
      date: json['date'] is int
          ? DateTime.fromMillisecondsSinceEpoch(json['date'] as int)
          : (json['date'] as dynamic)?.toDate() ?? DateTime.now(),
      description: json['description'] as String? ?? '',
      notes: json['notes'] as String?,
      imageUrl: parsedImageUrl,
      paymentMethod: json['paymentMethod'] != null
          ? PaymentMethod.values.firstWhere(
              (e) => e.name == json['paymentMethod'],
              orElse: () => PaymentMethod.other,
            )
          : null,
      approvals: List<String>.from(json['approvals'] ?? []),
      rejections: List<String>.from(json['rejections'] ?? []),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type.name,
      'groupId': groupId,
      'participants': participants,
      'paidById': paidById,
      'amount': amount,
      'splitDetails': splitDetails,
      'splitType': splitType.name,
      'category': category.name,
      'date': date.millisecondsSinceEpoch,
      'description': description,
      if (notes != null) 'notes': notes,
      if (imageUrl != null) 'imageUrl': imageUrl,
      if (imageUrl != null) 'receiptUrl': imageUrl,
      if (paymentMethod != null) 'paymentMethod': paymentMethod!.name,
      'approvals': approvals,
      'rejections': rejections,
    };
  }

  Expense copyWith({
    String? id,
    ExpenseType? type,
    String? groupId,
    List<String>? participants,
    String? paidById,
    double? amount,
    Map<String, double>? splitDetails,
    SplitType? splitType,
    ExpenseCategory? category,
    DateTime? date,
    String? description,
    String? notes,
    String? imageUrl,
    PaymentMethod? paymentMethod,
    List<String>? approvals,
    List<String>? rejections,
  }) {
    return Expense(
      id: id ?? this.id,
      type: type ?? this.type,
      groupId: groupId ?? this.groupId,
      participants: participants ?? this.participants,
      paidById: paidById ?? this.paidById,
      amount: amount ?? this.amount,
      splitDetails: splitDetails ?? this.splitDetails,
      splitType: splitType ?? this.splitType,
      category: category ?? this.category,
      date: date ?? this.date,
      description: description ?? this.description,
      notes: notes ?? this.notes,
      imageUrl: imageUrl ?? this.imageUrl,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      approvals: approvals ?? this.approvals,
      rejections: rejections ?? this.rejections,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is Expense && other.id == id;

  @override
  int get hashCode => id.hashCode;
}
