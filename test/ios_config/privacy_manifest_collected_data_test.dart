import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// PrivacyInfo.xcprivacy 位置情報収集宣言 + プライバシーポリシー外部API記載
/// TDD Red フェーズ
///
/// 受け入れ条件:
///   1. NSPrivacyCollectedDataTypes に位置情報データ型が宣言されている
///   2. 位置情報の収集目的（AppFunctionality）が明記されている
///   3. 位置情報がユーザーIDに紐付かない（Linked = false）と宣言されている
///   4. 位置情報がトラッキングに使用されない（Tracking = false）と宣言されている
///   5. プライバシーポリシーに Foursquare API が記載されている
///   6. プライバシーポリシーに Overpass API が記載されている
///
/// Engineer への実装依頼:
///   1. ios/Runner/PrivacyInfo.xcprivacy の NSPrivacyCollectedDataTypes に
///      位置情報（PreciseLocation）エントリを追加
///   2. lib/screens/policy_screen.dart 第3条に Foursquare / Overpass を追加

/// PrivacyInfo.xcprivacy のソースを読み込む
String _readPrivacyManifest() {
  final file = File('ios/Runner/PrivacyInfo.xcprivacy');
  if (!file.existsSync()) {
    fail(
      'ios/Runner/PrivacyInfo.xcprivacy が存在しません。\n'
      'ファイルパスが正しいか確認してください。',
    );
  }
  return file.readAsStringSync();
}

/// policy_screen.dart のソースを読み込む
String _readPolicySource() {
  final file = File('lib/screens/policy_screen.dart');
  if (!file.existsSync()) {
    fail(
      'lib/screens/policy_screen.dart が存在しません。\n'
      'ファイルパスが正しいか確認してください。',
    );
  }
  return file.readAsStringSync();
}

