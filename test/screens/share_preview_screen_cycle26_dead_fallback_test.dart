// TDD Red フェーズ
// Cycle 26: share_preview_screen._buildShareText の到達不能フォールバック分岐を削除
//
// 背景:
//   share_preview_screen.dart:88-93 の `if (text.isNotEmpty) return text;`
//   分岐とそれに続くフォールバック（"に決まりました" 直書きテンプレート）は
//   静的解析上 dead code である。
//
//   理由:
//     - SharePreviewScreen.scored は `required ScoredRestaurant`（非null）
//     - ShareUtils.buildRestaurantShareText は primaryScored が非nullなら
//       常に "お店が決まりました\n\n${name}\n${category}..." を構築して
//       非空文字列を返す（share_utils.dart:117-156）
//     - したがって `if (text.isNotEmpty)` は常に true
//     - 90-93 行の単独テンプレート（"に決まりました" / "参加者: ${names}"）には
//       決して到達しない
//
//   リスク:
//     dead code 側だけが `r.address` と `participants` のフォーマット責務を
//     持ち、Cycle 16 で起きた「片側だけ仕様変更が反映されて出力ずれ」型の
//     構造的バグを再発させ得る。Cycle 23-25 の「定数集約 → 構造ガード」流れに
//     沿って、本サイクルで dead branch ごと撤去する。
//
// 受け入れ条件（7 ケース）:
//   [1] 不変: 空 SearchState + primaryScored → buildRestaurantShareText が非空
//   [2] 不変: selectedMeetingPoint 含む SearchState + primaryScored → 非空
//       （[1][2] 合わせてフォールバック分岐が不到達である runtime 証明）
//   [3] share_preview_screen.dart に `に決まりました` リテラルが存在しない
//   [4] share_preview_screen.dart に `参加者: ` リテラル（コロン付き）が存在しない
//   [5] share_preview_screen.dart に `if (text.isNotEmpty)` パターンが存在しない
//   [6] _buildShareText 本体に中間変数 `final text =` が無い（単一 return 化）
//   [7] _buildShareText 本体行数（{ から } まで）が 7 行以内に短縮されている
//
//   Refactor Safe（出力バイト列不変）：受信者に届くシェア本文は変わらない。
//   削除されるのは到達不能な分岐のみ。

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mannaka/models/meeting_point.dart';
import 'package:mannaka/models/restaurant.dart';
import 'package:mannaka/models/scored_restaurant.dart';
import 'package:mannaka/providers/search_provider.dart';
import 'package:mannaka/utils/share_utils.dart';

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

String _readSource() {
  const path = 'lib/screens/share_preview_screen.dart';
  final file = File(path);
  if (!file.existsSync()) {
    fail('$path が存在しません。');
  }
  return file.readAsStringSync();
}

/// `_buildShareText(...)` の本体（{ から対応する } まで）を抜き出す。
/// シンプルな波括弧カウンタで実装（テスト対象メソッドはネスト無し想定）。
String _extractBuildShareTextBody(String source) {
  final start = source.indexOf('String _buildShareText(');
  if (start < 0) {
    fail('share_preview_screen.dart に `String _buildShareText(` が見つかりません。');
  }
  final braceStart = source.indexOf('{', start);
  if (braceStart < 0) {
    fail('_buildShareText 本体の開き波括弧が見つかりません。');
  }
  var depth = 0;
  for (var i = braceStart; i < source.length; i++) {
    final ch = source[i];
    if (ch == '{') depth++;
    if (ch == '}') {
      depth--;
      if (depth == 0) {
        return source.substring(braceStart, i + 1);
      }
    }
  }
  fail('_buildShareText の閉じ波括弧が見つかりません（中括弧数の不整合）。');
}

