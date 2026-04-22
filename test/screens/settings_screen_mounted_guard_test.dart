// TDD Red フェーズ
// Cycle 9: settings_screen.dart `_pickProfileImage` の async 後 setState に mounted ガード追加
//
// 問題:
//   `_pickProfileImage` 内で `_picker.pickImage(...)` の後に
//   `if (!mounted) return;` は一度置かれているが、その直後の
//   `await SharedPreferences.getInstance()` / `await prefs.setString(...)` の
//   2 連 await を跨いで `setState(() {});` が呼ばれている。
//   画像選択→prefs 書き込み中に画面離脱（戻る・バックグラウンド→dispose）すると
//   "setState() called after dispose()" クラッシュが発生し得る。
//
// 違反箇所（現状 lib/screens/settings_screen.dart）:
//   L141: final picked = await _picker.pickImage(...)
//   L148: if (!mounted) return;                          ← 既存ガード（これは OK）
//   L150: final prefs = await SharedPreferences.getInstance();
//   L151: await prefs.setString('profile_image_path', picked.path);
//   L152: setState(() {});                                ← mounted ガードなし（要追加）
//
// 修正方針（Engineer への引き継ぎ）:
//   L151 と L152 の間に `if (!mounted) return;` を追加する。
//   最小変更は 1 行挿入のみ。
//
// 本テストは CLAUDE.md 必須ルール「非同期後のcontext使用前に `if (mounted)` を確認」の
// 静的リグレッションガードとして、Cycle 9 以降で settings_screen.dart に
// await 後の無ガード setState が再混入することを防止する。
//
// さらに、本テストは Cycle 8（location_share_screen）からの横展開ルールを
// 「lib/screens/ 全体」に自動適用するプロジェクト全域スキャンを含み、
// 今後同パターンが他画面で発生した場合に検出できるようにする。

import 'dart:io';
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';

const _targetFile = 'lib/screens/settings_screen.dart';

List<String> _readLines(String path) {
  final file = File(path);
  if (!file.existsSync()) {
    fail(
      '$path が存在しません。\n'
      'ファイルパスが正しいか確認してください。\n'
      '（ファイル非存在のまま PASS させると偽グリーンになります）',
    );
  }
  return file.readAsLinesSync();
}

String _readSource(String path) {
  final file = File(path);
  if (!file.existsSync()) {
    fail('$path が存在しません。');
  }
  return file.readAsStringSync();
}

/// `await` の後に現れる `setState(` のうち、
/// その前に `if (!mounted) return;` が置かれていない行を検出する。
///
/// 検出ロジック（Cycle 8 の location_share_screen 版と同仕様）:
///   対象行: `setState(` を含み、同行に `mounted` を含まない
///   直前の非空行に `mounted` が含まれない
///   直近15行以内に `await ` が存在する（= 非同期跨ぎの setState）
List<String> _findUncheckedSetStateAfterAwait(List<String> lines) {
  final violations = <String>[];

  for (int i = 0; i < lines.length; i++) {
    final line = lines[i];

    if (!line.contains('setState(') || line.contains('mounted')) continue;

    // 直前の「コードとして意味のある行」を取得する。
    // 空行・コメント行（`//` 始まり）は無視し、実コード行のみを対象にする。
    // これにより `if (!mounted) return;` の直後にコメントや空行を挟んでも
    // ガード済みと認識できる。
    String prevCode = '';
    for (int j = i - 1; j >= math.max(0, i - 10); j--) {
      final trimmed = lines[j].trim();
      if (trimmed.isEmpty) continue;
      if (trimmed.startsWith('//')) continue;
      prevCode = lines[j];
      break;
    }

    if (prevCode.contains('mounted')) continue;

    final start = math.max(0, i - 15);
    final preceding = lines.sublist(start, i);
    final hasAwait = preceding.any((l) {
      final trimmed = l.trimLeft();
      if (trimmed.startsWith('//')) return false;
      return l.contains('await ');
    });
    if (!hasAwait) continue;

    violations.add('L${i + 1}: ${line.trim()}');
  }

  return violations;
}