void main() {
  // ══════════════════════════════════════════════════════════════
  // [1] NSPrivacyCollectedDataTypes — 位置情報収集の宣言
  // ══════════════════════════════════════════════════════════════

  group('PrivacyInfo.xcprivacy — 位置情報収集宣言', () {
    test('NSPrivacyCollectedDataTypes が空でないとき 位置情報収集が宣言されている', () {
      final content = _readPrivacyManifest();

      // 現状: <key>NSPrivacyCollectedDataTypes</key>\n\t<array/>
      // 期待: <array> に少なくとも1つの <dict> エントリがある
      final emptyArrayPattern = RegExp(
        r'<key>NSPrivacyCollectedDataTypes</key>\s*<array\s*/>',
      );
      expect(
        emptyArrayPattern.hasMatch(content),
        isFalse,
        reason:
            'NSPrivacyCollectedDataTypes が空の配列（<array/>）のままです。\n'
            '位置情報を外部API（Hotpepper/Foursquare/Overpass）に送信しているため、\n'
            'データ収集を宣言する必要があります。',
      );
    });

    test('NSPrivacyCollectedDataTypes に PreciseLocation が宣言されているとき GPS位置情報の収集が明示されている',
        () {
      final content = _readPrivacyManifest();

      expect(
        content,
        contains('NSPrivacyCollectedDataTypePreciseLocation'),
        reason:
            'NSPrivacyCollectedDataTypePreciseLocation が未宣言です。\n'
            'アプリは Geolocator で GPS 位置情報を取得し、\n'
            '外部APIに緯度経度を送信しているため宣言が必須です。',
      );
    });

    test('位置情報の収集目的に AppFunctionality が含まれているとき 利用目的が正しく宣言されている', () {
      final content = _readPrivacyManifest();

      // NSPrivacyCollectedDataTypePurposes の中に
      // NSPrivacyCollectedDataTypePurposeAppFunctionality が必要
      expect(
        content,
        contains('NSPrivacyCollectedDataTypePurposeAppFunctionality'),
        reason:
            'NSPrivacyCollectedDataTypePurposeAppFunctionality が未宣言です。\n'
            '位置情報はアプリの主要機能（集合場所提案）に使用するため、\n'
            'AppFunctionality 目的の宣言が必要です。',
      );
    });

    test('位置情報が NSPrivacyCollectedDataTypeLinked = false のとき ユーザーIDに紐付かないことが明示されている',
        () {
      final content = _readPrivacyManifest();

      // NSPrivacyCollectedDataTypeLinked の値が false であることを確認
      // plist 形式: <key>NSPrivacyCollectedDataTypeLinked</key>\n<false/>
      final linkedPattern = RegExp(
        r'<key>NSPrivacyCollectedDataTypeLinked</key>\s*<false\s*/>',
      );
      expect(
        linkedPattern.hasMatch(content),
        isTrue,
        reason:
            'NSPrivacyCollectedDataTypeLinked が <false/> で宣言されていません。\n'
            'アプリは会員登録不要のため、位置情報はユーザーIDに紐付きません。\n'
            '<false/> を設定してください。',
      );
    });

    test('位置情報が NSPrivacyCollectedDataTypeTracking = false のとき トラッキング不使用が明示されている',
        () {
      final content = _readPrivacyManifest();

      // NSPrivacyCollectedDataTypeTracking の値が false であることを確認
      final trackingPattern = RegExp(
        r'<key>NSPrivacyCollectedDataTypeTracking</key>\s*<false\s*/>',
      );
      expect(
        trackingPattern.hasMatch(content),
        isTrue,
        reason:
            'NSPrivacyCollectedDataTypeTracking が <false/> で宣言されていません。\n'
            'NSPrivacyTracking が false のため、Tracking も false にする必要があります。',
      );
    });
  });

  // ══════════════════════════════════════════════════════════════
  // [2] プライバシーポリシー — 外部API記載
  // ══════════════════════════════════════════════════════════════

  group('プライバシーポリシー — 外部API記載', () {
    test('第3条に Foursquare API が記載されているとき 外部サービスの透明性が確保されている', () {
      final content = _readPolicySource();

      // Foursquare への情報提供が第3条に記載されていること
      expect(
        content,
        contains('Foursquare'),
        reason:
            'プライバシーポリシー第3条に Foursquare API が記載されていません。\n'
            'アプリは Foursquare Places API に緯度経度を送信して\n'
            '周辺レストラン情報を取得しているため、記載が必要です。',
      );
    });

    test('第3条に Foursquare への提供情報（緯度・経度）が明記されているとき 送信データが開示されている', () {
      final content = _readPolicySource();

      // Foursquare セクションに緯度・経度の記載があること
      final hasFoursquare = content.contains('Foursquare');
      if (!hasFoursquare) {
        fail('Foursquare の記載自体がないため、提供情報の検証ができません');
      }

      // 「緯度」「経度」または「位置情報」の記載を確認
      // Foursquare の前後で提供情報として位置データに言及しているか
      final foursquareSection = RegExp(
        r'Foursquare.*?(緯度|経度|位置情報|検索条件)',
        dotAll: true,
      );
      expect(
        foursquareSection.hasMatch(content),
        isTrue,
        reason:
            'Foursquare API への提供情報（緯度・経度等）が明記されていません。\n'
            '第3条の Hotpepper と同様の形式で、送信データを開示してください。',
      );
    });

    test('第3条に Overpass API が記載されているとき 外部サービスの透明性が確保されている', () {
      final content = _readPolicySource();

      expect(
        content,
        contains('Overpass'),
        reason:
            'プライバシーポリシー第3条に Overpass API が記載されていません。\n'
            'アプリは Overpass API に緯度経度を送信して\n'
            '周辺施設情報を取得しているため、記載が必要です。',
      );
    });

    test('第3条に Overpass への提供情報（緯度・経度）が明記されているとき 送信データが開示されている', () {
      final content = _readPolicySource();

      final hasOverpass = content.contains('Overpass');
      if (!hasOverpass) {
        fail('Overpass の記載自体がないため、提供情報の検証ができません');
      }

      final overpassSection = RegExp(
        r'Overpass.*?(緯度|経度|位置情報|検索条件)',
        dotAll: true,
      );
      expect(
        overpassSection.hasMatch(content),
        isTrue,
        reason:
            'Overpass API への提供情報（緯度・経度等）が明記されていません。\n'
            '第3条の Hotpepper と同様の形式で、送信データを開示してください。',
      );
    });

    test('第4条の「位置情報は端末内でのみ処理し、外部サーバーへ送信しません」が修正されているとき 矛盾が解消されている',
        () {
      final content = _readPolicySource();

      // 現状の第4条に「位置情報は端末内でのみ処理し、外部サーバーへ送信しません」と
      // 書かれているが、実際には Hotpepper/Foursquare/Overpass に緯度経度を送信している。
      // 第3条で外部APIへの送信を開示する以上、第4条の記述と矛盾する。
      // 「駅座標（最寄り駅の緯度経度）を検索目的で外部APIに送信します」等に修正すべき。
      expect(
        content.contains('位置情報は端末内でのみ処理し、外部サーバーへ送信しません'),
        isFalse,
        reason:
            '第4条に「位置情報は端末内でのみ処理し、外部サーバーへ送信しません」が残っています。\n'
            '実際には Hotpepper/Foursquare/Overpass に駅座標（緯度経度）を送信しているため、\n'
            'この記述はユーザーに誤解を与えます。\n'
            '「GPS位置情報は最寄り駅の座標に変換してから外部APIに送信します」等に修正してください。',
      );
    });
  });
}
