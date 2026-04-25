// TDD Red フェーズ — Cycle 21
// saved_drafts リトライ系サイクルチェーン（Cycle 15〜20）最終清掃の
// 静的メタガード。本テストはテストファイルのみを対象とし、本番コード・
// pubspec には一切触れない。
//
// 背景:
//   Cycle 20 QA APPROVED 後、Critic から NON-BLOCKING 3 件が Cycle 21
//   送りとして残った:
//     (1) saved_drafts_screen_retry_test.dart:14 のヘッダコメントに
//         Cycle 19 リネーム前の旧ファイル名
//         'saved_drafts_screen_retry_test_version_guard_test.dart' が
//         残存（= 嘘コメント。読み手が新名を grep できない）。
//     (2) 役目を終えた
//         saved_drafts_retry_version_guard_structure_cleanup_test.dart が
//         残存（一回限り移行ガードの再帰構造。CLAUDE.md「呼び出し元
//         ゼロで削除」ルール違反）。
//     (3) saved_drafts_retry_version_guard_structure_test.dart の
//         group タイトル 'Cycle 19 — version guard minor 検証強化
//         （WARNING-1）' が履歴依存命名。Cycle 番号は運用ログであって
//         恒久テスト責務の名前ではない。
//
// 本テストの責務（= Cycle 21 の受け入れ条件）:
//   [C1-a] retry_test 本文に旧ファイル名リテラルが残っていない
//   [C1-b] retry_test 本文に Cycle 19 リネーム後の正規ファイル名が含まれる
//   [C2]   cleanup_test ファイルがファイルシステムから削除されている
//   [C3-a] structure_test の group タイトルが 'Cycle <N>' 始まりでない
//   [C3-b] structure_test の group タイトルに責務キーワード
//          （'minor' or 'version guard'）が含まれる
//   [C4-a] structure_test の恒久ガード [S2-a] が維持されている
//   [C4-b] structure_test の恒久ガード [S2-b] が維持されている
//   [C4-c] structure_test の恒久ガード [S2-c] が維持されている
//
// 非目標:
//   - `lib/` 配下の本番コード変更は行わない。
//   - `pubspec.yaml` の変更は行わない。
//   - `saved_drafts_retry_version_guard_test.dart` 本文変更は行わない。
//   - `saved_drafts_screen_retry_test.dart` のテスト本体変更は行わない
//     （ヘッダコメント 1 行の文字列置換のみ）。

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const _retryTestPath =
    'test/screens/saved_drafts_screen_retry_test.dart';
const _cleanupTestPath =
    'test/screens/saved_drafts_retry_version_guard_structure_cleanup_test.dart';
const _structureTestPath =
    'test/screens/saved_drafts_retry_version_guard_structure_test.dart';

const _oldGuardFileName =
    'saved_drafts_screen_retry_test_version_guard_test.dart';
const _canonicalGuardFileName =
    'saved_drafts_retry_version_guard_test.dart';

String _readFile(String path) {
  final file = File(path);
  if (!file.existsSync()) {
    fail('$path が存在しません。');
  }
  return file.readAsStringSync();
}

