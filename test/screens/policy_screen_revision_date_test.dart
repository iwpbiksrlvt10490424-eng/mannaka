// TDD Red フェーズ（Cycle 22）
// policy_screen.dart プライバシーポリシー最終改定日修正テスト
//
// 背景:
//   2026-04-24 06:52 commit `3841ae4` で policy_screen.dart 第2条のオプトアウト
//   導線が email 窓口に改定されたにもかかわらず、`policy_screen.dart:21` の
//   「最終改定日：2026年4月21日」が本文改定と乖離したまま残存している。
//   個人情報保護法・App Store 審査上、ポリシー本文と改定日の不一致は
//   虚偽記載扱いとなり得るため、Cycle 5 の前例に倣い 2026年4月24日 に更新する。
//
// 受け入れ条件（C1〜C7）:
//   C1: プライバシーポリシーの最終改定日が「2026年4月24日」であること
//   C2: 前サイクルの改定日（2026年4月21日）が残っていないこと（更新漏れ防止）
//   C3: Cycle 5 以前の改定日（2026年4月10日）も残っていないこと（回帰防止）
//   C4: 制定日（2024年4月1日）はヘッダーに維持されていること
//   C5: 最終改定日の日付フォーマット（YYYY年M月D日）を満たしていること
//   C6: ヘッダー全体リテラル
//       「Aimachi プライバシーポリシー\n制定日：2024年4月1日\n最終改定日：2026年4月24日」
//       が完全一致していること
//   C7: 利用規約（TermsScreen）の改定日「2025年3月15日」は無変更であること
//       （本サイクルのスコープ外のため意図しない巻き込みを防ぐ）
//
// 現状の違反箇所:
//   lib/screens/policy_screen.dart:21 — '最終改定日：2026年4月21日'
//
// Engineer への実装依頼:
//   policy_screen.dart L21 の '最終改定日：2026年4月21日' を
//   '最終改定日：2026年4月24日' に更新する。
//   TermsScreen のヘッダー（L152）は変更しないこと。

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
  // [1] プライバシーポリシー最終改定日の正確性（Cycle 22: 2026-04-24）
  // ══════════════════════════════════════════════════════════════

  group('policy_screen — プライバシーポリシー最終改定日', () {
    test('[C1] プライバシーポリシーの最終改定日が 2026年4月24日 のとき正しい改定日になる', () {
      final content = _readPolicySource();

      final hasCorrectDate = content.contains('最終改定日：2026年4月24日');

      expect(
        hasCorrectDate,
        isTrue,
        reason: 'プライバシーポリシーの最終改定日が 2026年4月24日 ではありません。\n'
            'header の「最終改定日：2026年4月21日」を「最終改定日：2026年4月24日」に更新してください。\n'
            '対象: lib/screens/policy_screen.dart の PrivacyPolicyScreen._PolicyContent.header',
      );
    });

    test('[C2] 前サイクルの改定日（2026年4月21日）がプライバシーポリシーに残っていないとき更新漏れがない', () {
      final content = _readPolicySource();
      final lines = content.split('\n');
      final violations = <String>[];

      for (int i = 0; i < lines.length; i++) {
        if (lines[i].contains('2026年4月21日')) {
          violations.add('  L${i + 1}: ${lines[i].trim()}');
        }
      }

      expect(
        violations,
        isEmpty,
        reason: '前サイクルの改定日「2026年4月21日」がまだ残っています。\n'
            '「2026年4月24日」に更新してください。\n'
            '違反箇所:\n${violations.join('\n')}',
      );
    });

    test('[C3] Cycle 5 以前の改定日（2026年4月10日）がプライバシーポリシーに残っていないとき回帰していない', () {
      final content = _readPolicySource();
      final lines = content.split('\n');
      final violations = <String>[];

      for (int i = 0; i < lines.length; i++) {
        if (lines[i].contains('2026年4月10日')) {
          violations.add('  L${i + 1}: ${lines[i].trim()}');
        }
      }

      expect(
        violations,
        isEmpty,
        reason: 'Cycle 5 以前の改定日「2026年4月10日」が残っています。\n'
            '「2026年4月24日」のみがプライバシーポリシーの改定日として残るようにしてください。\n'
            '違反箇所:\n${violations.join('\n')}',
      );
    });

    test('[C4] プライバシーポリシーのヘッダーに制定日（2024年4月1日）が含まれているとき制定日が維持されている', () {
      final content = _readPolicySource();

      final hasEstablishDate = content.contains('制定日：2024年4月1日');

      expect(
        hasEstablishDate,
        isTrue,
        reason: 'プライバシーポリシーのヘッダーに制定日（2024年4月1日）が含まれていません。\n'
            'ヘッダーは「制定日：2024年4月1日」と「最終改定日：2026年4月24日」の両方を含む必要があります。',
      );
    });

    test('[C5] プライバシーポリシーの最終改定日が YYYY年M月D日 形式のときフォーマットが正しい', () {
      final content = _readPolicySource();

      final hasRevisionDate =
          RegExp(r'最終改定日：\d{4}年\d{1,2}月\d{1,2}日').hasMatch(content);

      expect(
        hasRevisionDate,
        isTrue,
        reason: 'プライバシーポリシーのヘッダーに最終改定日が含まれていません。\n'
            'ヘッダーに「最終改定日：YYYY年M月D日」形式の日付を含めてください。',
      );
    });

    test('[C6] プライバシーポリシーのヘッダーが Aimachi ブランド + 制定日 + 最終改定日 2026年4月24日 の組合せのとき完全一致する', () {
      final content = _readPolicySource();

      // ソースコード上のリテラル `\n` に一致させるため \\n を使う
      final hasExactPrivacyHeader = content.contains(
        r'Aimachi プライバシーポリシー\n制定日：2024年4月1日\n最終改定日：2026年4月24日',
      );

      expect(
        hasExactPrivacyHeader,
        isTrue,
        reason: 'プライバシーポリシーのヘッダーが期待する完全な文字列になっていません。\n'
            '期待値: Aimachi プライバシーポリシー\\n制定日：2024年4月1日\\n最終改定日：2026年4月24日\n'
            'header 文字列全体の整合性を確認してください。',
      );
    });
  });

  // ══════════════════════════════════════════════════════════════
  // [2] 利用規約の改定日が意図せず変更されていないこと
  // ══════════════════════════════════════════════════════════════

  group('policy_screen — 利用規約の改定日リグレッション防止', () {
    test('[C7] 利用規約の最終改定日が 2025年3月15日 のままのとき意図しない変更がない', () {
      final content = _readPolicySource();

      // TermsScreen の header は変更しないことを確認
      final hasTermsDate = content.contains(
        r'Aimachi 利用規約\n制定日：2024年4月1日\n最終改定日：2025年3月15日',
      );

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
