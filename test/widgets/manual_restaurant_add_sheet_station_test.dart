// TDD Red フェーズ — Cycle 14
// 手動追加シートの最寄り駅ピッカー統合 + 保存経路 + 履歴表示経路の回帰ガード
//
// 背景:
//   `manual_restaurant_add_sheet.dart` は WIP として StationSearchSheet 連携を
//   実装済み（_nearestStation / _pickStation / _save 内で ReservedRestaurant /
//   VisitedRestaurant の `nearestStation:` 引数に渡す）だが、テスト未整備。
//   本ファイルはコミット前に契約を凍結し、後続 Cycle で「駅未選択で空文字」
//   「保存経路が壊れる」「履歴表示が消える」等のリグレッションを検知する。
//
// スコープ:
//   [1] ソース静的検査 3 本（manual_restaurant_add_sheet.dart）
//       - _nearestStation フィールド + StationSearchSheet 連携が残っている
//       - _save() 内で ReservedRestaurant / VisitedRestaurant の双方に
//         nearestStation: を渡している
//       - UI に「最寄り駅（任意）」ラベルと Icons.train_rounded が出ている
//   [2] モデル契約 2 本
//       - ReservedRestaurant.nearestStation の JSON ラウンドトリップ
//       - VisitedRestaurant.nearestStation の JSON ラウンドトリップ
//   [3] history_screen ガード 1 本
//       - history_screen.dart が entry.nearestStation を UI 表示している
//         （表示経路の撤去・コメントアウトを検知）

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mannaka/models/reserved_restaurant.dart';
import 'package:mannaka/models/visited_restaurant.dart';

const _sheetPath = 'lib/widgets/manual_restaurant_add_sheet.dart';
const _historyPath = 'lib/screens/history_screen.dart';

String _readFile(String path) {
  final file = File(path);
  if (!file.existsSync()) {
    fail('$path が存在しません（非存在のまま PASS させると偽グリーンになる）');
  }
  return file.readAsStringSync();
}

