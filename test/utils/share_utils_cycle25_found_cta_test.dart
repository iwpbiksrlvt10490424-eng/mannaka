// TDD Red フェーズ
// Cycle 25: 決定文 "Aimachi で見つけました" を ShareUtils.foundOnAimachiCta 定数に集約
//
// 背景:
//   share_utils.dart:147 と share_preview_screen.dart:93 に
//   同一の決定文文字列が二重定義されている。これは Cycle 16 で実際に
//   片側崩壊バグを起こした構造的二重定義と完全に同型であり、
//   Cycle 24 で line CTA に対して導入した「lib/ 全域 grep で出現
//   ファイル数 == 1」の静的ガードを再利用して構造防御を 1 件追加する。
//
// このテストは Cycle 24 と同設計で、機械的に再発を不可能にする。
//
// 受け入れ条件:
//   [1] share_utils.dart に `foundOnAimachiCta` 定数が宣言され、期待文字列と一致する
//   [2] buildRestaurantShareText() の出力に CTA が含まれる（Refactor Safe）
//   [3] share_preview_screen.dart は ShareUtils.foundOnAimachiCta を参照する
//       （リテラル直書きを残さない）
//   [4] lib/ 配下を再帰スキャンしてリテラルが定義側 1 ファイル
//       （share_utils.dart）のみに存在する

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mannaka/models/restaurant.dart';
import 'package:mannaka/models/scored_restaurant.dart';
import 'package:mannaka/providers/search_provider.dart';
import 'package:mannaka/utils/share_utils.dart';

// 期待値は「現に運用されている」文字列。share_utils.dart:147 /
// share_preview_screen.dart:93 と完全一致しなければならない
// （受信者に届く 1 文字単位の見え方を担保）。
const _expectedCta = 'Aimachi で見つけました';

// ── ヘルパー ──────────────────────────────────────────────
Restaurant _restaurant({
  required String id,
  required String name,
  String category = 'イタリアン',
}) {
  return Restaurant(
    id: id,
    name: name,
    stationIndex: 0,
    category: category,
    rating: 4.0,
    reviewCount: 50,
    priceLabel: '¥¥',
    priceAvg: 3000,
    tags: const [],
    emoji: '🍽️',
    description: 'テスト用',
    distanceMinutes: 5,
    address: '渋谷区1-1',
    openHours: '11:00-23:00',
  );
}

ScoredRestaurant _scored(Restaurant r) {
  return ScoredRestaurant(
    restaurant: r,
    score: 0.8,
    distanceKm: 0.4,
    participantDistances: const {},
    fairnessScore: 0.8,
  );
}

/// lib/ 配下の .dart ファイルを再帰列挙する。
List<File> _libDartFiles() {
  final dir = Directory('lib');
  if (!dir.existsSync()) {
    fail('lib/ ディレクトリが見つかりません。テスト実行時の cwd を確認してください。');
  }
  return dir
      .listSync(recursive: true, followLinks: false)
      .whereType<File>()
      .where((f) => f.path.endsWith('.dart'))
      .toList();
}

