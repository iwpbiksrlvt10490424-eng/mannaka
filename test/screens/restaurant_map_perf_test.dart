// TDD Red フェーズ
// Cycle 24: パフォーマンス最適化（地図画面）
//
// スコープ:
//   lib/widgets/restaurant_map.dart の MarkerLayer を RepaintBoundary でラップし、
//   静的ウィジェットに const を付与することで描画負荷を削減する。
//
// 受け入れ条件:
//   [1] MarkerLayer が RepaintBoundary で囲まれている
//   [2] 参加者ピン・重心・レストランの各 MarkerLayer がそれぞれ RepaintBoundary でラップされている
//   [3] RepaintBoundary の使用数が 3 以上である（3つの MarkerLayer に対応）

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  const targetFile = 'lib/widgets/restaurant_map.dart';

  group('地図ウィジェット — RepaintBoundary パフォーマンス最適化 (Cycle 24)', () {
    late List<String> lines;

    setUpAll(() {
      final file = File(targetFile);
      if (!file.existsSync()) {
        fail('$targetFile が存在しません。');
      }
      lines = file.readAsLinesSync();
    });

    // ─────────────────────────────────────────────────────────────────
    // テスト 1: RepaintBoundary が少なくとも 3 箇所使われているとき
    //           MarkerLayer ごとに描画キャッシュが有効になる
    // ─────────────────────────────────────────────────────────────────
    test(
      'RepaintBoundary が 3 つ以上存在するとき 各 MarkerLayer の描画が独立してキャッシュされる',
      () {
        final repaintCount = lines
            .where((l) => l.contains('RepaintBoundary('))
            .length;

        expect(
          repaintCount,
          greaterThanOrEqualTo(3),
          reason: 'lib/widgets/restaurant_map.dart に RepaintBoundary が $repaintCount 個しかありません。'
              '参加者・重心・レストランの 3 つの MarkerLayer をそれぞれ RepaintBoundary でラップしてください。',
        );
      },
    );

    // ─────────────────────────────────────────────────────────────────
    // テスト 2: RepaintBoundary が MarkerLayer の直前に現れるとき
    //           マーカー描画がフレームごとの再描画から保護される
    // ─────────────────────────────────────────────────────────────────
    test(
      'RepaintBoundary が MarkerLayer を child に持つとき マーカーレイヤーの再描画コストが削減される',
      () {
        // RepaintBoundary( ... child: MarkerLayer( パターンを検出
        // 連続行または同一行で RepaintBoundary の直後に MarkerLayer が来ることを確認
        bool foundWrappedMarker = false;

        for (var i = 0; i < lines.length - 1; i++) {
          final current = lines[i].trim();
          final next = lines[i + 1].trim();

          // パターン1: RepaintBoundary( が同行に child: MarkerLayer( を含む
          if (current.contains('RepaintBoundary(') &&
              current.contains('MarkerLayer(')) {
            foundWrappedMarker = true;
            break;
          }
          // パターン2: RepaintBoundary( の直後の行が child: MarkerLayer( または MarkerLayer(
          if (current.contains('RepaintBoundary(') &&
              (next.contains('MarkerLayer(') || next.contains('child: MarkerLayer('))) {
            foundWrappedMarker = true;
            break;
          }
          // パターン3: 数行以内に child: MarkerLayer が続く
          if (current.contains('RepaintBoundary(')) {
            for (var j = i + 1; j < lines.length && j <= i + 5; j++) {
              final inner = lines[j].trim();
              if (inner.contains('MarkerLayer(')) {
                foundWrappedMarker = true;
                break;
              }
              // 別の RepaintBoundary が来たら終了
              if (inner.contains('RepaintBoundary(')) break;
            }
            if (foundWrappedMarker) break;
          }
        }

        expect(
          foundWrappedMarker,
          isTrue,
          reason: 'RepaintBoundary( の子として MarkerLayer( が見つかりません。\n'
              'MarkerLayer を RepaintBoundary でラップしてください:\n'
              '  RepaintBoundary(\n'
              '    child: MarkerLayer(markers: [...]),\n'
              '  ),',
        );
      },
    );

    // ─────────────────────────────────────────────────────────────────
    // テスト 3: _TrianglePainter が const コンストラクタで生成されるとき
    //           参加者ピンマーカーの再ビルドコストが削減される
    // ─────────────────────────────────────────────────────────────────
    test(
      '_TrianglePainter が const で生成されるとき 参加者ピンの不要な再インスタンス化が抑制される',
      () {
        // _TrianglePainter( に対して const _TrianglePainter( が使われているか確認
        final nonConstTriangle = lines
            .where((l) =>
                l.contains('_TrianglePainter(') &&
                !l.trimLeft().startsWith('const') &&
                !l.contains('const _TrianglePainter(') &&
                !l.contains('class _TrianglePainter'))
            .toList();

        expect(
          nonConstTriangle,
          isEmpty,
          reason: '_TrianglePainter が const なしで使われています:\n'
              '${nonConstTriangle.join('\n')}\n'
              '`const _TrianglePainter(color: ...)` に変更してください。',
        );
      },
    );

    // ─────────────────────────────────────────────────────────────────
    // テスト 4: フィットボタンの Icon が const で生成されるとき
    //           静的アイコンの不要な再ビルドが防がれる
    // ─────────────────────────────────────────────────────────────────
    test(
      'zoom_out_map_rounded Icon が const で生成されるとき 静的アイコンが再ビルドされない',
      () {
        final zoomIconLines = lines
            .where((l) => l.contains('Icons.zoom_out_map_rounded'))
            .toList();

        expect(
          zoomIconLines,
          isNotEmpty,
          reason: 'Icons.zoom_out_map_rounded が $targetFile に見つかりません。',
        );

        final nonConstZoomIcon = zoomIconLines
            .where((l) =>
                !l.trimLeft().startsWith('const') &&
                !l.contains('const Icon'))
            .toList();

        expect(
          nonConstZoomIcon,
          isEmpty,
          reason: 'zoom_out_map_rounded の Icon が const なしで使われています:\n'
              '${nonConstZoomIcon.join('\n')}\n'
              '`const Icon(Icons.zoom_out_map_rounded, ...)` に変更してください。',
        );
      },
    );
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // Cycle 25: UIテキスト '?' 違反修正
  // 受け入れ条件:
  //   [1] フォールバック文字として '?' が使われていない
  //   [2] 代わりに Icons.person が使われている
  // ═══════════════════════════════════════════════════════════════════════════
  group('地図ウィジェット — UIテキスト違反修正 (Cycle 25)', () {
    late List<String> lines;

    setUpAll(() {
      final file = File(targetFile);
      if (!file.existsSync()) {
        fail('$targetFile が存在しません。');
      }
      lines = file.readAsLinesSync();
    });

    // ─────────────────────────────────────────────────────────────────
    // テスト 5: フォールバックとして '?' が使われていないとき
    //           UIテキスト禁止ルール（CLAUDE.md）に準拠している
    // ─────────────────────────────────────────────────────────────────
    test(
      "名前が空のときフォールバック文字 '?' が使われていないとき UIテキスト禁止ルールに準拠している",
      () {
        // ternary の値として '?' が文字列リテラルで使われている行を検出
        // 例: : '?', または ? '?' : など
        final questionMarkLines = lines
            .where((l) =>
                l.contains("'?'") &&
                !l.trimLeft().startsWith('//'))
            .toList();

        expect(
          questionMarkLines,
          isEmpty,
          reason: "CLAUDE.md「UIテキストに '?' 使用禁止」ルール違反。\n"
              "以下の行で '?' が使われています:\n"
              "${questionMarkLines.join('\n')}\n"
              "Icon(Icons.person, size: 14, color: Colors.white) に置き換えてください。",
        );
      },
    );

    // ─────────────────────────────────────────────────────────────────
    // テスト 6: Icons.person がフォールバックとして使われているとき
    //           名前なし参加者のピンにアイコンが表示される
    // ─────────────────────────────────────────────────────────────────
    test(
      '名前が空の参加者ピンに Icons.person が使われているとき 人物アイコンが表示される',
      () {
        final personIconLines = lines
            .where((l) =>
                l.contains('Icons.person') &&
                !l.trimLeft().startsWith('//'))
            .toList();

        expect(
          personIconLines,
          isNotEmpty,
          reason: '$targetFile に Icons.person が見つかりません。\n'
              "名前が空の参加者ピンのフォールバックとして"
              " Icon(Icons.person, size: 14, color: Colors.white) を使用してください。",
        );
      },
    );
  });
}
