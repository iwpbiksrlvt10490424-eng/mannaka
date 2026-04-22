// TDD Red フェーズ
// Cycle 11 → 12 → 13: lib/ 全域 `Aimachi` リテラル → `まんなか` ブランド統一の静的回帰テスト
//
// 背景:
//   CLAUDE.md Project Mission は本アプリ名を「まんなか」と明記している。
//   Cycle 11（2026-04-22 APPROVED）はユーザー露出面の大半を置換。
//   Cycle 12（2026-04-22 APPROVED）は `_patternAllowlist` 方式に進化させ、
//   `ranking_screen.dart:602` シェアカードフッター / `:410` #Aimachi ハッシュタグ /
//   `search_screen.dart:605` コメントを除去。
//
//   Cycle 13 は、Cycle 11/12 で「製品指標用語」として温存した以下 3 系統・6 箇所
//   を再評価の結果 legacy label と判定し、最終除去する:
//     - `Aimachi指数`      (ranking_screen L39 画面タイトル / L122 バナー見出し /
//                           L410 シェア text / L507 シェアカード見出し)
//     - `Aimachiユーザー`   (ranking_screen L98 説明文)
//     - `Aimachi全ユーザー` (ranking_screen L131 バナー本文)
//
// Cycle 13 本テストの変更:
//   [1] `_patternAllowlist` を空化（= `Aimachi` リテラルは許容パターン皆無）
//   [2] Group [3] の「Aimachi指数 / ユーザー / 全ユーザー 温存」2 テストを削除
//       （温存方針を廃止したため）
//   [3] Group [2] に ranking_screen.dart のミューテーション・ガード 3 件を追加
//       - `まんなか指数` が L39/L122/L410/L507 の 4 箇所で登場する
//       - `まんなかユーザー` が L98 で登場する
//       - `まんなか全ユーザー` が L131 で登場する
//       （空文字置換・半角/全角誤変換・カタカナ化などの取りこぼし検知）
//
// スコープ（PM 合意）:
//   [IN]  Cycle 13 で処理する legacy label 6 箇所
//         - `Aimachi指数` → `まんなか指数`        ×4
//         - `Aimachiユーザー` → `まんなかユーザー`   ×1
//         - `Aimachi全ユーザー` → `まんなか全ユーザー` ×1
//   [OUT] 内部クラス識別子 `AimachiApp`（app.dart / main.dart）
//         App Store URL スラッグ（`/app/aimachi/` — 小文字、変更不能）
//
// 本テストの責務:
//   [1] lib/ 配下で許可パターン以外の `Aimachi` リテラルが 0 件であること
//       （Cycle 13: `_patternAllowlist` 空化により、製品指標用語も違反扱い）
//   [2] 置換対象の各ファイルで `まんなか` / `まんなか指数` / `まんなかユーザー` /
//       `まんなか全ユーザー` が実際に登場していること
//       （空文字置換・大文字化などの誤置換を防ぐミューテーション・ガード）
//   [3] スコープ外の識別子（`AimachiApp`）が温存されていること

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const _libDir = 'lib';

/// 全体除外ファイル（Cycle 12: 空。ranking_screen はパターン許可方式へ移行）
const _excludedFiles = <String>{};

/// 行レベルの例外（該当行に Aimachi があっても違反扱いしない）
///
/// 値: その行がマッチすべき正規表現
final _lineAllowlist = <String, List<RegExp>>{
  // 内部クラス識別子（UI に露出しない）
  'lib/app.dart': [
    RegExp(r'class\s+AimachiApp\b'),
    RegExp(r'const\s+AimachiApp\s*\('),
  ],
  // main.dart から内部クラスを参照する箇所
  'lib/main.dart': [
    RegExp(r'\bAimachiApp\s*\('),
  ],
};

/// パターンレベル許可
///
/// Cycle 13: 空化。`Aimachi指数` / `Aimachiユーザー` / `Aimachi全ユーザー`
/// を legacy label と判定し、除去対象に移行。
/// マッチ部分を行から削除した後に残る `Aimachi` を違反として扱う。
final _patternAllowlist = <RegExp>[];

