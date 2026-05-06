// TDD Red フェーズ — Cycle 34: 実 Google Places API テストの隔離ガード
//
// 背景（security_report.md ISSUE-2 / WARNING）:
//   `test/services/rating_enrichment_real_api_test.dart` が通常の `flutter test`
//   実行で実 Google Places API を叩き、`print()` で写真 URL の先頭 100 文字
//   （`...&key=...` を含み得る）を stdout に出していた。
//
// 受入条件:
//   [A] test() 呼び出しに `skip:` 引数があり、Platform.environment を参照している
//       （= 環境変数未設定なら通常 `flutter test` でスキップされる）
//   [B] ファイル内に imageUrls の substring を print する行が存在しない
//       （API キー文字列が stdout に流れる経路を絶つ）
//
// このテストの責務（source-level static guard）:
//   実 API テストを実際に走らせると課金/レイテンシが発生するため、
//   ソース文字列に対する構造ガードで隔離状態を機械的に担保する。
//
// 不変項（侵してはならない）:
//   - 実 API テスト自体は削除しない（手動実行で疎通確認できる状態を保つ）

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const _target = 'test/services/rating_enrichment_real_api_test.dart';

String _read() {
  final f = File(_target);
  if (!f.existsSync()) {
    fail(
      '$_target が存在しません。\n'
      'Cycle 34 のスコープでは実 API テストを **削除せず** 隔離する方針です。\n'
      'ファイルパスが変わった場合はこのテストも追従させてください。',
    );
  }
  return f.readAsStringSync();
}

void main() {
  group('Cycle 34: rating_enrichment_real_api_test.dart が通常 flutter test から隔離されている', () {
    // ──────────────────────────────────────────────────────────────────
    // [A] skip: 引数 + 環境変数ガード
    // ──────────────────────────────────────────────────────────────────
    test('test(...) に skip: 引数があり Platform.environment を参照している', () {
      final src = _read();

      // skip: 引数の存在
      expect(
        RegExp(r'skip\s*:').hasMatch(src),
        isTrue,
        reason: '$_target の test(...) 呼び出しに skip: 引数が見当たりません。\n'
            '環境変数（例: RUN_REAL_API_TESTS=1）が未設定の時は\n'
            'skip される構造にしてください。\n'
            '例: skip: Platform.environment[\'RUN_REAL_API_TESTS\'] == \'1\'\n'
            '          ? null\n'
            '          : \'Set RUN_REAL_API_TESTS=1 to run.\',',
      );

      // 環境変数判定の存在
      expect(
        src.contains('Platform.environment'),
        isTrue,
        reason: 'skip 判定に Platform.environment が使われていません。\n'
            '通常 `flutter test` で実 API が叩かれない状態にしてください。',
      );

      // dart:io の import（Platform を使うため必要）
      expect(
        RegExp(r"import\s+'dart:io'").hasMatch(src),
        isTrue,
        reason: 'Platform を使うには `import \'dart:io\';` が必要です。',
      );
    });

    // ──────────────────────────────────────────────────────────────────
    // [B] imageUrls の substring を print する行が存在しない
    // ──────────────────────────────────────────────────────────────────
    test('imageUrls[*].substring を print する行が一切存在しない（API キー漏洩防止）', () {
      final src = _read();
      final lines = src.split('\n');
      final violations = <String>[];

      for (var i = 0; i < lines.length; i++) {
        final line = lines[i];
        final hasPrint = line.contains('print(');
        // imageUrls[N].substring(...) を含む print 行を検出
        final hasUrlSubstr =
            RegExp(r'imageUrls\[[\w\s]*\]\s*\.\s*substring').hasMatch(line);
        if (hasPrint && hasUrlSubstr) {
          violations.add('L${i + 1}: ${line.trim()}');
        }
      }

      expect(
        violations,
        isEmpty,
        reason: '実 API テストで写真 URL の substring を stdout に出している行があります。\n'
            'URL には API キー（&key=...）が末尾に含まれるため、\n'
            'substring の長さによってはキーの一部または全体が stdout に流れます。\n'
            '長さで打ち切るのではなく、URL を表示しない（件数のみ print 等）に変更してください。\n'
            '違反箇所:\n${violations.map((s) => '  $s').join('\n')}',
      );
    });

    // ──────────────────────────────────────────────────────────────────
    // [C] スキップしてもテスト件数が落ちないこと（=ファイル削除されていない）
    //     === 手動実行手段を残しているか軽く確認 ===
    // ──────────────────────────────────────────────────────────────────
    test('実 API テスト本体は削除せず残っている（手動疎通確認用）', () {
      final src = _read();
      expect(
        src.contains('RatingEnrichmentService.enrich'),
        isTrue,
        reason: '実 API 疎通確認の本体（RatingEnrichmentService.enrich 呼び出し）が消えています。\n'
            'スキップ化はしても、手動実行で写真取得の疎通確認はできる状態を保ってください。',
      );
    });
  });
}