void main() {
  // ══════════════════════════════════════════════════════════════
  // [1] share_utils.dart に foundOnAimachiCta 定数が定義されている
  //     （ソース文字列ベースで判定し、未宣言時のコンパイルエラーで
  //     他テストがブロックされないようにする）
  // ══════════════════════════════════════════════════════════════
  group('share_utils.dart — foundOnAimachiCta 定数の宣言', () {
    test('static const foundOnAimachiCta が宣言され、現運用 CTA と一致する', () {
      const path = 'lib/utils/share_utils.dart';
      final file = File(path);
      if (!file.existsSync()) {
        fail('$path が存在しません。');
      }
      final content = file.readAsStringSync();

      // `static const foundOnAimachiCta = '...';` の宣言を抽出。
      final decl = RegExp(
        r"""static\s+const\s+foundOnAimachiCta\s*=\s*['"]([^'"]+)['"]\s*;""",
      );
      final m = decl.firstMatch(content);

      expect(
        m,
        isNotNull,
        reason:
            '$path に `static const foundOnAimachiCta = ...;` が見つからない。\n'
            '\n'
            '実装方針（share_utils.dart のクラス先頭付近、lineDownloadCta の隣）:\n'
            "  static const foundOnAimachiCta = '$_expectedCta';\n"
            '\n'
            '理由: 決定文の単一所在 (single source of truth) を確立し、\n'
            'Cycle 16 のような片側崩壊バグの再発を構造的にブロックする。\n'
            '（Cycle 24 で line CTA に同設計を導入済み。本タスクはその横展開）',
      );

      // 値が一致していること（const 化はしたが文字列が変わっていないことを担保）。
      if (m != null) {
        expect(
          m.group(1),
          equals(_expectedCta),
          reason:
              'foundOnAimachiCta の値が期待文字列と一致しない。\n'
              '本タスクは Refactor Safe（出力バイト列不変）。\n'
              '値そのものは現運用文言を維持すること。',
        );
      }
    });
  });

  // ══════════════════════════════════════════════════════════════
  // [2] buildRestaurantShareText の出力本文に CTA が含まれる（Refactor Safe）
  //     これは現状でも Green。Green 化後も Green を保つことが本質。
  // ══════════════════════════════════════════════════════════════
  group('ShareUtils.buildRestaurantShareText — 出力バイト列の不変', () {
    test('出力本文に決定 CTA が含まれる（リテラル / 定数いずれでも一致）', () {
      final r = _restaurant(id: 'r1', name: 'テスト食堂');
      final sr = _scored(r);
      final state = SearchState();

      final text = ShareUtils.buildRestaurantShareText(
        state,
        primaryScored: sr,
        includeBackup: false,
      );

      expect(
        text,
        contains(_expectedCta),
        reason:
            'buildRestaurantShareText の出力に CTA が含まれない。\n'
            '本タスクは出力バイト列不変の Refactor Safe。\n'
            '定数化に際しても文字列値を変えてはならない。',
      );
    });
  });

  // ══════════════════════════════════════════════════════════════
  // [3] share_preview_screen.dart に決定 CTA のリテラル直書きが無い
  //     （Cycle 26 で _buildShareText のフォールバック分岐が削除され、
  //      screen 側からは ShareUtils.foundOnAimachiCta 参照そのものが
  //      不要になったため、「参照している」アサーションは撤去。
  //      単一所在の構造防御は [4] と本ケースで維持される）
  // ══════════════════════════════════════════════════════════════
  group('share_preview_screen.dart — foundOnAimachiCta 参照', () {
    test('決定 CTA のリテラル直書きが残っていない', () {
      const path = 'lib/screens/share_preview_screen.dart';
      final file = File(path);
      if (!file.existsSync()) {
        fail('$path が存在しません。');
      }
      final content = file.readAsStringSync();

      expect(
        content.contains(_expectedCta),
        isFalse,
        reason:
            '$path に決定 CTA のリテラル直書きが残っている。\n'
            '`ShareUtils.foundOnAimachiCta` 経由の参照に置き換えること。\n'
            '（リテラルが 2 箇所以上に存在することが Cycle 16 の片側崩壊を生んだ）',
      );
    });
  });

  // ══════════════════════════════════════════════════════════════
  // [4] lib/ 全域 — リテラル文字列は share_utils.dart にのみ存在
  // ══════════════════════════════════════════════════════════════
  group('lib/ 全域 — 決定 CTA リテラルの単一所在', () {
    test('リテラル "$_expectedCta" は lib/utils/share_utils.dart にのみ存在する', () {
      final files = _libDartFiles();
      final hits = <String>[];
      for (final f in files) {
        final content = f.readAsStringSync();
        if (content.contains(_expectedCta)) {
          hits.add(f.path);
        }
      }

      expect(
        hits.length,
        equals(1),
        reason:
            '決定 CTA "$_expectedCta" のリテラル定義は lib/ 配下に\n'
            'ちょうど 1 ファイル（share_utils.dart 内の foundOnAimachiCta 定義行）\n'
            'のみ存在しなければならない。\n'
            '\n'
            '検出された全ファイル:\n${hits.map((p) => '  - $p').join('\n')}\n'
            '\n'
            '修正方針:\n'
            '  - share_utils.dart に `static const foundOnAimachiCta = ...` を追加\n'
            '  - 他の参照箇所はリテラルを削除し ShareUtils.foundOnAimachiCta に置換',
      );

      if (hits.length == 1) {
        expect(
          hits.single.replaceAll(r'\', '/'),
          endsWith('lib/utils/share_utils.dart'),
          reason:
              'リテラルの唯一の出現箇所は lib/utils/share_utils.dart である必要がある。\n'
              '実際の出現: ${hits.single}',
        );
      }
    });
  });
}
