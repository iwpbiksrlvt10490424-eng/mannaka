import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/scored_restaurant.dart';
import '../utils/photo_ref.dart';

class VotingService {
  static final _db = FirebaseFirestore.instance;
  static const _col = 'voting_sessions';

  static List<Map<String, dynamic>> buildCandidateData(
          List<ScoredRestaurant> candidates) =>
      candidates
          .map((s) => <String, dynamic>{
                'id': s.restaurant.id,
                'name': s.restaurant.name,
                'category': s.restaurant.category,
                'priceStr': s.restaurant.priceStr,
                'address': s.restaurant.address,
                'imageUrl': PhotoRef.toRef(s.restaurant.imageUrl ?? ''),
                'votes': 0,
                'voters': <String>[],
              })
          .toList();

  // 投票セッション作成
  static Future<String> createSession({
    required String hostName,
    required List<ScoredRestaurant> candidates, // TOP3
    String? hostUid,
  }) async {
    if (hostName.isEmpty || hostName.length > 50) {
      throw ArgumentError('hostName は1〜50文字にしてください');
    }
    final id = _generateId();
    final candidateData = buildCandidateData(candidates);

    await _db.collection(_col).doc(id).set({
      'hostName': hostName,
      'hostUid': hostUid ?? '',
      'candidates': candidateData,
      'status': 'open', // open / closed
      'createdAt': FieldValue.serverTimestamp(),
      'expiresAt': Timestamp.fromDate(DateTime.now().add(const Duration(hours: 24))),
    });
    return id;
  }

  // 投票する
  static Future<void> vote({
    required String sessionId,
    required String restaurantId,
    required String voterName,
  }) async {
    if (voterName.isEmpty || voterName.length > 50) {
      throw ArgumentError('voterName は1〜50文字にしてください');
    }
    final ref = _db.collection(_col).doc(sessionId);
    await _db.runTransaction((tx) async {
      final doc = await tx.get(ref);
      if (!doc.exists) return;
      final data = doc.data()!;
      final candidates = List<Map<String, dynamic>>.from(
        (data['candidates'] as List? ?? []).map((e) => Map<String, dynamic>.from((e as Map?) ?? {}))
      );
      for (final c in candidates) {
        final voters = List<String>.from(c['voters'] as List? ?? []);
        if (voters.contains(voterName)) return; // 二重投票防止
        if (c['id'] == restaurantId) {
          voters.add(voterName);
          c['voters'] = voters;
          c['votes'] = voters.length;
        }
      }
      tx.update(ref, {'candidates': candidates});
    });
  }

  // リアルタイム監視
  static Stream<DocumentSnapshot<Map<String, dynamic>>> watchSession(String id) =>
      _db.collection(_col).doc(id).snapshots();

  // セッション取得
  static Future<Map<String, dynamic>?> getSession(String id) async {
    final doc = await _db.collection(_col).doc(id).get();
    return doc.exists ? doc.data() : null;
  }

  // セッションを閉じて決定したお店を保存
  static Future<void> closeSession({
    required String sessionId,
    required String decidedRestaurantId,
    required String decidedRestaurantName,
  }) async {
    await _db.collection(_col).doc(sessionId).update({
      'status': 'closed',
      'decidedRestaurantId': decidedRestaurantId,
      'decidedRestaurantName': decidedRestaurantName,
      'closedAt': FieldValue.serverTimestamp(),
    });
  }

  static String _generateId() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final rand = Random.secure();
    return List.generate(6, (_) => chars[rand.nextInt(chars.length)]).join();
  }
}
