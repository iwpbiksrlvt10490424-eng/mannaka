import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mannaka/utils/share_utils.dart';
import 'package:mannaka/providers/search_provider.dart';
import 'package:mannaka/models/restaurant.dart';
import 'package:mannaka/models/scored_restaurant.dart';
import 'package:mannaka/models/meeting_point.dart';

// ============================================================
// Cycle 26 TDD テスト
// 対象: share_utils.dart — sharePositionOrigin 修正
//       search_provider.dart — materialIcon デッドコード削除
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

const _meetingPoint = MeetingPoint(
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

void main() {
  // ══════════════════════════════════════════════════════════════
  // ① ShareUtils.share() — sharePositionOrigin パラメータ
  // 【Red フェーズ】
  //   sharePositionOrigin 名前付きパラメータが share() に存在しないため
  //   現状はコンパイルエラーとなり flutter test が失敗する。
  //
  //   Green にするには:
  //     static Future<void> share(
  //       BuildContext context,
  //       SearchState state, {
  //       Rect? sharePositionOrigin,   ← 追加
  //     }) async {
  //       ...
  //       await Share.share(
  //         text,
  //         subject: '...',
  //         sharePositionOrigin: sharePositionOrigin,  ← 追加
  //       );
  //     }
  // ══════════════════════════════════════════════════════════════
  group('ShareUtils.share() — sharePositionOriginパラメータ', () {
    testWidgets(
      'sharePositionOriginを渡して呼び出せる（Redフェーズ: コンパイルエラー）',
      (tester) async {
        await tester.pumpWidget(
          const MaterialApp(home: Scaffold(body: SizedBox())),
        );
        final context = tester.element(find.byType(Scaffold));
        final state = SearchState(selectedMeetingPoint: _meetingPoint);

        // ↓ sharePositionOrigin パラメータが存在しないためコンパイルエラー（Red）
        await ShareUtils.share(
          context,
          state,
          sharePositionOrigin: const Rect.fromLTWH(0, 0, 100, 50),
        );
      },
    );

    testWidgets(
      'sharePositionOriginを省略しても呼び出せる（後方互換）',
      (tester) async {
        await tester.pumpWidget(
          const MaterialApp(home: Scaffold(body: SizedBox())),
        );
        final context = tester.element(find.byType(Scaffold));
        final state = SearchState(); // meetingPoint なし → share は何もしない

        // パラメータなし呼び出しは既存動作を維持する
        // テキストが空なので Share.share() は呼ばれない（クラッシュしない）
        await ShareUtils.share(context, state);
      },
    );
  });

  // ══════════════════════════════════════════════════════════════
  // ② buildMeetingPointText — 回帰テスト
  // 【現状 Green】materialIcon 削除後も通り続けること
  // ══════════════════════════════════════════════════════════════
  group('ShareUtils.buildMeetingPointText() — 回帰テスト', () {
    test('selectedMeetingPointがnullのとき空文字を返す', () {
      final state = SearchState();
      expect(ShareUtils.buildMeetingPointText(state), isEmpty);
    });

    test('集合地点がある場合は駅名・参加者移動時間を含む', () {
      final state = SearchState(selectedMeetingPoint: _meetingPoint);
      final text = ShareUtils.buildMeetingPointText(state);
      expect(text, isNotEmpty);
      expect(text, contains('渋谷'));
      expect(text, contains('Aさん'));
      expect(text, contains('Bさん'));
    });

    test('Occasion設定に関わらずApp Storeリンクを含む', () {
      final state = SearchState(
        occasion: Occasion.birthday,
        selectedMeetingPoint: const MeetingPoint(
          stationIndex: 0,
          stationName: '新宿',
          stationEmoji: '🚉',
          lat: 35.6896,
          lng: 139.7006,
          totalMinutes: 15,
          maxMinutes: 10,
          minMinutes: 5,
          averageMinutes: 7.5,
          fairnessScore: 0.8,
          overallScore: 0.75,
          participantTimes: {'Cさん': 5, 'Dさん': 10},
        ),
      );
      final text = ShareUtils.buildMeetingPointText(state);
      expect(text, contains('apps.apple.com'));
      expect(text, contains('Aimachi'));
    });
  });

  // ══════════════════════════════════════════════════════════════
  // ③ buildRestaurantShareText — 回帰テスト
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
