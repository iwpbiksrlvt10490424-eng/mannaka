// TDD Red フェーズ
// search_screen.dart Divider禁止ルール違反テスト
//
// 受け入れ条件:
//   1. search_screen.dart 内の Divider ウィジェットを全て除去する
//   2. Divider の代わりに SizedBox + Container 等で同等の区切り線を実現する
//
// 違反箇所:
//   lib/screens/search_screen.dart:312 — Expanded(child: Divider(...))
//   lib/screens/search_screen.dart:321 — Expanded(child: Divider(...))
//
// Engineer への実装依頼:
//   L312, L321 の Divider(thickness: 1, color: Color(0xFFE0E0E0)) を
//   Container(height: 1, color: Color(0xFFE0E0E0)) 等の非Dividerウィジェットに置換

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// search_screen.dart のソースを読み込む。
/// ファイルが存在しない場合は fail()（偽グリーン防止）。
String _readSearchSource() {
  final file = File('lib/screens/search_screen.dart');
  if (!file.existsSync()) {
    fail(
      'lib/screens/search_screen.dart が存在しません。\n'
      'ファイルパスが正しいか確認してください。',
    );
  }
  return file.readAsStringSync();
}

void main() {
  // ══════════════════════════════════════════════════════════════
  // [1] Divider 禁止ルール違反の検出
  // ══════════════════════════════════════════════════════════════

  group('search_screen — Divider禁止ルール (CLAUDE.md)', () {
    test('search_screen.dart に Divider ウィジェットが含まれていないとき Divider禁止ルールに準拠する',
        () {
      final content = _readSearchSource();
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
        reason: 'search_screen.dart に Divider ウィジェットが残っています。\n'
            'CLAUDE.md: 「Divider禁止 — SizedBox 8-10px で区切る」\n'
            'Container(height: 1, color: ...) 等に置き換えてください。\n'
            '違反箇所:\n${violations.join('\n')}',
      );
    });

    test('ステップ区切りの左右の線が Divider 以外で実現されているとき CLAUDE.md準拠する', () {
      final content = _readSearchSource();

      // 「先にメンバーの駅を入れてね」テキスト周辺の Row 内に
      // Divider が使われていないことを確認
      // 修正後は Container(height: 1, ...) 等に変わっているはず
      final stepSeparatorRegion = RegExp(
        r"先にメンバーの駅を入れてね",
      );

      expect(
        stepSeparatorRegion.hasMatch(content),
        isTrue,
        reason: 'ステップ区切りテキスト「先にメンバーの駅を入れてね」が見つかりません。\n'
            'テキストが削除されていないか確認してください。',
      );

      // ステップ区切り周辺（前後20行）に Divider がないことを確認
      final lines = content.split('\n');
      int targetLine = -1;
      for (int i = 0; i < lines.length; i++) {
        if (lines[i].contains('先にメンバーの駅を入れてね')) {
          targetLine = i;
          break;
        }
      }

      if (targetLine == -1) {
        fail('ステップ区切りテキストの行が特定できません。');
      }

      final start = (targetLine - 10).clamp(0, lines.length);
      final end = (targetLine + 10).clamp(0, lines.length);
      final regionLines = lines.sublist(start, end);

      final dividerInRegion = <String>[];
      for (int i = 0; i < regionLines.length; i++) {
        final trimmed = regionLines[i].trimLeft();
        if (trimmed.startsWith('//') || trimmed.startsWith('import ')) continue;
        if (RegExp(r'\bDivider\s*\(').hasMatch(regionLines[i])) {
          dividerInRegion.add('  L${start + i + 1}: ${regionLines[i].trim()}');
        }
      }

      expect(
        dividerInRegion,
        isEmpty,
        reason: 'ステップ区切り「先にメンバーの駅を入れてね」周辺に Divider が残っています。\n'
            'Container(height: 1, color: Color(0xFFE0E0E0)) 等に置き換えてください。\n'
            '違反箇所:\n${dividerInRegion.join('\n')}',
      );
    });
  });

  // ══════════════════════════════════════════════════════════════
  // [2] showDivider プロパティ名はウィジェット使用ではないが
  //     実際の区切り表示が Divider でないことを確認
  // ══════════════════════════════════════════════════════════════

  group('search_screen — 参加者カード区切り線', () {
    test('showDivider が true のとき表示される区切りが Divider ウィジェットではないとき準拠する',
        () {
      final content = _readSearchSource();

      // showDivider の実装箇所（if (widget.showDivider) の次行）に
      // Divider( が含まれていないことを確認
      final lines = content.split('\n');
      for (int i = 0; i < lines.length; i++) {
        if (lines[i].contains('widget.showDivider') ||
            lines[i].contains('showDivider)')) {
          // 次の行に Divider ウィジェットがないこと
          if (i + 1 < lines.length) {
            final nextLine = lines[i + 1];
            expect(
              RegExp(r'\bDivider\s*\(').hasMatch(nextLine),
              isFalse,
              reason: 'L${i + 2}: showDivider の実装に Divider ウィジェットが使われています。\n'
                  'SizedBox + ColoredBox 等で実現してください。\n'
                  '実際: ${nextLine.trim()}',
            );
          }
        }
      }
    });
  });
}
