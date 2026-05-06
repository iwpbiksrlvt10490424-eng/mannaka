// TDD Red フェーズ — Cycle 33: lib/ 全域での LINE 共有 URL 集約・SnackBar フォールバック
//
// 背景:
//   Cycle 32 では `share_utils.dart` 内の 2 関数のみ `line://msg/text/?<encoded>` に
//   切替えたが、qa-reviewer / Critic は同じ root cause を抱える 3 画面の取りこぼしを
//   CRITICAL 3 件で指摘した:
//     - lib/screens/saved_drafts_screen.dart:136
//     - lib/screens/restaurant_detail_screen.dart:786
//     - lib/screens/settings_screen.dart:586
//   ＋ share_utils.dart 内 2 関数も完全同型コピペ（依存関係を可視化ルール違反）。
//
//   Cycle 33 のスコープ:
//     1. `ShareUtils.launchLineWithText(String text)` ヘルパに 5 箇所を集約
//     2. lib/ 全域で `https://line.me/R/share` 出現 0 件
//     3. 3 画面が共通ヘルパを呼ぶ
//     4. 各画面で起動失敗時に SnackBar（または Share.share フォールバック）が出る
//     5. restaurant_detail_screen の `Navigator.pop` は **成功時のみ** 呼ばれる
//        （失敗時に pop してしまうと SnackBar が一瞬で消えて視認不能）
//
// このテストの責務（source-level static guard）:
//   widget テストは Firebase / SharedPreferences 依存で重く偽グリーン化しやすいため、
//   ソース文字列に対する **構造ガード** で 5 つの受入条件を機械担保する。
//
// 期待される Red 失敗:
//   - test [1]: lib/ に `https://line.me/R/share` が 3 箇所残っているので fail
//   - test [2]: `share_utils.dart` に `launchLineWithText` が無いので fail
//   - test [3]: 3 画面のいずれも `ShareUtils.launchLineWithText` を呼んでいないので fail
//   - test [4]: 3 画面のいずれも LINE 失敗時 SnackBar を出していないので fail
//   - test [5]: restaurant_detail_screen の `_shareLine` で Navigator.pop が
//     成功条件分岐の外（無条件呼び出し）にあるので fail
//
// 不変項（侵してはならない）:
//   - Cycle 27〜30 snapshot 49 サブテスト 1 バイト不変（buildLineTextFor* 純関数）
//   - Cycle 31 Future<bool> 契約 A/B/C
//   - Cycle 32 share_utils 2 関数の line: スキーム
//   - Info.plist の `<string>line</string>`（Cycle 32 で追加済）

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const _shareUtils = 'lib/utils/share_utils.dart';
const _savedDrafts = 'lib/screens/saved_drafts_screen.dart';
const _restaurantDetail = 'lib/screens/restaurant_detail_screen.dart';
const _settings = 'lib/screens/settings_screen.dart';

String _read(String path) {
  final f = File(path);
  if (!f.existsSync()) {
    fail('$path が存在しません。ファイルパスが変わっていないか確認してください。');
  }
  return f.readAsStringSync();
}

/// 指定メソッドのブロック本体を抽出する（単純な波括弧カウント）。
/// 既存 `settings_screen_mounted_guard_test.dart` と同じ抽出戦略。
String? _extractMethodBody(String source, String signatureRegex) {
  final sigMatch = RegExp(signatureRegex).firstMatch(source);
  if (sigMatch == null) return null;
  final bodyStart = source.indexOf('{', sigMatch.end - 1);
  if (bodyStart < 0) return null;

  int depth = 0;
  for (int i = bodyStart; i < source.length; i++) {
    final ch = source[i];
    if (ch == '{') {
      depth++;
    } else if (ch == '}') {
      depth--;
      if (depth == 0) {
        return source.substring(bodyStart, i + 1);
      }
    }
  }
  return null;
}

