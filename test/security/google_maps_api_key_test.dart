// TDD Red フェーズ
// Google Maps APIキー本番化テスト
//
// 受け入れ条件:
//   1. Info.plist に GMSApiKey のハードコードされたAPIキーリテラルが残存しない
//   2. secrets.dart.example に googleMapsApiKey フィールドが含まれる
//   3. secrets.dart.example に geocodingApiKey フィールドが含まれる
//   4. secrets.dart の全フィールドが secrets.dart.example にも存在する（同期）
//   5. secrets.dart と firebase_options.dart 以外のトラック対象ファイルに
//      APIキーリテラルが直書きされていない
//
// 現状の問題:
//   - Info.plist:44 にAPIキーがハードコードされていた（修正済み）
//   - secrets.dart.example に googleMapsApiKey / geocodingApiKey が未定義
//   - CLAUDE.md「APIキー直書き禁止」ルール違反

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Info.plist から指定キーの値を抽出する。
/// plist の `<key>KEY</key>\n<string>VALUE</string>` パターンに対応。
String? _extractPlistValue(String content, String key) {
  final match = RegExp(
    '<key>${RegExp.escape(key)}</key>\\s*<string>([^<]+)</string>',
  ).firstMatch(content);
  return match?.group(1);
}

/// secrets.dart / secrets.dart.example から static const String フィールド名一覧を抽出する。
/// ファイルが存在しない場合は null を返す。
Set<String>? _extractSecretFieldNames(String filePath) {
  final file = File(filePath);
  if (!file.existsSync()) {
    return null;
  }
  final content = file.readAsStringSync();
  return RegExp(r'static\s+const\s+String\s+(\w+)')
      .allMatches(content)
      .map((m) => m.group(1)!)
      .toSet();
}

/// 指定ディレクトリ以下の .dart ファイルから、
/// 除外リストに含まれないファイルで AIzaSy プレフィックスを含む行を検出する。
Map<String, List<String>> _findHardcodedApiKeys({
  required String directory,
  required Set<String> excludeFiles,
}) {
  final dir = Directory(directory);
  if (!dir.existsSync()) {
    fail('$directory が存在しません');
  }

  final violations = <String, List<String>>{};
  final dartFiles = dir
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('.dart'));

  for (final file in dartFiles) {
    final relativePath =
        file.path.replaceFirst(RegExp(r'^.*?/lib/'), 'lib/');
    if (excludeFiles.any((excluded) => relativePath.endsWith(excluded))) {
      continue;
    }

    final lines = file.readAsLinesSync();
    final matchingLines = <String>[];
    for (int i = 0; i < lines.length; i++) {
      if (lines[i].contains('AIzaSy')) {
        matchingLines.add('  L${i + 1}: ${lines[i].trim()}');
      }
    }
    if (matchingLines.isNotEmpty) {
      violations[relativePath] = matchingLines;
    }
  }
  return violations;
}