void main() {
  // ── [1] ソース静的検査 × 3 ───────────────────────────────────────
  group('manual_restaurant_add_sheet.dart — StationSearchSheet 連携の静的検査',
      () {
    test(
        '最寄り駅 state と StationSearchSheet 呼び出しが残っているとき '
        'ピッカー機能は配線されている', () {
      final src = _readFile(_sheetPath);

      // StationSearchSheet を import している
      expect(
        src.contains("import 'station_search_sheet.dart'") ||
            src.contains('import \'package:mannaka/widgets/station_search_sheet.dart\''),
        isTrue,
        reason:
            'StationSearchSheet を import していません。'
            '駅ピッカーのボトムシートを他画面と同じ実装で揃えるため必須です。',
      );

      // 選択中の駅名を保持する state
      expect(
        RegExp(r'String\?\s+_nearestStation').hasMatch(src),
        isTrue,
        reason:
            '_nearestStation (String?) フィールドが見つかりません。'
            '駅未選択 null / 選択済み String の二値を取る state として必要です。',
      );

      // StationSearchSheet を showModalBottomSheet で開く関数
      expect(
        src.contains('StationSearchSheet'),
        isTrue,
        reason:
            'StationSearchSheet ウィジェットが呼ばれていません。'
            'お気に入り駅・全駅検索のフォールバックを他画面と共通化するため必須。',
      );
      expect(
        RegExp(r'showModalBottomSheet<SelectedStation>').hasMatch(src),
        isTrue,
        reason:
            'showModalBottomSheet<SelectedStation> の戻り値型指定が欠落。'
            '選択結果（駅名＋座標）を型安全に受け取るための契約。',
      );
    });

    test(
        '_save() が Reserved / Visited 双方に nearestStation: を渡すとき '
        '保存経路は駅名を欠落させない', () {
      final src = _readFile(_sheetPath);

      // ReservedRestaurant コンストラクタに nearestStation: が渡っている
      // （Reserved / Visited 両方の add 呼び出しで必ず渡すこと）
      final reservedCount = RegExp(r'ReservedRestaurant\s*\(')
          .allMatches(src)
          .length;
      final visitedCount = RegExp(r'VisitedRestaurant\s*\(')
          .allMatches(src)
          .length;
      expect(reservedCount, greaterThanOrEqualTo(1),
          reason: 'ReservedRestaurant コンストラクタ呼び出しが見つからない');
      expect(visitedCount, greaterThanOrEqualTo(1),
          reason: 'VisitedRestaurant コンストラクタ呼び出しが見つからない');

      // _save() の中身（AddTarget.reserved 分岐〜メソッド末尾）に
      // nearestStation: が 2 回以上（reserved + visited）出てくる
      final nearestStationArgs =
          RegExp(r'nearestStation\s*:\s*\w').allMatches(src).length;
      expect(
        nearestStationArgs,
        greaterThanOrEqualTo(2),
        reason:
            '_save() 内で nearestStation: 引数が 2 回未満です'
            '（reserved と visited の両分岐に必要）。\n'
            '手動追加した駅名が保存モデルまで到達しなくなっています。',
      );

      // 駅未選択（null）時は空文字に正規化して渡す（モデルは String 必須）
      expect(
        src.contains('_nearestStation ?? \'\'') ||
            src.contains('_nearestStation ?? ""'),
        isTrue,
        reason:
            '駅未選択時の null → "" 正規化が見つかりません。'
            'ReservedRestaurant.nearestStation は非 null String のため、'
            '未選択時は空文字で保存し "駅なし" を明示する必要があります。',
      );
    });

    test(
        'ピッカー UI に「最寄り駅（任意）」ラベルと Icons.train_rounded があるとき '
        'UI 契約（CLAUDE.md: Material Icons のみ / 任意入力である旨の明示）が守られている',
        () {
      final src = _readFile(_sheetPath);

      // ラベル文言
      expect(
        src.contains('最寄り駅（任意）'),
        isTrue,
        reason:
            '「最寄り駅（任意）」ラベルが見つかりません。'
            '必須入力と誤解されない文言で明示してください。',
      );

      // プレースホルダ文言（CLAUDE.md: 疑問形「?」禁止 → 命令形）
      expect(
        src.contains('駅を検索して選ぶ'),
        isTrue,
        reason:
            'プレースホルダ「駅を検索して選ぶ」が見つかりません。'
            'CLAUDE.md: UI テキストに「?」禁止 → 命令形で表示する必要があります。',
      );

      // Material Icon を使用（CLAUDE.md: 絵文字UIアイコン禁止）
      expect(
        src.contains('Icons.train_rounded') ||
            src.contains('Icons.directions_train') ||
            src.contains('Icons.subway') ||
            src.contains('Icons.train'),
        isTrue,
        reason:
            'Icons.train_rounded 等の Material Icon が使われていません。'
            'CLAUDE.md: 絵文字をUIアイコンとして使用禁止。',
      );

      // 疑問符（全角・半角）を含まない（CLAUDE.md UI Design Rules）
      // ピッカー関連ブロック内の文言に「?」「？」がないこと
      final forbiddenQuestion = RegExp(r'[?？]');
      final stationBlockStart = src.indexOf('最寄り駅（任意）');
      if (stationBlockStart >= 0) {
        // 最寄り駅ラベル直後 400 文字以内のブロックに対して検査
        final end = (stationBlockStart + 400).clamp(0, src.length);
        final block = src.substring(stationBlockStart, end);
        expect(
          forbiddenQuestion.hasMatch(block),
          isFalse,
          reason:
              '最寄り駅ピッカー周辺に「?」「？」が含まれています。'
              'CLAUDE.md UI Design Rules: 疑問形禁止。',
        );
      }
    });
  });

  // ── [2] モデル契約 × 2 ───────────────────────────────────────
  group('モデル契約 — nearestStation の保存/復元ラウンドトリップ', () {
    test(
        'ReservedRestaurant が nearestStation を受け取り toJson/fromJson で往復するとき '
        '駅名は欠落しない', () {
      final original = ReservedRestaurant(
        id: 'manual_123',
        restaurantName: 'まんぷく食堂',
        category: '居酒屋',
        reservedAt: DateTime(2026, 4, 23, 19, 0),
        groupNames: const ['同期'],
        nearestStation: '恵比寿',
      );

      final restored = ReservedRestaurant.fromJson(original.toJson());
      expect(restored.nearestStation, equals('恵比寿'),
          reason: 'ReservedRestaurant.nearestStation がラウンドトリップで欠落');
      expect(restored.restaurantName, equals('まんぷく食堂'));
      expect(restored.category, equals('居酒屋'));
      expect(restored.groupNames, equals(const ['同期']));

      // 駅未選択時（空文字）もラウンドトリップすること
      final noStation = ReservedRestaurant(
        id: 'manual_124',
        restaurantName: '名無し酒場',
        category: 'バー',
        reservedAt: DateTime(2026, 4, 23),
        nearestStation: '',
      );
      final restoredNoStation =
          ReservedRestaurant.fromJson(noStation.toJson());
      expect(restoredNoStation.nearestStation, equals(''),
          reason: '駅未選択（空文字）の ReservedRestaurant がラウンドトリップで壊れる');
    });

    test(
        'VisitedRestaurant が nearestStation を受け取り toJson/fromJson で往復するとき '
        '駅名は欠落しない', () {
      final original = VisitedRestaurant(
        id: 'manual_200',
        restaurantName: '坦々麺専門店',
        category: 'ラーメン',
        visitedAt: DateTime(2026, 4, 22, 12, 30),
        groupNames: const ['同僚', '学生時代'],
        nearestStation: '池袋',
      );

      final restored = VisitedRestaurant.fromJson(original.toJson());
      expect(restored.nearestStation, equals('池袋'),
          reason: 'VisitedRestaurant.nearestStation がラウンドトリップで欠落');
      expect(restored.restaurantName, equals('坦々麺専門店'));
      expect(restored.category, equals('ラーメン'));
      expect(restored.groupNames, equals(const ['同僚', '学生時代']));

      // 旧データ互換（nearestStation キーが JSON に無い場合、空文字で復元されること）
      final legacyJson = Map<String, dynamic>.from(original.toJson())
        ..remove('nearestStation');
      final legacyRestored = VisitedRestaurant.fromJson(legacyJson);
      expect(legacyRestored.nearestStation, equals(''),
          reason:
              'nearestStation キーが欠落した旧データを読み込むと空文字で復元されるべき'
              '（fromJson のデフォルト値契約）');
    });
  });

  // ── [3] history_screen 表示経路ガード × 1 ─────────────────────────
  group('history_screen.dart — nearestStation の表示経路ガード', () {
    test(
        'history_screen.dart が entry.nearestStation を Text に表示しているとき '
        '手動追加した駅名は履歴カードで見える', () {
      final src = _readFile(_historyPath);

      // 条件付き描画: `if (entry.nearestStation.isNotEmpty)` で空文字を非表示
      expect(
        RegExp(r'entry\.nearestStation\.isNotEmpty').hasMatch(src),
        isTrue,
        reason:
            'history_screen.dart に entry.nearestStation.isNotEmpty の条件分岐が無い。'
            '駅未選択（空文字）でもラベル枠が出る UX バグを招く。',
      );

      // 「〇〇駅」形式で Text に渡している
      expect(
        RegExp(r"\$\{entry\.nearestStation\}駅").hasMatch(src) ||
            src.contains(r"'${entry.nearestStation}駅'") ||
            src.contains(r'"${entry.nearestStation}駅"'),
        isTrue,
        reason:
            "history_screen.dart に '\${entry.nearestStation}駅' の Text が無い。"
            '手動追加した最寄り駅が履歴カードに表示されない回帰。',
      );

      // 駅アイコン（Icons.train_rounded）が nearestStation ブロックに併置
      expect(
        src.contains('Icons.train_rounded'),
        isTrue,
        reason:
            'history_screen.dart で駅アイコン（Icons.train_rounded）が使われていない。'
            'CLAUDE.md: Material Icons のみ使用。',
      );
    });
  });
}
