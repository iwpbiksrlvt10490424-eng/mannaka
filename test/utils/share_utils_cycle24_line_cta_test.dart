// TDD Red フェーズ
// Cycle 24: LINE 誘導文 (line CTA) を ShareUtils.lineDownloadCta 定数に集約
//
// 背景:
//   share_utils.dart:194 と saved_drafts_screen.dart:187 に
//   同一の LINE 誘導文字列が二重定義されていた。これが Cycle 16 の
//   機械置換で片側だけ書き換えられ、Cycle 23 で発覚した不整合の根本原因。
//
// このテストは「同じ文字列リテラルが lib/ 配下に 1 ファイルしか残っていない」
// ことを機械的に担保し、再発防止の構造的ガードとなる。
//
// 受け入れ条件:
//   [1] share_utils.dart に `lineDownloadCta` 定数が宣言され、期待文字列と一致する
//   [2] buildLineTextForSelections() の出力バイト列が変化しない（Refactor Safe）
//   [3] saved_drafts_screen.dart は ShareUtils.lineDownloadCta を参照する
//       （リテラル直書きを残さない）
//   [4] lib/ 配下を grep してリテラル文字列が定義側 1 ファイル（share_utils.dart）
//       のみに存在する

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mannaka/models/restaurant.dart';
import 'package:mannaka/models/scored_restaurant.dart';
import 'package:mannaka/providers/search_provider.dart';
import 'package:mannaka/utils/share_utils.dart';

// 期待値は「現に運用されている」文字列。share_utils.dart:194 / saved_drafts_screen.dart:187
// と完全一致しなければならない（LINE 受信者に届く 1 文字単位の見え方を担保）。
const _expectedCta = 'あなたもAimachi（無料）で同じ条件のお店を探してみましょう👇';

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
  // [1] share_utils.dart に lineDownloadCta 定数が定義されている
  //     （ソース文字列ベースで判定し、コンパイルエラーで他テストが
  //     ブロックされないようにする）
  // ══════════════════════════════════════════════════════════════
  group('share_utils.dart — lineDownloadCta 定数の宣言', () {
    test('static const lineDownloadCta が宣言され、現運用 CTA と一致する', () {
      const path = 'lib/utils/share_utils.dart';
      final file = File(path);
      if (!file.existsSync()) {
        fail('$path が存在しません。');
      }
      final content = file.readAsStringSync();

      // `static const lineDownloadCta = '...';` の宣言を抽出。
      // 先頭の static は省略可（クラス内 const がある以上のゆるい一致でOK）。
      final decl = RegExp(
        r"""static\s+const\s+lineDownloadCta\s*=\s*['"]([^'"]+)['"]\s*;""",
      );
      final m = decl.firstMatch(content);

      expect(
        m,
        isNotNull,
        reason:
            '$path に `static const lineDownloadCta = ...;` が見つからない。\n'
            '\n'
            '実装方針（share_utils.dart のクラス先頭付近）:\n'
            "  static const lineDownloadCta =\n"
            "      '$_expectedCta';\n"
            '\n'
            '理由: LINE 誘導文の単一所在 (single source of truth) を確立し、\n'
            'Cycle 16 のような片側崩壊バグの再発を構造的にブロックする。',
      );

      // 値が一致していること（const 化はしたが文字列が変わっていないことを担保）。
      if (m != null) {
        expect(
          m.group(1),
          equals(_expectedCta),
          reason:
              'lineDownloadCta の値が期待文字列と一致しない。\n'
              '本タスクは Refactor Safe（出力バイト列不変）。\n'
              '値そのものは Cycle 23 で確定した文言を維持すること。',
        );
      }
    });
  });

  // ══════════════════════════════════════════════════════════════
  // [2] buildLineTextForSelections の出力末尾が CTA を含む（Refactor Safe）
  //     これは現状でも Green。Green 化後も Green を保つことが本質。
  // ══════════════════════════════════════════════════════════════
  group('ShareUtils.buildLineTextForSelections — 出力バイト列の不変', () {
    test('出力本文に LINE 誘導 CTA が含まれる（リテラル / 定数いずれでも一致）', () {
      final r = _restaurant(id: 'r1', name: 'テスト食堂');
      final sr = _scored(r);
      final state = SearchState(centroidLat: 35.658, centroidLng: 139.701);

      final text = ShareUtils.buildLineTextForSelections(
        state,
        [(station: '新宿', scored: sr)],
      );

      expect(
        text,
        contains(_expectedCta),
        reason:
            'buildLineTextForSelections の出力に CTA が含まれない。\n'
            '本タスクは出力バイト列不変の Refactor Safe。\n'
            '定数化に際しても文字列値を変えてはならない。',
      );
    });
  });

  // ══════════════════════════════════════════════════════════════
  // [3] saved_drafts_screen.dart が定数を参照する（直書き禁止）
  // ══════════════════════════════════════════════════════════════
  group('saved_drafts_screen.dart — lineDownloadCta 参照', () {
    test('ShareUtils.lineDownloadCta を参照している', () {
      const path = 'lib/screens/saved_drafts_screen.dart';
      final file = File(path);
      if (!file.existsSync()) {
        fail('$path が存在しません。');
      }
      final content = file.readAsStringSync();

      expect(
        content.contains('ShareUtils.lineDownloadCta'),
        isTrue,
        reason:
            '$path は LINE 誘導文をリテラル直書きせず、\n'
            'ShareUtils.lineDownloadCta を参照する形に統一する必要がある。\n'
            '（Cycle 16 の片側崩壊バグの再発防止。これが Cycle 24 の本目的）',
      );
    });

    test('LINE 誘導文のリテラル直書きが残っていない', () {
      const path = 'lib/screens/saved_drafts_screen.dart';
      final file = File(path);
      if (!file.existsSync()) {
        fail('$path が存在しません。');
      }
      final content = file.readAsStringSync();

      expect(
        content.contains(_expectedCta),
        isFalse,
        reason:
            '$path に LINE 誘導文のリテラル直書きが残っている。\n'
            '`ShareUtils.lineDownloadCta` 経由の参照に置き換えること。\n'
            '（リテラルが 2 箇所以上に存在することが Cycle 16 の片側崩壊を生んだ）',
      );
    });
  });

  // ══════════════════════════════════════════════════════════════
  // [4] lib/ 全域 — リテラル文字列は share_utils.dart にのみ存在
  // ══════════════════════════════════════════════════════════════
  group('lib/ 全域 — LINE 誘導文リテラルの単一所在', () {
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
            'LINE 誘導文 "$_expectedCta" のリテラル定義は lib/ 配下に\n'
            'ちょうど 1 ファイル（share_utils.dart 内の lineDownloadCta 定義行）\n'
            'のみ存在しなければならない。\n'
            '\n'
            '検出された全ファイル:\n${hits.map((p) => '  - $p').join('\n')}\n'
            '\n'
            '修正方針:\n'
            '  - share_utils.dart に `static const lineDownloadCta = ...` を追加\n'
            '  - 他の参照箇所はリテラルを削除し ShareUtils.lineDownloadCta に置換',
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
