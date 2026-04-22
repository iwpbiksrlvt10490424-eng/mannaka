// TDD Red フェーズ
// Cycle 8: location_share_screen.dart の async 後 setState に mounted ガード追加
//
// 問題:
//   `_loadSession` / `_submit` の中で `await` 後の `setState(...)` が
//   `if (!mounted) return;` なしに呼ばれている。
//   ウィジェットが dispose された後に setState が走ると
//   "setState() called after dispose()" クラッシュが発生する。
//
// 違反箇所（現状）:
//   lib/screens/location_share_screen.dart:
//     L29: await LocationSessionService.getSession(...)
//     L31: setState(() { _error = '...'; _loading = false; });        ← mounted ガードなし
//     L37: setState(() { _hostName = ...; _loading = false; });       ← mounted ガードなし
//     L42: setState(() { _error = '...'; _loading = false; });        ← mounted ガードなし（catch）
//     L53: await Geolocator.checkPermission()
//     L55: await Geolocator.requestPermission()
//     L58: setState(() { _error = '...'; _submitting = false; });     ← mounted ガードなし
//     L64: await Geolocator.getCurrentPosition(...)
//     L68: await LocationSessionService.submitLocation(...)
//     L73: setState(() { _done = true; _submitting = false; });       ← mounted ガードなし
//     L78: setState(() { _error = '...'; _submitting = false; });     ← mounted ガードなし（catch）
//
// 修正方針（Engineer への引き継ぎ）:
//   各 await 後の setState 直前に `if (!mounted) return;` を追加する。
//   _submit() の冒頭 `setState(() => _submitting = true);` は await 前なので変更不要。
//
// 本テストは CLAUDE.md 必須ルール「非同期後のcontext使用前に `if (mounted)` を確認」の
// 静的リグレッションガードとして、Cycle 8 以降で同画面に await 後の
// 無ガード setState が再混入することを防止する。

import 'dart:io';
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';

const _targetFile = 'lib/screens/location_share_screen.dart';

List<String> _readLines() {
  final file = File(_targetFile);
  if (!file.existsSync()) {
    fail(
      '$_targetFile が存在しません。\n'
      'ファイルパスが正しいか確認してください。\n'
      '（ファイル非存在のまま PASS させると偽グリーンになります）',
    );
  }
  return file.readAsLinesSync();
}

String _readSource() {
  final file = File(_targetFile);
  if (!file.existsSync()) {
    fail('$_targetFile が存在しません。');
  }
  return file.readAsStringSync();
}

