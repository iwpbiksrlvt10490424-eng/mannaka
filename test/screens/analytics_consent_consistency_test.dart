// TDD Red フェーズ
// 分析データ収集のオプトイン整合性確保テスト
//
// 背景:
//   コミット 0205314 で AnalyticsService.isOptedIn() のデフォルトが true に変更され
//   11種類の分析コレクション（station_counts / station_demand / search_logs /
//   restaurant_clicks / category_demand / reservation_leads / reservation_logs /
//   share_logs / filter_logs / sort_logs / decided_restaurants / decision_logs）
//   への書き込みが有効化された。一方で
//     ① 設定画面にオプトアウトUIが存在しない
//     ② プライバシーポリシー第2条は「オプトイン」と記載しており実挙動（デフォルトON）と矛盾
//     ③ 新規収集項目（クリック/予約タップ/シェア/フィルタ/ソート/決定ログ）がポリシー未記載
//   の3つのリリースブロッカー級の不整合がある。
//
// 受け入れ条件:
//   1. settings_screen.dart に分析データ提供のオプトアウトUIが存在する
//      （AnalyticsService.setOptIn が呼ばれるトグル/スイッチがある）
//   2. プライバシーポリシー第2条に下記の新規収集項目の説明が含まれている
//      - レストランの閲覧/クリック
//      - 予約ボタン押下（送客指標）
//      - シェア動作
//      - フィルター使用
//      - ソート使用
//      - 店舗決定（コンバージョン）
//   3. プライバシーポリシーの分析データ説明が実挙動（デフォルト有効／設定から無効化可能）
//      と整合する表現になっている（「オプトイン（同意した場合のみ）」という表現は
//      デフォルトfalseに変更するか、「デフォルト有効／マイページから無効化可能」等に改める）
//   4. AnalyticsService のクラスコメントが実挙動と一致している
//
// Engineer への実装依頼:
//   A. settings_screen.dart の「アプリ設定」または新規セクションに
//      利用統計提供のオン/オフ切り替えUIを追加する。ON/OFF 切替時に
//      AnalyticsService.setOptIn(value) を呼ぶこと。
//   B. policy_screen.dart 第2条の分析データに関する説明を更新し、
//      新規6コレクションの利用目的を記載し、デフォルトがONであること
//      （または逆にデフォルトfalseに戻してオプトインを維持すること）を
//      明示する。
//   C. analytics_service.dart のクラスコメント「データ提供はユーザーのオプトイン制」
//      を実挙動に合わせて更新する（デフォルトtrueのままならば「デフォルト有効、
//      マイページからオプトアウト可能」等）。

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String _readFile(String path) {
  final file = File(path);
  if (!file.existsSync()) {
    fail(
      '$path が存在しません。\n'
      'ファイルパスが正しいか確認してください。\n'
      '（ファイル非存在のまま PASS させると偽グリーンになります）',
    );
  }
  return file.readAsStringSync();
}