void main() {
  group('Google Maps APIキー本番化 — Info.plist', () {
    test(
        'Info.plist の GMSApiKey がハードコードされたAPIキーリテラルでないとき セキュリティが確保される',
        () {
      final file = File('ios/Runner/Info.plist');
      expect(file.existsSync(), isTrue,
          reason: 'ios/Runner/Info.plist が見つからない');

      final content = file.readAsStringSync();
      final gmsApiKeyValue = _extractPlistValue(content, 'GMSApiKey');

      // GMSApiKey が存在する場合、リテラルAPIキーでないことを確認
      // 許容される値: $(GOOGLE_MAPS_API_KEY) などのビルド変数、または GMSApiKey 自体が削除されている
      if (gmsApiKeyValue != null) {
        expect(
          gmsApiKeyValue.startsWith('AIzaSy'),
          isFalse,
          reason:
              'Info.plist に GMSApiKey がハードコードされています: $gmsApiKeyValue\n'
              'ビルド時変数 \$(GOOGLE_MAPS_API_KEY) に置き換えるか、\n'
              'secrets.dart 経由で注入する仕組みに変更してください。\n'
              'CLAUDE.md「APIキー直書き禁止」ルール違反',
        );
      }
      // gmsApiKeyValue が null の場合は、キーが削除された（AppDelegate が別経路で注入）ので OK
    });

    test(
        'Info.plist に AIzaSy で始まるリテラル文字列が含まれないとき APIキーが漏洩しない',
        () {
      final file = File('ios/Runner/Info.plist');
      expect(file.existsSync(), isTrue,
          reason: 'ios/Runner/Info.plist が見つからない');

      final content = file.readAsStringSync();
      final apiKeyPattern = RegExp(r'AIzaSy[A-Za-z0-9_-]{33}');
      final matches = apiKeyPattern.allMatches(content).toList();

      expect(
        matches,
        isEmpty,
        reason:
            'Info.plist に Google APIキーリテラルが含まれています。\n'
            '検出されたキー: ${matches.map((m) => m.group(0)).join(', ')}\n'
            'このキーは git 履歴に残り、漏洩リスクがあります。\n'
            'ビルド時注入に切り替えてください。',
      );
    });
  });

  group('Google Maps APIキー本番化 — secrets.dart.example 同期', () {
    test(
        'secrets.dart.example に googleMapsApiKey フィールドがあるとき 新規開発者がコンパイルできる',
        () {
      final file = File('lib/config/secrets.dart.example');
      expect(file.existsSync(), isTrue,
          reason: 'lib/config/secrets.dart.example が見つからない');

      final content = file.readAsStringSync();
      expect(
        content,
        contains('googleMapsApiKey'),
        reason:
            'secrets.dart.example に googleMapsApiKey フィールドがありません。\n'
            'secrets.dart には googleMapsApiKey が定義されていますが、\n'
            'テンプレートに含まれていないため、新規開発者が\n'
            'secrets.dart.example をコピーするとコンパイルエラーになります。',
      );
    });

    test(
        'secrets.dart.example に geocodingApiKey フィールドがあるとき 新規開発者がコンパイルできる',
        () {
      final file = File('lib/config/secrets.dart.example');
      expect(file.existsSync(), isTrue,
          reason: 'lib/config/secrets.dart.example が見つからない');

      final content = file.readAsStringSync();
      expect(
        content,
        contains('geocodingApiKey'),
        reason:
            'secrets.dart.example に geocodingApiKey フィールドがありません。\n'
            'secrets.dart には geocodingApiKey が定義されていますが、\n'
            'テンプレートに含まれていないため、新規開発者が\n'
            'secrets.dart.example をコピーするとコンパイルエラーになります。',
      );
    });

    test(
        'secrets.dart の全フィールドが secrets.dart.example にも存在するとき テンプレートが完全に同期している',
        () {
      final secretsFields =
          _extractSecretFieldNames('lib/config/secrets.dart');
      if (secretsFields == null) {
        markTestSkipped(
            'lib/config/secrets.dart が存在しないため（CI環境等）スキップ');
        return;
      }
      final exampleFields =
          _extractSecretFieldNames('lib/config/secrets.dart.example');
      if (exampleFields == null) {
        fail('lib/config/secrets.dart.example が存在しません。');
      }

      final missingInExample = secretsFields.difference(exampleFields);

      expect(
        missingInExample,
        isEmpty,
        reason:
            'secrets.dart.example に以下のフィールドが不足しています:\n'
            '${missingInExample.map((f) => '  - $f').join('\n')}\n'
            '\n'
            'secrets.dart のフィールド: ${secretsFields.join(', ')}\n'
            'secrets.dart.example のフィールド: ${exampleFields.join(', ')}\n'
            '\n'
            'テンプレートが不完全だと、新規開発者がコンパイルできません。',
      );
    });
  });

  group('Google Maps APIキー本番化 — Dart コード内直書き禁止', () {
    test(
        'secrets.dart 以外の Dart ファイルに AIzaSy リテラルが含まれないとき APIキーが分散管理されていない',
        () {
      // secrets.dart と firebase_options.dart は除外
      // （secrets.dart はキー管理の正規ファイル、firebase_options.dart は Firebase 自動生成）
      final violations = _findHardcodedApiKeys(
        directory: 'lib',
        excludeFiles: {
          'config/secrets.dart',
          'firebase_options.dart',
        },
      );

      expect(
        violations,
        isEmpty,
        reason:
            '以下のファイルに APIキーリテラルが直書きされています:\n'
            '${violations.entries.map((e) => '${e.key}:\n${e.value.join('\n')}').join('\n\n')}\n'
            '\n'
            'APIキーは secrets.dart で一元管理し、\n'
            'ApiConfig 経由で参照してください。',
      );
    });
  });

  group('Google Maps APIキー本番化 — secrets.dart.example のプレースホルダー', () {
    test(
        'secrets.dart.example に実際のAPIキーが含まれないとき シークレットが漏洩しない',
        () {
      final file = File('lib/config/secrets.dart.example');
      expect(file.existsSync(), isTrue,
          reason: 'lib/config/secrets.dart.example が見つからない');

      final content = file.readAsStringSync();
      final apiKeyPattern = RegExp(r'AIzaSy[A-Za-z0-9_-]{33}');
      final matches = apiKeyPattern.allMatches(content).toList();

      expect(
        matches,
        isEmpty,
        reason:
            'secrets.dart.example に実際のAPIキーが含まれています。\n'
            '検出されたキー: ${matches.map((m) => m.group(0)).join(', ')}\n'
            'テンプレートにはプレースホルダー（YOUR_xxx_API_KEY）を使用してください。',
      );
    });
  });
}
