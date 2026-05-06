// TDD 規格テスト（Refactor Safe / 出力バイト列スナップショット）
// Cycle 30: buildLineTextForMeetingPoints の本文ブロック構成を equals で固定する。
//
// 背景:
//   `buildLineTextForMeetingPoints`（share_utils.dart:247-285）は
//   **右上 LINE ボタンで本番ユーザーが LINE に流す「集合駅候補」テキスト**
//   を組み立てる高インパクトな関数。state.results 空ガード・日時 0/date/time/
//   両方分岐・`take(5)` 上限・`participantTimes` 空ガード・末尾仕様
//   （`sb.write` vs `writeln`）と性質の違う分岐が多い。
//
//   既存テストは LINE 誘導 CTA・appStoreUrl のリテラル単一所在を `contains`
//   で守るのみで、**本文ブロックの順序・改行挿入位置・境界値で行が出る/消える**
//   挙動は機械的に守られていない。
//
//   Cycle 27（buildRestaurantShareText）/ Cycle 28（buildReservationLineText）
//   / Cycle 29（buildLineTextForSelections）と同型の characterization snapshot
//   test を被せて、share_utils.dart の build 系 4 関数すべての出力バイト列
//   を将来改修から保護する（share_utils 全域 byte-frozen の最終回）。
//   production 差分ゼロ。
//
//   本サイクルで固定する invariant（C1〜C10）:
//
//     [C1] state.results が空のとき '' を返す（早期 return）
//     [C2] 最小 1 件 — date/time なし / participantTimes 空のとき
//          見出し → 空行 → "候補の集合駅" → 空行 → 📍駅 → 空行 → CTA → URL
//          のフォーマット（⏱ 行は出ない）
//     [C3] participantTimes 1 人のとき ⏱ "name N分" 1 人分行が出る
//     [C4] participantTimes 複数人のとき ' / ' 区切りで連結される（順序は
//          Map insertion order）
//     [C5] take(5) 上限 — 6 件渡しても 📍 ブロックは 5 件で打ち切られ、
//          6 件目の駅名は本文に出ない
//     [C6] 🗓 日時ブロック — date のみ / time のみ / 両方ありの順序と書式、
//          🗓 行の **直後** に空行（writeln('')）が必ず入る
//     [C7] 時刻 0 パディング — hour=9/minute=5 で "09:05"、hour=0/minute=0
//          で "00:00"
//     [C8] 末尾仕様 — `sb.write(appStoreUrl)` のため改行で終わらず
//          ShareUtils.appStoreUrl で完全一致終了する
//     [C9] participantTimes 空ガード — `participantTimes.isNotEmpty` の
//          直下境界で ⏱ 行が出ない（📍 行のみで次の駅 or 末尾に進む）
//     [C10] 全ブロック合成スナップショット — 全条件成立時の完全フォーマット
//          がバイト一致する
//
// 注:
//   - 本テストは production コード差分ゼロ。書いた瞬間に Green であるのが
//     正しい状態（characterization snapshot）。
//   - `appStoreUrl` の **値** は Cycle 16/24/25 系の既存テストが検出する。
//     本テストは構造（順序・境界・take 上限・末尾仕様）のみを担保する。
//   - これで share_utils.dart の build 系関数（restaurant share / reservation
//     line / selections line / meeting points line）の characterization
//     snapshot が全完成する。

import 'package:flutter/material.dart' show TimeOfDay;
import 'package:flutter_test/flutter_test.dart';
import 'package:mannaka/models/meeting_point.dart';
import 'package:mannaka/providers/search_provider.dart';
import 'package:mannaka/utils/share_utils.dart';

// ── ヘルパー ──────────────────────────────────────────────
MeetingPoint _point({
  required String stationName,
  Map<String, int> times = const {},
}) {
  return MeetingPoint(
    stationIndex: 0,
    stationName: stationName,
    stationEmoji: '🚉',
    lat: 35.690,
    lng: 139.700,
    totalMinutes: times.values.fold(0, (a, b) => a + b),
    maxMinutes:
        times.values.isEmpty ? 0 : times.values.reduce((a, b) => a > b ? a : b),
    minMinutes:
        times.values.isEmpty ? 0 : times.values.reduce((a, b) => a < b ? a : b),
    averageMinutes: 10,
    fairnessScore: 0.9,
    overallScore: 0.9,
    participantTimes: times,
  );
}

