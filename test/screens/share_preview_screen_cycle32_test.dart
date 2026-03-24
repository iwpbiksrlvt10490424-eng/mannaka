// TDD Red フェーズ
// Cycle 32: share_preview_screen.dart — UIラベル旧表記除去
//
// スコープ:
//   [ISSUE] share_preview_screen.dart:347
//           Cycle 30 で代替案の出力形式を `代替案①②` → `→ 店名（カテゴリ / 価格）` に変更したが
//           ユーザーに見えるトグルの説明文が旧フォーマット名 `代替案①②をシェアテキストに追加` のまま。
//           実際の出力と不整合なので `代替案をシェアテキストに追加` に修正する。
//
// CLAUDE.md 参照:
//   - UIテキストに「？」（全角・半角問わず）使用禁止

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  // ─────────────────────────────────────────────────────
  // グループ1: 旧フォーマット名 `代替案①②` がUIに残っていない
  // ─────────────────────────────────────────────────────
  group(
    'ISSUE share_preview_screen トグル説明文の旧フォーマット名除去',
    () {
      test(
        '代替案①② がUIテキストに含まれていないとき 出力フォーマットとラベルが一致している',
        () {
          final file = File('lib/screens/share_preview_screen.dart');
          if (!file.existsSync()) {
            fail('lib/screens/share_preview_screen.dart が存在しません。');
          }
          final content = file.readAsStringSync();

          // ①② (circled numbers) が subtitle テキスト内に含まれていないことを確認
          expect(
            content.contains('代替案①'),
            isFalse,
            reason: 'lib/screens/share_preview_screen.dart に'
                " '代替案①②をシェアテキストに追加' の旧フォーマット名が残っています。\n"
                '\n'
                'Cycle 30 で代替案の出力形式を `→ 店名（カテゴリ / 価格）` に変更しましたが、\n'
                'トグルの説明文が旧フォーマット名のままで実際の出力と不整合です。\n'
                '\n'
                '修正: `代替案①②をシェアテキストに追加` → `代替案をシェアテキストに追加`',
          );
        },
      );
    },
  );

  // ─────────────────────────────────────────────────────
  // グループ2: 修正後のラベル `代替案をシェアテキストに追加` が存在する
  // ─────────────────────────────────────────────────────
  group(
    'ISSUE share_preview_screen トグル説明文が新フォーマットに更新済み',
    () {
      test(
        '代替案をシェアテキストに追加 がUIテキストに存在するとき トグルラベルが正しく更新されている',
        () {
          final file = File('lib/screens/share_preview_screen.dart');
          if (!file.existsSync()) {
            fail('lib/screens/share_preview_screen.dart が存在しません。');
          }
          final content = file.readAsStringSync();

          expect(
            content.contains('代替案をシェアテキストに追加'),
            isTrue,
            reason: 'lib/screens/share_preview_screen.dart に'
                " '代替案をシェアテキストに追加' が見つかりません。\n"
                '\n'
                'SwitchListTile の subtitle を以下に変更してください:\n'
                "  subtitle: Text('代替案をシェアテキストに追加', ...)",
          );
        },
      );
    },
  );
}