void main() {
  // ══════════════════════════════════════════════════════════════════════
  // [1] lib/ 全域: `https://line.me/R/share` 出現 0 件
  // ══════════════════════════════════════════════════════════════════════

  group('Cycle 33: lib/ 全域で `https://line.me/R/share` が完全に消えていること', () {
    test('lib/ 配下のすべての *.dart に `https://line.me/R/share` 文字列が含まれない', () {
      final dir = Directory('lib');
      expect(dir.existsSync(), isTrue, reason: 'lib/ が存在しません。');

      final hits = <String>[];
      final dartFiles = dir
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart'))
          .toList();

      for (final f in dartFiles) {
        final lines = f.readAsLinesSync();
        for (var i = 0; i < lines.length; i++) {
          if (lines[i].contains('https://line.me/R/share')) {
            hits.add('${f.path}:${i + 1}: ${lines[i].trim()}');
          }
        }
      }

      expect(
        hits,
        isEmpty,
        reason: 'lib/ 配下に `https://line.me/R/share` が残存しています。\n'
            'iOS で canLaunchUrl(https://line.me/...) は Safari の存在で'
            '常に true を返すため、未インストール検知が効きません。\n'
            '`line://msg/text/?<encoded>` に切替え、共通ヘルパ '
            '`ShareUtils.launchLineWithText(text)` に集約してください。\n'
            '違反箇所:\n${hits.map((l) => '  $l').join('\n')}',
      );
    });
  });

  // ══════════════════════════════════════════════════════════════════════
  // [2] share_utils.dart: 共通ヘルパ launchLineWithText の存在
  // ══════════════════════════════════════════════════════════════════════

  group('Cycle 33: ShareUtils.launchLineWithText 共通ヘルパが定義されていること', () {
    test('share_utils.dart に static Future<bool> launchLineWithText シグネチャが存在する', () {
      final src = _read(_shareUtils);

      // 戻り値型 + メソッド名 + 引数 1 個（String text）の最小契約。
      final hasSignature = RegExp(
        r'static\s+Future<bool>\s+launchLineWithText\s*\(\s*String\s+\w+\s*\)\s*async',
      ).hasMatch(src);

      expect(
        hasSignature,
        isTrue,
        reason: '`static Future<bool> launchLineWithText(String text) async {...}` が '
            'share_utils.dart に見当たりません。\n'
            '5 箇所の LINE 起動コード（share_utils 2 + screens 3）を 1 箇所に集約するため、'
            'このヘルパを追加してください。',
      );
    });

    test('launchLineWithText の本体は line:// スキームを使い https://line.me/R/share を含まない', () {
      final src = _read(_shareUtils);
      final body = _extractMethodBody(
        src,
        r'static\s+Future<bool>\s+launchLineWithText\s*\(',
      );

      expect(
        body,
        isNotNull,
        reason: 'launchLineWithText() メソッド本体を抽出できませんでした。',
      );

      expect(
        body!.contains('line://'),
        isTrue,
        reason: 'launchLineWithText 本体に `line://` リテラルが見当たりません。'
            '`line://msg/text/?\$encoded` の形で URL を組んでください。',
      );
      expect(
        body.contains('https://line.me/R/share'),
        isFalse,
        reason: 'launchLineWithText 本体に旧 URL `https://line.me/R/share` が混入しています。'
            'iOS で常に canLaunch=true となり Cycle 31 の早期 false が発火しません。',
      );
      expect(
        body.contains('canLaunchUrl'),
        isTrue,
        reason: 'launchLineWithText 本体に canLaunchUrl の呼び出しが見当たりません。'
            '存在チェックなしで起動すると未インストール時に無反応 UX バグが復活します。',
      );
    });

    test(
        'share_utils.dart 内の shareSelectionsToLine / shareMeetingPointsToLine が共通ヘルパに集約されている',
        () {
      final src = _read(_shareUtils);

      // 共通ヘルパに集約されているなら、share_utils.dart 内に
      // `Uri.parse('line://msg/text/` を直接組む箇所は launchLineWithText の
      // 本体 1 箇所のみになる（2 関数の重複が解消される）。
      final occurrences =
          "Uri.parse('line://".allMatches(src).length;

      expect(
        occurrences <= 1,
        isTrue,
        reason: '`Uri.parse(\'line://...\')` が share_utils.dart 内に '
            '$occurrences 箇所あります。\n'
            'shareSelectionsToLine / shareMeetingPointsToLine は '
            '`launchLineWithText(text)` を呼ぶだけにし、URL 組み立ては'
            '共通ヘルパ 1 箇所のみに集約してください。\n'
            '（CLAUDE.md「依存関係を可視化（共通処理は 1 箇所のみ・コピペ禁止）」）',
      );
    });
  });

  // ══════════════════════════════════════════════════════════════════════
  // [3] 3 画面: ShareUtils.launchLineWithText の呼び出し
  // ══════════════════════════════════════════════════════════════════════

  group('Cycle 33: 3 画面が ShareUtils.launchLineWithText に委譲していること', () {
    test('saved_drafts_screen.dart が ShareUtils.launchLineWithText(...) を呼ぶ', () {
      final src = _read(_savedDrafts);
      expect(
        RegExp(r'ShareUtils\.launchLineWithText\s*\(').hasMatch(src),
        isTrue,
        reason: 'saved_drafts_screen.dart の `_send()` で '
            '`ShareUtils.launchLineWithText(text)` の呼び出しが見当たりません。\n'
            '直接 `Uri.parse(\'https://line.me/R/share?text=...\')` を組まずに、'
            '共通ヘルパに委譲してください。',
      );
    });

    test('restaurant_detail_screen.dart が ShareUtils.launchLineWithText(...) を呼ぶ', () {
      final src = _read(_restaurantDetail);
      expect(
        RegExp(r'ShareUtils\.launchLineWithText\s*\(').hasMatch(src),
        isTrue,
        reason: 'restaurant_detail_screen.dart の `_shareLine()` で '
            '`ShareUtils.launchLineWithText(text)` の呼び出しが見当たりません。\n'
            '`buildReservationLineText(...)` で組んだテキストを共通ヘルパに渡してください。',
      );
    });

    test('settings_screen.dart が ShareUtils.launchLineWithText(...) を呼ぶ', () {
      final src = _read(_settings);
      expect(
        RegExp(r'ShareUtils\.launchLineWithText\s*\(').hasMatch(src),
        isTrue,
        reason: 'settings_screen.dart の「LINEで紹介する」アクションで '
            '`ShareUtils.launchLineWithText(text)` の呼び出しが見当たりません。\n'
            '直接 URL を組まず、共通ヘルパに委譲してください。',
      );
    });
  });

  // ══════════════════════════════════════════════════════════════════════
  // [4] 3 画面: 起動失敗時の SnackBar フォールバック
  // ══════════════════════════════════════════════════════════════════════

  group('Cycle 33: 3 画面で LINE 起動失敗時に SnackBar が出ること', () {
    // 受入条件:
    //   `launchLineWithText` の戻り値 false を受けて、ユーザーに「LINE が無いか
    //   起動できなかった」旨の SnackBar を出す。settings_screen は既に
    //   `Share.share()` フォールバックがあるためどちらでも可（else 分岐に何かが
    //   実装されていれば OK）。
    //
    //   ソース上の判定:
    //     - 「ScaffoldMessenger.of(context).showSnackBar」 を含む
    //       OR `Share.share(` を含む（settings の既存フォールバック）

    test('saved_drafts_screen.dart に起動失敗時 SnackBar が用意されている', () {
      final src = _read(_savedDrafts);
      final body = _extractMethodBody(src, r'Future<void>\s+_send\s*\(\s*\)\s*async');

      expect(body, isNotNull, reason: '_send() 本体を抽出できませんでした。');
      expect(
        body!.contains('ScaffoldMessenger') && body.contains('showSnackBar'),
        isTrue,
        reason: '_send() 内に `ScaffoldMessenger.of(context).showSnackBar(...)` が '
            '見当たりません。\n'
            '`launchLineWithText` の戻り値が false のときに「LINE が見つからなかった」'
            '旨の SnackBar を出してください（無反応 UX バグの解消）。',
      );
    });

    test('restaurant_detail_screen.dart の _shareLine に起動失敗時 SnackBar が用意されている', () {
      final src = _read(_restaurantDetail);
      final body = _extractMethodBody(
        src,
        r'Future<void>\s+_shareLine\s*\(\s*BuildContext\s+\w+\s*\)\s*async',
      );

      expect(body, isNotNull, reason: '_shareLine() 本体を抽出できませんでした。');
      expect(
        body!.contains('ScaffoldMessenger') && body.contains('showSnackBar'),
        isTrue,
        reason: '_shareLine() 内に SnackBar 表示が見当たりません。\n'
            '失敗時に「LINE を開けませんでした」等の通知を出してください。',
      );
    });

    test('settings_screen.dart の「LINEで紹介する」分岐に失敗時フォールバックが残っている', () {
      final src = _read(_settings);

      // 「LINEで紹介する」アクション本体は閉包なので _extractMethodBody が使えない。
      // ファイル全体で SnackBar / Share.share いずれかの存在を確認する。
      // （既存の `Share.share()` フォールバックは保持されていれば OK）
      final hasSnackBar = src.contains('ScaffoldMessenger') &&
          src.contains('showSnackBar');
      final hasShareFallback = RegExp(r'Share\.share\s*\(').hasMatch(src);

      expect(
        hasSnackBar || hasShareFallback,
        isTrue,
        reason: 'settings_screen.dart に LINE 起動失敗時の'
            ' SnackBar も Share.share フォールバックも見当たりません。\n'
            '既存の `Share.share(...)` フォールバックは保持してください。',
      );
    });
  });

  // ══════════════════════════════════════════════════════════════════════
  // [5] restaurant_detail_screen: Navigator.pop は成功時のみ
  // ══════════════════════════════════════════════════════════════════════

  group('Cycle 33: restaurant_detail_screen の _shareLine は失敗時に Navigator.pop しない', () {
    test('_shareLine の Navigator.pop は launchLineWithText の戻り値 true 分岐内にある', () {
      final src = _read(_restaurantDetail);
      final body = _extractMethodBody(
        src,
        r'Future<void>\s+_shareLine\s*\(\s*BuildContext\s+\w+\s*\)\s*async',
      );

      expect(body, isNotNull, reason: '_shareLine() 本体を抽出できませんでした。');

      // 現状（Cycle 32 まで）は `await launchUrl(...)` の後に **無条件で**
      //   `if (context.mounted) Navigator.pop(context);`
      // が呼ばれる。失敗時にも pop されるため SnackBar が一瞬で消える。
      //
      // 受入条件:
      //   - `Navigator.pop` の呼び出し回数は 1 回以下（成功時のみ）
      //   - 直前 6 行以内に launchLineWithText の戻り値を if で見ている形跡がある
      //     （= 成功条件分岐内に pop が居る）
      final lines = body!.split('\n');

      // 6.1: pop 呼び出しの数を測る。複数あるなら成功・失敗を分岐できていない疑い。
      final popLineNumbers = <int>[];
      for (var i = 0; i < lines.length; i++) {
        if (RegExp(r'Navigator\.pop\s*\(').hasMatch(lines[i])) {
          popLineNumbers.add(i);
        }
      }

      expect(
        popLineNumbers.isNotEmpty,
        isTrue,
        reason: '_shareLine() 内に `Navigator.pop(...)` が見当たりません。'
            '成功時にシートを閉じる導線は残してください。',
      );

      // 6.2: 各 pop の直前 8 行以内に launchLineWithText の戻り値判定が居るか確認。
      //      （`final ok = await ShareUtils.launchLineWithText(...)` を受けて
      //       `if (ok)` か `if (sent)` 等のブール if 内に pop が居れば OK）
      bool allPopsGuardedBySuccess = true;
      final unguarded = <String>[];
      for (final idx in popLineNumbers) {
        bool guarded = false;
        for (int j = idx - 1; j >= (idx - 8 < 0 ? 0 : idx - 8); j--) {
          final t = lines[j];
          // 「if (ok)」「if (sent)」「if (launched)」「if (await ShareUtils.launchLineWithText(...))」
          // 等の真偽分岐に入っていれば guarded とみなす。
          if (RegExp(r'if\s*\(').hasMatch(t) &&
              (t.contains('ok') ||
                  t.contains('sent') ||
                  t.contains('launched') ||
                  t.contains('launchLineWithText'))) {
            guarded = true;
            break;
          }
        }
        if (!guarded) {
          allPopsGuardedBySuccess = false;
          unguarded.add('L${idx + 1}: ${lines[idx].trim()}');
        }
      }

      expect(
        allPopsGuardedBySuccess,
        isTrue,
        reason: '_shareLine() の `Navigator.pop` が成功条件分岐の外で呼ばれています。\n'
            '失敗時に pop すると SnackBar が一瞬で消えてしまうため、\n'
            '`final ok = await ShareUtils.launchLineWithText(text);` の戻り値で\n'
            'pop を if (ok) の中に入れてください。\n'
            '違反箇所:\n${unguarded.map((l) => '  $l').join('\n')}',
      );
    });
  });
}
