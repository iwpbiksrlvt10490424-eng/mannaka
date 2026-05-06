// TDD 規格テスト（Refactor Safe / 出力バイト列スナップショット）
// Cycle 27: buildRestaurantShareText の本文ブロック構成を equals で固定する。
//
// 背景:
//   Cycle 23-26 の改修群（LINE 誘導文の定数集約・決定 CTA の定数集約・
//   share_preview_screen フォールバック分岐削除）はいずれも「出力バイト列
//   不変」を Refactor Safe の前提として施工された。しかし既存テストは
//   「contains で部分文字列を見るだけ」「リテラル単一所在を grep で見る
//   だけ」のレベルに留まり、本文の **ブロック順序** や **境界値で行が
//   出る/消える** 挙動は機械的に守られていない。
//
//   本サイクルは production 差分ゼロで、buildRestaurantShareText
//   （share_utils.dart:109-156）の以下 invariant を 8 ケースで固定する:
//
//     - 見出し / 店名 / カテゴリ / 予算 / 評価 / 全員の移動時間 /
//       代替案 / 決定 CTA / App Store URL の **順序**
//     - priceAvg=0 で予算行が **出ない**、priceAvg=1 で **出る**
//     - rating<3.0 で評価行が **出ない**、rating>=3.0 で **出る**
//     - includeBackup=false なら top3>1 でも代替案ブロックが出ない
//     - top3.length<=1 では代替案ブロックが出ない
//     - top3.length>=4 でも代替案は **2 件で打ち切られる**（i<=2 ガード）
//     - 全ブロック合成スナップショットがバイト一致する
//
// 注:
//   - foundOnAimachiCta / appStoreUrl の **値** は Cycle 24/25/16 系の
//     既存テストが守る。本テストは構造（順序・境界）のみを担保する。
//   - 期待値は ShareUtils.foundOnAimachiCta / ShareUtils.appStoreUrl を
//     interpolate して構築するので、CTA/URL の **値の変更** は他テストで
//     検出される（このテストでは結合だけを担保する）。

import 'package:flutter_test/flutter_test.dart';
import 'package:mannaka/models/meeting_point.dart';
import 'package:mannaka/models/restaurant.dart';
import 'package:mannaka/models/scored_restaurant.dart';
import 'package:mannaka/providers/search_provider.dart';
import 'package:mannaka/utils/share_utils.dart';