/// 指定メソッドのブロック本体を抽出する（単純な波括弧カウント）。
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
  // ══════════════════════════════════════════════════════════════
  // [1] settings_screen.dart 静的スキャン: await 後 setState のガード
  // ══════════════════════════════════════════════════════════════

  group('settings_screen — async 後 setState の mounted ガード', () {
    test('await 後の setState がすべて mounted ガード直後にあるときクラッシュしない', () {
      final lines = _readLines(_targetFile);
      final violations = _findUncheckedSetStateAfterAwait(lines);

      expect(
        violations,
        isEmpty,
        reason: 'await 後の setState の前に `if (!mounted) return;` が必要です。\n'
            '違反箇所:\n${violations.map((l) => '  $l').join('\n')}\n'
            '\n'
            '修正例:\n'
            '  final prefs = await SharedPreferences.getInstance();\n'
            '  await prefs.setString(\'profile_image_path\', picked.path);\n'
            '  if (!mounted) return;   ← 追加\n'
            '  setState(() {});\n'
            '\n'
            'CLAUDE.md: 「非同期後の context 使用前に if (mounted) を確認」',
      );
    });
  });

  // ══════════════════════════════════════════════════════════════
  // [2] _pickProfileImage メソッド内の個別ガード確認（退化防止）
  // ══════════════════════════════════════════════════════════════

  group('settings_screen — _pickProfileImage メソッド別 mounted ガード', () {
    test('_pickProfileImage ブロック内に setState 前の mounted ガードが存在するとき破棄耐性が保たれる', () {
      final source = _readSource(_targetFile);
      final body = _extractMethodBody(
        source,
        r'Future<void>\s+_pickProfileImage\(\)\s*async',
      );

      expect(
        body,
        isNotNull,
        reason: '_pickProfileImage() メソッド本体を抽出できませんでした。\n'
            'シグネチャが `Future<void> _pickProfileImage() async {` の形で残っているか確認してください。',
      );

      // _pickProfileImage() 内で発生する await は
      //   1) showModalBottomSheet<ImageSource>(...)
      //   2) _picker.pickImage(...)
      //   3) SharedPreferences.getInstance()
      //   4) prefs.setString(...)
      // の 4 回。
      // 現状は 2) の直後に 1 箇所 `if (!mounted) return;` がある。
      // L152 の `setState(() {});` の前にもう 1 箇所必要なので、合計 2 箇所以上。
      final count = 'if (!mounted) return'.allMatches(body!).length;
      expect(
        count >= 2,
        isTrue,
        reason: '_pickProfileImage() の `if (!mounted) return;` が不足しています（現在 $count 箇所）。\n'
            'pickImage の直後に加えて、prefs.setString の後（setState の直前）にも\n'
            '`if (!mounted) return;` が必要です（最低 2 箇所以上）。',
      );
    });

    test('_pickProfileImage の末尾 setState 直前に mounted ガードがあるとき async 後クラッシュを防げる', () {
      final source = _readSource(_targetFile);
      final body = _extractMethodBody(
        source,
        r'Future<void>\s+_pickProfileImage\(\)\s*async',
      );

      expect(body, isNotNull);

      // メソッド本体を行ごとに走査し、末尾側の `setState(() {});` の直前 10 行以内に
      // `mounted` チェックが存在することを確認する。
      final bodyLines = body!.split('\n');
      int targetIdx = -1;
      for (int i = bodyLines.length - 1; i >= 0; i--) {
        final t = bodyLines[i].trim();
        // 対象: 単純な `setState(() {});` もしくは `setState(() {` で始まる行
        if (t == 'setState(() {});' || t.startsWith('setState(()')) {
          if (!bodyLines[i].contains('mounted')) {
            targetIdx = i;
            break;
          }
        }
      }

      // もし無ガード setState が見つからないなら、それは修正済み（Green）。
      if (targetIdx < 0) {
        return;
      }

      // 見つかった場合、直前 10 行以内に mounted ガードがあるか確認。
      bool guarded = false;
      for (int j = targetIdx - 1; j >= math.max(0, targetIdx - 10); j--) {
        if (bodyLines[j].contains('if (!mounted) return')) {
          guarded = true;
          break;
        }
      }
      expect(
        guarded,
        isTrue,
        reason: '_pickProfileImage() 末尾 `setState(() {});` の直前に '
            '`if (!mounted) return;` が見つかりません。\n'
            'prefs.setString 直後に mounted ガードを追加してください。',
      );
    });
  });

  // ══════════════════════════════════════════════════════════════
  // [3] lib/screens/ 全体の横展開スキャン（Cycle 8 → Cycle 9 ルール）
  // ══════════════════════════════════════════════════════════════

  group('lib/screens/ 全体 — async 後 setState の mounted ガード', () {
    test('lib/screens/ 配下のすべての *.dart で await 後 setState が mounted ガードされているとき横展開ルールが守られる', () {
      final dir = Directory('lib/screens');
      expect(dir.existsSync(), isTrue, reason: 'lib/screens/ が存在しません。');

      final violations = <String>[];
      final dartFiles = dir
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart'))
          .toList();

      for (final file in dartFiles) {
        final lines = file.readAsLinesSync();
        final fileViolations = _findUncheckedSetStateAfterAwait(lines);
        for (final v in fileViolations) {
          violations.add('${file.path} $v');
        }
      }

      expect(
        violations,
        isEmpty,
        reason: 'lib/screens/ 配下で await 後に無ガード setState が見つかりました。\n'
            '違反箇所:\n${violations.map((l) => '  $l').join('\n')}\n'
            '\n'
            'CLAUDE.md「同パターンの全箇所を検索して一括修正」ルールに従い、\n'
            '各 setState の直前に `if (!mounted) return;` を追加してください。',
      );
    });
  });

  // ══════════════════════════════════════════════════════════════
  // [4] 既存機能の回帰防止（Cycle 9 の修正で壊さないこと）
  // ══════════════════════════════════════════════════════════════

  group('settings_screen — 回帰防止（既存構造を壊さない）', () {
    test('profile_image_path 永続化キーが保持されているとき画像保存フローが壊れない', () {
      final source = _readSource(_targetFile);
      expect(
        source.contains("prefs.setString('profile_image_path'"),
        isTrue,
        reason: "prefs.setString('profile_image_path', ...) が失われています。\n"
            'プロフィール画像の永続化に必要な副作用なので保持してください。',
      );
    });

    test('profileImagePathProvider への書き込みが保持されているとき UI 反映が壊れない', () {
      final source = _readSource(_targetFile);
      expect(
        source.contains('profileImagePathProvider.notifier'),
        isTrue,
        reason: 'profileImagePathProvider への notifier 書き込みが失われています。\n'
            'UI への即時反映に必要なので保持してください。',
      );
    });

    test('_pickProfileImage の showModalBottomSheet が保持されているとき画像選択 UX が壊れない', () {
      final source = _readSource(_targetFile);
      final body = _extractMethodBody(
        source,
        r'Future<void>\s+_pickProfileImage\(\)\s*async',
      );
      expect(body, isNotNull);
      expect(
        body!.contains('showModalBottomSheet'),
        isTrue,
        reason: '_pickProfileImage() の showModalBottomSheet が失われています。\n'
            'ギャラリー/カメラ選択 UI に必要なので保持してください。',
      );
      expect(
        body.contains('ImageSource.gallery'),
        isTrue,
        reason: 'ImageSource.gallery の選択肢が失われています。',
      );
      expect(
        body.contains('ImageSource.camera'),
        isTrue,
        reason: 'ImageSource.camera の選択肢が失われています。',
      );
    });
  });
}
