import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';

class LocationSessionService {
  static final _db = FirebaseFirestore.instance;
  static const _collection = 'location_sessions';

  // セッション作成（Person A が呼ぶ）
  static Future<String> createSession({
    required String hostName,
    required int slotIndex,
    required String participantName,
    required String ownerUid,
  }) async {
    final sessionId = _generateId();
    await _db.collection(_collection).doc(sessionId).set({
      'ownerUid': ownerUid,
      'hostName': hostName,
      'slotIndex': slotIndex,
      'participantName': participantName,
      'lat': null,
      'lng': null,
      'submitted': false,
      'createdAt': FieldValue.serverTimestamp(),
      'expiresAt': Timestamp.fromDate(
          DateTime.now().add(const Duration(hours: 24))),
    });
    return sessionId;
  }

  // 位置情報送信（Person B が呼ぶ）
  static Future<void> submitLocation({
    required String sessionId,
    required double lat,
    required double lng,
  }) async {
    await _db.collection(_collection).doc(sessionId).update({
      'lat': lat,
      'lng': lng,
      'submitted': true,
      'submittedAt': FieldValue.serverTimestamp(),
    });
  }

  // リアルタイム監視（Person A が呼ぶ）
  static Stream<DocumentSnapshot<Map<String, dynamic>>> watchSession(
      String sessionId) {
    return _db.collection(_collection).doc(sessionId).snapshots();
  }

  // セッション情報取得
  static Future<Map<String, dynamic>?> getSession(String sessionId) async {
    final doc = await _db.collection(_collection).doc(sessionId).get();
    return doc.exists ? doc.data() : null;
  }

  static String _generateId() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final rand = Random.secure();
    return List.generate(6, (_) => chars[rand.nextInt(chars.length)]).join();
  }
}