/// `await` の後に現れる `setState(` のうち、
/// その前に `if (!mounted) return;` が置かれていない行を検出する。
///
/// 検出ロジック:
///   対象行: `setState(` を含み、同行に `mounted` を含まない
///   直前の非空行に `mounted` が含まれない
///   直近15行以内に `await ` が存在する（= 非同期跨ぎの setState）
List<String> _findUncheckedSetStateAfterAwait(List<String> lines) {
  final violations = <String>[];

  for (int i = 0; i < lines.length; i++) {
    final line = lines[i];

    if (!line.contains('setState(') || line.contains('mounted')) continue;

    String prevNonEmpty = '';
    for (int j = i - 1; j >= math.max(0, i - 10); j--) {
      if (lines[j].trim().isNotEmpty) {
        prevNonEmpty = lines[j];
        break;
      }
    }

    if (prevNonEmpty.contains('mounted')) continue;

    final start = math.max(0, i - 15);
    final preceding = lines.sublist(start, i);
    // `await ` を含む行を検出。コメント行は除外。
    // `final x = await ...` / `perm = await ...` / `  await ...` のいずれも拾う。
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
  // [1] ファイル全体の静的スキャン: await 後 setState のガード
  // ══════════════════════════════════════════════════════════════

  group('location_share_screen — async 後 setState の mounted ガード', () {
    test('await 後の setState がすべて mounted ガード直後にあるときクラッシュしない', () {
      final lines = _readLines();
      final violations = _findUncheckedSetStateAfterAwait(lines);

      expect(
        violations,
        isEmpty,
        reason: 'await 後の setState の前に `if (!mounted) return;` が必要です。\n'
            '違反箇所:\n${violations.map((l) => '  $l').join('\n')}\n'
            '\n'
            '修正例:\n'
            '  final data = await LocationSessionService.getSession(...);\n'
            '  if (!mounted) return;   ← 追加\n'
            '  setState(() { ... });\n'
            '\n'
            'CLAUDE.md: 「非同期後の context 使用前に if (mounted) を確認」',
      );
    });
  });

  // ══════════════════════════════════════════════════════════════
  // [2] メソッド別の個別ガード確認（退化防止）
  // ══════════════════════════════════════════════════════════════

  group('location_share_screen — メソッド別 mounted ガード', () {
    test('_loadSession ブロック内に mounted ガードが存在するとき awiat 後の破棄耐性が保たれる', () {
      final source = _readSource();
      final body =
          _extractMethodBody(source, r'Future<void>\s+_loadSession\(\)\s*async');

      expect(
        body,
        isNotNull,
        reason: '_loadSession() メソッド本体を抽出できませんでした。\n'
            'シグネチャが `Future<void> _loadSession() async {` の形で残っているか確認してください。',
      );

      expect(
        body!.contains('if (!mounted) return'),
        isTrue,
        reason: '_loadSession() に `if (!mounted) return;` が存在しません。\n'
            '`await LocationSessionService.getSession(...)` の後の setState 前に\n'
            '`if (!mounted) return;` を追加してください。',
      );
    });

    test('_submit ブロック内に mounted ガードが存在するとき await 後の破棄耐性が保たれる', () {
      final source = _readSource();
      final body =
          _extractMethodBody(source, r'Future<void>\s+_submit\(\)\s*async');

      expect(
        body,
        isNotNull,
        reason: '_submit() メソッド本体を抽出できませんでした。\n'
            'シグネチャが `Future<void> _submit() async {` の形で残っているか確認してください。',
      );

      // _submit() は await が 3 箇所（checkPermission / requestPermission / getCurrentPosition / submitLocation）
      // 後の setState が 3 箇所（deniedForever / done / catch）あるため、
      // mounted ガードの出現回数も複数必要。2 回以上を期待する。
      final count = 'if (!mounted) return'.allMatches(body!).length;
      expect(
        count >= 2,
        isTrue,
        reason: '_submit() の `if (!mounted) return;` が不足しています（現在 $count 箇所）。\n'
            '権限結果後の setState・位置送信後の setState・catch 節の setState それぞれの前に\n'
            '`if (!mounted) return;` が必要です（最低 2 箇所以上）。',
      );
    });
  });

  // ══════════════════════════════════════════════════════════════
  // [3] 既存の固定文言・構造が退化していないことの回帰確認
  // ══════════════════════════════════════════════════════════════

  group('location_share_screen — 回帰防止（Cycle 7 成果物を壊さない）', () {
    test('Cycle 7 で追加した固定文言が維持されているときエラー文言が壊れていない', () {
      final source = _readSource();

      expect(
        source.contains('このリンクは無効または期限切れです'),
        isTrue,
        reason: '「このリンクは無効または期限切れです」が失われています。',
      );
      expect(
        source.contains('現在地を設定すると最寄駅が自動入力できます。設定 > プライバシー > 位置情報 から有効にしてください。'),
        isTrue,
        reason: '「現在地を設定すると最寄駅が自動入力できます。設定 > プライバシー > 位置情報 から有効にしてください。」が失われています。',
      );
      expect(
        source.contains('通信状況を確認してもう一度お試しください'),
        isTrue,
        reason: '通信失敗時の固定文言が失われています。',
      );
    });

    test('_submit の冒頭 setState が await 前のまま保持されているとき無駄な早期 return が入らない', () {
      final source = _readSource();
      final body =
          _extractMethodBody(source, r'Future<void>\s+_submit\(\)\s*async');

      expect(body, isNotNull);
      // _submit() は `setState(() => _submitting = true);` で開始するのが本来の設計。
      // これは await 前なので mounted ガードを付ける必要は無い。
      expect(
        body!.contains('setState(() => _submitting = true)'),
        isTrue,
        reason: '_submit() 冒頭の `setState(() => _submitting = true);` が失われています。\n'
            '初期のローディング表示に必要な副作用なので保持してください。',
      );
    });
  });
}
