// TDD Red→Green フェーズ（Cycle 6）
// policy_screen.dart プライバシーポリシー第2条本文の静的回帰テスト
//
// 背景:
//   Cycle 1（2026-04-21）で policy_screen.dart 第2条に
//   法令整合の根幹条項を追加した:
//     - 分析機能が「デフォルトで有効（ON）」であること
//     - 「マイページの『利用統計の提供』」からいつでも無効化（オプトアウト）可能
//     - 氏名・メール等の個人識別情報は送信せず匿名IDのみ
//     - 新規収集対象の 9 コレクション名（restaurant_clicks / category_demand /
//       reservation_leads / reservation_logs / share_logs / filter_logs /
//       sort_logs / decided_restaurants / decision_logs）
//   これらは個人情報保護法・App Store 審査の整合性を保つ根幹のため、
//   将来のリファクタ・文言圧縮で欠落すると法令違反／審査リジェクトに直結する。
//
//   既存の analytics_consent_consistency_test.dart は「閲覧/クリック」等の
//   概念レベルのキーワードのみチェックしており、具体的なコレクション名や
//   オプトアウト導線の文言までは守っていない。本テストはその不足を埋める。
//
// スコープ:
//   - 対象: PrivacyPolicyScreen の第2条本文のみ
//   - 非対象: TermsScreen・他条項・実装コード（analytics_service.dart 等）
//   - 形式: 静的ソース解析（File 読み込み）— 他の policy_screen_*_test と同じ方式
//
// 受け入れ条件:
//   AC1. 第2条に 9 コレクション名すべてが記載されていること
//        （restaurant_clicks / category_demand / reservation_leads /
//          reservation_logs / share_logs / filter_logs / sort_logs /
//          decided_restaurants / decision_logs）
//   AC2. 「デフォルトで有効（ON）」の明示があること
//   AC3. 「オプトアウト」の明示があること
//   AC4. オプトアウト導線として「お問い合わせ窓口」への連絡が明示されていること
//        （UI トグル方式は v1.0.3+7 で削除済。email 問い合わせ経由のオプトアウトに切替）
//   AC5. 「氏名・メール等の個人識別情報は送信せず」の明示があること
//   AC6. 「匿名ID」の明示があること
//   AC7. 収集先として「Firebase（Google LLC）」が明示されていること
//
// Red 状態の定義:
//   本サイクル着手時点では「回帰テスト未整備＝保護ゼロ」の状態。
//   テスト追加により上記 AC1〜AC7 が常時検証され Green 状態になる。
//   既存コードは Cycle 1 Green 時点で AC を満たしているため、
//   Engineer の Green 実装作業は不要（テスト追加のみで完結）。
//
// Engineer への引き継ぎ:
//   本テストはソース変更なしでパスするはず。
//   もし失敗した場合は Cycle 1 の成果物が欠落している可能性があるため
//   lib/screens/policy_screen.dart 第2条本文を確認すること。

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

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

/// PrivacyPolicyScreen の第2条本文のみを抽出する。
/// TermsScreen や他条項の誤検出を避けるため、
/// 「第2条（収集する情報および利用目的）」開始から次の `_PolicySection` 直前までを取得。
String _extractArticle2Body(String source) {
  const startMarker = "title: '第2条（収集する情報および利用目的）'";
  final startIdx = source.indexOf(startMarker);
  if (startIdx < 0) {
    fail(
      'PrivacyPolicyScreen の第2条セクションが見つかりません。\n'
      '構造が変わった場合は本テストの抽出ロジックを更新してください。',
    );
  }
  // 次の _PolicySection( の出現位置までを第2条のブロックとみなす
  final tail = source.substring(startIdx);
  final nextSectionIdx = tail.indexOf('_PolicySection(', 1);
  final article2 =
      nextSectionIdx < 0 ? tail : tail.substring(0, nextSectionIdx);
  return article2;
}

