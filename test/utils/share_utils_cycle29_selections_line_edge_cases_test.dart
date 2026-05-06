// TDD 規格テスト（Refactor Safe / 出力バイト列スナップショット）
// Cycle 29: buildLineTextForSelections の本文ブロック構成を equals で固定する。
//
// 背景:
//   `buildLineTextForSelections`（share_utils.dart:164-207）は **下部バー
//   「候補リストを LINE で送る」で本番ユーザーが LINE に流すテキスト** を
//   組み立てる高インパクトな関数。10 引数〜複数 optional 分岐を持ち、
//   `take(5)` 上限・`rating > 0` 境界・`hotpepperUrl` null フォールバックなど
//   性質の違う分岐が多い。
//
//   既存の Cycle 24 テスト（cycle24_line_cta_test.dart）は LINE 誘導 CTA の
//   リテラル単一所在のみを `contains` で守るのみで、**本文ブロックの順序・
//   改行挿入位置・境界値で行が出る/消える** 挙動は機械的に守られていない。
//
//   Cycle 27（buildRestaurantShareText）/ Cycle 28（buildReservationLineText）
//   と同型の characterization snapshot test を被せて、将来改修からバイト列
//   を守る。production 差分ゼロ。
//
//   本サイクルで固定する invariant（C1〜C10）:
//
//     [C1] selections が空のとき '' を返す（早期 return）
//     [C2] 最小1件 — date/time なし / rating=0 / priceAvg=0 / hotpepperUrl
//          null のとき、フォールバック URL を組む（番号付き 1 件構成）
//     [C3] hotpepperUrl 非空のとき shortStoreUrl は **そのままの URL** を返し、
//          maps フォールバックに落ちない
//     [C4] rating 境界値 — rating=0 で ★ 行が出ない / rating=0.1 で出る
//          （`r.rating > 0` ガードの直上下を機械的に固定）
//     [C5] priceStr 反映 — priceAvg=0 で '予算情報なし' / priceAvg=3000 で
//          '¥3,000〜'（カンマ区切り）が meta 行に入る
//     [C6] take(5) 上限 — 6 件渡しても番号付き本文は 5 件で打ち切られ、
//          連番は 1.〜5. になる
//     [C7] 🗓 日時ブロック — date のみ / time のみ / 両方ありの順序と書式
//     [C8] 時刻 0 パディング — hour=9/minute=5 で "09:05"、hour=0/minute=0
//          で "00:00"
//     [C9] 末尾仕様 — `sb.write(appStoreUrl)` のため改行で終わらず
//          ShareUtils.appStoreUrl で完全一致終了する
//     [C10] 全ブロック合成スナップショット — 全条件成立時の完全フォーマット
//          がバイト一致する
//
// 注:
//   - 本テストは production コード差分ゼロ。書いた瞬間に Green であるのが
//     正しい状態（characterization snapshot）。
//   - `appStoreUrl` / `lineDownloadCta` の値変更は Cycle 16/24/25 系の既存
//     テストが検出する。本テストは構造（順序・境界・take 上限・末尾仕様）
//     のみを担保する。
//   - `buildLineTextForMeetingPoints` は Cycle 30 候補としてスコープ外。

import 'package:flutter/material.dart' show TimeOfDay;
import 'package:flutter_test/flutter_test.dart';
import 'package:mannaka/models/restaurant.dart';
import 'package:mannaka/models/scored_restaurant.dart';
import 'package:mannaka/providers/search_provider.dart';
import 'package:mannaka/utils/share_utils.dart';

