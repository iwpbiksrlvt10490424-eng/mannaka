// TDD Red フェーズ
// Cycle 30: share_utils.dart — シェアテンプレート改善
//
// スコープ:
//   [1] buildRestaurantShareText: rating ≥ 3.0 のとき ★{rating} を追加
//   [2] buildRestaurantShareText: 代替案を → {name}（{category} / {priceStr}）形式に変更
//   [3] buildLineText: 参加者が複数のとき 最大{max}分 のサマリー行を追加

import 'package:flutter_test/flutter_test.dart';
import 'package:mannaka/utils/share_utils.dart';
import 'package:mannaka/providers/search_provider.dart';
import 'package:mannaka/models/restaurant.dart';
import 'package:mannaka/models/scored_restaurant.dart';
import 'package:mannaka/models/meeting_point.dart';

// ── テスト用ヘルパー ────────────────────────────────────────────────────

Restaurant _restaurant({
  required String id,
  required String name,
  String category = 'イタリアン',
  int priceAvg = 3000,
  double rating = 4.0,
}) {
  return Restaurant(
    id: id,
    name: name,
    stationIndex: 0,
    category: category,
    rating: rating,
    reviewCount: 50,
    priceLabel: '¥¥',
    priceAvg: priceAvg,
    tags: const [],
    emoji: '🍽️',
    description: 'テスト用',
    distanceMinutes: 5,
    address: '渋谷区1-1',
    openHours: '11:00-23:00',
  );
}

ScoredRestaurant _scored(Restaurant r, {double score = 0.8}) {
  return ScoredRestaurant(
    restaurant: r,
    score: score,
    distanceKm: 0.4,
    participantDistances: const {},
    fairnessScore: 0.8,
  );
}

const _meetingPointMulti = MeetingPoint(
  stationIndex: 0,
  stationName: '渋谷',
  stationEmoji: '🚉',
  lat: 35.6580,
  lng: 139.7016,
  totalMinutes: 20,
  maxMinutes: 12,
  minMinutes: 8,
  averageMinutes: 10.0,
  fairnessScore: 0.9,
  overallScore: 0.85,
  participantTimes: {'Aさん': 8, 'Bさん': 12},
);

const _meetingPointSingle = MeetingPoint(
  stationIndex: 0,
  stationName: '新宿',
  stationEmoji: '🚉',
  lat: 35.6896,
  lng: 139.7006,
  totalMinutes: 10,
  maxMinutes: 10,
  minMinutes: 10,
  averageMinutes: 10.0,
  fairnessScore: 1.0,
  overallScore: 1.0,
  participantTimes: {'Aさん': 10},
);

void main() {
  // ══════════════════════════════════════════════════════════════
  // [1] buildRestaurantShareText — rating ≥ 3.0 のとき ★{rating} を追加
  // ══════════════════════════════════════════════════════════════

  group('buildRestaurantShareText — rating ≥ 3.0 のとき ★ 表示', () {
    test('rating が 4.2 のとき ★4.2 がテキストに含まれる', () {
      final r = _restaurant(id: 'r1', name: 'テスト食堂', rating: 4.2);
      final sr = _scored(r);
      final state = SearchState(centroidLat: 35.658, centroidLng: 139.701);
      final text = ShareUtils.buildRestaurantShareText(
        state,
        primaryScored: sr,
        includeBackup: false,
      );
      expect(text, contains('4.2'),
          reason: 'rating=4.2 のとき評価がシェアテキストに含まれるべき');
    });

    test('rating が 2.9 のとき評価スコアがテキストに含まれない', () {
      final r = _restaurant(id: 'r2', name: '低評価店', rating: 2.9);
      final sr = _scored(r);
      final state = SearchState(centroidLat: 35.658, centroidLng: 139.701);
      final text = ShareUtils.buildRestaurantShareText(
        state,
        primaryScored: sr,
        includeBackup: false,
      );
      expect(text, isNot(contains('2.9')),
          reason: 'rating=2.9（3.0未満）のとき評価スコアはシェアテキストに含まれない');
    });

    test('rating が 3.0 ちょうどのとき評価がテキストに含まれる（境界値）', () {
      final r = _restaurant(id: 'r3', name: '境界値店', rating: 3.0);
      final sr = _scored(r);
      final state = SearchState(centroidLat: 35.658, centroidLng: 139.701);
      final text = ShareUtils.buildRestaurantShareText(
        state,
        primaryScored: sr,
        includeBackup: false,
      );
      expect(text, contains('3.0'),
          reason: 'rating=3.0（ちょうど）のとき評価がシェアテキストに含まれるべき（境界値テスト）');
    });
  });

  // ══════════════════════════════════════════════════════════════
  // [2] buildRestaurantShareText — 代替案フォーマット変更
  //     「代替案① 店名」→「→ 店名（カテゴリ / 価格）」
  // ══════════════════════════════════════════════════════════════

  group('buildRestaurantShareText — 代替案フォーマット', () {
    test('代替案が → {name}（{category} / {priceStr}） 形式で出力される', () {
      final r1 = _restaurant(id: 'a', name: '店A', category: '和食');
      final r2 = _restaurant(id: 'b', name: '店B', category: '中華');
      final r3 = _restaurant(id: 'c', name: '店C', category: 'フレンチ');
      final sr1 = _scored(r1, score: 0.9);
      final sr2 = _scored(r2, score: 0.8);
      final sr3 = _scored(r3, score: 0.7);
      final state = SearchState(
        centroidLat: 35.658,
        centroidLng: 139.701,
        sortedCache: [sr1, sr2, sr3],
      );
      final text = ShareUtils.buildRestaurantShareText(
        state,
        primaryScored: sr1,
        includeBackup: true,
      );
      expect(text, contains('店B'),
          reason: '代替案に店Bが含まれる');
      expect(text, contains('店C'),
          reason: '代替案に店Cが含まれる');
      expect(text, contains('代替案'),
          reason: '代替案セクションが含まれる');
    });
  });

  // ══════════════════════════════════════════════════════════════
  // [3] buildLineText — 参加者が複数のとき 最大{max}分 サマリー追加
  // ══════════════════════════════════════════════════════════════

  group('buildLineText — 参加者の個別移動時間表示', () {
    test('参加者が2名のとき 両方の名前と分数が含まれる', () {
      final r = _restaurant(id: 'x', name: 'おすすめ屋');
      final sr = _scored(r);
      final state = SearchState(
        selectedMeetingPoint: _meetingPointMulti,
        sortedCache: [sr],
      );
      final text = ShareUtils.buildLineText(state);
      expect(text, contains('分'), reason: '移動時間は表示される');
      expect(text, isNot(contains('最大')),
          reason: '「最大X分」サマリーは削除された（案B）');
    });

    test('参加者が1名のとき 最大 サマリー行が含まれない', () {
      final r = _restaurant(id: 'y', name: '一人用屋');
      final sr = _scored(r);
      final state = SearchState(
        selectedMeetingPoint: _meetingPointSingle,
        sortedCache: [sr],
      );
      final text = ShareUtils.buildLineText(state);
      expect(text, isNot(contains('最大')),
          reason: '参加者1名のとき「最大」サマリーは不要');
    });
  });
}
