// TDD Red フェーズ
// Cycle 7: location_share_screen.dart 生例外 $e UI 露出禁止 + エラー画面回帰テスト
//
// 問題:
//   location_share_screen.dart の setState 内 `_error = '...: $e'` で
//   例外の toString() がそのまま UI の _buildError() に流れる。
//   Exception 型名・スタック・内部実装が画面に露出し、
//   - ユーザーが読めない技術文字列が表示される（UX 劣化）
//   - FirebaseException のパス・プロジェクトID・内部メッセージが漏れうる（セキュリティ）
//
// 違反箇所:
//   lib/screens/location_share_screen.dart:43
//     _error = '読み込みエラー: $e';
//   lib/screens/location_share_screen.dart:79
//     _error = '送信に失敗しました: $e';
//
// 修正方針（Engineer への引き継ぎ）:
//   1. L43: `_error = 'このリンクを開けませんでした。通信状況を確認してもう一度お試しください。';`
//      （既存の「このリンクは無効または期限切れです」パターンと整合）
//   2. L79: `_error = '送信に失敗しました。通信状況を確認してもう一度お試しください。';`
//   3. 位置情報拒否の固定文言（L59 '位置情報をONにすると最寄り駅を自動で選択できます。設定 > プライバシー > 位置情報 から有効にしてください。'）は変更しない
//   4. _buildError() の構造（error_outline_rounded アイコン + Text(_error!) + 戻るボタン）は維持
//
// 本テストは Red→Green のガードとして、Cycle 7 以降で
// 同一画面に raw `$e` が再混入することを防止する。

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const _targetFile = 'lib/screens/location_share_screen.dart';

String _readSource() {
  final file = File(_targetFile);
  if (!file.existsSync()) {
    fail(
      '$_targetFile が存在しません。\n'
      'ファイルパスが正しいか確認してください。\n'
      '（ファイル非存在のまま PASS させると偽グリーンになります）',
    );
  }
  return file.readAsStringSync();
}

List<String> _readLines() {
  final file = File(_targetFile);
  if (!file.existsSync()) {
    fail('$_targetFile が存在しません。');
  }
  return file.readAsLinesSync();
}

