import 'package:flutter_test/flutter_test.dart';
import 'package:mannaka/utils/share_utils.dart';
import 'package:mannaka/providers/search_provider.dart';
import 'package:mannaka/models/restaurant.dart';
import 'package:mannaka/models/scored_restaurant.dart';

// ============================================================
// Cycle 26 TDD テスト（Cycle 30 以降で一部縮小）
// 対象: share_utils.dart — buildRestaurantShareText 回帰テスト
//
// 旧スコープだった `ShareUtils.share()` と `buildMeetingPointText` は
// 2026-04-24 の dead-code 整理で lib 側から削除されたため、対応する
// テスト群も併せて撤去した。buildRestaurantShareText は share_preview_screen.dart
// から呼ばれる生存コードのため回帰テストは維持する。
// ============================================================

// ── テスト用ヘルパー ─────────────────────────────────────────────────────
Restaurant _restaurant({
  required String id,
  required String name,
  String category = 'イタリアン',
  int priceAvg = 3000,
}) {
  return Restaurant(
    id: id,
    name: name,
    stationIndex: 0,
    category: category,
    rating: 4.0,
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

void main() {
  // ══════════════════════════════════════════════════════════════
  // buildRestaurantShareText — 回帰テスト
  // ══════════════════════════════════════════════════════════════
  group('ShareUtils.buildRestaurantShareText() — 回帰テスト', () {
    test('sortedRestaurantsが空でprimaryScoredもnullのとき空文字を返す', () {
      final state = SearchState();
      expect(ShareUtils.buildRestaurantShareText(state), isEmpty);
    });

    test('primaryScoredを直接渡すと店名・カテゴリを含む', () {
      final r = _restaurant(id: 'r1', name: 'テスト食堂', category: 'イタリアン');
      final sr = _scored(r, score: 0.9);
      final state = SearchState(
        centroidLat: 35.658,
        centroidLng: 139.701,
      );
      final text = ShareUtils.buildRestaurantShareText(
        state,
        primaryScored: sr,
        includeBackup: false,
      );
      expect(text, contains('テスト食堂'));
      expect(text, contains('イタリアン'));
    });

    test('includeBackup=trueのとき上位2店が代替案に含まれる', () {
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
      expect(text, contains('代替案'));
      expect(text, contains('店B'));
      expect(text, contains('店C'));
    });

    test('シェアテキストにApp Storeリンクが含まれる', () {
      final r = _restaurant(id: 'r2', name: '花カフェ');
      final sr = _scored(r);
      final state = SearchState(
        occasion: Occasion.girlsNight,
        centroidLat: 35.658,
        centroidLng: 139.701,
      );
      final text = ShareUtils.buildRestaurantShareText(
        state,
        primaryScored: sr,
        includeBackup: false,
      );
      expect(text, contains('apps.apple.com'));
      expect(text, contains('Aimachi'));
    });

    test('priceAvg=0のとき予算行を含まない', () {
      final r = _restaurant(id: 'r3', name: '無料カフェ', priceAvg: 0);
      final sr = _scored(r);
      final state = SearchState(
        centroidLat: 35.658,
        centroidLng: 139.701,
      );
      final text = ShareUtils.buildRestaurantShareText(
        state,
        primaryScored: sr,
        includeBackup: false,
      );
      expect(text, isNot(contains('予算')));
    });
  });

  // ══════════════════════════════════════════════════════════════
  // ④ SortOptionExt / OccasionExt — materialIcon削除後の回帰テスト
  // 【現状 Green】削除後も label・filterXxx が壊れないことを保証
  // ══════════════════════════════════════════════════════════════
  group('SortOptionExt — materialIcon削除後の回帰テスト', () {
    test('全SortOptionのlabelが非空', () {
      for (final option in SortOption.values) {
        expect(option.label, isNotEmpty, reason: '$option の label が空');
      }
    });

    test('SortOptionのlabel値が期待通り', () {
      expect(SortOption.recommended.label, 'おすすめ順');
      expect(SortOption.distance.label, '距離順');
      expect(SortOption.rating.label, '評価順');
      expect(SortOption.budget.label, '価格順');
    });
  });

  group('OccasionExt — materialIcon削除後の回帰テスト', () {
    test('全Occasionのlabelが非空（none以外）', () {
      for (final occ in Occasion.values) {
        if (occ == Occasion.none) continue;
        expect(occ.label, isNotEmpty, reason: '$occ の label が空');
      }
    });

    test('filterFemaleが正しい値を返す', () {
      expect(Occasion.girlsNight.filterFemale, isTrue);
      expect(Occasion.mixer.filterFemale, isTrue);
      expect(Occasion.date.filterFemale, isTrue);
      expect(Occasion.birthday.filterFemale, isFalse);
      expect(Occasion.lunch.filterFemale, isFalse);
      expect(Occasion.welcome.filterFemale, isFalse);
    });

    test('filterPrivateが正しい値を返す', () {
      expect(Occasion.birthday.filterPrivate, isTrue);
      expect(Occasion.girlsNight.filterPrivate, isTrue);
      expect(Occasion.welcome.filterPrivate, isTrue);
      expect(Occasion.lunch.filterPrivate, isFalse);
      expect(Occasion.date.filterPrivate, isFalse);
    });

    test('filterLunchが正しい値を返す', () {
      expect(Occasion.lunch.filterLunch, isTrue);
      expect(Occasion.girlsNight.filterLunch, isFalse);
      expect(Occasion.birthday.filterLunch, isFalse);
    });
  });
}