// ── ヘルパー ──────────────────────────────────────────────
Restaurant _restaurant({
  required String id,
  required String name,
  String category = 'イタリアン',
  double rating = 0,
  int priceAvg = 0,
  String? hotpepperUrl,
  String stationName = '',
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
    hotpepperUrl: hotpepperUrl,
    stationName: stationName,
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

({String station, ScoredRestaurant scored}) _entry({
  required String station,
  required ScoredRestaurant scored,
}) =>
    (station: station, scored: scored);

void main() {
  // ══════════════════════════════════════════════════════════════
  // [C1] selections 空 — 早期 return で空文字
  // ══════════════════════════════════════════════════════════════
  group('buildLineTextForSelections [C1] selections 空', () {
    test('selections が空のとき 本文は空文字列で即 return', () {
      final state = SearchState();

      final text = ShareUtils.buildLineTextForSelections(state, const []);

      expect(
        text,
        equals(''),
        reason:
            'selections.isEmpty のとき関数先頭で `return ""` する仕様。\n'
            'ヘッダ等は組まれず空文字でなければならない（呼び出し元の\n'
            '`if (text.isEmpty) return;` 早期離脱前提）。',
      );
    });
  });

  // ══════════════════════════════════════════════════════════════
  // [C2] 最小 1 件 — date/time なし / rating=0 / priceAvg=0 /
  //      hotpepperUrl null のフォールバック URL 構成
  // ══════════════════════════════════════════════════════════════
  group('buildLineTextForSelections [C2] 最小 1 件 / フォールバック URL', () {
    test('hotpepperUrl null のとき maps フォールバック URL が組まれ、'
        'rating=0 で ★ 行が消え、🗓 ブロックが出ない', () {
      final r = _restaurant(
        id: 'r1',
        name: 'テスト食堂',
        category: 'イタリアン',
        rating: 0,
        priceAvg: 0,
        hotpepperUrl: null,
        stationName: '渋谷',
      );
      final sr = _scored(r);
      final state = SearchState();

      final text = ShareUtils.buildLineTextForSelections(
        state,
        [_entry(station: '渋谷', scored: sr)],
      );

      // shortStoreUrl: hotpepperUrl=null → 'https://maps.google.com/?q=<encoded>'
      // bits.join(' ') = 'テスト食堂 渋谷' → encodeComponent
      const fallback =
          'https://maps.google.com/?q=%E3%83%86%E3%82%B9%E3%83%88%E9%A3%9F'
          '%E5%A0%82%20%E6%B8%8B%E8%B0%B7';

      const expected =
          'Aimachiで探したお店の候補を共有します\n'
          '\n'
          '\n'
          '1. テスト食堂（渋谷駅）\n'
          '  イタリアン / 予算情報なし\n'
          '  $fallback\n'
          '\n'
          '1回で送れるのは5件までです\n'
          'あなたもAimachi（無料）で同じ条件のお店を探してみましょう👇\n'
          'https://apps.apple.com/jp/app/aimachi/id6761008332';

      expect(
        text,
        equals(expected),
        reason:
            '最小ケースのバイト列が崩れた。期待した不変量:\n'
            '  - 見出し直後の空行（writeln("")）は date/time なしでも残る\n'
            '  - 1 件目の前にも空行（for ループ先頭の writeln("")）が入る\n'
            '  - rating=0 では ★ 行は meta に入らない\n'
            '  - priceAvg=0 では priceStr が "予算情報なし" になる\n'
            '  - hotpepperUrl=null は maps URL に落ち、name+stationName を\n'
            '    URI.encodeComponent して q= に積む\n'
            '\n'
            '実際の本文:\n$text',
      );
    });
  });

  // ══════════════════════════════════════════════════════════════
  // [C3] hotpepperUrl 非空 — そのままの URL がそのまま入り、
  //      maps フォールバックに落ちない
  // ══════════════════════════════════════════════════════════════
  group('buildLineTextForSelections [C3] hotpepperUrl 非空', () {
    test('hotpepperUrl が非空のとき shortStoreUrl はそのまま返し、'
        'maps URL フォールバックには落ちない', () {
      const url = 'https://www.hotpepper.jp/strJ001234567/';
      final r = _restaurant(
        id: 'r1',
        name: 'テスト食堂',
        category: 'イタリアン',
        rating: 0,
        priceAvg: 0,
        hotpepperUrl: url,
        stationName: '渋谷',
      );
      final sr = _scored(r);
      final state = SearchState();

      final text = ShareUtils.buildLineTextForSelections(
        state,
        [_entry(station: '渋谷', scored: sr)],
      );

      expect(
        text.contains('  $url\n'),
        isTrue,
        reason:
            'hotpepperUrl 非空のとき URL 行はそのまま `  $url` でなければならない。\n'
            '実際の本文:\n$text',
      );
      expect(
        text.contains('maps.google.com/?q='),
        isFalse,
        reason:
            'hotpepperUrl が与えられているのに maps フォールバック URL が出ている。\n'
            'shortStoreUrl の優先順位（hotpepperUrl > maps）が崩れた可能性。\n'
            '実際の本文:\n$text',
      );
    });
  });

  // ══════════════════════════════════════════════════════════════
  // [C4] rating > 0 境界値 — rating=0 で ★ 出ない / rating=0.1 で出る
  // ══════════════════════════════════════════════════════════════
  group('buildLineTextForSelections [C4] rating 境界値', () {
    test('rating=0 のとき ★ メタは出ない（meta=[category, priceStr] のみ）', () {
      final r = _restaurant(
        id: 'r1',
        name: 'テスト食堂',
        category: 'イタリアン',
        rating: 0,
        priceAvg: 0,
        hotpepperUrl: 'https://example.com/r1',
      );
      final sr = _scored(r);
      final state = SearchState();

      final text = ShareUtils.buildLineTextForSelections(
        state,
        [_entry(station: '渋谷', scored: sr)],
      );

      expect(
        text.contains('★'),
        isFalse,
        reason:
            'rating=0 は `r.rating > 0` を満たさず ★ メタは付かない仕様。\n'
            '実際の本文:\n$text',
      );
      expect(
        text.contains('  イタリアン / 予算情報なし\n'),
        isTrue,
        reason: 'meta 行は category と priceStr のみで構成される必要がある。',
      );
    });

    test('rating=0.1 のとき ★0.1 メタが付く（境界の直上）', () {
      final r = _restaurant(
        id: 'r1',
        name: 'テスト食堂',
        category: 'イタリアン',
        rating: 0.1,
        priceAvg: 0,
        hotpepperUrl: 'https://example.com/r1',
      );
      final sr = _scored(r);
      final state = SearchState();

      final text = ShareUtils.buildLineTextForSelections(
        state,
        [_entry(station: '渋谷', scored: sr)],
      );

      expect(
        text.contains('  イタリアン / 予算情報なし / ★0.1\n'),
        isTrue,
        reason:
            'rating=0.1（>0 の直上）で ★0.1 メタが meta 末尾に追加される必要がある。\n'
            'toStringAsFixed(1) で小数 1 桁固定。実際の本文:\n$text',
      );
    });
  });

  // ══════════════════════════════════════════════════════════════
  // [C5] priceStr 反映 — priceAvg=0 と非0 で文言が切り替わる
  // ══════════════════════════════════════════════════════════════
  group('buildLineTextForSelections [C5] priceStr 反映', () {
    test('priceAvg=3000 のとき meta に "¥3,000〜" がカンマ区切りで入る', () {
      final r = _restaurant(
        id: 'r1',
        name: 'テスト食堂',
        category: 'イタリアン',
        rating: 0,
        priceAvg: 3000,
        hotpepperUrl: 'https://example.com/r1',
      );
      final sr = _scored(r);
      final state = SearchState();

      final text = ShareUtils.buildLineTextForSelections(
        state,
        [_entry(station: '渋谷', scored: sr)],
      );

      expect(
        text.contains('  イタリアン / ¥3,000〜\n'),
        isTrue,
        reason:
            'priceAvg>0 で priceStr は "¥{N}〜"（3 桁区切りカンマ）になる仕様。\n'
            '実際の本文:\n$text',
      );
    });

    test('priceAvg=0 のとき meta に "予算情報なし" が入る', () {
      final r = _restaurant(
        id: 'r1',
        name: 'テスト食堂',
        category: 'イタリアン',
        rating: 0,
        priceAvg: 0,
        hotpepperUrl: 'https://example.com/r1',
      );
      final sr = _scored(r);
      final state = SearchState();

      final text = ShareUtils.buildLineTextForSelections(
        state,
        [_entry(station: '渋谷', scored: sr)],
      );

      expect(
        text.contains('  イタリアン / 予算情報なし\n'),
        isTrue,
        reason:
            'priceAvg=0（情報なし）で priceStr は "予算情報なし" 固定。\n'
            '"¥0〜" のような誤表示が出てはならない。実際の本文:\n$text',
      );
    });
  });

  // ══════════════════════════════════════════════════════════════
  // [C6] take(5) 上限 — 6 件渡しても本文は 5 件で打ち切り、連番 1.〜5.
  // ══════════════════════════════════════════════════════════════
  group('buildLineTextForSelections [C6] take(5) 上限', () {
    test('selections 6 件のとき本文は 5 件で打ち切られ、6 件目は出ない', () {
      final entries = List.generate(6, (i) {
        final r = _restaurant(
          id: 'r$i',
          name: '店${i + 1}',
          category: 'イタリアン',
          rating: 0,
          priceAvg: 0,
          hotpepperUrl: 'https://example.com/r$i',
        );
        return _entry(station: '渋谷', scored: _scored(r));
      });
      final state = SearchState();

      final text =
          ShareUtils.buildLineTextForSelections(state, entries);

      // 1〜5 番目は出る
      for (var i = 1; i <= 5; i++) {
        expect(
          text.contains('$i. 店$i（渋谷駅）\n'),
          isTrue,
          reason:
              '$i 件目が本文に含まれていない。take(5) 上限の **直下** は\n'
              'すべて含まれていなければならない。実際の本文:\n$text',
        );
      }
      // 6 番目は出ない（take(5) で切られるため）
      expect(
        text.contains('6. 店6'),
        isFalse,
        reason:
            '6 件目は selections.take(5) で切られて本文に出ない仕様。\n'
            'UI 側でも 6 件目以降は選択できないが、関数自体も保険として\n'
            'take(5) を持つ。実際の本文:\n$text',
      );
    });
  });

  // ══════════════════════════════════════════════════════════════
  // [C7] 🗓 日時ブロック — date / time の有無で挙動が変わる
  // ══════════════════════════════════════════════════════════════
  group('buildLineTextForSelections [C7] 🗓 日時ブロック', () {
    test('date のみのとき "🗓 M/D" 行が見出し直後に出る（時刻なし）', () {
      final r = _restaurant(
        id: 'r1',
        name: 'テスト食堂',
        category: 'イタリアン',
        rating: 0,
        priceAvg: 0,
        hotpepperUrl: 'https://example.com/r1',
      );
      final sr = _scored(r);
      final state = SearchState(selectedDate: DateTime(2026, 4, 30));

      final text = ShareUtils.buildLineTextForSelections(
        state,
        [_entry(station: '渋谷', scored: sr)],
      );

      expect(
        text.contains('\n🗓 4/30\n'),
        isTrue,
        reason:
            'date のみのとき parts.join(" ") = "M/D" になり時刻が付かない。\n'
            '末尾スペースが残ってもいけない。実際の本文:\n$text',
      );
    });

    test('time のみのとき "🗓 HH:MM" 行が見出し直後に出る（日付なし）', () {
      final r = _restaurant(
        id: 'r1',
        name: 'テスト食堂',
        category: 'イタリアン',
        rating: 0,
        priceAvg: 0,
        hotpepperUrl: 'https://example.com/r1',
      );
      final sr = _scored(r);
      final state = SearchState(
        selectedMeetingTime: const TimeOfDay(hour: 19, minute: 30),
      );

      final text = ShareUtils.buildLineTextForSelections(
        state,
        [_entry(station: '渋谷', scored: sr)],
      );

      expect(
        text.contains('\n🗓 19:30\n'),
        isTrue,
        reason:
            'time のみのとき parts.join(" ") = "HH:MM" になり日付が付かない。\n'
            '実際の本文:\n$text',
      );
    });

    test('date / time 両方ありのとき "🗓 M/D HH:MM" 1 行（半角スペース連結）', () {
      final r = _restaurant(
        id: 'r1',
        name: 'テスト食堂',
        category: 'イタリアン',
        rating: 0,
        priceAvg: 0,
        hotpepperUrl: 'https://example.com/r1',
      );
      final sr = _scored(r);
      final state = SearchState(
        selectedDate: DateTime(2026, 4, 30),
        selectedMeetingTime: const TimeOfDay(hour: 19, minute: 30),
      );

      final text = ShareUtils.buildLineTextForSelections(
        state,
        [_entry(station: '渋谷', scored: sr)],
      );

      expect(
        text.contains('\n🗓 4/30 19:30\n'),
        isTrue,
        reason:
            '両方あるとき "M/D HH:MM" の順序・半角スペース連結が崩れた可能性。\n'
            '実際の本文:\n$text',
      );
    });
  });

  // ══════════════════════════════════════════════════════════════
  // [C8] 時刻 0 パディング — hour/minute を 2 桁に揃える
  // ══════════════════════════════════════════════════════════════
  group('buildLineTextForSelections [C8] 時刻 0 パディング', () {
    test('hour=9 minute=5 のとき "09:05" に padLeft される', () {
      final r = _restaurant(
        id: 'r1',
        name: 'テスト食堂',
        category: 'イタリアン',
        rating: 0,
        priceAvg: 0,
        hotpepperUrl: 'https://example.com/r1',
      );
      final sr = _scored(r);
      final state = SearchState(
        selectedMeetingTime: const TimeOfDay(hour: 9, minute: 5),
      );

      final text = ShareUtils.buildLineTextForSelections(
        state,
        [_entry(station: '渋谷', scored: sr)],
      );

      expect(
        text.contains('🗓 09:05\n'),
        isTrue,
        reason:
            'hour/minute は `toString().padLeft(2, "0")` で 2 桁に揃える。\n'
            '"9:5" のような 1 桁表示になっていないか。実際の本文:\n$text',
      );
    });

    test('hour=0 minute=0（深夜 0:00 境界値）のとき "00:00" になる', () {
      final r = _restaurant(
        id: 'r1',
        name: 'テスト食堂',
        category: 'イタリアン',
        rating: 0,
        priceAvg: 0,
        hotpepperUrl: 'https://example.com/r1',
      );
      final sr = _scored(r);
      final state = SearchState(
        selectedMeetingTime: const TimeOfDay(hour: 0, minute: 0),
      );

      final text = ShareUtils.buildLineTextForSelections(
        state,
        [_entry(station: '渋谷', scored: sr)],
      );

      expect(
        text.contains('🗓 00:00\n'),
        isTrue,
        reason:
            'hour=0/minute=0 で "00:00" にならず空文字や "0:0" にならないか。\n'
            '実際の本文:\n$text',
      );
    });
  });

  // ══════════════════════════════════════════════════════════════
  // [C9] 末尾仕様 — `sb.write(appStoreUrl)` のため改行で終わらない
  // ══════════════════════════════════════════════════════════════
  group('buildLineTextForSelections [C9] 末尾仕様', () {
    test('本文末尾は appStoreUrl で終わり、改行で終わらない', () {
      final r = _restaurant(
        id: 'r1',
        name: 'テスト食堂',
        category: 'イタリアン',
        rating: 0,
        priceAvg: 0,
        hotpepperUrl: 'https://example.com/r1',
      );
      final sr = _scored(r);
      final state = SearchState();

      final text = ShareUtils.buildLineTextForSelections(
        state,
        [_entry(station: '渋谷', scored: sr)],
      );

      expect(
        text.endsWith('\n'),
        isFalse,
        reason:
            '末尾は `sb.write(appStoreUrl)`（writeln ではない）。\n'
            'LINE の URL プレビュー用に末尾改行を入れない仕様が崩れた。\n'
            '実際の本文末尾 20 文字: "${text.substring(text.length - 20)}"',
      );
      expect(
        text.endsWith(ShareUtils.appStoreUrl),
        isTrue,
        reason:
            '末尾は ShareUtils.appStoreUrl で完全一致終了する必要がある。\n'
            '実際の本文末尾 60 文字:\n${text.substring(text.length - 60)}',
      );
    });
  });

  // ══════════════════════════════════════════════════════════════
  // [C10] 全ブロック合成スナップショット — 全条件成立時の完全フォーマット
  // ══════════════════════════════════════════════════════════════
  group('buildLineTextForSelections [C10] 全ブロック合成スナップショット', () {
    test('日時 + 3 件（rating>0 / priceAvg>0 / hotpepperUrl あり）は'
        '規定フォーマットでバイト一致する', () {
      final r1 = _restaurant(
        id: 'r1',
        name: 'まんなか食堂',
        category: 'イタリアン',
        rating: 4.2,
        priceAvg: 3000,
        hotpepperUrl: 'https://www.hotpepper.jp/strJ001/',
      );
      final r2 = _restaurant(
        id: 'r2',
        name: 'ど真ん中ビストロ',
        category: 'フレンチ',
        rating: 4.5,
        priceAvg: 5000,
        hotpepperUrl: 'https://www.hotpepper.jp/strJ002/',
      );
      final r3 = _restaurant(
        id: 'r3',
        name: 'センターバル',
        category: 'スペイン料理',
        rating: 3.8,
        priceAvg: 4000,
        hotpepperUrl: 'https://www.hotpepper.jp/strJ003/',
      );
      final state = SearchState(
        selectedDate: DateTime(2026, 4, 30),
        selectedMeetingTime: const TimeOfDay(hour: 19, minute: 30),
      );

      final text = ShareUtils.buildLineTextForSelections(
        state,
        [
          _entry(station: '新宿', scored: _scored(r1)),
          _entry(station: '渋谷', scored: _scored(r2)),
          _entry(station: '池袋', scored: _scored(r3)),
        ],
      );

      const expected =
          'Aimachiで探したお店の候補を共有します\n'
          '\n'
          '🗓 4/30 19:30\n'
          '\n'
          '1. まんなか食堂（新宿駅）\n'
          '  イタリアン / ¥3,000〜 / ★4.2\n'
          '  https://www.hotpepper.jp/strJ001/\n'
          '\n'
          '2. ど真ん中ビストロ（渋谷駅）\n'
          '  フレンチ / ¥5,000〜 / ★4.5\n'
          '  https://www.hotpepper.jp/strJ002/\n'
          '\n'
          '3. センターバル（池袋駅）\n'
          '  スペイン料理 / ¥4,000〜 / ★3.8\n'
          '  https://www.hotpepper.jp/strJ003/\n'
          '\n'
          '1回で送れるのは5件までです\n'
          'あなたもAimachi（無料）で同じ条件のお店を探してみましょう👇\n'
          'https://apps.apple.com/jp/app/aimachi/id6761008332';

      expect(
        text,
        equals(expected),
        reason:
            '全ブロック合成時の本文バイト列が変化した。\n'
            '\n'
            '期待フォーマット:\n'
            '  見出し → 空行 → 🗓日時\n'
            '  → 空行 → 1.店名（駅） → meta → URL\n'
            '  → 空行 → 2.店名（駅） → meta → URL\n'
            '  → 空行 → 3.店名（駅） → meta → URL\n'
            '  → 空行 → "1回で送れるのは5件までです"\n'
            '  → LINE 誘導 CTA → App Store URL（末尾改行なし）\n'
            '\n'
            '注意: 各店舗ブロックの **前** に空行が入る（for ループ先頭の\n'
            'writeln("")）。最後の店舗の URL 行直後にも 1 件分空行があり、\n'
            'その後に「1回で送れるのは5件までです」が続く。',
      );
    });
  });
}
