// TDD Red テスト: シェアファイル名・コメント内の旧ブランド名修正
//
// 受け入れ条件:
//   1. ranking_screen.dart のシェア画像ファイル名が mannaka_ranking.png であること
//   2. share_preview_screen.dart のシェア画像ファイル名が mannaka_share.png であること
//   3. search_provider.dart のコメント内「Aimachi」が「まんなか」に修正されていること
//   4. lib/ 配下に aima_ プレフィックスのファイル名リテラルが残っていないこと
//
// 注: 実装前の Red テスト。現状すべて FAIL する。

import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // ═══════════════════════════════════════════════════════════
  // グループ1: ranking_screen.dart — シェア画像ファイル名
  // ═══════════════════════════════════════════════════════════
  group('ranking_screen — シェア画像ファイル名', () {
    test('ranking_screen.dart のシェア画像ファイル名が mannaka_ranking.png のとき', () {
      final file = File('lib/screens/ranking_screen.dart');
      expect(file.existsSync(), isTrue,
          reason: 'lib/screens/ranking_screen.dart が存在しません');

      final content = file.readAsStringSync();

      // 旧ファイル名が残っていないこと
      expect(
        content.contains('aima_ranking.png'),
        isFalse,
        reason: 'ranking_screen.dart に旧ファイル名 "aima_ranking.png" が残っています。'
            '"mannaka_ranking.png" に変更してください。',
      );

      // 新ファイル名が存在すること
      expect(
        content.contains('mannaka_ranking.png'),
        isTrue,
        reason: 'ranking_screen.dart に新ファイル名 "mannaka_ranking.png" が見つかりません。',
      );
    });
  });

  // ═══════════════════════════════════════════════════════════
  // グループ2: share_preview_screen.dart — シェア画像ファイル名
  // ═══════════════════════════════════════════════════════════
  group('share_preview_screen — シェア画像ファイル名', () {
    test('share_preview_screen.dart のシェア画像ファイル名が mannaka_share.png のとき', () {
      final file = File('lib/screens/share_preview_screen.dart');
      expect(file.existsSync(), isTrue,
          reason: 'lib/screens/share_preview_screen.dart が存在しません');

      final content = file.readAsStringSync();

      // 旧ファイル名が残っていないこと
      expect(
        content.contains('aima_share.png'),
        isFalse,
        reason: 'share_preview_screen.dart に旧ファイル名 "aima_share.png" が残っています。'
            '"mannaka_share.png" に変更してください。',
      );

      // 新ファイル名が存在すること
      expect(
        content.contains('mannaka_share.png'),
        isTrue,
        reason:
            'share_preview_screen.dart に新ファイル名 "mannaka_share.png" が見つかりません。',
      );
    });
  });

  // ═══════════════════════════════════════════════════════════
  // グループ3: search_provider.dart — コメント内の旧ブランド名
  // ═══════════════════════════════════════════════════════════
  group('search_provider — コメント内の旧ブランド名', () {
    test('search_provider.dart のコメントに「Aimachi」が残っていないとき', () {
      final file = File('lib/providers/search_provider.dart');
      expect(file.existsSync(), isTrue,
          reason: 'lib/providers/search_provider.dart が存在しません');

      final lines = file.readAsLinesSync();
      final violations = <String>[];

      for (int i = 0; i < lines.length; i++) {
        final line = lines[i];
        final trimmed = line.trimLeft();

        // コメント行のみ検査（旧ブランド名の残存チェック）
        if (trimmed.startsWith('//') || trimmed.startsWith('///')) {
          if (line.contains('Aimachi')) {
            violations.add('  L${i + 1}: ${line.trim()}');
          }
        }
      }

      expect(
        violations,
        isEmpty,
        reason: 'search_provider.dart のコメントに旧ブランド名 "Aimachi" が残っています。\n'
            '「まんなか」に修正してください。\n\n'
            '違反箇所:\n${violations.join('\n')}',
      );
    });
  });

  // ═══════════════════════════════════════════════════════════
  // グループ4: lib/ 全体 — aima_ プレフィックスのファイル名リテラル
  // ═══════════════════════════════════════════════════════════
  group('lib/ 全体 — aima_ プレフィックスのファイル名', () {
    test('lib/ 配下に aima_ プレフィックスのファイル名リテラルが残っていないとき', () {
      final libDir = Directory('lib');
      expect(libDir.existsSync(), isTrue);

      final dartFiles = libDir
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart'))
          .toList();

      final aimaFilePattern = RegExp(r"'aima_\w+\.\w+'");
      final violations = <String>[];

      for (final file in dartFiles) {
        final lines = file.readAsLinesSync();
        for (int i = 0; i < lines.length; i++) {
          if (aimaFilePattern.hasMatch(lines[i])) {
            violations.add('  ${file.path}:${i + 1}: ${lines[i].trim()}');
          }
        }
      }

      expect(
        violations,
        isEmpty,
        reason: 'lib/ 配下に旧ブランド名の aima_ プレフィックスファイル名が残っています。\n'
            'mannaka_ プレフィックスに変更してください。\n\n'
            '違反箇所:\n${violations.join('\n')}',
      );
    });

    test('lib/ 配下のシェアファイル名パスに aima が含まれていないとき', () {
      final libDir = Directory('lib');
      final dartFiles = libDir
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart'))
          .toList();

      // tempDir パス内の aima_share.png パターンも検出
      final aimaPathPattern = RegExp(r'aima_\w+\.png');
      final violations = <String>[];

      for (final file in dartFiles) {
        final lines = file.readAsLinesSync();
        for (int i = 0; i < lines.length; i++) {
          if (aimaPathPattern.hasMatch(lines[i])) {
            violations.add('  ${file.path}:${i + 1}: ${lines[i].trim()}');
          }
        }
      }

      expect(
        violations,
        isEmpty,
        reason: 'lib/ 配下にシェア画像パス内の旧ブランド名 aima_ が残っています。\n'
            '違反箇所:\n${violations.join('\n')}',
      );
    });
  });
}
