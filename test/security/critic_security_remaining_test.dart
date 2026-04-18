// TDD Red フェーズ
// Critic/Security 残件修正テスト
//
// 受け入れ条件:
//   1. テストファイル内に AIzaSy APIキーリテラルが含まれない（Security W-1）
//   2. geocoding_service.dart の debugPrint が生例外 $e を含まない（Security W-4）
//   3. ios/Flutter/Secrets.xcconfig.example テンプレートが存在する（Critic WARNING）
//   4. AppDelegate.swift が空文字キーをガードする（Critic WARNING）
//   5. google_maps_api_key_test.dart が secrets.dart 不在時にスキップする（Critic CRITICAL）

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Security W-1 — テストファイル内APIキーリテラル禁止', () {
    test(
        'テストファイルに AIzaSy リテラルが含まれないとき リポジトリにAPIキーが漏洩しない',
        () {
      final testDir = Directory('test');
      expect(testDir.existsSync(), isTrue,
          reason: 'test/ ディレクトリが見つからない');

      final violations = <String, List<String>>{};
      final dartFiles = testDir
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart'));

      for (final file in dartFiles) {
        final lines = file.readAsLinesSync();
        final matchingLines = <String>[];
        for (int i = 0; i < lines.length; i++) {
          if (RegExp(r'AIzaSy[A-Za-z0-9_-]{10,}').hasMatch(lines[i])) {
            matchingLines.add('  L${i + 1}: ${lines[i].trim()}');
          }
        }
        if (matchingLines.isNotEmpty) {
          final relativePath =
              file.path.replaceFirst(RegExp(r'^.*?/test/'), 'test/');
          violations[relativePath] = matchingLines;
        }
      }

      expect(
        violations,
        isEmpty,
        reason:
            'テストファイルに Google APIキーリテラルが含まれています。\n'
            '${violations.entries.map((e) => '${e.key}:\n${e.value.join('\n')}').join('\n\n')}\n'
            '\n'
            'コメントであってもコミットするとリポジトリに実キーが残ります。\n'
            'APIキーを伏せ字（AIzaSy...XXXX）に置き換えてください。',
      );
    });
  });

  group('Security W-4 — geocoding_service.dart 例外ダンプ安全化', () {
    test(
        'geocoding_service.dart の debugPrint が生例外 \$e を含まないとき APIキーURLが漏洩しない',
        () {
      final file = File('lib/services/geocoding_service.dart');
      expect(file.existsSync(), isTrue,
          reason: 'lib/services/geocoding_service.dart が見つからない');

      final lines = file.readAsLinesSync();
      final violations = lines
          .where((line) =>
              line.contains('debugPrint') &&
              RegExp(r'\$e[^{a-zA-Z_]').hasMatch(line))
          .toList();

      expect(
        violations,
        isEmpty,
        reason:
            'geocoding_service.dart の debugPrint に \$e が直接含まれています。\n'
            '例外の toString() にはAPIキーを含むURL等が含まれる可能性があります。\n'
            '\${e.runtimeType} を使用してください。\n'
            '違反行:\n${violations.map((l) => '  $l').join('\n')}',
      );
    });
  });

  group('Critic WARNING — Secrets.xcconfig.example テンプレート', () {
    test(
        'ios/Flutter/Secrets.xcconfig.example が存在するとき 新規開発者がセットアップできる',
        () {
      final file = File('ios/Flutter/Secrets.xcconfig.example');
      expect(
        file.existsSync(),
        isTrue,
        reason:
            'ios/Flutter/Secrets.xcconfig.example が存在しません。\n'
            'Secrets.xcconfig は .gitignore で除外されているため、\n'
            '新規開発者がセットアップ方法を知るためのテンプレートが必要です。',
      );
    });

    test(
        'Secrets.xcconfig.example に GOOGLE_MAPS_API_KEY が含まれるとき 必要な設定が分かる',
        () {
      final file = File('ios/Flutter/Secrets.xcconfig.example');
      if (!file.existsSync()) {
        fail('ios/Flutter/Secrets.xcconfig.example が存在しない（前提テスト失敗）');
      }

      final content = file.readAsStringSync();
      expect(
        content,
        contains('GOOGLE_MAPS_API_KEY'),
        reason:
            'Secrets.xcconfig.example に GOOGLE_MAPS_API_KEY が含まれていません。\n'
            'Info.plist で \$(GOOGLE_MAPS_API_KEY) を参照しているため、\n'
            'テンプレートにこのキーを含める必要があります。',
      );
    });

    test(
        'Secrets.xcconfig.example に実際のAPIキーが含まれないとき シークレットが漏洩しない',
        () {
      final file = File('ios/Flutter/Secrets.xcconfig.example');
      if (!file.existsSync()) {
        fail('ios/Flutter/Secrets.xcconfig.example が存在しない（前提テスト失敗）');
      }

      final content = file.readAsStringSync();
      final apiKeyPattern = RegExp(r'AIzaSy[A-Za-z0-9_-]{33}');
      expect(
        apiKeyPattern.hasMatch(content),
        isFalse,
        reason:
            'Secrets.xcconfig.example に実際のAPIキーが含まれています。\n'
            'テンプレートにはプレースホルダーを使用してください。',
      );
    });
  });

  group('Critic WARNING — AppDelegate.swift 空キーガード', () {
    test(
        'AppDelegate.swift が空文字のGMSApiKeyでGMSServicesを初期化しないとき クラッシュしない',
        () {
      final file = File('ios/Runner/AppDelegate.swift');
      expect(file.existsSync(), isTrue,
          reason: 'ios/Runner/AppDelegate.swift が見つからない');

      final content = file.readAsStringSync();

      // GMSServices.provideAPIKey を呼ぶ前に空文字チェックがあることを確認
      // 期待: !key.isEmpty, key.count > 0, key != "" 等
      final hasEmptyGuard = content.contains('isEmpty') ||
          content.contains('.count > 0') ||
          content.contains('!= ""') ||
          content.contains("!= ''");

      expect(
        hasEmptyGuard,
        isTrue,
        reason:
            'AppDelegate.swift に空文字キーのガードがありません。\n'
            'GMSApiKey が空文字 "" の場合、GMSServices.provideAPIKey("") で\n'
            'クラッシュまたは無効な状態になる可能性があります。\n'
            'if let key = ..., !key.isEmpty { ... } に変更してください。',
      );
    });
  });

  group('Critic CRITICAL — secrets.dart 不在時のテストスキップ', () {
    test(
        'google_maps_api_key_test.dart が secrets.dart 不在時にスキップパターンを使うとき CIで失敗しない',
        () {
      final file = File('test/security/google_maps_api_key_test.dart');
      expect(file.existsSync(), isTrue,
          reason: 'test/security/google_maps_api_key_test.dart が見つからない');

      final content = file.readAsStringSync();

      // secrets.dart を参照するテストがある場合、不在時のスキップ機構があるか確認
      // 現状: _extractSecretFieldNames() が fail() を呼ぶ → CI で失敗
      // 期待: secrets.dart が無い場合は markTestSkipped() 等でスキップ
      if (content.contains("secrets.dart'") ||
          content.contains("secrets.dart\"")) {
        final hasSkipPattern = content.contains('markTestSkipped') ||
            content.contains('skip:') ||
            content.contains('Skip(');

        expect(
          hasSkipPattern,
          isTrue,
          reason:
              'google_maps_api_key_test.dart が secrets.dart を読み込んでいますが、\n'
              'ファイル不在時のスキップパターンがありません。\n'
              'CI 環境では secrets.dart は .gitignore で除外されるため、\n'
              'テストが fail() して CI 全体が失敗します。\n'
              'secrets.dart 不在時は markTestSkipped() でスキップしてください。',
        );
      }
    });
  });
}
