// Cycle 19 Critic ISSUE 解消後（Cycle 20）の恒久メタガード。
//
// 背景:
//   Cycle 18 で追加した version guard テスト本体
//   `saved_drafts_retry_version_guard_test.dart` は、Riverpod の minor が
//   `^2.5.0` 等にダウングレードされた場合にサイレントに偽グリーン化する
//   リスクを抱えていた。Cycle 19 で minor >= 6 の閾値検証を追加し、
//   本ファイルはその恒久ガードが将来誤って弱体化されないことを担保する。
//
//   Cycle 19 で同居していた旧ファイル名のリネーム判定（S1 系）は
//   一回限りの移行ガードだったため、Cycle 20 で除去済み。本ファイルには
//   恒久メタガード S2 系のみを残している。
//
// 非目標:
//   - `lib/` 配下の本番コード変更は行わない。
//   - `pubspec.yaml` の変更は行わない。
//   - `saved_drafts_retry_version_guard_test.dart` の本文変更は行わない。

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const _canonicalGuardPath =
    'test/screens/saved_drafts_retry_version_guard_test.dart';

String _readFile(String path) {
  final file = File(path);
  if (!file.existsSync()) {
    fail('$path が存在しません。');
  }
  return file.readAsStringSync();
}

void main() {
  group('version guard minor 検証メタガード', () {
    // ══════════════════════════════════════════════════════════════════════
    // [S2-a] 正規ファイルに minor を抽出する正規表現が含まれていること
    //       （major-only 検証から minor を含めた検証に拡張されている担保）
    // ══════════════════════════════════════════════════════════════════════
    test('[S2-a] 正規ファイル本文に flutter_riverpod の minor を抽出する正規表現が含まれる', () {
      final src = _readFile(_canonicalGuardPath);

      // Cycle 18 時点の正規表現は `(\d+)\.(\d+)` を持つが、minor キャプチャを
      // **使用している**（group(2) を int.parse する等）ことを保証したい。
      // 「minor」というリテラル名を要求することで、検証対象になっているかの
      // 可読性も担保する。
      final hasMinorTokenInCode = RegExp(r'\bminor\b').hasMatch(src);

      expect(
        hasMinorTokenInCode,
        isTrue,
        reason:
            '正規ファイルに "minor" というローカル変数名／コメントが見当たりません。\n'
            'flutter_riverpod の minor バージョンを抽出して検証していない可能性があります。\n'
            '例: `final minor = int.parse(match!.group(2)!);` を追加し、\n'
            '    `expect(minor, greaterThanOrEqualTo(6), reason: ...);` で検査してください。',
      );
    });

    // ══════════════════════════════════════════════════════════════════════
    // [S2-b] minor >= 6 の境界値検証が存在すること
    // ══════════════════════════════════════════════════════════════════════
    test('[S2-b] 正規ファイル本文に minor >= 6 相当の閾値検証が含まれる', () {
      final src = _readFile(_canonicalGuardPath);

      // 許容する書き方（OR）:
      //   - `greaterThanOrEqualTo(6)`
      //   - `>= 6`
      //   - `minor, 6` 周辺の明示（`greaterThanOrEqualTo` と組み合わせた1行）
      final hasMinorThreshold =
          RegExp(r'greaterThanOrEqualTo\s*\(\s*6\s*\)').hasMatch(src) ||
              RegExp(r'minor[^;]{0,80}>=\s*6').hasMatch(src) ||
              RegExp(r'>=\s*6[^;]{0,80}minor').hasMatch(src);

      expect(
        hasMinorThreshold,
        isTrue,
        reason:
            '正規ファイルに "minor >= 6" 相当の閾値検証が見当たりません。\n'
            '現状は major のみ検査のため、`flutter_riverpod: ^2.5.0` 等へ\n'
            '誤って minor を下げた際にサイレントに通過します。\n'
            '例: `expect(minor, greaterThanOrEqualTo(6), reason: ...);`\n'
            '    を [5]（または新しい [6]）に 3 行で追加してください。',
      );
    });

    // ══════════════════════════════════════════════════════════════════════
    // [S2-c] minor downgrade のリスクを説明するコメントが本文にあること
    //       （「なぜ minor まで検証するか」が後続の読み手に伝わる担保）
    // ══════════════════════════════════════════════════════════════════════
    test('[S2-c] 正規ファイルに minor downgrade リスクを説明するコメントが含まれる', () {
      final src = _readFile(_canonicalGuardPath);

      // 「2.5」「minor を下げた」「minor downgrade」「minor の下位」等の
      // いずれかの語彙が本文コメントに含まれることを要求する。
      final hasDowngradeRationale = src.contains('2.5') ||
          src.contains('minor を下げ') ||
          src.contains('minor downgrade') ||
          src.contains('minor の下') ||
          src.contains('下位 minor') ||
          src.contains('下方');

      expect(
        hasDowngradeRationale,
        isTrue,
        reason:
            '正規ファイル本文に「なぜ minor >= 6 を要求するか」の説明が見当たりません。\n'
            'minor downgrade（例: `^2.5.0` へのダウングレード）がサイレントに\n'
            '偽グリーン化するリスクを、コメントで 1 行以上明記してください。',
      );
    });
  });
}