void main() {
  group('Cycle 21 — saved_drafts チェーン最終清掃', () {
    // ══════════════════════════════════════════════════════════════════════
    // [C1-a] retry_test ヘッダの旧ファイル名参照が除去されている
    // ══════════════════════════════════════════════════════════════════════
    test('[C1-a] retry_test 本文に旧ファイル名リテラルが残っていない', () {
      final src = _readFile(_retryTestPath);

      final hasOldName = src.contains(_oldGuardFileName);

      expect(
        hasOldName,
        isFalse,
        reason:
            '$_retryTestPath に Cycle 19 リネーム前の旧ファイル名\n'
            '"$_oldGuardFileName" が残っています。\n'
            'これは嘘コメントで、読み手が grep で正規ファイルに辿り着けません。\n'
            '現行の正規ファイル名 "$_canonicalGuardFileName" に置換してください。',
      );
    });

    // ══════════════════════════════════════════════════════════════════════
    // [C1-b] retry_test ヘッダに正規ファイル名が含まれる
    //        （旧名を削除するだけで参照自体を消してしまわないための担保）
    // ══════════════════════════════════════════════════════════════════════
    test('[C1-b] retry_test 本文に正規ファイル名 $_canonicalGuardFileName が含まれる', () {
      final src = _readFile(_retryTestPath);

      final hasCanonicalName = src.contains(_canonicalGuardFileName);

      expect(
        hasCanonicalName,
        isTrue,
        reason:
            '$_retryTestPath に正規 version guard ファイル名\n'
            '"$_canonicalGuardFileName" の参照が見当たりません。\n'
            '「major bump 時は併置の version guard が赤く落ちるので再設計の合図」\n'
            'というヘッダ記述は、読み手が現行ファイル名を辿れて初めて意味を持ちます。\n'
            '旧ファイル名を単に削除するのではなく、現行の正規名に置換してください。',
      );
    });

    // ══════════════════════════════════════════════════════════════════════
    // [C2] cleanup_test がファイルシステムから削除されている
    //      一回限りの移行ガードを assertion で守る再帰構造を解消。
    //      cleanup_test の責務は Cycle 20 完了時点で果たし終わった。
    // ══════════════════════════════════════════════════════════════════════
    test('[C2] cleanup_test ファイルがファイルシステムから削除されている', () {
      final exists = File(_cleanupTestPath).existsSync();

      expect(
        exists,
        isFalse,
        reason:
            '$_cleanupTestPath がまだ存在します。\n'
            'Cycle 20 で structure_test から [S1-a]/[S1-b]/_deprecatedGuardPath\n'
            'を除去済みであり、cleanup_test はもう守るべき対象がありません。\n'
            '一回限りの移行ガードを assertion で守る再帰構造を解消するため、\n'
            'CLAUDE.md「呼び出し元ゼロで削除」ルールに従いファイルごと削除してください。',
      );
    });

    // ══════════════════════════════════════════════════════════════════════
    // [C3-a] structure_test の group タイトルが履歴依存でない
    //        'Cycle <N> — ...' 始まりは運用ログ命名で、テスト責務の
    //        恒久命名ではない。'minor 検証メタガード' のような責務
    //        ベース命名に置換する。
    // ══════════════════════════════════════════════════════════════════════
    test('[C3-a] structure_test の group タイトルが "Cycle <N>" 始まりでない', () {
      final src = _readFile(_structureTestPath);

      // group('....', ...) の第一引数（シングルクォート）を全て抽出。
      // テスト本体（`test('...')`）は除外したいので group のみを対象とする。
      final matches =
          RegExp(r"""group\s*\(\s*['"]([^'"]+)['"]""").allMatches(src);

      expect(
        matches.isNotEmpty,
        isTrue,
        reason: '$_structureTestPath に group(...) 宣言が見つかりません。',
      );

      final cycleHistoryTitles = <String>[];
      for (final m in matches) {
        final title = m.group(1)!;
        if (RegExp(r'^Cycle\s+\d+').hasMatch(title)) {
          cycleHistoryTitles.add(title);
        }
      }

      expect(
        cycleHistoryTitles,
        isEmpty,
        reason:
            '$_structureTestPath に履歴依存の group タイトルが残っています:\n'
            '  $cycleHistoryTitles\n'
            'Cycle 番号は運用ログであって恒久テスト責務の名前ではありません。\n'
            '例: "version guard minor 検証メタガード" のような、\n'
            'テストが何を守っているかを示す責務ベース命名に置換してください。',
      );
    });

    // ══════════════════════════════════════════════════════════════════════
    // [C3-b] structure_test の group タイトルに責務キーワードが含まれる
    //        [C3-a] で単に空文字や無意味な文字列に差し替えることを防ぐ。
    // ══════════════════════════════════════════════════════════════════════
    test('[C3-b] structure_test の group タイトルに責務キーワードが含まれる', () {
      final src = _readFile(_structureTestPath);

      final matches =
          RegExp(r"""group\s*\(\s*['"]([^'"]+)['"]""").allMatches(src);
      final titles = matches.map((m) => m.group(1)!).toList();

      final hasResponsibilityKeyword = titles.any(
        (t) => t.contains('minor') || t.contains('version guard'),
      );

      expect(
        hasResponsibilityKeyword,
        isTrue,
        reason:
            '$_structureTestPath の group タイトルに責務キーワード\n'
            '（"minor" または "version guard"）が見当たりません:\n'
            '  現行 titles: $titles\n'
            '本ファイルは version guard 本体が minor 検証を持つことを守る\n'
            'メタガードです。タイトルからそれが読み取れる命名にしてください。',
      );
    });

    // ══════════════════════════════════════════════════════════════════════
    // [C4-a] 恒久ガード [S2-a] が維持されている（non-regression）
    // ══════════════════════════════════════════════════════════════════════
    test('[C4-a] structure_test 本文に恒久ガード [S2-a] が残っている', () {
      final src = _readFile(_structureTestPath);

      expect(
        src.contains('[S2-a]'),
        isTrue,
        reason:
            '$_structureTestPath の恒久ガード [S2-a]（minor 語彙検査）が\n'
            '誤って削除されています。Cycle 21 の清掃対象は group タイトルの\n'
            '命名のみで、[S2-*] 本体は温存する必要があります。',
      );
    });

    // ══════════════════════════════════════════════════════════════════════
    // [C4-b] 恒久ガード [S2-b] が維持されている（non-regression）
    // ══════════════════════════════════════════════════════════════════════
    test('[C4-b] structure_test 本文に恒久ガード [S2-b] が残っている', () {
      final src = _readFile(_structureTestPath);

      expect(
        src.contains('[S2-b]'),
        isTrue,
        reason:
            '$_structureTestPath の恒久ガード [S2-b]（minor >= 6 閾値検査）が\n'
            '誤って削除されています。温存してください。',
      );
    });

    // ══════════════════════════════════════════════════════════════════════
    // [C4-c] 恒久ガード [S2-c] が維持されている（non-regression）
    // ══════════════════════════════════════════════════════════════════════
    test('[C4-c] structure_test 本文に恒久ガード [S2-c] が残っている', () {
      final src = _readFile(_structureTestPath);

      expect(
        src.contains('[S2-c]'),
        isTrue,
        reason:
            '$_structureTestPath の恒久ガード [S2-c]（minor downgrade 説明\n'
            'コメント検査）が誤って削除されています。温存してください。',
      );
    });
  });
}
