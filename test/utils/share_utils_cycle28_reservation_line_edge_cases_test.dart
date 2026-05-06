// TDD 規格テスト（Refactor Safe / 出力バイト列スナップショット）
// Cycle 28: buildReservationLineText の本文ブロック構成を equals で固定する。
//
// 背景:
//   既存の `share_utils_reservation_line_test.dart` は `contains` ベースの
//   部分一致しか取らず、本文の **ブロック順序**・**改行挿入位置**・
//   **末尾仕様（writeln vs write）** が機械的に守られていない。
//
//   `buildReservationLineText` (`share_utils.dart:31-84`) は Hotpepper 予約
//   完了後に **本番ユーザーが LINE で実際に送るテキスト** を組み立てる
//   高インパクトな関数で、10 引数 / 5 個の optional 分岐を持つ。Cycle 27
//   の `buildRestaurantShareText` 同型の characterization snapshot test を
//   被せて、将来改修からバイト列を守る。
//
//   本サイクルは production 差分ゼロで、以下 invariant を 10 ケースで固定
//   する:
//
//     - 見出し / 📍店名 / category / 駅+徒歩 / 🗓 日時 / 👥 メンバー /
//       maps URL / DL 誘導文 / App Store URL の **順序**
//     - category 空 で行が出ない / category あり で 📍 直下に出る
//     - walkInfo の組み立て: stationName のみ / walkMinutes のみ / 両方 /
//       walkMinutes=0 で徒歩省略 / walkMinutes=1 境界値
//     - 🗓 ブロック: date のみ / time のみ / 両方 / 時刻 0 パディング
//     - 👥 行: 空配列で出ない / 空文字混入を `where(isNotEmpty)` で除外
//     - maps URL: lat/lng 片方欠けで出ない / 両方あり時の URL 書式
//     - 末尾は `sb.write(appStoreUrl)` のため **改行で終わらない**
//     - 全ブロック合成スナップショットがバイト一致する
//
// 注:
//   - 本テストは production コード差分ゼロ。書いた瞬間に Green であるのが
//     正しい状態（characterization snapshot）。
//   - `appStoreUrl` の値は ShareUtils.appStoreUrl から interpolate して
//     構築する。URL の値変更は他テスト（Cycle 16/24/25 系）が検出する。
//   - 既存 `share_utils_reservation_line_test.dart` は contains ベースの
//     仕様駆動テストとして温存（責務分離）。

import 'package:flutter/material.dart' show TimeOfDay;
import 'package:flutter_test/flutter_test.dart';
import 'package:mannaka/utils/share_utils.dart';

