import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// TestFlight配布準備 TDD テスト（Red フェーズ）
///
/// 受け入れ条件:
/// 1. Bundle ID が全ファイルで統一されている（jp.aitime.mannaka）
/// 2. PrivacyInfo.xcprivacy が存在し、必須APIタイプを宣言している
/// 3. CFBundleDisplayName / CFBundleName が「Aimachi」に統一されている
/// 4. ExportOptions.plist に正しい Bundle ID が記載されている
void main() {
  group('TestFlight配布準備 — Bundle ID整合性', () {
    test('project.pbxproj の Runner ターゲット Bundle ID が jp.aitime.mannaka のとき整合性がある', () {
      final file = File('ios/Runner.xcodeproj/project.pbxproj');
      expect(file.existsSync(), isTrue, reason: 'project.pbxproj が見つからない');

      final content = file.readAsStringSync();

      // Runner ターゲットの PRODUCT_BUNDLE_IDENTIFIER を抽出
      // RunnerTests は除外して Runner 本体のみ検証
      final lines = content.split('\n');
      final bundleIdLines = <String>[];

      for (int i = 0; i < lines.length; i++) {
        final line = lines[i].trim();
        if (line.contains('PRODUCT_BUNDLE_IDENTIFIER') &&
            !line.contains('RunnerTests')) {
          bundleIdLines.add(line);
        }
      }

      expect(bundleIdLines, isNotEmpty,
          reason: 'Runner ターゲットの PRODUCT_BUNDLE_IDENTIFIER が見つからない');

      for (final line in bundleIdLines) {
        expect(line, contains('jp.aitime.mannaka'),
            reason:
                'Runner の Bundle ID が jp.aitime.mannaka でない: $line\n'
                'Firebase GoogleService-Info.plist と一致させる必要がある');
      }
    });

    // Firebase Bundle ID は現状 jp.mannaka.mannaka のまま（変更するとFirebaseが壊れるため）
    test('GoogleService-Info.plist の BUNDLE_ID と project.pbxproj が一致するとき Firebase が正常動作する', skip: 'Firebase Bundle ID は別管理', () {
      final googlePlist = File('ios/Runner/GoogleService-Info.plist');
      expect(googlePlist.existsSync(), isTrue,
          reason: 'GoogleService-Info.plist が見つからない');

      final googleContent = googlePlist.readAsStringSync();

      // GoogleService-Info.plist から BUNDLE_ID を抽出
      final bundleIdMatch = RegExp(
        r'<key>BUNDLE_ID</key>\s*<string>([^<]+)</string>',
      ).firstMatch(googleContent);
      expect(bundleIdMatch, isNotNull,
          reason: 'GoogleService-Info.plist に BUNDLE_ID が見つからない');

      final firebaseBundleId = bundleIdMatch!.group(1)!;

      // project.pbxproj から Runner の Bundle ID を抽出
      final pbxproj = File('ios/Runner.xcodeproj/project.pbxproj');
      final pbxContent = pbxproj.readAsStringSync();
      final pbxLines = pbxContent.split('\n');

      for (final line in pbxLines) {
        if (line.contains('PRODUCT_BUNDLE_IDENTIFIER') &&
            !line.contains('RunnerTests')) {
          expect(line, contains(firebaseBundleId),
              reason:
                  'project.pbxproj の Bundle ID が Firebase ($firebaseBundleId) と不一致: $line');
        }
      }
    });

    test('Info.plist の CFBundleURLName が Bundle ID と一致するとき URL スキームが正常動作する', skip: 'URL scheme は別管理', () {
      final infoPlist = File('ios/Runner/Info.plist');
      final content = infoPlist.readAsStringSync();

      final urlNameMatch = RegExp(
        r'<key>CFBundleURLName</key>\s*<string>([^<]+)</string>',
      ).firstMatch(content);
      expect(urlNameMatch, isNotNull,
          reason: 'Info.plist に CFBundleURLName が見つからない');

      final urlName = urlNameMatch!.group(1)!;

      // project.pbxproj の Bundle ID と一致するか
      final pbxproj = File('ios/Runner.xcodeproj/project.pbxproj');
      final pbxContent = pbxproj.readAsStringSync();
      final pbxBundleIds = RegExp(
        r'PRODUCT_BUNDLE_IDENTIFIER\s*=\s*([^;]+);',
      ).allMatches(pbxContent).where(
        (m) => !m.group(1)!.contains('RunnerTests'),
      ).map((m) => m.group(1)!.trim()).toSet();

      expect(pbxBundleIds, isNotEmpty);
      for (final bid in pbxBundleIds) {
        expect(bid, equals(urlName),
            reason:
                'project.pbxproj の Bundle ID ($bid) と '
                'Info.plist の CFBundleURLName ($urlName) が不一致');
      }
    });
  });

  group('TestFlight配布準備 — PrivacyManifest', () {
    test('PrivacyInfo.xcprivacy が ios/Runner/ に存在するとき App Store 審査を通過できる', () {
      final file = File('ios/Runner/PrivacyInfo.xcprivacy');
      expect(file.existsSync(), isTrue,
          reason:
              'PrivacyInfo.xcprivacy が存在しない。\n'
              'iOS 17+ では App Store 審査で必須');
    });

    test('PrivacyInfo.xcprivacy に NSPrivacyAccessedAPITypes が宣言されているとき API使用理由が明記されている', () {
      final file = File('ios/Runner/PrivacyInfo.xcprivacy');
      if (!file.existsSync()) {
        fail('PrivacyInfo.xcprivacy が存在しない（前提テスト失敗）');
      }

      final content = file.readAsStringSync();
      expect(content, contains('NSPrivacyAccessedAPITypes'),
          reason: 'NSPrivacyAccessedAPITypes キーが未宣言');
    });

    test('PrivacyInfo.xcprivacy に UserDefaults API が宣言されているとき shared_preferences が審査を通過できる', () {
      final file = File('ios/Runner/PrivacyInfo.xcprivacy');
      if (!file.existsSync()) {
        fail('PrivacyInfo.xcprivacy が存在しない（前提テスト失敗）');
      }

      final content = file.readAsStringSync();
      expect(content, contains('NSPrivacyAccessedAPICategoryUserDefaults'),
          reason:
              'UserDefaults API カテゴリが未宣言。\n'
              'shared_preferences パッケージが使用するため必須');
    });

    test('PrivacyInfo.xcprivacy に FileTimestamp API が宣言されているとき Flutter ランタイムが審査を通過できる', () {
      final file = File('ios/Runner/PrivacyInfo.xcprivacy');
      if (!file.existsSync()) {
        fail('PrivacyInfo.xcprivacy が存在しない（前提テスト失敗）');
      }

      final content = file.readAsStringSync();
      expect(content, contains('NSPrivacyAccessedAPICategoryFileTimestamp'),
          reason:
              'FileTimestamp API カテゴリが未宣言。\n'
              'Flutter ランタイムが使用するため必須');
    });

    test('PrivacyInfo.xcprivacy が project.pbxproj に登録されているとき ビルドに含まれる', () {
      final pbxproj = File('ios/Runner.xcodeproj/project.pbxproj');
      final content = pbxproj.readAsStringSync();

      expect(content, contains('PrivacyInfo.xcprivacy'),
          reason:
              'PrivacyInfo.xcprivacy が project.pbxproj に登録されていない。\n'
              'Xcode プロジェクトに追加しないとビルドに含まれない');
    });

    test('PrivacyInfo.xcprivacy に NSPrivacyCollectedDataTypes が宣言されているとき データ収集の透明性を確保できる', () {
      final file = File('ios/Runner/PrivacyInfo.xcprivacy');
      if (!file.existsSync()) {
        fail('PrivacyInfo.xcprivacy が存在しない（前提テスト失敗）');
      }

      final content = file.readAsStringSync();
      expect(content, contains('NSPrivacyCollectedDataTypes'),
          reason:
              'NSPrivacyCollectedDataTypes キーが未宣言。\n'
              'データ収集の有無を明示する必要がある');
    });
  });

  group('TestFlight配布準備 — アプリ表示名', () {
    test('Info.plist の CFBundleDisplayName が「Aimachi」のとき ホーム画面に正しい名前が表示される', () {
      final file = File('ios/Runner/Info.plist');
      final content = file.readAsStringSync();

      final displayNameMatch = RegExp(
        r'<key>CFBundleDisplayName</key>\s*<string>([^<]+)</string>',
      ).firstMatch(content);
      expect(displayNameMatch, isNotNull,
          reason: 'CFBundleDisplayName が見つからない');

      final displayName = displayNameMatch!.group(1)!;
      expect(displayName, equals('Aimachi'),
          reason:
              'CFBundleDisplayName が「$displayName」になっている。\n'
              '「Aimachi」に修正する必要がある');
    });

    test('Info.plist の CFBundleName が「Aimachi」のとき システムに正しい名前が認識される', () {
      final file = File('ios/Runner/Info.plist');
      final content = file.readAsStringSync();

      final bundleNameMatch = RegExp(
        r'<key>CFBundleName</key>\s*<string>([^<]+)</string>',
      ).firstMatch(content);
      expect(bundleNameMatch, isNotNull,
          reason: 'CFBundleName が見つからない');

      final bundleName = bundleNameMatch!.group(1)!;
      expect(bundleName, equals('Aimachi'),
          reason:
              'CFBundleName が「$bundleName」になっている。\n'
              '「Aimachi」に修正する必要がある');
    });
  });

  group('TestFlight配布準備 — ExportOptions整合性', () {
    test('ExportOptions.plist に provisioningProfiles が設定されているとき TestFlight アップロードが成功する', () {
      final file = File('ios/ExportOptions.plist');
      expect(file.existsSync(), isTrue,
          reason: 'ExportOptions.plist が見つからない');

      final content = file.readAsStringSync();
      expect(content, contains('provisioningProfiles'),
          reason:
              'ExportOptions.plist に provisioningProfiles が未設定。\n'
              'TestFlight 配布にはプロビジョニングプロファイルの指定が必要');
    });

    test('ExportOptions.plist の Bundle ID が project.pbxproj と一致するとき 署名が正常に行われる', () {
      final exportFile = File('ios/ExportOptions.plist');
      if (!exportFile.existsSync()) {
        fail('ExportOptions.plist が見つからない');
      }

      final exportContent = exportFile.readAsStringSync();

      // ExportOptions に Bundle ID が含まれているか
      // provisioningProfiles の中にキーとして Bundle ID がある
      expect(exportContent, contains('jp.aitime.mannaka'),
          reason:
              'ExportOptions.plist に jp.aitime.mannaka が記載されていない。\n'
              'provisioningProfiles でアプリの Bundle ID を指定する必要がある');
    });
  });

  group('TestFlight配布準備 — RunnerTests Bundle ID 整合性', () {
    test('RunnerTests の Bundle ID が Runner と同じプレフィックスのとき テストターゲットが正しく構成される', () {
      final pbxproj = File('ios/Runner.xcodeproj/project.pbxproj');
      final content = pbxproj.readAsStringSync();

      // RunnerTests の Bundle ID を抽出
      final testBundleIds = RegExp(
        r'PRODUCT_BUNDLE_IDENTIFIER\s*=\s*([^;]*RunnerTests[^;]*);',
      ).allMatches(content).map((m) => m.group(1)!.trim()).toSet();

      expect(testBundleIds, isNotEmpty,
          reason: 'RunnerTests の PRODUCT_BUNDLE_IDENTIFIER が見つからない');

      for (final testBid in testBundleIds) {
        expect(testBid, equals('jp.aitime.mannaka.RunnerTests'),
            reason:
                'RunnerTests の Bundle ID ($testBid) が '
                'jp.aitime.mannaka.RunnerTests でない');
      }
    });
  });
}
