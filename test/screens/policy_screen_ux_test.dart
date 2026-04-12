// TDD Red フェーズ
// policy_screen.dart UX修正テスト
//
// 受け入れ条件:
//   1. 利用規約 第4条の手動改行 `\n　　` 3箇所を除去（文章を連続テキストにする）
//   2. _PolicyContent の Divider を SizedBox(height: 8〜10) に置換
//
// 違反箇所:
//   lib/screens/policy_screen.dart:148 — `\n　　ネットワーク`
//   lib/screens/policy_screen.dart:150 — `\n　　行為`
//   lib/screens/policy_screen.dart:153 — `\n　　逆アセンブル`
//   lib/screens/policy_screen.dart:232 — `Divider(color: Colors.grey.shade200)`
//
// Engineer への実装依頼:
//   1. 第4条の3箇所: `\n　　` を除去し、前後のテキストを繋げる
//   2. _PolicyContent.build() 内の Divider を SizedBox(height: 8) に置換

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
  // [1] 手動改行+全角スペース（`\n　　`）の除去
  // ══════════════════════════════════════════════════════════════

  group('policy_screen — 手動改行+全角スペース除去', () {
    test('第4条に「\\n　　」（改行+全角スペース）が含まれていないとき UX品質に準拠する', () {
      final content = _readPolicySource();
      final lines = content.split('\n');
      final violations = <String>[];

      for (int i = 0; i < lines.length; i++) {
        // `\n　　` はソースコード上では文字列リテラル内に `\n　　` と書かれている
        // 全角スペース（U+3000）が2つ続くパターンを検出
        if (lines[i].contains('\\n\u3000\u3000')) {
          violations.add('  L${i + 1}: ${lines[i].trim()}');
        }
      }

      expect(
        violations,
        isEmpty,
        reason: '第4条に手動改行+全角スペース（\\n　　）が残っています。\n'
            '文章を連続テキストに修正してください。\n'
            '違反箇所:\n${violations.join('\n')}',
      );
    });

    test('第4条の禁止事項3番の文章が途中で改行されていないとき読みやすさに準拠する', () {
      final content = _readPolicySource();

      // 修正後は「サーバーやネットワーク」が1つの連続テキストになるはず
      // 改行で分断されている場合 `や\n` が含まれる
      final hasManualBreak3 = content.contains('サーバーや\\n');

      expect(
        hasManualBreak3,
        isFalse,
        reason: '第4条3番「サーバーや」の後に手動改行が入っています。\n'
            '「サーバーやネットワーク」を連続テキストにしてください。',
      );
    });

    test('第4条の禁止事項5番の文章が途中で改行されていないとき読みやすさに準拠する', () {
      final content = _readPolicySource();

      // 修正後は「蓄積する行為」が1つの連続テキストになるはず
      final hasManualBreak5 = content.contains('蓄積する\\n');

      expect(
        hasManualBreak5,
        isFalse,
        reason: '第4条5番「蓄積する」の後に手動改行が入っています。\n'
            '「蓄積する行為」を連続テキストにしてください。',
      );
    });

    test('第4条の禁止事項7番の文章が途中で改行されていないとき読みやすさに準拠する', () {
      final content = _readPolicySource();

      // 修正後は「逆コンパイル、逆アセンブルする行為」が連続になるはず
      final hasManualBreak7 = content.contains('逆コンパイル、\\n');

      expect(
        hasManualBreak7,
        isFalse,
        reason: '第4条7番「逆コンパイル、」の後に手動改行が入っています。\n'
            '「逆コンパイル、逆アセンブルする行為」を連続テキストにしてください。',
      );
    });
  });

  // ══════════════════════════════════════════════════════════════
  // [2] Divider 禁止ルール違反の修正
  // ══════════════════════════════════════════════════════════════

  group('policy_screen — Divider禁止ルール (CLAUDE.md)', () {
    test('policy_screen.dart に Divider ウィジェットが含まれていないとき Divider禁止ルールに準拠する',
        () {
      final content = _readPolicySource();
      final lines = content.split('\n');
      final violations = <String>[];

      for (int i = 0; i < lines.length; i++) {
        final trimmed = lines[i].trimLeft();
        // import 文・コメントはスキップ
        if (trimmed.startsWith('//') || trimmed.startsWith('import ')) continue;

        // Divider( または Divider() をウィジェット使用として検出
        if (RegExp(r'\bDivider\s*\(').hasMatch(lines[i])) {
          violations.add('  L${i + 1}: ${lines[i].trim()}');
        }
      }

      expect(
        violations,
        isEmpty,
        reason: 'policy_screen.dart に Divider ウィジェットが残っています。\n'
            'CLAUDE.md: 「Divider禁止 — SizedBox 8-10px で区切る」\n'
            'SizedBox(height: 8) に置き換えてください。\n'
            '違反箇所:\n${violations.join('\n')}',
      );
    });

    test('_PolicyContent のヘッダー区切りが SizedBox(height: 8〜10) であるとき CLAUDE.md準拠する',
        () {
      final content = _readPolicySource();

      // Divider の代わりに SizedBox(height: 8) 〜 SizedBox(height: 10) が
      // header 直後に存在することを確認
      // 既存: SizedBox(height: 20) → Divider → SizedBox(height: 16)
      // 期待: SizedBox(height: 20) → SizedBox(height: 8〜10) → SizedBox(height: 16)
      //   または Divider 行が SizedBox に変わっていること

      final hasDivider = RegExp(r'\bDivider\b').hasMatch(content);

      expect(
        hasDivider,
        isFalse,
        reason: '_PolicyContent 内に Divider への参照が残っています。\n'
            'SizedBox(height: 8) または SizedBox(height: 10) に置き換えてください。',
      );
    });
  });

  // ══════════════════════════════════════════════════════════════
  // [3] インデント用全角スペース（`\n　　`）が残っていないこと（包括チェック）
  // ══════════════════════════════════════════════════════════════

  group('policy_screen — インデント用全角スペース除去（包括）', () {
    test('policy_screen.dart に改行+全角スペースインデント（\\n＋全角スペース2個）が含まれていないとき', () {
      final content = _readPolicySource();
      final lines = content.split('\n');
      final violations = <String>[];

      for (int i = 0; i < lines.length; i++) {
        final trimmed = lines[i].trimLeft();
        // コメント行はスキップ
        if (trimmed.startsWith('//')) continue;

        // `\n　　`（改行+全角スペース2個）= 手動インデント用途を検出
        // `１　` 等の番号+全角スペース1個はリスト書式なので対象外
        if (lines[i].contains('\\n\u3000\u3000')) {
          violations.add('  L${i + 1}: ${lines[i].trim()}');
        }
      }

      expect(
        violations,
        isEmpty,
        reason: 'policy_screen.dart にインデント用全角スペース（\\n　　）が残っています。\n'
            '手動改行+全角スペースインデントを除去してください。\n'
            '違反箇所:\n${violations.join('\n')}',
      );
    });
  });

  // ══════════════════════════════════════════════════════════════
  // [4] 連続SizedBox冗長整理
  // ══════════════════════════════════════════════════════════════

  group('policy_screen — SizedBox冗長整理', () {
    test('_PolicyContent のヘッダー後に連続SizedBoxが3つ並んでいないとき冗長が解消されている', () {
      final content = _readPolicySource();
      final lines = content.split('\n');

      // 連続する SizedBox(height: N) を3行以上検出したら冗長
      // 現状: SizedBox(height: 20), SizedBox(height: 8), SizedBox(height: 16)
      // → 1つの SizedBox にまとめるべき
      int consecutiveSizedBoxCount = 0;
      int maxConsecutive = 0;
      final violations = <String>[];
      int startLine = -1;

      for (int i = 0; i < lines.length; i++) {
        final trimmed = lines[i].trim();
        if (RegExp(r'^const\s+SizedBox\(height:\s*\d+\),?$').hasMatch(trimmed)) {
          if (consecutiveSizedBoxCount == 0) startLine = i;
          consecutiveSizedBoxCount++;
          if (consecutiveSizedBoxCount > maxConsecutive) {
            maxConsecutive = consecutiveSizedBoxCount;
          }
        } else {
          if (consecutiveSizedBoxCount >= 3) {
            violations.add(
              '  L${startLine + 1}〜L${startLine + consecutiveSizedBoxCount}: '
              'SizedBox が $consecutiveSizedBoxCount 個連続しています',
            );
          }
          consecutiveSizedBoxCount = 0;
        }
      }
      // ファイル末尾チェック
      if (consecutiveSizedBoxCount >= 3) {
        violations.add(
          '  L${startLine + 1}〜L${startLine + consecutiveSizedBoxCount}: '
          'SizedBox が $consecutiveSizedBoxCount 個連続しています',
        );
      }

      expect(
        violations,
        isEmpty,
        reason: '_PolicyContent 内に SizedBox が3つ以上連続しています。\n'
            '合計値の SizedBox 1つにまとめてください。\n'
            '例: SizedBox(height: 20) + SizedBox(height: 8) + SizedBox(height: 16)\n'
            '  → SizedBox(height: 28) （20 + 8 を統合、16 は sections 前の余白として残す等）\n'
            '違反箇所:\n${violations.join('\n')}',
      );
    });

    test('_PolicyContent のヘッダーとセクション間の余白が SizedBox 2つ以下であるとき整理されている',
        () {
      final content = _readPolicySource();

      // header 直後の余白ブロック: SizedBox(height: 20) → SizedBox(height: 8) → SizedBox(height: 16)
      // 3つの SizedBox が連続するパターンを検出
      final pattern = RegExp(
        r'SizedBox\(height:\s*20\).*\n\s*const\s+SizedBox\(height:\s*8\).*\n\s*const\s+SizedBox\(height:\s*16\)',
        multiLine: true,
      );

      expect(
        pattern.hasMatch(content),
        isFalse,
        reason: '_PolicyContent に SizedBox(height: 20), SizedBox(height: 8), SizedBox(height: 16) の\n'
            '3連続パターンが残っています。\n'
            '1〜2つの SizedBox にまとめてください。',
      );
    });
  });
}