void main() {
  // ══════════════════════════════════════════════════════════════
  // [1] 不変条件: buildRestaurantShareText は primaryScored 渡しで常に非空
  //     （= フォールバック分岐は決して必要にならないことの runtime 証明）
  //     現状でも Green。削除後も Green を保つことが本質。
  // ══════════════════════════════════════════════════════════════
  group('ShareUtils.buildRestaurantShareText — primaryScored 非null時の非空不変', () {
    test('空の SearchState + primaryScored → 非空', () {
      final r = _restaurant(id: 'r1', name: 'テスト食堂');
      final sr = _scored(r);
      final state = SearchState();

      final text = ShareUtils.buildRestaurantShareText(
        state,
        primaryScored: sr,
        includeBackup: false,
      );

      expect(
        text.isNotEmpty,
        isTrue,
        reason:
            'primaryScored が非null なら buildRestaurantShareText は常に非空を返す。\n'
            'これが share_preview_screen の `if (text.isNotEmpty)` を常に true にし、\n'
            'フォールバック分岐を不到達にしている根拠。\n'
            '空 state でも `お店が決まりました\\n\\n${r.name}...` が必ず構築される。',
      );
    });

    test('selectedMeetingPoint・results 入りの SearchState + primaryScored → 非空', () {
      final r = _restaurant(id: 'r1', name: 'テスト食堂');
      final sr = _scored(r);
      final point = MeetingPoint(
        stationIndex: 0,
        stationName: '新宿',
        stationEmoji: '🚉',
        lat: 35.690,
        lng: 139.700,
        totalMinutes: 20,
        maxMinutes: 12,
        minMinutes: 8,
        averageMinutes: 10,
        fairnessScore: 0.9,
        overallScore: 0.9,
        participantTimes: const {'あや': 12, 'ゆう': 8},
      );
      final state = SearchState(
        results: [point],
        selectedMeetingPoint: point,
      );

      final text = ShareUtils.buildRestaurantShareText(
        state,
        primaryScored: sr,
        includeBackup: true,
      );

      expect(
        text.isNotEmpty,
        isTrue,
        reason:
            'selectedMeetingPoint がある通常パスでも非空。\n'
            'フォールバック削除後も同等の出力が得られる必要がある。',
      );
      expect(
        text,
        contains('お店が決まりました'),
        reason: '主経路の見出しが本文に必ず含まれる。',
      );
    });

  });

  // ══════════════════════════════════════════════════════════════
  // [2] 構造ガード: フォールバック特有のリテラルが share_preview_screen から消える
  // ══════════════════════════════════════════════════════════════
  group('share_preview_screen.dart — フォールバック特有リテラルの除去', () {
    test('リテラル "に決まりました" が存在しない（フォールバック専用文言の撤去）', () {
      final src = _readSource();
      expect(
        src.contains('に決まりました'),
        isFalse,
        reason:
            'share_preview_screen.dart にフォールバック専用リテラル "に決まりました" が残っている。\n'
            '到達不能な分岐 (line 90-93) をメソッドごと撤去する必要がある。\n'
            '（主経路の文言は ShareUtils.buildRestaurantShareText 内の "お店が決まりました" のみ）',
      );
    });

    test('リテラル "参加者: "（コロン付き）が存在しない', () {
      final src = _readSource();
      expect(
        src.contains('参加者: '),
        isFalse,
        reason:
            'share_preview_screen.dart にフォールバック専用フォーマット "参加者: \$names" が残っている。\n'
            '主経路は Wrap ウィジェットでのチップ表示 ("参加者" 単独ラベル) なので、\n'
            'コロン付きフォーマットはフォールバック専用。dead code として撤去すること。',
      );
    });
  });

  // ══════════════════════════════════════════════════════════════
  // [3] 構造ガード: _buildShareText の制御構造から fallback パスが消える
  // ══════════════════════════════════════════════════════════════
  group('share_preview_screen.dart — _buildShareText の構造', () {
    test('`if (text.isNotEmpty)` パターンが存在しない', () {
      final src = _readSource();
      expect(
        src.contains('if (text.isNotEmpty)'),
        isFalse,
        reason:
            '`if (text.isNotEmpty) return text;` は不変条件 [1] により常に true で、\n'
            '到達不能フォールバックを守る形骸的ガードである。\n'
            'メソッドを単一 return に短縮することで分岐自体を排除すること。',
      );
    });

    test('_buildShareText 本体に中間変数 `final text =` が無い（単一 return 化）', () {
      final src = _readSource();
      final body = _extractBuildShareTextBody(src);

      expect(
        body.contains('final text ='),
        isFalse,
        reason:
            '_buildShareText は `return ShareUtils.buildRestaurantShareText(...)` の\n'
            '単一 return 文に短縮されているべき。\n'
            '中間変数 `final text =` は分岐 (`if text.isNotEmpty`) を前提とした書き方で、\n'
            'フォールバック撤去後は不要。\n'
            '\n'
            '実装例:\n'
            '  String _buildShareText(SearchState state) {\n'
            '    return ShareUtils.buildRestaurantShareText(\n'
            '      state,\n'
            '      primaryScored: widget.scored,\n'
            '      includeBackup: _includeBackup,\n'
            '    );\n'
            '  }',
      );
    });

    test('_buildShareText 本体は短縮されている（行数 7 以下）', () {
      final src = _readSource();
      final body = _extractBuildShareTextBody(src);
      final lineCount = body.split('\n').length;

      expect(
        lineCount,
        lessThanOrEqualTo(7),
        reason:
            '_buildShareText は単一 return に短縮され、本体は 7 行以内に収まるべき。\n'
            '現状: $lineCount 行（中間変数 + if 分岐 + フォールバック template を含む）。\n'
            '期待: { + return 行 (折返し 4 行程度) + } = 7 行以内。\n'
            '\n'
            '本テストはメソッド肥大化の機械的ガード。\n'
            '将来また dead branch を生やしたとき同じテストで弾く。',
      );
    });
  });
}
