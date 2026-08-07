import 'dart:async';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../../models/settlement.dart';
import '../../models/enums.dart';
import '../../services/cloudinary_service.dart';
import '../settlement_repository.dart';


/// Firestore-backed settlement repository.
class FirebaseSettlementRepository implements SettlementRepository {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final CloudinaryService _cloudinary = CloudinaryService();

  CollectionReference<Map<String, dynamic>> get _col => _db.collection('settlements');

  @override
  Future<Settlement?> getSettlementById(String id) async {
    final doc = await _col.doc(id).get();
    if (!doc.exists) return null;
    return Settlement.fromJson(doc.data()!, id: doc.id);
  }

  bool _isIndexError(FirebaseException e) {
    final message = e.message ?? '';
    return e.code == 'failed-precondition' && message.toLowerCase().contains('index');
  }

  List<Settlement> _mapAndSort(QuerySnapshot<Map<String, dynamic>> snap) {
    final settlements = snap.docs
        .map((doc) => Settlement.fromJson(doc.data(), id: doc.id))
        .toList();
    settlements.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return settlements;
  }

  Stream<List<Settlement>> _watchByFromAndToQueries(String userId) {
    final controller = StreamController<List<Settlement>>();
    List<Settlement> fromList = const [];
    List<Settlement> toList = const [];

    void emitMerged() {
      final merged = <String, Settlement>{};
      for (final s in fromList) {
        merged[s.id] = s;
      }
      for (final s in toList) {
        merged[s.id] = s;
      }
      final values = merged.values.toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      controller.add(values);
    }

    final fromSub = _col
        .where('fromUser', isEqualTo: userId)
        .snapshots()
        .map(_mapAndSort)
        .listen((value) {
      fromList = value;
      emitMerged();
    }, onError: controller.addError);

    final toSub = _col
        .where('toUser', isEqualTo: userId)
        .snapshots()
        .map(_mapAndSort)
        .listen((value) {
      toList = value;
      emitMerged();
    }, onError: controller.addError);

    controller.onCancel = () async {
      await fromSub.cancel();
      await toSub.cancel();
    };

    return controller.stream;
  }

  @override
  Stream<List<Settlement>> watchUserSettlements(String userId) {
    final primary = _col
        .where(Filter.or(
          Filter('fromUser', isEqualTo: userId),
          Filter('toUser', isEqualTo: userId),
        ))
        .orderBy('createdAt', descending: true);

    return (() async* {
      try {
        await primary.limit(1).get();
        yield* primary.snapshots().map(_mapAndSort);
      } on FirebaseException catch (e) {
        if (!_isIndexError(e)) rethrow;
        debugPrint('Missing Firestore index for settlements stream. Falling back to merged single-field queries.');
        yield* _watchByFromAndToQueries(userId);
      }
    })();
  }

  @override
  Future<List<Settlement>> getUserSettlements(String userId) async {
    final primary = _col
        .where(Filter.or(
          Filter('fromUser', isEqualTo: userId),
          Filter('toUser', isEqualTo: userId),
        ))
        .orderBy('createdAt', descending: true);

    try {
      final snap = await primary.get();
      return _mapAndSort(snap);
    } on FirebaseException catch (e) {
      if (!_isIndexError(e)) rethrow;

      final fromSnap = await _col.where('fromUser', isEqualTo: userId).get();
      final toSnap = await _col.where('toUser', isEqualTo: userId).get();

      final merged = <String, Settlement>{};
      for (final s in _mapAndSort(fromSnap)) {
        merged[s.id] = s;
      }
      for (final s in _mapAndSort(toSnap)) {
        merged[s.id] = s;
      }

      final settlements = merged.values.toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return settlements;
    }
  }

  @override
  Future<void> addSettlement(Settlement settlement, {dynamic imageFile}) async {
    String? proofUrl = settlement.proofUrl;

    if (imageFile is File) {
      proofUrl = await _cloudinary.uploadImage(imageFile);
      if (proofUrl == null || proofUrl.isEmpty) {
        throw StateError(
          'Proof image upload failed. Please check your internet connection and try again.',
        );
      }
    }

    final data = settlement
        .copyWith(proofUrl: proofUrl)
        .toJson()
      ..['createdAt'] = FieldValue.serverTimestamp();
      
    await _col.add(data);
  }

  @override
  Future<void> updateStatus(
    String id,
    SettlementStatus status, {
    String? rejectionReason,
    int? verificationAttempts,
    List<String>? approvals,
    List<String>? rejections,
  }) async {
    await _col.doc(id).update({
      'status': status.name,
      if (rejectionReason != null) 'rejectionReason': rejectionReason,
      if (verificationAttempts != null) 'verificationAttempts': verificationAttempts,
      if (approvals != null) 'approvals': approvals,
      if (rejections != null) 'rejections': rejections,
    });
  }

  @override
  Future<void> updateTransactionId(String id, String transactionId) async {
    await _col.doc(id).update({'transactionId': transactionId});
  }
}
