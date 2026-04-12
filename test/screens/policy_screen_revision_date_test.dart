// TDD Red フェーズ
// policy_screen.dart プライバシーポリシー最終改定日修正テスト
//
// 受け入れ条件:
//   1. プライバシーポリシーの最終改定日が 2026年4月10日 であること
//   2. 改定日が制定日よりも後であること
//   3. 古い改定日（2026年3月17日）が残っていないこと
//
// 現状の違反箇所:
//   lib/screens/policy_screen.dart:21 — '最終改定日：2026年3月17日'
//
// Engineer への実装依頼:
//   policy_screen.dart L21 の '最終改定日：2026年3月17日' を
//   '最終改定日：2026年4月10日' に更新する

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// policy_screen.dart のソースを読み込む。
/// ファイルが存在しない場合は fail()（偽グリーン防止）。
String _readPolicySource() {
  final file = File('lib/screens/policy_screen.dart');
  if (!file.existsSync()) {
    fail(
      'lib/screens/policy_screen.dart が存在しません。\n'
      'ファイルパスが正しいか確認してください。\n'
      '（ファイル非存在のまま PASS させると偽グリーンになります）',
    );
  }
  return file.readAsStringSync();
}

void main() {
  // ══════════════════════════════════════════════════════════════
  // [1] プライバシーポリシー最終改定日の正確性
  // ══════════════════════════════════════════════════════════════

  group('policy_screen — プライバシーポリシー最終改定日', () {
    test('プライバシーポリシーの最終改定日が 2026年4月10日 のとき正しい改定日になる', () {
      final content = _readPolicySource();

      final hasCorrectDate = content.contains('最終改定日：2026年4月10日');

      expect(
        hasCorrectDate,
        isTrue,
        reason: 'プライバシーポリシーの最終改定日が 2026年4月10日 ではありません。\n'
            'header の「最終改定日：2026年3月17日」を「最終改定日：2026年4月10日」に更新してください。\n'
            '対象: lib/screens/policy_screen.dart の PrivacyPolicyScreen._PolicyContent.header',
      );
    });

    test('古い改定日（2026年3月17日）がプライバシーポリシーに残っていないとき更新漏れがない', () {
      final content = _readPolicySource();
      final lines = content.split('\n');
      final violations = <String>[];

      for (int i = 0; i < lines.length; i++) {
        if (lines[i].contains('2026年3月17日')) {
          violations.add('  L${i + 1}: ${lines[i].trim()}');
        }
      }

      expect(
        violations,
        isEmpty,
        reason: '古い改定日「2026年3月17日」がまだ残っています。\n'
            '「2026年4月10日」に更新してください。\n'
            '違反箇所:\n${violations.join('\n')}',
      );
    });

    test('プライバシーポリシーのヘッダーに制定日と最終改定日の両方が含まれているとき完全なヘッダーになる', () {
      final content = _readPolicySource();

      // PrivacyPolicyScreen の header に制定日・最終改定日の両方があること
      final hasEstablishDate = content.contains('制定日：2024年4月1日');
      final hasRevisionDate = RegExp(r'最終改定日：\d{4}年\d{1,2}月\d{1,2}日').hasMatch(content);

      expect(
        hasEstablishDate,
        isTrue,
        reason: 'プライバシーポリシーのヘッダーに制定日（2024年4月1日）が含まれていません。\n'
            'ヘッダーは「制定日：2024年4月1日」と「最終改定日：2026年4月10日」の両方を含む必要があります。',
      );

      expect(
        hasRevisionDate,
        isTrue,
        reason: 'プライバシーポリシーのヘッダーに最終改定日が含まれていません。\n'
            'ヘッダーに「最終改定日：YYYY年M月D日」形式の日付を含めてください。',
      );
    });
  });

  // ══════════════════════════════════════════════════════════════
  // [2] 利用規約の改定日が意図せず変更されていないこと
  // ══════════════════════════════════════════════════════════════

  group('policy_screen — 利用規約の改定日リグレッション防止', () {
    test('利用規約の最終改定日が 2025年3月15日 のままのとき意図しない変更がない', () {
      final content = _readPolicySource();

      // TermsScreen の header は変更しないことを確認
      // ソースコード上のリテラル `\n` に一致させるため \\n を使う
      final hasTermsDate = content.contains(r'Aimachi 利用規約\n制定日：2024年4月1日\n最終改定日：2025年3月15日');

      expect(
        hasTermsDate,
        isTrue,
        reason: '利用規約の最終改定日が変更されています。\n'
            '今回のタスクではプライバシーポリシーの改定日のみ更新対象です。\n'
            '利用規約のヘッダーは「最終改定日：2025年3月15日」のままにしてください。',
      );
    });
  });
}