void main() {
  // ══════════════════════════════════════════════════════════════
  // [C1] state.results 空 — 早期 return で空文字
  // ══════════════════════════════════════════════════════════════
  group('buildLineTextForMeetingPoints [C1] state.results 空', () {
    test('state.results が空のとき 本文は空文字列で即 return', () {
      final state = SearchState();

      final text = ShareUtils.buildLineTextForMeetingPoints(state);

      expect(
        text,
        equals(''),
        reason:
            'state.results.isEmpty のとき関数先頭で `return ""` する仕様。\n'
            'ヘッダ等は組まれず空文字でなければならない（呼び出し元の\n'
            '`if (text.isEmpty) return;` 早期離脱前提）。',
      );
    });
  });

  // ══════════════════════════════════════════════════════════════
  // [C2] 最小 1 件 — date/time なし / participantTimes 空のフルフォーマット
  // ══════════════════════════════════════════════════════════════
  group('buildLineTextForMeetingPoints [C2] 最小 1 件', () {
    test('date/time なし / participantTimes 空のとき '
        '見出し → 空行 → "候補の集合駅" → 空行 → 📍駅 → 空行 → CTA → URL', () {
      final state = SearchState(
        results: [_point(stationName: '新宿')],
      );

      final text = ShareUtils.buildLineTextForMeetingPoints(state);

      const expected =
          'みんなで集まれる駅の候補です（Aimachiより）\n'
          '\n'
          '候補の集合駅\n'
          '\n'
          '📍 新宿駅\n'
          '\n'
          'Aimachiでお店を見つけられます👇\n'
          'https://apps.apple.com/jp/app/aimachi/id6761008332';

      expect(
        text,
        equals(expected),
        reason:
            '最小ケースのバイト列が崩れた。期待した不変量:\n'
            '  - 見出し直後の空行（writeln("")）は date/time なしでも残る\n'
            '  - date/time 両方 null のとき 🗓 行とその直後の空行は **出ない**\n'
            '  - "候補の集合駅" 行の前に空行は入らない\n'
            '  - 1 件目の前に空行（for ループ先頭の writeln("")）が入る\n'
            '  - participantTimes 空では ⏱ 行は出ない（📍 行のみ）\n'
            '  - 末尾は appStoreUrl で改行なし\n'
            '\n'
            '実際の本文:\n$text',
      );
    });
  });

  // ══════════════════════════════════════════════════════════════
  // [C3] participantTimes 1 人 — ⏱ "name N分" 行が出る
  // ══════════════════════════════════════════════════════════════
  group('buildLineTextForMeetingPoints [C3] participantTimes 1 人', () {
    test('participantTimes 1 人のとき ⏱ "name N分" 1 人分行が出る', () {
      final state = SearchState(
        results: [
          _point(stationName: '新宿', times: const {'あや': 12}),
        ],
      );

      final text = ShareUtils.buildLineTextForMeetingPoints(state);

      expect(
        text.contains('📍 新宿駅\n⏱ あや 12分\n'),
        isTrue,
        reason:
            '📍 行直後に ⏱ 行が続く順序が崩れた。\n'
            '1 人分のときは "name N分" のみ（区切り " / " は付かない）。\n'
            '実際の本文:\n$text',
      );
    });
  });

  // ══════════════════════════════════════════════════════════════
  // [C4] participantTimes 複数 — ' / ' 区切りで連結される
  // ══════════════════════════════════════════════════════════════
  group('buildLineTextForMeetingPoints [C4] participantTimes 複数', () {
    test('participantTimes 複数人のとき " / " 区切りで連結される（Map 順序保持）', () {
      final state = SearchState(
        results: [
          _point(
            stationName: '新宿',
            // Dart の Map リテラルは LinkedHashMap なので insertion order が保たれる。
            // 本文の順序が Map のエントリ順に従うことを保証する。
            times: const {'あや': 12, 'ゆう': 8, 'みき': 15},
          ),
        ],
      );

      final text = ShareUtils.buildLineTextForMeetingPoints(state);

      expect(
        text.contains('⏱ あや 12分 / ゆう 8分 / みき 15分\n'),
        isTrue,
        reason:
            '⏱ 行の連結が崩れた。期待した形式:\n'
            '  - "name1 N分 / name2 N分 / name3 N分" のように\n'
            '    " / "（半角スペース・スラッシュ・半角スペース）で連結\n'
            '  - 順序は participantTimes のエントリ順（insertion order）\n'
            '実際の本文:\n$text',
      );
    });
  });

  // ══════════════════════════════════════════════════════════════
  // [C5] take(5) 上限 — 6 件渡しても 📍 ブロックは 5 件で打ち切り
  // ══════════════════════════════════════════════════════════════
  group('buildLineTextForMeetingPoints [C5] take(5) 上限', () {
    test('results 6 件のとき 📍 ブロックは 5 件で打ち切られ、6 件目は出ない', () {
      final results = List.generate(
        6,
        (i) => _point(stationName: '駅${i + 1}'),
      );
      final state = SearchState(results: results);

      final text = ShareUtils.buildLineTextForMeetingPoints(state);

      // 1〜5 件目は出る
      for (var i = 1; i <= 5; i++) {
        expect(
          text.contains('📍 駅$i駅\n'),
          isTrue,
          reason:
              '$i 件目（駅$i）が本文に含まれていない。take(5) 上限の **直下** は\n'
              'すべて含まれていなければならない。実際の本文:\n$text',
        );
      }
      // 6 件目は出ない（take(5) で切られるため）
      expect(
        text.contains('駅6'),
        isFalse,
        reason:
            '6 件目（駅6）は state.results.take(5) で切られて本文に出ない仕様。\n'
            'UI 側で 6 件以上ヒットしても LINE 本文には 5 件のみ含む保険。\n'
            '実際の本文:\n$text',
      );
    });
  });

  // ══════════════════════════════════════════════════════════════
  // [C6] 🗓 日時ブロック — date / time の有無で挙動が変わる
  // ══════════════════════════════════════════════════════════════
  group('buildLineTextForMeetingPoints [C6] 🗓 日時ブロック', () {
    test('date のみのとき "🗓 M/D" 行 + 直後に空行（時刻なし）', () {
      final state = SearchState(
        results: [_point(stationName: '新宿')],
        selectedDate: DateTime(2026, 4, 30),
      );

      final text = ShareUtils.buildLineTextForMeetingPoints(state);

      expect(
        text.contains('\n🗓 4/30\n\n候補の集合駅\n'),
        isTrue,
        reason:
            'date のみのとき parts.join(" ") = "M/D" になり時刻が付かない。\n'
            '🗓 行の **直後** に空行（writeln("")）が必ず入り、その次に\n'
            '"候補の集合駅" 行が続く順序が崩れた可能性。\n'
            '実際の本文:\n$text',
      );
    });

    test('time のみのとき "🗓 HH:MM" 行 + 直後に空行（日付なし）', () {
      final state = SearchState(
        results: [_point(stationName: '新宿')],
        selectedMeetingTime: const TimeOfDay(hour: 19, minute: 30),
      );

      final text = ShareUtils.buildLineTextForMeetingPoints(state);

      expect(
        text.contains('\n🗓 19:30\n\n候補の集合駅\n'),
        isTrue,
        reason:
            'time のみのとき parts.join(" ") = "HH:MM" になり日付が付かない。\n'
            '🗓 行の直後の空行も維持される必要がある。\n'
            '実際の本文:\n$text',
      );
    });

    test('date / time 両方ありのとき "🗓 M/D HH:MM" 1 行（半角スペース連結）', () {
      final state = SearchState(
        results: [_point(stationName: '新宿')],
        selectedDate: DateTime(2026, 4, 30),
        selectedMeetingTime: const TimeOfDay(hour: 19, minute: 30),
      );

      final text = ShareUtils.buildLineTextForMeetingPoints(state);

      expect(
        text.contains('\n🗓 4/30 19:30\n\n候補の集合駅\n'),
        isTrue,
        reason:
            '両方あるとき "M/D HH:MM" の順序・半角スペース連結が崩れた可能性。\n'
            '実際の本文:\n$text',
      );
    });
  });

  // ══════════════════════════════════════════════════════════════
  // [C7] 時刻 0 パディング — hour/minute を 2 桁に揃える
  // ══════════════════════════════════════════════════════════════
  group('buildLineTextForMeetingPoints [C7] 時刻 0 パディング', () {
    test('hour=9 minute=5 のとき "09:05" に padLeft される', () {
      final state = SearchState(
        results: [_point(stationName: '新宿')],
        selectedMeetingTime: const TimeOfDay(hour: 9, minute: 5),
      );

      final text = ShareUtils.buildLineTextForMeetingPoints(state);

      expect(
        text.contains('🗓 09:05\n'),
        isTrue,
        reason:
            'hour/minute は `toString().padLeft(2, "0")` で 2 桁に揃える。\n'
            '"9:5" のような 1 桁表示になっていないか。実際の本文:\n$text',
      );
    });

    test('hour=0 minute=0（深夜 0:00 境界値）のとき "00:00" になる', () {
      final state = SearchState(
        results: [_point(stationName: '新宿')],
        selectedMeetingTime: const TimeOfDay(hour: 0, minute: 0),
      );

      final text = ShareUtils.buildLineTextForMeetingPoints(state);

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
  // [C8] 末尾仕様 — `sb.write(appStoreUrl)` のため改行で終わらない
  // ══════════════════════════════════════════════════════════════
  group('buildLineTextForMeetingPoints [C8] 末尾仕様', () {
    test('本文末尾は appStoreUrl で終わり、改行で終わらない', () {
      final state = SearchState(
        results: [_point(stationName: '新宿', times: const {'あや': 12})],
      );

      final text = ShareUtils.buildLineTextForMeetingPoints(state);

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
  // [C9] participantTimes 空ガード — `isNotEmpty` 直下で ⏱ 行が出ない
  // ══════════════════════════════════════════════════════════════
  group('buildLineTextForMeetingPoints [C9] participantTimes 空ガード', () {
    test('participantTimes 空のとき ⏱ 行は出ず、📍 駅行のみで次へ進む', () {
      final state = SearchState(
        results: [
          _point(stationName: '新宿'),
          _point(stationName: '渋谷', times: const {'あや': 5}),
        ],
      );

      final text = ShareUtils.buildLineTextForMeetingPoints(state);

      // 1 件目（新宿）は participantTimes 空 → 📍 行直後に空行 + 📍 渋谷駅 が続く
      expect(
        text.contains('📍 新宿駅\n\n📍 渋谷駅\n'),
        isTrue,
        reason:
            'participantTimes 空のとき ⏱ 行は出ない仕様（isNotEmpty ガード）。\n'
            '📍 新宿駅 行の直後に for ループ先頭の writeln("") による空行が\n'
            '挟まり、次の 📍 渋谷駅 が続かなければならない。\n'
            '実際の本文:\n$text',
      );
      // 2 件目（渋谷）は participantTimes 非空 → ⏱ 行が出る
      expect(
        text.contains('📍 渋谷駅\n⏱ あや 5分\n'),
        isTrue,
        reason:
            '非空の participantTimes は通常通り ⏱ 行を出力する。\n'
            '実際の本文:\n$text',
      );
    });
  });

  // ══════════════════════════════════════════════════════════════
  // [C10] 全ブロック合成スナップショット — 全条件成立時の完全フォーマット
  // ══════════════════════════════════════════════════════════════
  group('buildLineTextForMeetingPoints [C10] 全ブロック合成スナップショット', () {
    test('日時 + 3 件（participantTimes 複数人）は規定フォーマットでバイト一致する', () {
      final state = SearchState(
        results: [
          _point(
            stationName: '新宿',
            times: const {'あや': 12, 'ゆう': 8},
          ),
          _point(
            stationName: '渋谷',
            times: const {'あや': 15, 'ゆう': 5},
          ),
          _point(
            stationName: '池袋',
            times: const {'あや': 10, 'ゆう': 11},
          ),
        ],
        selectedDate: DateTime(2026, 4, 30),
        selectedMeetingTime: const TimeOfDay(hour: 19, minute: 30),
      );

      final text = ShareUtils.buildLineTextForMeetingPoints(state);

      const expected =
          'みんなで集まれる駅の候補です（Aimachiより）\n'
          '\n'
          '🗓 4/30 19:30\n'
          '\n'
          '候補の集合駅\n'
          '\n'
          '📍 新宿駅\n'
          '⏱ あや 12分 / ゆう 8分\n'
          '\n'
          '📍 渋谷駅\n'
          '⏱ あや 15分 / ゆう 5分\n'
          '\n'
          '📍 池袋駅\n'
          '⏱ あや 10分 / ゆう 11分\n'
          '\n'
          'Aimachiでお店を見つけられます👇\n'
          'https://apps.apple.com/jp/app/aimachi/id6761008332';

      expect(
        text,
        equals(expected),
        reason:
            '全ブロック合成時の本文バイト列が変化した。\n'
            '\n'
            '期待フォーマット:\n'
            '  見出し → 空行 → 🗓日時 → 空行\n'
            '  → "候補の集合駅"\n'
            '  → 空行 → 📍駅1 → ⏱行1\n'
            '  → 空行 → 📍駅2 → ⏱行2\n'
            '  → 空行 → 📍駅3 → ⏱行3\n'
            '  → 空行 → "Aimachiでお店を見つけられます👇"\n'
            '  → App Store URL（末尾改行なし）\n'
            '\n'
            '注意: 各 📍 ブロックの **前** に空行が入る（for ループ先頭の\n'
            'writeln("")）。最後の ⏱ 行直後にも 1 件分空行があり、その後に\n'
            '"Aimachiでお店を見つけられます👇" が続く。',
      );
    });
  });
}