void main() {
  // ══════════════════════════════════════════════════════════════
  // [C1] 最小ケース — equals で全文固定
  //      restaurantName のみ、他全 optional は empty/null
  //      → 見出し / 📍店名 / DL 誘導文 / App Store URL のみ
  // ══════════════════════════════════════════════════════════════
  group('buildReservationLineText [C1] 最小ケース', () {
    test('全 optional が empty/null のとき本文は最小構成になる', () {
      final text = ShareUtils.buildReservationLineText(
        restaurantName: 'テスト店',
        category: '',
        stationName: '',
        walkMinutes: null,
        lat: null,
        lng: null,
        meetingDate: null,
        meetingTime: null,
        groupNames: const [],
      );

      const expected =
          'Aimachiで予約しました\n'
          '\n'
          '📍 テスト店\n'
          '\n'
          'みんなの集合場所、Aimachiならすぐ決まります\n'
          'https://apps.apple.com/jp/app/aimachi/id6761008332';

      expect(
        text,
        equals(expected),
        reason:
            '最小ケース（category 空 / walk 抑止 / 🗓 抑止 / 👥 抑止 / maps URL 抑止）\n'
            'の本文バイト列が変化した。Cycle 23-26 の Refactor Safe 前提（出力\n'
            'バイト列不変）を破っている可能性が高い。',
      );
    });
  });

  // ══════════════════════════════════════════════════════════════
  // [C2] category 行 — category が非空のとき 📍 直下に挿入される
  // ══════════════════════════════════════════════════════════════
  group('buildReservationLineText [C2] category 行', () {
    test('category が非空のとき 📍 店名の直下に category 行が挿入される', () {
      final text = ShareUtils.buildReservationLineText(
        restaurantName: 'テスト店',
        category: 'イタリアン',
        stationName: '',
        walkMinutes: null,
        lat: null,
        lng: null,
        meetingDate: null,
        meetingTime: null,
        groupNames: const [],
      );

      const expected =
          'Aimachiで予約しました\n'
          '\n'
          '📍 テスト店\n'
          'イタリアン\n'
          '\n'
          'みんなの集合場所、Aimachiならすぐ決まります\n'
          'https://apps.apple.com/jp/app/aimachi/id6761008332';

      expect(
        text,
        equals(expected),
        reason:
            'category 非空時の挿入位置（📍 店名直下 / walk より上）が崩れた可能性。\n'
            '実際の本文:\n$text',
      );
    });
  });

  // ══════════════════════════════════════════════════════════════
  // [C3] walkInfo 組み立てバリエーション
  //      `walkInfo = [stationName駅?, 徒歩X分?].join('から')`
  // ══════════════════════════════════════════════════════════════
  group('buildReservationLineText [C3] walkInfo 組み立て', () {
    test('stationName のみ（walkMinutes null）のとき "渋谷駅" 1 行のみ出る', () {
      final text = ShareUtils.buildReservationLineText(
        restaurantName: 'テスト店',
        category: '',
        stationName: '渋谷',
        walkMinutes: null,
        lat: null,
        lng: null,
        meetingDate: null,
        meetingTime: null,
        groupNames: const [],
      );

      const expected =
          'Aimachiで予約しました\n'
          '\n'
          '📍 テスト店\n'
          '渋谷駅\n'
          '\n'
          'みんなの集合場所、Aimachiならすぐ決まります\n'
          'https://apps.apple.com/jp/app/aimachi/id6761008332';

      expect(
        text,
        equals(expected),
        reason:
            'stationName のみのとき walkInfo は "<stationName>駅" 単独になり、\n'
            '"から" が前後に付いてはならない。',
      );
    });

    test('walkMinutes のみ（stationName 空）のとき "徒歩5分" 1 行のみ出る', () {
      final text = ShareUtils.buildReservationLineText(
        restaurantName: 'テスト店',
        category: '',
        stationName: '',
        walkMinutes: 5,
        lat: null,
        lng: null,
        meetingDate: null,
        meetingTime: null,
        groupNames: const [],
      );

      const expected =
          'Aimachiで予約しました\n'
          '\n'
          '📍 テスト店\n'
          '徒歩5分\n'
          '\n'
          'みんなの集合場所、Aimachiならすぐ決まります\n'
          'https://apps.apple.com/jp/app/aimachi/id6761008332';

      expect(
        text,
        equals(expected),
        reason:
            'walkMinutes のみのとき walkInfo は "徒歩X分" 単独になり、\n'
            '"から" が前後に付いてはならない（join("から") 仕様）。',
      );
    });

    test('stationName と walkMinutes 両方あるとき 駅+徒歩X分が 1 行に結合される', () {
      final text = ShareUtils.buildReservationLineText(
        restaurantName: 'テスト店',
        category: '',
        stationName: '渋谷',
        walkMinutes: 5,
        lat: null,
        lng: null,
        meetingDate: null,
        meetingTime: null,
        groupNames: const [],
      );

      const expected =
          'Aimachiで予約しました\n'
          '\n'
          '📍 テスト店\n'
          '渋谷駅から徒歩5分\n'
          '\n'
          'みんなの集合場所、Aimachiならすぐ決まります\n'
          'https://apps.apple.com/jp/app/aimachi/id6761008332';

      expect(
        text,
        equals(expected),
        reason:
            '両方ありのとき "から" 区切りで 1 行に結合される仕様が崩れた。',
      );
    });
  });

  // ══════════════════════════════════════════════════════════════
  // [C4] walkMinutes 境界値 — `walkMinutes != null && walkMinutes > 0`
  // ══════════════════════════════════════════════════════════════
  group('buildReservationLineText [C4] walkMinutes 境界値', () {
    test('walkMinutes=0 のとき徒歩部分は出ない（stationName のみ表示）', () {
      final text = ShareUtils.buildReservationLineText(
        restaurantName: 'テスト店',
        category: '',
        stationName: '池袋',
        walkMinutes: 0,
        lat: null,
        lng: null,
        meetingDate: null,
        meetingTime: null,
        groupNames: const [],
      );

      expect(
        text.contains('徒歩'),
        isFalse,
        reason:
            'walkMinutes=0 は `> 0` を満たさないため徒歩は出してはならない。\n'
            '実際の本文:\n$text',
      );
      expect(
        text.contains('池袋駅\n'),
        isTrue,
        reason: 'stationName 単独で walkInfo 行が出るべき。',
      );
    });

    test('walkMinutes=1 のとき徒歩 1 分行が出る（境界値の直上）', () {
      final text = ShareUtils.buildReservationLineText(
        restaurantName: 'テスト店',
        category: '',
        stationName: '池袋',
        walkMinutes: 1,
        lat: null,
        lng: null,
        meetingDate: null,
        meetingTime: null,
        groupNames: const [],
      );

      expect(
        text.contains('池袋駅から徒歩1分'),
        isTrue,
        reason:
            'walkMinutes=1（`> 0` 境界の直上）で徒歩 1 分行が出るべき。\n'
            '実際の本文:\n$text',
      );
    });
  });

  // ══════════════════════════════════════════════════════════════
  // [C5] 🗓 日時ブロック — date / time の有無で挙動が変わる
  // ══════════════════════════════════════════════════════════════
  group('buildReservationLineText [C5] 🗓 日時ブロック', () {
    test('meetingDate のみのとき "🗓 M/D" 単独行（時刻なし）', () {
      final text = ShareUtils.buildReservationLineText(
        restaurantName: 'テスト店',
        category: '',
        stationName: '',
        walkMinutes: null,
        lat: null,
        lng: null,
        meetingDate: DateTime(2026, 4, 30),
        meetingTime: null,
        groupNames: const [],
      );

      const expected =
          'Aimachiで予約しました\n'
          '\n'
          '📍 テスト店\n'
          '\n'
          '🗓 4/30\n'
          '\n'
          'みんなの集合場所、Aimachiならすぐ決まります\n'
          'https://apps.apple.com/jp/app/aimachi/id6761008332';

      expect(
        text,
        equals(expected),
        reason:
            'date のみのとき parts.join(" ") = "M/D" になり末尾スペース無し。',
      );
    });

    test('meetingTime のみのとき "🗓 HH:MM" 単独行（日付なし）', () {
      final text = ShareUtils.buildReservationLineText(
        restaurantName: 'テスト店',
        category: '',
        stationName: '',
        walkMinutes: null,
        lat: null,
        lng: null,
        meetingDate: null,
        meetingTime: const TimeOfDay(hour: 19, minute: 30),
        groupNames: const [],
      );

      const expected =
          'Aimachiで予約しました\n'
          '\n'
          '📍 テスト店\n'
          '\n'
          '🗓 19:30\n'
          '\n'
          'みんなの集合場所、Aimachiならすぐ決まります\n'
          'https://apps.apple.com/jp/app/aimachi/id6761008332';

      expect(
        text,
        equals(expected),
        reason:
            'time のみのとき parts.join(" ") = "HH:MM" になり先頭スペース無し。',
      );
    });

    test('両方あるとき "🗓 M/D HH:MM" 1 行（半角スペース連結）', () {
      final text = ShareUtils.buildReservationLineText(
        restaurantName: 'テスト店',
        category: '',
        stationName: '',
        walkMinutes: null,
        lat: null,
        lng: null,
        meetingDate: DateTime(2026, 4, 30),
        meetingTime: const TimeOfDay(hour: 19, minute: 30),
        groupNames: const [],
      );

      const expected =
          'Aimachiで予約しました\n'
          '\n'
          '📍 テスト店\n'
          '\n'
          '🗓 4/30 19:30\n'
          '\n'
          'みんなの集合場所、Aimachiならすぐ決まります\n'
          'https://apps.apple.com/jp/app/aimachi/id6761008332';

      expect(
        text,
        equals(expected),
        reason:
            '両方あるとき "M/D HH:MM" の順序・半角スペース連結が崩れた可能性。',
      );
    });
  });

  // ══════════════════════════════════════════════════════════════
  // [C6] 時刻 0 パディング — hour/minute を 2 桁に揃える
  // ══════════════════════════════════════════════════════════════
  group('buildReservationLineText [C6] 時刻 0 パディング', () {
    test('hour=9 minute=5 のとき "09:05" に padLeft される', () {
      final text = ShareUtils.buildReservationLineText(
        restaurantName: 'テスト店',
        category: '',
        stationName: '',
        walkMinutes: null,
        lat: null,
        lng: null,
        meetingDate: null,
        meetingTime: const TimeOfDay(hour: 9, minute: 5),
        groupNames: const [],
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
      final text = ShareUtils.buildReservationLineText(
        restaurantName: 'テスト店',
        category: '',
        stationName: '',
        walkMinutes: null,
        lat: null,
        lng: null,
        meetingDate: null,
        meetingTime: const TimeOfDay(hour: 0, minute: 0),
        groupNames: const [],
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
  // [C7] 👥 メンバー行 — 空文字フィルタと「、」連結
  // ══════════════════════════════════════════════════════════════
  group('buildReservationLineText [C7] 👥 メンバー行', () {
    test('groupNames が全要素空文字のとき 👥 行は出ない', () {
      // ['', ''] → cleanGroup = [] → if (cleanGroup.isNotEmpty) 抑止
      final text = ShareUtils.buildReservationLineText(
        restaurantName: 'テスト店',
        category: '',
        stationName: '',
        walkMinutes: null,
        lat: null,
        lng: null,
        meetingDate: null,
        meetingTime: null,
        groupNames: const ['', ''],
      );

      expect(
        text.contains('👥'),
        isFalse,
        reason:
            'groupNames が空文字のみのとき cleanGroup は空となり 👥 行は出ない。\n'
            '実際の本文:\n$text',
      );
    });

    test('groupNames に空文字混入時、空要素は除外され「、」二重化しない', () {
      final text = ShareUtils.buildReservationLineText(
        restaurantName: 'テスト店',
        category: '',
        stationName: '',
        walkMinutes: null,
        lat: null,
        lng: null,
        meetingDate: null,
        meetingTime: null,
        groupNames: const ['あや', '', 'ゆう', 'たく'],
      );

      expect(
        text.contains('👥 あや、ゆう、たく\n'),
        isTrue,
        reason:
            'cleanGroup = where((n) => n.isNotEmpty).toList() で空文字を除外、\n'
            '"、" 連結。"、、" の二重化が起きてはならない。実際の本文:\n$text',
      );
      expect(
        text.contains('、、'),
        isFalse,
        reason: '区切りの「、」が連続してはならない（UI バグの兆候）。',
      );
    });
  });

  // ══════════════════════════════════════════════════════════════
  // [C8] maps URL — lat/lng 両方揃ったときだけ出る
  // ══════════════════════════════════════════════════════════════
  group('buildReservationLineText [C8] maps URL', () {
    test('lat のみ（lng=null）のとき maps URL は出ない', () {
      final text = ShareUtils.buildReservationLineText(
        restaurantName: 'テスト店',
        category: '',
        stationName: '',
        walkMinutes: null,
        lat: 35.0,
        lng: null,
        meetingDate: null,
        meetingTime: null,
        groupNames: const [],
      );

      expect(
        text.contains('maps.google.com'),
        isFalse,
        reason:
            'lat/lng のどちらかが null のとき maps URL は組まない（`lat != null && lng != null`）。\n'
            '実際の本文:\n$text',
      );
    });

    test('lng のみ（lat=null）のとき maps URL は出ない', () {
      final text = ShareUtils.buildReservationLineText(
        restaurantName: 'テスト店',
        category: '',
        stationName: '',
        walkMinutes: null,
        lat: null,
        lng: 139.0,
        meetingDate: null,
        meetingTime: null,
        groupNames: const [],
      );

      expect(
        text.contains('maps.google.com'),
        isFalse,
        reason:
            'lng だけ与えられても lat=null では URL 組み立て条件を満たさない。\n'
            '実際の本文:\n$text',
      );
    });

    test('lat/lng 両方ありのとき "https://maps.google.com/maps?q=lat,lng" 単独行', () {
      final text = ShareUtils.buildReservationLineText(
        restaurantName: 'テスト店',
        category: '',
        stationName: '',
        walkMinutes: null,
        lat: 35.658,
        lng: 139.7016,
        meetingDate: null,
        meetingTime: null,
        groupNames: const [],
      );

      const expected =
          'Aimachiで予約しました\n'
          '\n'
          '📍 テスト店\n'
          '\n'
          'https://maps.google.com/maps?q=35.658,139.7016\n'
          '\n'
          'みんなの集合場所、Aimachiならすぐ決まります\n'
          'https://apps.apple.com/jp/app/aimachi/id6761008332';

      expect(
        text,
        equals(expected),
        reason:
            'maps URL は "?q=lat,lng" の順序・カンマ連結（URL エンコード無し）\n'
            'を保つ。Dart の double.toString() の trailing zero 挙動も含めて固定。',
      );
    });
  });

  // ══════════════════════════════════════════════════════════════
  // [C9] 末尾仕様 — `sb.write(appStoreUrl)` のため改行で終わらない
  // ══════════════════════════════════════════════════════════════
  group('buildReservationLineText [C9] 末尾仕様', () {
    test('本文末尾は appStoreUrl で終わり、改行で終わらない', () {
      final text = ShareUtils.buildReservationLineText(
        restaurantName: 'テスト店',
        category: '',
        stationName: '',
        walkMinutes: null,
        lat: null,
        lng: null,
        meetingDate: null,
        meetingTime: null,
        groupNames: const [],
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
  group('buildReservationLineText [C10] 全ブロック合成スナップショット', () {
    test('全フィールド埋まった本文は規定フォーマットでバイト一致する', () {
      final text = ShareUtils.buildReservationLineText(
        restaurantName: 'まんなか食堂',
        category: 'イタリアン',
        stationName: '渋谷',
        walkMinutes: 5,
        lat: 35.658,
        lng: 139.7016,
        meetingDate: DateTime(2026, 4, 30),
        meetingTime: const TimeOfDay(hour: 19, minute: 30),
        groupNames: const ['あや', 'ゆう', 'たく'],
      );

      const expected =
          'Aimachiで予約しました\n'
          '\n'
          '📍 まんなか食堂\n'
          'イタリアン\n'
          '渋谷駅から徒歩5分\n'
          '\n'
          '🗓 4/30 19:30\n'
          '👥 あや、ゆう、たく\n'
          '\n'
          'https://maps.google.com/maps?q=35.658,139.7016\n'
          '\n'
          'みんなの集合場所、Aimachiならすぐ決まります\n'
          'https://apps.apple.com/jp/app/aimachi/id6761008332';

      expect(
        text,
        equals(expected),
        reason:
            '全ブロック合成時の本文バイト列が変化した。\n'
            '\n'
            '期待フォーマット:\n'
            '  見出し → 空行 → 📍店名 → category → 駅+徒歩\n'
            '  → 空行 → 🗓日時 → 👥メンバー\n'
            '  → 空行 → maps URL\n'
            '  → 空行 → DL 誘導文 → App Store URL（末尾改行なし）\n'
            '\n'
            '注意: 🗓 と 👥 の間に空行は **無い**（👥 は date ブロック直後\n'
            'に writeln で連結される）。maps URL の前にだけ空行が入る。',
      );
    });
  });
}