void main() {
  // ══════════════════════════════════════════════════════════════
  // [1] 9 コレクション名の網羅（AC1）
  // ══════════════════════════════════════════════════════════════

  group('policy_screen — 第2条 コレクション名の網羅（回帰防止）', () {
    // Cycle 1 で追記された分析コレクション名の列挙
    // 将来追加する場合はここに追記する
    const requiredCollections = <String>[
      'restaurant_clicks',
      'category_demand',
      'reservation_leads',
      'reservation_logs',
      'share_logs',
      'filter_logs',
      'sort_logs',
      'decided_restaurants',
      'decision_logs',
    ];

    for (final name in requiredCollections) {
      test('第2条に「$name」コレクション名が記載されているとき実装と整合する', () {
        final article2 = _extractArticle2Body(_readPolicySource());
        expect(
          article2.contains(name),
          isTrue,
          reason: 'プライバシーポリシー第2条に「$name」が記載されていません。\n'
              '実装（analytics_service.dart）では Firestore へ書き込まれているため、\n'
              'ポリシーに明記しないと個人情報保護法・App Store 審査違反となります。\n'
              'Cycle 1 で追記された収集内容リストに $name を復元してください。',
        );
      });
    }

    test('第2条に 9 コレクション名すべてが同時に存在するとき網羅性が担保される', () {
      final article2 = _extractArticle2Body(_readPolicySource());
      final missing = <String>[];
      for (final name in requiredCollections) {
        if (!article2.contains(name)) missing.add(name);
      }
      expect(
        missing,
        isEmpty,
        reason: '第2条に下記のコレクション名が欠落しています:\n'
            '${missing.map((e) => '  - $e').join('\n')}\n'
            'Cycle 1 で追加した「収集内容」リストから欠落している可能性があります。',
      );
    });
  });

  // ══════════════════════════════════════════════════════════════
  // [2] デフォルト ON とオプトアウトの明示（AC2・AC3・AC4）
  // ══════════════════════════════════════════════════════════════

  group('policy_screen — 第2条 デフォルトON/オプトアウト表記（回帰防止）', () {
    test('第2条に「デフォルトで有効（ON）」が明示されているとき実挙動と整合する', () {
      final article2 = _extractArticle2Body(_readPolicySource());
      expect(
        article2.contains('デフォルトで有効（ON）'),
        isTrue,
        reason: '第2条に「デフォルトで有効（ON）」の明示がありません。\n'
            'AnalyticsService.isOptedIn() のデフォルトは true のため、\n'
            'ポリシーも「デフォルト有効」を明示しないと実挙動と矛盾します。\n'
            'Cycle 1 で追加した文言「本機能はデフォルトで有効（ON）ですが…」を復元してください。',
      );
    });

    test('第2条に「オプトアウト」の明示があるときユーザーが停止方法を認識できる', () {
      final article2 = _extractArticle2Body(_readPolicySource());
      expect(
        article2.contains('オプトアウト'),
        isTrue,
        reason: '第2条に「オプトアウト」の明示がありません。\n'
            'デフォルトONの実挙動に対して、停止手段を明記しないと\n'
            '個人情報保護法・GDPR の透明性要件を満たせません。\n'
            '「いつでも無効化（オプトアウト）できます」の文言を復元してください。',
      );
    });

    test('第2条にオプトアウト導線として「お問い合わせ窓口」への連絡が明示されているとき'
        'ユーザーが迷わず停止手段にたどり着ける', () {
      final article2 = _extractArticle2Body(_readPolicySource());
      // v1.0.3+7 で UI トグル方式を撤去し email 問い合わせ方式に切替済。
      // ここでは「お問い合わせ窓口」の文言と「第8条」への参照を両方検証する。
      expect(
        article2.contains('お問い合わせ窓口'),
        isTrue,
        reason: '第2条にオプトアウト導線（お問い合わせ窓口）が明示されていません。\n'
            'UI トグル撤去後はメール問い合わせ経由で停止できることを明記しないと\n'
            '法的なオプトアウト権利を満たせません。',
      );
      expect(
        article2.contains('第8条'),
        isTrue,
        reason: '第2条のオプトアウト記述は第8条（お問い合わせ）を参照していません。\n'
            'メールアドレスを第8条に集約しているため、参照リンクが必要です。',
      );
    });
  });

  // ══════════════════════════════════════════════════════════════
  // [3] 匿名性の明示（AC5・AC6）
  // ══════════════════════════════════════════════════════════════

  group('policy_screen — 第2条 匿名性表記（回帰防止）', () {
    test('第2条に「氏名・メール等の個人識別情報は送信せず」が明示されているとき'
        '個人情報保護法の透明性要件を満たす', () {
      final article2 = _extractArticle2Body(_readPolicySource());
      expect(
        article2.contains('氏名・メール等の個人識別情報は送信せず'),
        isTrue,
        reason: '第2条に「氏名・メール等の個人識別情報は送信せず」の明示がありません。\n'
            'ユーザーが何が送信/非送信かを判断できる情報として必須です。\n'
            'Cycle 1 で追加した文言を復元してください。',
      );
    });

    test('第2条に「匿名ID」が明示されているとき識別情報非送信が具体的に伝わる', () {
      final article2 = _extractArticle2Body(_readPolicySource());
      expect(
        article2.contains('匿名ID'),
        isTrue,
        reason: '第2条に「匿名ID」の明示がありません。\n'
            '「匿名IDと紐づく統計のみを収集」という表現で、\n'
            '個人識別情報を扱わないことを具体的に示す必要があります。',
      );
    });
  });

  // ══════════════════════════════════════════════════════════════
  // [4] 送信先の明示（AC7）
  // ══════════════════════════════════════════════════════════════

  group('policy_screen — 第2条 送信先表記（回帰防止）', () {
    test('第2条の匿名統計ブロックに「Firebase（Google LLC）」が明示されているとき'
        '第三者提供先が明確になる', () {
      final article2 = _extractArticle2Body(_readPolicySource());
      // 匿名統計ブロック内の保存場所表記を検出
      // （クラッシュレポートにも同表記があるが、両方残っていれば OK）
      expect(
        article2.contains('Firebase（Google LLC）'),
        isTrue,
        reason: '第2条に「Firebase（Google LLC）」の保存場所明示がありません。\n'
            '第三者提供先を明記しないと個人情報保護法 27 条違反になります。\n'
            '匿名統計の「保存場所：Firebase（Google LLC）のサーバー」を復元してください。',
      );
    });
  });
}