void main() {
  // ══════════════════════════════════════════════════════════════
  // [1] 設定画面のオプトアウトUI
  // ══════════════════════════════════════════════════════════════

  group('settings_screen — 分析データ提供のオプトアウトUI', () {
    test('設定画面から AnalyticsService.setOptIn を呼ぶ導線があるとき'
        ' ユーザーがオプトアウトできる', () {
      final content = _readFile('lib/screens/settings_screen.dart');

      final importsAnalytics = RegExp(
        r'''import\s+['"][^'"]*analytics_service\.dart['"]''',
      ).hasMatch(content);
      final callsSetOptIn = content.contains('AnalyticsService.setOptIn');

      expect(
        importsAnalytics,
        isTrue,
        reason: 'settings_screen.dart が analytics_service.dart を import していません。\n'
            '「利用統計を提供する」等のトグルを追加して AnalyticsService.setOptIn を呼んでください。',
      );
      expect(
        callsSetOptIn,
        isTrue,
        reason: 'settings_screen.dart から AnalyticsService.setOptIn が呼ばれていません。\n'
            'マイページ > アプリ設定 等に利用統計提供の ON/OFF トグルを追加し、\n'
            'onChanged で AnalyticsService.setOptIn(value) を呼んでください。',
      );
    });

    test('設定画面に「利用統計」「データ提供」等のユーザー向け説明が存在するとき'
        ' ユーザーが何を ON/OFF しているか理解できる', () {
      final content = _readFile('lib/screens/settings_screen.dart');

      final hasUserFacingLabel = RegExp(
        r'(利用統計|分析データ|データ提供|統計データ|利用データ|匿名データ)',
      ).hasMatch(content);

      expect(
        hasUserFacingLabel,
        isTrue,
        reason: '設定画面にユーザー向けのラベル（例: 「利用統計を提供する」「匿名データの提供」）'
            'が見つかりません。\nトグルが何を切り替えるのかユーザーに分かる文言を添えてください。',
      );
    });

    test('設定画面にトグル/スイッチ相当のウィジェットが導入されているとき'
        'オン/オフの切り替え操作ができる', () {
      final content = _readFile('lib/screens/settings_screen.dart');

      // Switch / SwitchListTile / CupertinoSwitch のいずれかが追加されていること
      final hasSwitch = RegExp(
        r'\b(Switch|SwitchListTile|CupertinoSwitch)\b',
      ).hasMatch(content);

      expect(
        hasSwitch,
        isTrue,
        reason: '設定画面に Switch / SwitchListTile / CupertinoSwitch が見つかりません。\n'
            'オプトアウト用の切り替えUIを追加してください。',
      );
    });
  });

  // ══════════════════════════════════════════════════════════════
  // [2] プライバシーポリシーの新規収集項目カバレッジ
  // ══════════════════════════════════════════════════════════════

  group('policy_screen — 分析データ収集項目のカバレッジ', () {
    test('第2条に新規6種の収集項目（クリック/予約/シェア/フィルタ/ソート/決定）の'
        '利用目的が記載されているとき個人情報保護法・App Store審査に準拠する', () {
      final content = _readFile('lib/screens/policy_screen.dart');

      // 新規コレクション 6種のキーワードそれぞれがポリシー本文に出現するか確認
      final missing = <String>[];

      // restaurant_clicks / category_demand
      final hasClick = RegExp(r'(閲覧|クリック|タップ履歴|閲覧履歴)')
          .hasMatch(content);
      if (!hasClick) {
        missing.add('レストラン閲覧/クリックログ（restaurant_clicks / category_demand）');
      }

      // reservation_leads / reservation_logs
      final hasReservation = RegExp(r'(予約ボタン|予約操作|予約タップ|送客)')
          .hasMatch(content);
      if (!hasReservation) {
        missing.add('予約ボタン押下ログ（reservation_leads / reservation_logs）');
      }

      // share_logs
      final hasShare = RegExp(r'(シェア操作|共有操作|シェア履歴|シェアログ)')
          .hasMatch(content);
      if (!hasShare) {
        missing.add('シェアログ（share_logs）');
      }

      // filter_logs
      final hasFilter = RegExp(r'(フィルタ|絞り込み)').hasMatch(content);
      if (!hasFilter) {
        missing.add('フィルター使用ログ（filter_logs）');
      }

      // sort_logs
      final hasSort = RegExp(r'(並び替え|ソート)').hasMatch(content);
      if (!hasSort) {
        missing.add('ソート使用ログ（sort_logs）');
      }

      // decided_restaurants / decision_logs
      final hasDecision = RegExp(r'(決定|選択結果|コンバージョン|最終選択)')
          .hasMatch(content);
      if (!hasDecision) {
        missing.add('店舗決定ログ（decided_restaurants / decision_logs）');
      }

      expect(
        missing,
        isEmpty,
        reason: 'プライバシーポリシー第2条に以下の収集項目の説明が記載されていません:\n'
            '${missing.map((e) => '  - $e').join('\n')}\n\n'
            '実装（analytics_service.dart）では既に Firestore に送信されているため、\n'
            '個人情報保護法・GDPR・App Store 審査ガイドラインに違反する可能性があります。\n'
            '第2条「収集する情報および利用目的」に追記してください。',
      );
    });

    test('プライバシーポリシーの分析データ説明が実挙動（デフォルトON）と整合するとき'
        'ユーザーを誤認させない', () {
      final policyContent = _readFile('lib/screens/policy_screen.dart');
      final analyticsContent = _readFile('lib/services/analytics_service.dart');

      // 実挙動: isOptedIn() のデフォルト値を抽出
      // `return prefs.getBool(_optInKey) ?? true;`  → デフォルト ON
      // `return prefs.getBool(_optInKey) ?? false;` → デフォルト OFF
      final defaultTrueMatch = RegExp(
        r'getBool\(\s*_optInKey\s*\)\s*\?\?\s*true',
      ).hasMatch(analyticsContent);
      final defaultFalseMatch = RegExp(
        r'getBool\(\s*_optInKey\s*\)\s*\?\?\s*false',
      ).hasMatch(analyticsContent);

      // ポリシー側で「オプトイン制で同意した場合のみ」という表現があるか
      final policySaysStrictOptIn = RegExp(
        r'(オプトイン制|同意した場合のみ|明示的に同意)',
      ).hasMatch(policyContent);

      // ポリシー側で「デフォルト有効／オプトアウト可能」という表現があるか
      final policySaysDefaultOn = RegExp(
        r'(デフォルト(で)?(有効|ON|オン)|'
        r'初期(設定|状態)(は|で)?(有効|ON|オン)|'
        r'(マイページ|設定|プロフィール|設定画面).*(から|で)(無効|オフ|OFF|オプトアウト|停止)|'
        r'(オプトアウト|無効化|オフ)(可能|できます))',
      ).hasMatch(policyContent);

      if (defaultTrueMatch) {
        // 実挙動がデフォルトON → ポリシーは「デフォルト有効、オフ可能」を明記すべき
        expect(
          policySaysDefaultOn,
          isTrue,
          reason: 'AnalyticsService.isOptedIn() はデフォルト true（= 同意なしで有効）ですが、\n'
              'プライバシーポリシーは「デフォルトON／無効化可能」を明記していません。\n'
              '実挙動と文言が矛盾しているのでユーザー/審査員を誤認させます。\n'
              '解決策:\n'
              '  a. ポリシー第2条に「統計提供はデフォルト有効。マイページから無効化可能」と明記\n'
              '  b. または analytics_service.dart の default を false に戻す',
        );
        expect(
          policySaysStrictOptIn,
          isFalse,
          reason: 'ポリシーに「オプトイン制／同意した場合のみ」等の表現が残っています。\n'
              '実挙動（デフォルトON）と矛盾しているので、表現を修正してください。',
        );
      } else if (defaultFalseMatch) {
        // 実挙動がオプトイン（デフォルトfalse）→ ポリシーもオプトイン表現でOK
        expect(
          policySaysStrictOptIn,
          isTrue,
          reason: 'AnalyticsService.isOptedIn() はデフォルト false ですが、\n'
              'ポリシーに「オプトイン制／同意した場合のみ」等の表現がありません。',
        );
      } else {
        fail(
          'analytics_service.dart の isOptedIn() デフォルト値を判定できませんでした。\n'
          '`getBool(_optInKey) ?? true/false` の形式にしてください。',
        );
      }
    });
  });

  // ══════════════════════════════════════════════════════════════
  // [3] AnalyticsService のコメントと実挙動の整合性
  // ══════════════════════════════════════════════════════════════

  group('analytics_service — クラスコメントと実挙動の整合', () {
    test('analytics_service.dart のクラスコメントが実挙動（デフォルトON/OFF）と一致するとき'
        '開発者を誤認させない', () {
      final content = _readFile('lib/services/analytics_service.dart');

      final defaultTrue = RegExp(
        r'getBool\(\s*_optInKey\s*\)\s*\?\?\s*true',
      ).hasMatch(content);
      final defaultFalse = RegExp(
        r'getBool\(\s*_optInKey\s*\)\s*\?\?\s*false',
      ).hasMatch(content);

      // トップレベル "/// データ提供はユーザーのオプトイン制"（= 明示的同意が前提）
      // というコメントが残っていないこと（実挙動がデフォルトtrueの場合）
      final hasStrictOptInComment = RegExp(
        r'///.*オプトイン制',
      ).hasMatch(content);

      if (defaultTrue) {
        expect(
          hasStrictOptInComment,
          isFalse,
          reason: 'クラスコメントに「オプトイン制」と書かれているのに、\n'
              'isOptedIn() のデフォルトは true（= 同意なしで収集）になっています。\n'
              'コメントを「デフォルト有効（オプトアウト可能）」等に修正するか、\n'
              'デフォルトを false に戻してください。',
        );
      } else if (defaultFalse) {
        expect(
          hasStrictOptInComment,
          isTrue,
          reason: 'isOptedIn() のデフォルトは false ですが、クラスコメントに\n'
              '「オプトイン制」と明記されていません。',
        );
      }
    });
  });
}