// ── ヘルパー ──────────────────────────────────────────────
Restaurant _restaurant({
  required String id,
  required String name,
  String category = 'イタリアン',
  double rating = 2.5,
  int priceAvg = 0,
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

ScoredRestaurant _scored(Restaurant r) {
  return ScoredRestaurant(
    restaurant: r,
    score: 0.8,
    distanceKm: 0.4,
    participantDistances: const {},
    fairnessScore: 0.8,
  );
}

MeetingPoint _point(Map<String, int> times) {
  return MeetingPoint(
    stationIndex: 0,
    stationName: '新宿',
    stationEmoji: '🚉',
    lat: 35.690,
    lng: 139.700,
    totalMinutes: times.values.fold(0, (a, b) => a + b),
    maxMinutes: times.values.isEmpty ? 0 : times.values.reduce((a, b) => a > b ? a : b),
    minMinutes: times.values.isEmpty ? 0 : times.values.reduce((a, b) => a < b ? a : b),
    averageMinutes: 10,
    fairnessScore: 0.9,
    overallScore: 0.9,
    participantTimes: times,
  );
}

void main() {
  // ══════════════════════════════════════════════════════════════
  // [C1] 最小ケース — equals で全文固定
  //      priceAvg=0, rating<3.0, no meetingPoint, includeBackup=false
  //      → 見出し / 店名 / カテゴリ / 決定 CTA / URL のみ
  // ══════════════════════════════════════════════════════════════
  group('buildRestaurantShareText [C1] 最小ケース', () {
    test('priceAvg=0 / rating<3.0 / no time / no backup のとき本文は最小構成になる', () {
      final r = _restaurant(
        id: 'r1',
        name: 'テスト食堂',
        category: 'イタリアン',
        rating: 2.5,
        priceAvg: 0,
      );
      final sr = _scored(r);
      final state = SearchState();

      final text = ShareUtils.buildRestaurantShareText(
        state,
        primaryScored: sr,
        includeBackup: false,
      );

      const expected =
          'お店が決まりました\n'
          '\n'
          'テスト食堂\n'
          'イタリアン\n'
          '\n'
          'Aimachi で見つけました\n'
          'https://apps.apple.com/jp/app/aimachi/id6761008332\n';

      expect(
        text,
        equals(expected),
        reason:
            '最小ケース（予算行・評価行・移動時間ブロック・代替案ブロックがいずれも\n'
            '抑止される条件）の本文バイト列が変化した。\n'
            'Cycle 23-26 の Refactor Safe 前提（出力不変）を破っている可能性が高い。',
      );
    });
  });

  // ══════════════════════════════════════════════════════════════
  // [C2] 予算境界値 — priceAvg=1 で「予算 ¥1〜」行が出る
  //      （`if (r.priceAvg > 0)` の 0 直上の境界）
  // ══════════════════════════════════════════════════════════════
  group('buildRestaurantShareText [C2] 予算境界 priceAvg=1', () {
    test('priceAvg=1 のとき "予算 ¥1〜" 行がカテゴリ直下に挿入される', () {
      final r = _restaurant(
        id: 'r2',
        name: 'テスト食堂',
        category: 'イタリアン',
        rating: 2.5,
        priceAvg: 1,
      );
      final sr = _scored(r);
      final state = SearchState();

      final text = ShareUtils.buildRestaurantShareText(
        state,
        primaryScored: sr,
        includeBackup: false,
      );

      const expected =
          'お店が決まりました\n'
          '\n'
          'テスト食堂\n'
          'イタリアン\n'
          '予算 ¥1〜\n'
          '\n'
          'Aimachi で見つけました\n'
          'https://apps.apple.com/jp/app/aimachi/id6761008332\n';

      expect(
        text,
        equals(expected),
        reason:
            '`if (r.priceAvg > 0)` の境界値（priceAvg=1）で予算行が挿入される\n'
            '位置・書式が変化した。priceStr の formatter（カンマ区切り）含めて\n'
            '受信者に届くバイト列を保護する。',
      );
    });
  });

  // ══════════════════════════════════════════════════════════════
  // [C3] 評価境界値 — rating=2.99 で評価行なし、rating=3.0 で評価行あり
  //      （`if (r.rating >= 3.0)` の境界）
  // ══════════════════════════════════════════════════════════════
  group('buildRestaurantShareText [C3] 評価境界 rating>=3.0', () {
    test('rating=2.99 のとき評価行は出ない', () {
      final r = _restaurant(
        id: 'r3a',
        name: 'テスト食堂',
        rating: 2.99,
        priceAvg: 0,
      );
      final sr = _scored(r);
      final state = SearchState();

      final text = ShareUtils.buildRestaurantShareText(
        state,
        primaryScored: sr,
        includeBackup: false,
      );

      expect(
        text.contains('評価'),
        isFalse,
        reason:
            'rating=2.99 は `>= 3.0` を満たさないため評価行は出してはならない。\n'
            '実際の本文:\n$text',
      );
    });

    test('rating=3.0 ちょうどのとき "評価 3.0" 行がカテゴリ直下に挿入される', () {
      final r = _restaurant(
        id: 'r3b',
        name: 'テスト食堂',
        category: 'イタリアン',
        rating: 3.0,
        priceAvg: 0,
      );
      final sr = _scored(r);
      final state = SearchState();

      final text = ShareUtils.buildRestaurantShareText(
        state,
        primaryScored: sr,
        includeBackup: false,
      );

      const expected =
          'お店が決まりました\n'
          '\n'
          'テスト食堂\n'
          'イタリアン\n'
          '評価 3.0\n'
          '\n'
          'Aimachi で見つけました\n'
          'https://apps.apple.com/jp/app/aimachi/id6761008332\n';

      expect(
        text,
        equals(expected),
        reason:
            'rating=3.0 ちょうど（境界値）で評価行が挿入される位置・書式\n'
            '（小数 1 桁）が変化した。',
      );
    });
  });

  // ══════════════════════════════════════════════════════════════
  // [C4] 全員の移動時間ブロック — participantTimes の挿入順序を保ち
  //      `  名前：分数分` の書式で各行が並ぶ
  // ══════════════════════════════════════════════════════════════
  group('buildRestaurantShareText [C4] 全員の移動時間ブロック', () {
    test('selectedMeetingPoint がある場合、participantTimes が宣言順で本文に並ぶ', () {
      final r = _restaurant(
        id: 'r4',
        name: 'テスト食堂',
        category: 'イタリアン',
        rating: 2.5,
        priceAvg: 0,
      );
      final sr = _scored(r);
      // Map リテラルは挿入順を保つ（Dart は LinkedHashMap がデフォルト）
      final point = _point(const {'あや': 12, 'ゆう': 8, 'まな': 15});
      final state = SearchState(selectedMeetingPoint: point);

      final text = ShareUtils.buildRestaurantShareText(
        state,
        primaryScored: sr,
        includeBackup: false,
      );

      const expected =
          'お店が決まりました\n'
          '\n'
          'テスト食堂\n'
          'イタリアン\n'
          '\n'
          '全員の移動時間\n'
          '  あや：12分\n'
          '  ゆう：8分\n'
          '  まな：15分\n'
          '\n'
          'Aimachi で見つけました\n'
          'https://apps.apple.com/jp/app/aimachi/id6761008332\n';

      expect(
        text,
        equals(expected),
        reason:
            '全員の移動時間ブロックの「2 行スペース挿入」「インデント 2」\n'
            '「全角コロン」「分単位」「Map 挿入順保持」のいずれかが\n'
            '崩れた可能性がある。',
      );
    });
  });

  // ══════════════════════════════════════════════════════════════
  // [C5] includeBackup=false かつ top3.length>=2 でも代替案ブロックは出ない
  // ══════════════════════════════════════════════════════════════
  group('buildRestaurantShareText [C5] includeBackup=false で代替案抑止', () {
    test('sortedRestaurants が複数件あっても includeBackup=false なら "代替案" は出ない', () {
      final primary = _scored(_restaurant(id: 'p', name: 'テスト食堂'));
      final alt1 = _scored(_restaurant(
          id: 'a1', name: '代替1', category: 'フレンチ', priceAvg: 2500));
      final alt2 = _scored(_restaurant(
          id: 'a2', name: '代替2', category: '中華', priceAvg: 4000));
      final state = SearchState(sortedCache: [primary, alt1, alt2]);

      final text = ShareUtils.buildRestaurantShareText(
        state,
        primaryScored: primary,
        includeBackup: false,
      );

      expect(
        text.contains('代替案'),
        isFalse,
        reason:
            'includeBackup=false のとき代替案ブロックは出してはならない。\n'
            '実際の本文:\n$text',
      );
      expect(
        text.contains('代替1'),
        isFalse,
        reason: 'includeBackup=false のとき alt1 の店名も出てはならない。',
      );
    });
  });

  // ══════════════════════════════════════════════════════════════
  // [C6] includeBackup=true でも top3.length<=1 では代替案ブロックは出ない
  // ══════════════════════════════════════════════════════════════
  group('buildRestaurantShareText [C6] top3<=1 で代替案抑止', () {
    test('sortedRestaurants が空でも includeBackup=true で代替案ブロックは出ない', () {
      final primary = _scored(_restaurant(id: 'p', name: 'テスト食堂'));
      // sortedCache を渡さない → sortedRestaurants は空（hasCentroid=false）
      final state = SearchState();

      final text = ShareUtils.buildRestaurantShareText(
        state,
        primaryScored: primary,
        includeBackup: true,
      );

      expect(
        text.contains('代替案'),
        isFalse,
        reason:
            'top3.length=0 では `if (top3.length > 1)` ガードで代替案ブロックは\n'
            '出してはならない。実際の本文:\n$text',
      );
    });

    test('sortedRestaurants が 1 件のみのとき includeBackup=true でも代替案ブロックは出ない', () {
      final primary = _scored(_restaurant(id: 'p', name: 'テスト食堂'));
      final state = SearchState(sortedCache: [primary]);

      final text = ShareUtils.buildRestaurantShareText(
        state,
        primaryScored: primary,
        includeBackup: true,
      );

      expect(
        text.contains('代替案'),
        isFalse,
        reason:
            'top3.length=1 では `top3.length > 1` ガードで代替案ブロックは\n'
            '出してはならない（境界値）。実際の本文:\n$text',
      );
    });
  });

  // ══════════════════════════════════════════════════════════════
  // [C7] 代替案最大件数 — sortedRestaurants 4 件あっても 2 件で打ち切る
  //      （`take(3)` で top3 が 3 件 / `i<=2` ループで alt は 2 件）
  // ══════════════════════════════════════════════════════════════
  group('buildRestaurantShareText [C7] 代替案 2 件打ち切り', () {
    test('sortedRestaurants 4 件 + includeBackup=true でも代替案は alt1/alt2 の 2 件のみ', () {
      final primary = _scored(_restaurant(id: 'p', name: 'テスト食堂'));
      final alt1 = _scored(_restaurant(
          id: 'a1', name: '代替1', category: 'イタリアン', priceAvg: 2500));
      final alt2 = _scored(_restaurant(
          id: 'a2', name: '代替2', category: 'フレンチ', priceAvg: 4000));
      final alt3 = _scored(_restaurant(
          id: 'a3', name: '代替3', category: '中華', priceAvg: 1500));
      final state = SearchState(sortedCache: [primary, alt1, alt2, alt3]);

      final text = ShareUtils.buildRestaurantShareText(
        state,
        primaryScored: primary,
        includeBackup: true,
      );

      expect(
        text.contains('代替1（イタリアン / ¥2,500〜）'),
        isTrue,
        reason: '代替案 1 件目（alt1）の書式が崩れた。実際の本文:\n$text',
      );
      expect(
        text.contains('代替2（フレンチ / ¥4,000〜）'),
        isTrue,
        reason: '代替案 2 件目（alt2）の書式が崩れた。実際の本文:\n$text',
      );
      expect(
        text.contains('代替3'),
        isFalse,
        reason:
            'sortedRestaurants が 4 件あっても代替案は 2 件で打ち切られなければ\n'
            'ならない（take(3) で top3=3、i<=2 で 2 件）。\n'
            '実際の本文:\n$text',
      );
    });
  });

  // ══════════════════════════════════════════════════════════════
  // [C8] 全ブロック合成スナップショット — 全条件を満たした完全フォーマット
  // ══════════════════════════════════════════════════════════════
  group('buildRestaurantShareText [C8] 全ブロック合成スナップショット', () {
    test('全条件成立時の本文は規定フォーマットでバイト一致する', () {
      final primary = _scored(_restaurant(
        id: 'p',
        name: '本店',
        category: '和食',
        rating: 4.0,
        priceAvg: 3000,
      ));
      final alt1 = _scored(_restaurant(
        id: 'a1',
        name: '代替1',
        category: 'イタリアン',
        priceAvg: 2500,
      ));
      final alt2 = _scored(_restaurant(
        id: 'a2',
        name: '代替2',
        category: 'フレンチ',
        priceAvg: 4000,
      ));
      // 4 件目を入れて take(3) と i<=2 ガードの両方を同時に通す
      final alt3 = _scored(_restaurant(
        id: 'a3',
        name: '代替3',
        category: '中華',
        priceAvg: 1500,
      ));
      final point = _point(const {'あや': 12, 'ゆう': 8});
      final state = SearchState(
        selectedMeetingPoint: point,
        sortedCache: [primary, alt1, alt2, alt3],
      );

      final text = ShareUtils.buildRestaurantShareText(
        state,
        primaryScored: primary,
        includeBackup: true,
      );

      const expected =
          'お店が決まりました\n'
          '\n'
          '本店\n'
          '和食\n'
          '予算 ¥3,000〜\n'
          '評価 4.0\n'
          '\n'
          '全員の移動時間\n'
          '  あや：12分\n'
          '  ゆう：8分\n'
          '\n'
          '代替案\n'
          '代替1（イタリアン / ¥2,500〜）\n'
          '代替2（フレンチ / ¥4,000〜）\n'
          '\n'
          'Aimachi で見つけました\n'
          'https://apps.apple.com/jp/app/aimachi/id6761008332\n';

      expect(
        text,
        equals(expected),
        reason:
            '全ブロック合成時の本文バイト列が変化した。Cycle 23-26 の\n'
            '「Refactor Safe（出力バイト列不変）」前提が破られた可能性。\n'
            '\n'
            '期待フォーマット:\n'
            '  見出し → 空行 → 店名 → カテゴリ → 予算 → 評価\n'
            '  → 空行 → 全員の移動時間 (header + lines) → 空行\n'
            '  → 代替案 (header + 最大2行) → 空行\n'
            '  → 決定 CTA → App Store URL',
      );
    });
  });
}
