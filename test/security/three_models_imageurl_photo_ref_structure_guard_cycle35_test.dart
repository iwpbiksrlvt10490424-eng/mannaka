// TDD Red フェーズ — Cycle 35: 3 モデル横断 imageUrl 素通し検出（構造ガード）
//
// 背景（Critic CRITICAL ISSUE-A / CLAUDE.md「同パターン全箇所一括修正」明示違反）:
//   Cycle 34 で `lib/models/restaurant.dart` の toJson は `PhotoRef.toRef` 経由に
//   修正されたが、同パターンの 3 モデル（HistoryRestaurant / VisitedRestaurant /
//   ReservedRestaurant）の toJson は `imageUrl` を素通ししたまま残っている。
//
//   将来また新しいモデルが `imageUrl: imageUrl` 素通しで追加されると同じ漏洩が
//   再発するため、`lib/` 配下を `Directory.listSync` で機械的に走査して
//   素通しパターンの検出をリグレッション防止する。
//
// 受入条件:
//   [A] `lib/` 配下の .dart ファイル全てを listSync で走査できる
//   [B] toJson() 内に `'imageUrl': imageUrl,` の素通しパターンが 1 件もない
//       （= 全箇所が `PhotoRef.toRef(imageUrl!)` 経由に修正されている）
//   [C] 走査結果が空ではない（テスト実装が壊れていないことの自己点検）
//
// 不変項:
//   - 既存テストファイル（`test/`）は対象外（テスト用ダミーは素通しでよい）
//   - 検索画面・詳細画面の Widget で `imageUrl` を build に渡す引数は対象外
//     （toJson の文脈ではない）
//
// 注意:
//   - 単純な substring マッチではなく「toJson 内」に限定するため、
//     ファイル全体のテキストに対して "toJson(" 〜 次の "}" ブロックを抽出する
//     ヒューリスティックを使う（正確な構文解析ではない）。
//   - 誤検知が出たら正規表現を絞る方向で修正する。

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Cycle 35: 3 モデル横断 imageUrl 素通し検出（lib/ 全 .dart 走査）', () {
    // ──────────────────────────────────────────────────────────────────
    // [A] / [C] 走査自体ができていることの自己点検
    // ──────────────────────────────────────────────────────────────────
    test('lib/ 配下に .dart ファイルが 1 件以上存在する（走査健全性）', () {
      final files = _collectDartFiles(Directory('lib'));
      expect(files, isNotEmpty,
          reason: 'lib/ から .dart ファイルが 1 つも収集できませんでした。'
              ' Directory.listSync の対象パスがズレていないか確認してください。');
    });

    // ──────────────────────────────────────────────────────────────────
    // [B] toJson 内に `'imageUrl': imageUrl,` 素通しが残っていない
    // ──────────────────────────────────────────────────────────────────
    test('toJson() 内に `imageUrl` 素通しパターンが lib/ 全体で 1 件もない', () {
      final files = _collectDartFiles(Directory('lib'));
      final violations = <String>[];

      for (final f in files) {
        final src = f.readAsStringSync();
        // toJson( ... ) ブロックを抽出して、その中だけ素通しを検査する。
        // ブロック境界はざっくり「toJson(」〜次の「factory」または class 末尾「}」までで
        // 切るが、実用上 toJson の中身は連続する `=> { ... };` か `{ ... }` なので
        // `toJson` 出現位置から 1500 文字までを対象とする。
        final blocks = _extractToJsonBlocks(src);
        for (final block in blocks) {
          // 素通し検出: 'imageUrl': imageUrl,  または  'imageUrl': imageUrl}
          // PhotoRef.toRef(imageUrl) を含む行は許可。
          for (final line in block.split('\n')) {
            final trimmed = line.trim();
            // 'imageUrl' のキー名でかつ値側に PhotoRef を含まないものを違反扱い
            final keyMatch = RegExp(r'''['"]imageUrl['"]\s*:''')
                .hasMatch(trimmed);
            if (!keyMatch) continue;
            if (trimmed.contains('PhotoRef.')) continue;
            // 値が null リテラルだけのケースは安全（保険）
            if (RegExp(r'''['"]imageUrl['"]\s*:\s*null\b''')
                .hasMatch(trimmed)) {
              continue;
            }
            violations.add('${f.path}: $trimmed');
          }
        }
      }

      expect(
        violations,
        isEmpty,
        reason: 'toJson() で `imageUrl` を PhotoRef.toRef を経由せず素通ししている箇所があります。\n'
            'Google Places の写真 URL はキーが末尾に付くため Firestore に書くと漏洩します。\n'
            '`PhotoRef.toRef(imageUrl!)` 経由に修正してください。\n'
            '違反箇所:\n${violations.map((s) => '  $s').join('\n')}',
      );
    });
  });
}

/// `lib/` ツリー全体から .dart ファイルを再帰収集する。
List<File> _collectDartFiles(Directory dir) {
  final res = <File>[];
  if (!dir.existsSync()) return res;
  for (final ent in dir.listSync(recursive: true, followLinks: false)) {
    if (ent is File && ent.path.endsWith('.dart')) {
      res.add(ent);
    }
  }
  return res;
}

/// ファイル全体から `toJson` メソッドのブロック相当を抽出する（ヒューリスティック）。
/// 完全な構文解析ではなく、`toJson(` 出現位置から 1500 文字までを 1 ブロックとして
/// 集める。誤検知が出たら個別にチューニングする。
List<String> _extractToJsonBlocks(String src) {
  final blocks = <String>[];
  final pattern = RegExp(r'toJson\s*\(');
  for (final m in pattern.allMatches(src)) {
    final start = m.start;
    final end = (start + 1500).clamp(0, src.length);
    blocks.add(src.substring(start, end));
  }
  return blocks;
}