void main() {
  // ══════════════════════════════════════════════════════════════
  // [1] _error に生例外 $e が直接埋め込まれていないこと
  // ══════════════════════════════════════════════════════════════

  group('location_share_screen — _error への生例外 \$e 露出禁止', () {
    test('_error 代入行に生の \$e が含まれていないとき UI に例外型名が露出しない', () {
      final lines = _readLines();
      final violations = <String>[];

      for (int i = 0; i < lines.length; i++) {
        final line = lines[i];
        // `_error = '...: $e'` / `_error = "...$e"` 等を検出。
        // `${e.runtimeType}` 等の安全な加工形式は除外する。
        final hasErrorAssign = RegExp(r'_error\s*=').hasMatch(line);
        final hasRawDollarE = RegExp(r'\$e(?![{a-zA-Z_0-9])').hasMatch(line);
        if (hasErrorAssign && hasRawDollarE) {
          violations.add('L${i + 1}: ${line.trim()}');
        }
      }

      expect(
        violations,
        isEmpty,
        reason: '_error への代入に生例外 \$e が埋め込まれています。\n'
            'Exception の toString() がそのまま UI 表示されるため、\n'
            '固定文言（例: 「通信状況を確認してもう一度お試しください。」）に置き換えてください。\n'
            '違反箇所:\n${violations.map((l) => '  $l').join('\n')}',
      );
    });

    test('catch 節直下の setState に \$e を含む文字列リテラルが無いとき露出経路が閉じている', () {
      final source = _readSource();

      // catch (e) { ... setState(() { ... '...$e' ... }); } を単純にファイル全体で検出
      // （ローカル変数 e を補間した文字列リテラルがソースに一切残らないことを要件とする）
      final matches = RegExp(
        r'''(?:'[^']*\$e(?![{a-zA-Z_0-9])[^']*'|"[^"]*\$e(?![{a-zA-Z_0-9])[^"]*")''',
      ).allMatches(source);

      final literals = matches.map((m) => m.group(0)!).toList();

      expect(
        literals,
        isEmpty,
        reason: 'location_share_screen.dart 内に \$e を直接埋めた文字列リテラルが残っています。\n'
            '該当リテラル: $literals\n'
            'エラー文言はすべて固定文言にしてください。',
      );
    });
  });

  // ══════════════════════════════════════════════════════════════
  // [2] 固定文言の存在（Green 基準）
  // ══════════════════════════════════════════════════════════════

  group('location_share_screen — 固定文言の存在', () {
    test('セッション読み込み失敗時の固定文言が存在するときユーザー向けエラーになる', () {
      final source = _readSource();

      // 読み込み失敗パス（catch 節）で使う固定文言を検査。
      // 具体の語尾は Engineer 判断だが、
      //   - 「このリンク」に関する案内 or 「通信」への言及
      //   - 「お試しください」等の再試行導線
      // のいずれかが含まれていれば許容する（過剰な文字列完全一致を避ける）。
      final hasReadFailureFixedCopy = source.contains(
            'このリンクを開けませんでした',
          ) ||
          (source.contains('通信状況') && source.contains('お試しください'));

      expect(
        hasReadFailureFixedCopy,
        isTrue,
        reason: 'セッション読み込み失敗時の固定文言が見当たりません。\n'
            '例: 「このリンクを開けませんでした。通信状況を確認してもう一度お試しください。」\n'
            '_loadSession() の catch 節で _error に設定してください。',
      );
    });

    test('位置情報送信失敗時の固定文言が存在するときユーザー向けエラーになる', () {
      final source = _readSource();

      // 「送信に失敗しました」プレフィックスは残してよいが、その後ろが \$e ではなく固定文言であることを期待する。
      // つまり `送信に失敗しました。` で終わる or `送信に失敗しました` の直後が日本語句点/案内文になっていれば可。
      final hasSendFailureFixedCopy = RegExp(
        r"'送信に失敗しました[。\n].*?'",
        multiLine: true,
      ).hasMatch(source) ||
          source.contains("送信に失敗しました。もう一度お試しください") ||
          source.contains("送信に失敗しました。通信状況を確認してもう一度お試しください");

      expect(
        hasSendFailureFixedCopy,
        isTrue,
        reason: '位置情報送信失敗時の固定文言が見当たりません。\n'
            '例: 「送信に失敗しました。通信状況を確認してもう一度お試しください。」\n'
            '_submit() の catch 節で \$e を含まない固定文言に置き換えてください。',
      );
    });

    test('位置情報拒否の既存固定文言が維持されているとき権限導線が壊れていない', () {
      final source = _readSource();

      // 今回のサイクルで触らないこと（リグレッション防止）
      expect(
        source.contains('位置情報をONにすると最寄り駅を自動で選択できます。設定 > プライバシー > 位置情報 から有効にしてください。'),
        isTrue,
        reason: '位置情報拒否時の固定文言が失われています。\n'
            '「位置情報をONにすると最寄り駅を自動で選択できます。設定 > プライバシー > 位置情報 から有効にしてください。」は維持してください。\n'
            '本サイクルの修正対象は catch 節の \$e 露出のみです。',
      );
    });

    test('無効リンク時の既存固定文言が維持されているとき期限切れ導線が壊れていない', () {
      final source = _readSource();

      expect(
        source.contains('このリンクは無効または期限切れです'),
        isTrue,
        reason: 'セッション未存在時の固定文言が失われています。\n'
            '「このリンクは無効または期限切れです」は維持してください。',
      );
    });
  });

  // ══════════════════════════════════════════════════════════════
  // [3] _buildError の Widget 構造回帰テスト
  // ══════════════════════════════════════════════════════════════
  //
  // LocationShareScreen は Firestore 依存のため完全な runtime widget テストは
  // Firebase 初期化が必要になる。本サイクルではソースレベルで
  // _buildError() の構造（アイコン + エラー文言 + 戻るボタン）が残っていることを
  // 静的に保証する（構造退化の回帰防止）。

  group('location_share_screen — _buildError 構造回帰', () {
    test('_buildError メソッドが存在するときエラー表示経路が保持される', () {
      final source = _readSource();

      expect(
        source.contains('Widget _buildError()'),
        isTrue,
        reason: '_buildError() メソッドが削除されています。\n'
            'エラー表示パスを維持してください。',
      );
    });

    test('_buildError に error_outline_rounded アイコンが残っているとき視覚表示が保たれる', () {
      final source = _readSource();

      // _buildError のブロックを切り出して局所検査する
      final match = RegExp(
        r'Widget\s+_buildError\(\)\s*\{[\s\S]*?^\s{0,2}\}',
        multiLine: true,
      ).firstMatch(source);
      expect(
        match,
        isNotNull,
        reason: '_buildError() のブロックを解析できませんでした。メソッド形式を維持してください。',
      );
      final block = match!.group(0)!;

      expect(
        block.contains('Icons.error_outline_rounded'),
        isTrue,
        reason: '_buildError に error_outline_rounded アイコンが見当たりません。\n'
            '視覚的なエラー表示を保持してください。',
      );
      expect(
        block.contains('_error!'),
        isTrue,
        reason: '_buildError に _error! の表示が見当たりません。\n'
            '固定文言を Text(_error!) で表示する構造を保持してください。',
      );
      expect(
        block.contains("'戻る'"),
        isTrue,
        reason: '_buildError の「戻る」ボタンが失われています。\n'
            'Navigator.of(context).pop() を呼ぶ TextButton(「戻る」) を保持してください。',
      );
      expect(
        block.contains('Navigator.of(context).pop()'),
        isTrue,
        reason: '_buildError の戻る導線 Navigator.of(context).pop() が失われています。',
      );
    });

    test('build() の分岐で _error チェックから _buildError に到達する経路が残っているとき表示パスが保たれる', () {
      final source = _readSource();

      // `_error != null` → `_buildError()` の分岐が build() 内に残っていること
      expect(
        source.contains('_error != null'),
        isTrue,
        reason: 'build() 内の _error != null 分岐が失われています。\n'
            '_error への代入が UI に反映される経路を保持してください。',
      );
      expect(
        source.contains('_buildError()'),
        isTrue,
        reason: 'build() から _buildError() を呼び出す経路が失われています。',
      );
    });
  });
}