/// lib/ 配下の .dart ファイルを再帰的に列挙
List<File> _allLibDartFiles() {
  final dir = Directory(_libDir);
  if (!dir.existsSync()) {
    fail(
      '$_libDir/ が存在しません。\n'
      '（ディレクトリ非存在のまま PASS させると偽グリーンになります）',
    );
  }
  return dir
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('.dart'))
      .toList();
}

/// 行レベル例外にマッチするとき true
bool _isAllowedLine(String relativePath, String line) {
  final normalized = relativePath.replaceAll(r'\', '/');
  final allow = _lineAllowlist[normalized];
  if (allow == null) return false;
  return allow.any((re) => re.hasMatch(line));
}

/// パターン許可を適用した後の残存文字列を返す
String _stripAllowedPatterns(String line) {
  var stripped = line;
  for (final re in _patternAllowlist) {
    stripped = stripped.replaceAll(re, '');
  }
  return stripped;
}

String _readSource(String path) {
  final file = File(path);
  if (!file.existsSync()) {
    fail('$path が存在しません。');
  }
  return file.readAsStringSync();
}

List<String> _readLines(String path) {
  final file = File(path);
  if (!file.existsSync()) {
    fail('$path が存在しません。');
  }
  return file.readAsLinesSync();
}

void main() {
  // ══════════════════════════════════════════════════════════════
  // [1] lib/ 全域: ユーザー露出リテラルから `Aimachi` を排除
  // ══════════════════════════════════════════════════════════════

  group('lib/ 全域 — Aimachi リテラルの静的排除 (ブランド「まんなか」統一)', () {
    test('lib/ 配下の全 .dart で許可パターン以外の Aimachi が 0 件のとき UI/シェア/ポリシー/コメントの表記が統一される', () {
      final violations = <String>[];
      for (final file in _allLibDartFiles()) {
        final path = file.path.replaceAll(r'\', '/');
        if (_excludedFiles.contains(path)) continue;

        final lines = file.readAsLinesSync();
        for (int i = 0; i < lines.length; i++) {
          final line = lines[i];
          if (!line.contains('Aimachi')) continue;
          if (_isAllowedLine(path, line)) continue;
          final stripped = _stripAllowedPatterns(line);
          if (!stripped.contains('Aimachi')) continue;
          violations.add('$path:${i + 1}: ${line.trim()}');
        }
      }

      expect(
        violations,
        isEmpty,
        reason: 'lib/ 配下に `Aimachi` リテラルが残っています。\n'
            'CLAUDE.md Project Mission は本アプリ名を「まんなか」と明記。\n'
            'Cycle 13 で除去すべき legacy label 6 箇所:\n'
            '  - ranking_screen.dart:39  画面タイトル `Aimachi指数ランキング`\n'
            '  - ranking_screen.dart:98  説明文 `Aimachiユーザーが最もよく...`\n'
            '  - ranking_screen.dart:122 バナー見出し `「Aimachi指数」について`\n'
            '  - ranking_screen.dart:131 バナー本文 `...Aimachi全ユーザーの...`\n'
            '  - ranking_screen.dart:410 シェア text `Aimachi指数ランキング🏆`\n'
            '  - ranking_screen.dart:507 シェアカード見出し `Aimachi指数ランキング`\n'
            '\n'
            '違反箇所（${violations.length} 件）:\n'
            '${violations.map((l) => '  $l').join('\n')}\n'
            '\n'
            '唯一の許容（行レベル例外）:\n'
            '  - lib/app.dart の class 識別子 `AimachiApp`\n'
            '  - lib/main.dart の `AimachiApp()` 参照\n'
            '  - App Store URL スラッグ（小文字 `aimachi` のため本テスト対象外）\n',
      );
    });
  });

  // ══════════════════════════════════════════════════════════════
  // [2] 置換対象ファイルで「まんなか」が実在する（ミューテーション・ガード）
  // ══════════════════════════════════════════════════════════════
  //
  // 空文字置換・大文字化・AIMACHI 等の誤置換を検出する。
  // Engineer が `Aimachi` を単純削除するだけの手抜きを防ぐ。

  group('置換対象ファイル — `まんなか` 表記への置換が完了している', () {
    test('lib/app.dart の MaterialApp.title が「まんなか」のときタスクスイッチャー表示が統一される', () {
      final src = _readSource('lib/app.dart');
      expect(
        RegExp(r'''title:\s*['"]まんなか['"]''').hasMatch(src),
        isTrue,
        reason: 'lib/app.dart:15 の `title: \'Aimachi\'` を `title: \'まんなか\'` に。\n'
            '（iOS のタスクスイッチャーに表示されるアプリ名）',
      );
    });

    test('lib/screens/splash_screen.dart のロゴテキストが「まんなか」のとき起動画面が統一される', () {
      final src = _readSource('lib/screens/splash_screen.dart');
      expect(
        src.contains("'まんなか'"),
        isTrue,
        reason: 'splash_screen.dart:108 の `\'Aimachi\'` を `\'まんなか\'` に置換してください。',
      );
      expect(
        src.contains("'Aimachi'"),
        isFalse,
        reason: 'splash_screen.dart に `\'Aimachi\'` が残存しています。',
      );
    });

    test('lib/screens/home_screen.dart のヘッダーとバナー文言が「まんなか」のときホーム画面のブランド表記が統一される', () {
      final src = _readSource('lib/screens/home_screen.dart');
      // ヘッダー（L306）
      expect(
        src.contains("'まんなか'"),
        isTrue,
        reason: 'home_screen.dart:306 のヘッダーを `\'まんなか\'` に置換してください。',
      );
      // バナー文言（L1147）
      expect(
        src.contains('まんなか 厳選のお店情報をこの枠でお届けします'),
        isTrue,
        reason: 'home_screen.dart:1147 の `\'Aimachi 厳選のお店情報...\'` を\n'
            '`\'まんなか 厳選のお店情報...\'` に置換してください。',
      );
      expect(
        src.contains('Aimachi'),
        isFalse,
        reason: 'home_screen.dart に `Aimachi` が残存しています（コメントは存在しない想定）。',
      );
    });

    test('lib/screens/policy_screen.dart の見出しが「まんなか」のときプライバシーポリシー・利用規約の名称が統一される', () {
      final src = _readSource('lib/screens/policy_screen.dart');
      expect(
        src.contains('まんなか プライバシーポリシー'),
        isTrue,
        reason: 'policy_screen.dart:21 の見出しを `まんなか プライバシーポリシー` に。',
      );
      expect(
        src.contains('まんなか 利用規約'),
        isTrue,
        reason: 'policy_screen.dart:146 の見出しを `まんなか 利用規約` に。',
      );
      expect(
        src.contains('まんなか（以下「当アプリ」）'),
        isTrue,
        reason: 'policy_screen.dart:151 の利用規約本文を `まんなか（以下「当アプリ」）` に。',
      );
      expect(
        src.contains('Aimachi'),
        isFalse,
        reason: 'policy_screen.dart に `Aimachi` が残存しています。',
      );
    });

    test('lib/utils/share_utils.dart の 4 箇所が「まんなか」のときシェア文言のブランド表記が統一される', () {
      final src = _readSource('lib/utils/share_utils.dart');
      // L60: レストラン決定後シェア
      expect(
        src.contains('まんなかで見つけました'),
        isTrue,
        reason: 'share_utils.dart:60 を `まんなかで見つけました` に。',
      );
      // L91: 集合場所シェア
      expect(
        src.contains('まんなかでみんなの中間地点からお店を提案'),
        isTrue,
        reason: 'share_utils.dart:91 を `まんなかでみんなの中間地点からお店を提案` に。',
      );
      // L141: LINE シェア
      expect(
        src.contains('まんなかで決めました'),
        isTrue,
        reason: 'share_utils.dart:141 を `まんなかで決めました` に。',
      );
      // L156: Share.share subject
      expect(
        src.contains('まんなかでお店を見つけました'),
        isTrue,
        reason: 'share_utils.dart:156 の subject を `まんなかでお店を見つけました` に。',
      );
      // 残存チェック（lowercase URL `/app/aimachi/` は許容）
      expect(
        src.contains('Aimachi'),
        isFalse,
        reason: 'share_utils.dart に `Aimachi` が残存しています。',
      );
    });

    test('lib/screens/settings_screen.dart のシェア文言と mailto subject が「まんなか」のとき設定画面が統一される', () {
      final src = _readSource('lib/screens/settings_screen.dart');
      // L575
      expect(
        src.contains('友達にまんなかを教えよう'),
        isTrue,
        reason: 'settings_screen.dart:575 を `友達にまんなかを教えよう` に。',
      );
      // L580 / L613
      expect(
        'まんなか（無料）'.allMatches(src).isNotEmpty,
        isTrue,
        reason: 'settings_screen.dart:580/613 の `Aimachi（無料）` を `まんなか（無料）` に。',
      );
      // L640: mailto subject。URL エンコード後の「まんなか」= `%E3%81%BE%E3%82%93%E3%81%AA%E3%81%8B`
      // もしくは生文字列 `まんなか` をクエリに入れる実装も可
      final hasEncodedMannaka = src.contains('%E3%81%BE%E3%82%93%E3%81%AA%E3%81%8B');
      final hasRawMannakaInMailto =
          RegExp(r'mailto:[^"]*subject=[^"]*まんなか').hasMatch(src);
      expect(
        hasEncodedMannaka || hasRawMannakaInMailto,
        isTrue,
        reason: 'settings_screen.dart:640 の mailto subject を「まんなか お問い合わせ」\n'
            'に変更してください（URL エンコード `%E3%81%BE%E3%82%93%E3%81%AA%E3%81%8B` または\n'
            '生 `まんなか` を subject クエリに含む）。',
      );
      expect(
        src.contains('Aimachi'),
        isFalse,
        reason: 'settings_screen.dart に `Aimachi` が残存しています。',
      );
    });

    test('lib/screens/search_screen.dart のシェア文とキャッチコピーとコメントが「まんなか」のとき位置共有導線・空状態・コメントが統一される', () {
      final src = _readSource('lib/screens/search_screen.dart');
      // L607: 【Aimachi】... → 【まんなか】...
      expect(
        src.contains('【まんなか】'),
        isTrue,
        reason: 'search_screen.dart:607 の `【Aimachi】...` を `【まんなか】...` に。',
      );
      // L1903: あとはAimachiにおまかせ → あとはまんなかにおまかせ
      expect(
        src.contains('あとはまんなかにおまかせ'),
        isTrue,
        reason: 'search_screen.dart:1903 の `あとはAimachiにおまかせ` を\n'
            '`あとはまんなかにおまかせ` に。',
      );
      // Cycle 12: コメント L605 の `Aimachi の説明` もブランド統一の対象。
      // ファイル全体で `Aimachi` が 0 件であること（コメント含む）。
      final lines = _readLines('lib/screens/search_screen.dart');
      final residualAimachi = <String>[];
      for (int i = 0; i < lines.length; i++) {
        if (lines[i].contains('Aimachi')) {
          residualAimachi.add('L${i + 1}: ${lines[i].trim()}');
        }
      }
      expect(
        residualAimachi,
        isEmpty,
        reason: 'search_screen.dart に `Aimachi` が残存しています（コメント含む）。\n'
            'L605 の `// 〜 Aimachi の説明 〜` も `まんなか の説明` に更新が必要です。\n'
            '${residualAimachi.join('\n')}',
      );
    });

    test('lib/screens/scene_area_screen.dart のハッシュタグが「#まんなか」のときランキングシェアが統一される', () {
      final src = _readSource('lib/screens/scene_area_screen.dart');
      expect(
        src.contains('#まんなか'),
        isTrue,
        reason: 'scene_area_screen.dart:414 の `#Aimachi` を `#まんなか` に。',
      );
      expect(
        src.contains('#Aimachi'),
        isFalse,
        reason: 'scene_area_screen.dart に `#Aimachi` が残存しています。',
      );
    });

    test('lib/screens/vote_invite_screen.dart の招待文言が「まんなか」のとき投票招待シェアが統一される', () {
      final src = _readSource('lib/screens/vote_invite_screen.dart');
      expect(
        src.contains('【まんなか】'),
        isTrue,
        reason: 'vote_invite_screen.dart:15 の `【Aimachi】...` を `【まんなか】...` に。',
      );
      expect(
        src.contains('Aimachi'),
        isFalse,
        reason: 'vote_invite_screen.dart に `Aimachi` が残存しています。',
      );
    });

    test('lib/screens/share_preview_screen.dart のフォールバック文言が「まんなか」のとき画像シェアが統一される', () {
      final src = _readSource('lib/screens/share_preview_screen.dart');
      expect(
        src.contains('まんなかで見つけました'),
        isTrue,
        reason: 'share_preview_screen.dart:93 を `まんなかで見つけました` に。',
      );
      expect(
        src.contains('Aimachi'),
        isFalse,
        reason: 'share_preview_screen.dart に `Aimachi` が残存しています。',
      );
    });

    test('lib/widgets/illustrations.dart のテキスト描画が「まんなか」のときイラスト内ロゴが統一される', () {
      final src = _readSource('lib/widgets/illustrations.dart');
      expect(
        src.contains("text: 'まんなか'"),
        isTrue,
        reason: 'illustrations.dart:955 の `text: \'Aimachi\'` を\n'
            '`text: \'まんなか\'` に。',
      );
      expect(
        src.contains('Aimachi'),
        isFalse,
        reason: 'illustrations.dart に `Aimachi` が残存しています。',
      );
    });

    test('lib/widgets/share_card_widget.dart のバッジが「まんなか」のときシェアカード画像が統一される', () {
      final src = _readSource('lib/widgets/share_card_widget.dart');
      expect(
        src.contains("'まんなか'"),
        isTrue,
        reason: 'share_card_widget.dart:65 の `\'Aimachi\'` を `\'まんなか\'` に。',
      );
      expect(
        src.contains('Aimachi'),
        isFalse,
        reason: 'share_card_widget.dart に `Aimachi` が残存しています。',
      );
    });

    // Cycle 13 新規: ranking_screen の legacy label 6 箇所のミューテーション・ガード 3 件
    //
    // `_patternAllowlist` 空化で Group [1] スキャンが違反検出するが、それだけでは
    // 「Engineer が Aimachi を単純削除した」ケースを検出できない。以下 3 件は
    // 期待文言（まんなか指数 / まんなかユーザー / まんなか全ユーザー）が実在し、
    // かつ旧文言（Aimachi指数 / Aimachiユーザー / Aimachi全ユーザー）が 0 件で
    // あることを個別に確認する。

    test('lib/screens/ranking_screen.dart の「まんなか指数」が L39/L122/L410/L507 の 4 箇所で登場するとき画面タイトル・バナー見出し・シェア文・シェアカード見出しのブランド表記が統一される', () {
      final src = _readSource('lib/screens/ranking_screen.dart');
      final occurrences = 'まんなか指数'.allMatches(src).length;
      expect(
        occurrences,
        greaterThanOrEqualTo(4),
        reason: 'ranking_screen.dart 内で「まんなか指数」が 4 回以上登場する必要があります。\n'
            '実際の出現回数: $occurrences\n'
            '対象箇所:\n'
            '  - L39  画面タイトル `Aimachi指数ランキング` → `まんなか指数ランキング`\n'
            '  - L122 バナー見出し `「Aimachi指数」について` → `「まんなか指数」について`\n'
            '  - L410 シェア text `Aimachi指数ランキング🏆` → `まんなか指数ランキング🏆`\n'
            '  - L507 シェアカード見出し `Aimachi指数ランキング` → `まんなか指数ランキング`',
      );
      expect(
        src.contains('Aimachi指数'),
        isFalse,
        reason: 'ranking_screen.dart に `Aimachi指数` が残存しています。\n'
            'Cycle 13 は legacy label を完全除去する Cycle です。',
      );
    });

    test('lib/screens/ranking_screen.dart の「まんなかユーザー」が L98 で登場するとき説明文のブランド表記が統一される', () {
      final src = _readSource('lib/screens/ranking_screen.dart');
      expect(
        src.contains('まんなかユーザーが最もよく集まった駅ランキング'),
        isTrue,
        reason: 'ranking_screen.dart:98 の `Aimachiユーザーが最もよく集まった駅ランキング` を\n'
            '`まんなかユーザーが最もよく集まった駅ランキング` に置換してください。\n'
            '（空文字削除や半角化した場合の取りこぼしを検出）',
      );
      expect(
        src.contains('Aimachiユーザー'),
        isFalse,
        reason: 'ranking_screen.dart に `Aimachiユーザー` が残存しています。',
      );
    });

    test('lib/screens/ranking_screen.dart の「まんなか全ユーザー」が L131 で登場するときバナー本文のブランド表記が統一される', () {
      final src = _readSource('lib/screens/ranking_screen.dart');
      expect(
        src.contains('まんなか全ユーザーの検索データに基づいています'),
        isTrue,
        reason: 'ranking_screen.dart:131 の `Aimachi全ユーザーの検索データに基づいています` を\n'
            '`まんなか全ユーザーの検索データに基づいています` に置換してください。',
      );
      expect(
        src.contains('Aimachi全ユーザー'),
        isFalse,
        reason: 'ranking_screen.dart に `Aimachi全ユーザー` が残存しています。',
      );
    });

    // Cycle 12 ガード: ranking_screen の純ブランド残骸 2 箇所（継続）
    test('lib/screens/ranking_screen.dart のシェアカードフッターとハッシュタグが「まんなか」のときシェア画像とSNS導線が統一される', () {
      final src = _readSource('lib/screens/ranking_screen.dart');

      // L602: シェアカードフッター — 純ブランド残骸（「指数」とは無関係）
      expect(
        src.contains('まんなか - 集合場所を決めるアプリ'),
        isTrue,
        reason: 'ranking_screen.dart:602 のシェアカードフッターを\n'
            '`\'まんなか - 集合場所を決めるアプリ\'` に置換してください。\n'
            'このテキストは SNS 投稿画像に焼き込まれ、App Store 名称との不一致が\n'
            'ブランド毀損リスクとなります。',
      );
      expect(
        src.contains("'Aimachi - 集合場所を決めるアプリ'"),
        isFalse,
        reason: 'ranking_screen.dart:602 に旧ブランド残骸が残っています。',
      );

      // L410: `#Aimachi` ハッシュタグ（同行の `Aimachi指数ランキング🏆` は温存）
      expect(
        src.contains('#まんなか'),
        isTrue,
        reason: 'ranking_screen.dart:410 のハッシュタグを `#まんなか` に置換してください。\n'
            '（scene_area_screen.dart:414 と同じ `#まんなか` に統一して\n'
            ' SNS タグ検索導線を揃える）',
      );
      expect(
        src.contains('#Aimachi'),
        isFalse,
        reason: 'ranking_screen.dart:410 の `#Aimachi` ハッシュタグが残存しています。\n'
            '（同行の `Aimachi指数ランキング🏆` は温存し、`#Aimachi` のみ `#まんなか` に）',
      );
    });
  });

  // ══════════════════════════════════════════════════════════════
  // [3] スコープ外の識別子・製品用語が温存されていること
  // ══════════════════════════════════════════════════════════════
  //
  // Engineer が機械的全置換で内部クラス識別子や製品指標名まで壊さないことを保証。

  group('スコープ外 — 内部識別子（AimachiApp）の温存', () {
    test('lib/app.dart の `class AimachiApp` 識別子が温存されているとき呼び出し元との整合性が保たれる', () {
      final src = _readSource('lib/app.dart');
      expect(
        RegExp(r'class\s+AimachiApp\b').hasMatch(src),
        isTrue,
        reason: 'lib/app.dart の `class AimachiApp` を変更しないでください。\n'
            'main.dart からの参照を壊します（スコープ外）。',
      );
    });

    test('lib/main.dart の `AimachiApp()` 参照が温存されているときアプリ起動が成立する', () {
      final src = _readSource('lib/main.dart');
      expect(
        src.contains('AimachiApp()'),
        isTrue,
        reason: 'lib/main.dart の `runApp(const ProviderScope(child: AimachiApp()))`\n'
            'を変更しないでください（内部識別子）。',
      );
    });
  });
}
