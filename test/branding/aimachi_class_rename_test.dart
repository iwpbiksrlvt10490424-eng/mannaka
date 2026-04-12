// TDD Red テスト: AimaApp → AimachiApp クラス名リネーム
//
// 受け入れ条件:
//   1. lib/app.dart のクラス名が AimachiApp であること
//   2. lib/main.dart の参照が AimachiApp であること
//   3. lib/ 配下に旧クラス名 AimaApp が残っていないこと
//   4. test/ 配下のコメント以外に旧クラス名 AimaApp が残っていないこと

import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AimaApp → AimachiApp クラス名リネーム', () {
    test('lib/app.dart のクラス定義が AimachiApp のとき', () {
      final file = File('lib/app.dart');
      expect(file.existsSync(), isTrue, reason: 'lib/app.dart が存在しません');

      final content = file.readAsStringSync();
      // AimachiApp クラスが定義されている
      expect(
        content.contains('class AimachiApp extends StatelessWidget'),
        isTrue,
        reason: 'lib/app.dart に "class AimachiApp" が見つかりません。'
            '旧クラス名 "AimaApp" → "AimachiApp" にリネームしてください。',
      );
    });

    test('lib/app.dart のコンストラクタが AimachiApp のとき', () {
      final file = File('lib/app.dart');
      final content = file.readAsStringSync();
      // const AimachiApp コンストラクタが定義されている
      expect(
        content.contains('const AimachiApp('),
        isTrue,
        reason: 'lib/app.dart に "const AimachiApp(" が見つかりません。'
            'コンストラクタも "AimachiApp" にリネームしてください。',
      );
    });

    test('lib/app.dart に旧クラス名 AimaApp が残っていないとき', () {
      final file = File('lib/app.dart');
      final content = file.readAsStringSync();
      final lines = content.split('\n');
      final violations = <String>[];

      for (int i = 0; i < lines.length; i++) {
        final line = lines[i];
        final trimmed = line.trimLeft();
        // コメント行はスキップ
        if (trimmed.startsWith('//') || trimmed.startsWith('///')) continue;

        if (RegExp(r'\bAimaApp\b').hasMatch(line)) {
          violations.add('  L${i + 1}: ${line.trim()}');
        }
      }

      expect(
        violations,
        isEmpty,
        reason: 'lib/app.dart に旧クラス名 "AimaApp" が残っています。\n'
            '違反箇所:\n${violations.join('\n')}',
      );
    });

    test('lib/main.dart の runApp で AimachiApp が使われているとき', () {
      final file = File('lib/main.dart');
      expect(file.existsSync(), isTrue, reason: 'lib/main.dart が存在しません');

      final content = file.readAsStringSync();
      expect(
        content.contains('AimachiApp()'),
        isTrue,
        reason: 'lib/main.dart に "AimachiApp()" が見つかりません。'
            'runApp 内の "AimaApp()" → "AimachiApp()" にリネームしてください。',
      );
    });

    test('lib/main.dart に旧クラス名 AimaApp が残っていないとき', () {
      final file = File('lib/main.dart');
      final content = file.readAsStringSync();
      final lines = content.split('\n');
      final violations = <String>[];

      for (int i = 0; i < lines.length; i++) {
        final line = lines[i];
        final trimmed = line.trimLeft();
        if (trimmed.startsWith('//') || trimmed.startsWith('///')) continue;

        if (RegExp(r'\bAimaApp\b').hasMatch(line)) {
          violations.add('  L${i + 1}: ${line.trim()}');
        }
      }

      expect(
        violations,
        isEmpty,
        reason: 'lib/main.dart に旧クラス名 "AimaApp" が残っています。\n'
            '違反箇所:\n${violations.join('\n')}',
      );
    });

    test('lib/ 配下の全 .dart に旧クラス名 AimaApp が残っていないとき', () {
      final libDir = Directory('lib');
      expect(libDir.existsSync(), isTrue);

      final dartFiles = libDir
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart'))
          .toList();

      final violations = <String>[];

      for (final file in dartFiles) {
        final lines = file.readAsLinesSync();
        for (int i = 0; i < lines.length; i++) {
          final line = lines[i];
          final trimmed = line.trimLeft();
          // コメント行・import 文はスキップ
          if (trimmed.startsWith('//') || trimmed.startsWith('///')) continue;
          if (trimmed.startsWith('import ')) continue;

          if (RegExp(r'\bAimaApp\b').hasMatch(line)) {
            violations.add('  ${file.path}:${i + 1}: ${line.trim()}');
          }
        }
      }

      expect(
        violations,
        isEmpty,
        reason: 'lib/ 配下に旧クラス名 "AimaApp" が残っています。\n'
            '違反箇所:\n${violations.join('\n')}',
      );
    });

    test('test/ 配下のコード行に旧クラス名 AimaApp が残っていないとき', () {
      final testDir = Directory('test');
      if (!testDir.existsSync()) return;

      final dartFiles = testDir
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart'))
          .toList();

      final violations = <String>[];

      for (final file in dartFiles) {
        // このテストファイル自体はスキップ
        if (file.path.contains('aimachi_class_rename_test.dart')) continue;

        final lines = file.readAsLinesSync();
        for (int i = 0; i < lines.length; i++) {
          final line = lines[i];
          final trimmed = line.trimLeft();
          // コメント行はスキップ
          if (trimmed.startsWith('//') || trimmed.startsWith('///')) continue;

          if (RegExp(r'\bAimaApp\b').hasMatch(line)) {
            violations.add('  ${file.path}:${i + 1}: ${line.trim()}');
          }
        }
      }

      expect(
        violations,
        isEmpty,
        reason: 'test/ 配下のコード行に旧クラス名 "AimaApp" が残っています。\n'
            'テスト内でも "AimachiApp" に更新してください。\n'
            '違反箇所:\n${violations.join('\n')}',
      );
    });
  });
}
