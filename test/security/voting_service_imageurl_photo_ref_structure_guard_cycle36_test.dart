// TDD Red フェーズ — Cycle 36: lib/ 全域 Map リテラル `'imageUrl':` の PhotoRef.toRef ラップ強制
//
// 背景（Critic CRITICAL — Cycle 35 構造ガードの設計上の盲点）:
//   Cycle 35 の構造ガード（`three_models_imageurl_photo_ref_structure_guard_cycle35_test.dart`）
//   は `toJson(` 出現位置から 1500 文字までを抽出する設計のため、
//   サービス層（例: `voting_service.dart` の `createSession` 内 Map リテラル）の
//   素通しを **構造的に検出できない**。
//
//   結果として `lib/services/voting_service.dart:25`
//     'imageUrl': s.restaurant.imageUrl ?? '',
//   が PhotoRef.toRef を経由せず Firestore に書き込まれており、
//   `voting_sessions/{id}.candidates[].imageUrl` 経由で API キーが第三者に
//   到達する経路が残った。
//
// このファイルの責務:
//   - Cycle 35 の toJson 限定ガードを補完し、`lib/` 配下の **全 .dart ファイル** に
//     現れる Map リテラル `'imageUrl':` キーが、必ず以下のいずれかであることを assert:
//       (1) 値が `PhotoRef.toRef(...)` を経由している
//       (2) 値が `null` リテラル
//   - これにより、サービス層・Provider 層・モデル層を問わず、新しいファイルが
//     追加されても素通し回帰を機械検出できる。
//
// 受入条件:
//   [A] lib/ 配下に .dart ファイルが 1 件以上収集できる（自己点検）
//   [B] Map リテラル `'imageUrl':` の値が PhotoRef.toRef または null 以外の箇所が 0 件
//
// 不変項:
//   - Widget の named parameter `imageUrl: ...`（クォート無し）は対象外
//     （Map リテラルではないため）
//   - テストファイル（`test/`）は対象外
//   - コメント行 `//` で始まる行は対象外
//
// 注意:
//   - 単純な substring マッチではなく `RegExp(r'''['\"]imageUrl['\"]\s*:''')` で
//     クォート付きキーのみを対象とする（=Map リテラル限定）。
//   - `?? ''` のようなフォールバック式は値が API キーを含み得るので **違反扱い**。
//     PhotoRef.toRef(value ?? '') のように外側でラップする必要がある。

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Cycle 36: lib/ 全域 Map リテラル `\'imageUrl\':` PhotoRef.toRef ラップ強制', () {
    // ──────────────────────────────────────────────────────────────────
    // [A] 走査自体ができていることの自己点検
    // ──────────────────────────────────────────────────────────────────
    test('lib/ 配下に .dart ファイルが 1 件以上存在する（走査健全性）', () {
      final files = _collectDartFiles(Directory('lib'));
      expect(files, isNotEmpty,
          reason: 'lib/ から .dart ファイルが 1 つも収集できませんでした。');
    });

    // ──────────────────────────────────────────────────────────────────
    // [B] 全 Map リテラル `'imageUrl':` が PhotoRef.toRef 経由または null
    // ──────────────────────────────────────────────────────────────────
    test('Map リテラル `\'imageUrl\':` の値が PhotoRef.toRef 経由でない箇所が 0 件', () {
      final files = _collectDartFiles(Directory('lib'));
      final violations = <String>[];

      // クォート付きキー `'imageUrl':` または `"imageUrl":` を Map リテラルとして検出
      final keyPattern = RegExp(r'''['"]imageUrl['"]\s*:''');

      for (final f in files) {
        final lines = f.readAsLinesSync();
        for (var i = 0; i < lines.length; i++) {
          final line = lines[i];
          final trimmed = line.trim();
          if (trimmed.startsWith('//')) continue;
          if (!keyPattern.hasMatch(trimmed)) continue;

          // 許可パターン (1): PhotoRef.toRef(...) を含む
          if (trimmed.contains('PhotoRef.toRef(')) continue;

          // 許可パターン (2): 値が null リテラル
          //   `'imageUrl': null` の形のみ許可（`?? null` 等の式は混入し得るので厳格に）
          if (RegExp(r'''['"]imageUrl['"]\s*:\s*null\s*[,}]''').hasMatch(trimmed)) {
            continue;
          }

          violations.add('${f.path}:${i + 1}: $trimmed');
        }
      }

      expect(
        violations,
        isEmpty,
        reason: 'Map リテラル `\'imageUrl\':` の値が PhotoRef.toRef を経由せず、\n'
            'かつ null リテラルでもない箇所があります。\n\n'
            '`Restaurant.imageUrl` には Hotpepper / Google Places / 空文字が混在し得るため、\n'
            'Firestore へ書き出す前に必ず `PhotoRef.toRef(...)` で正規化する必要があります。\n'
            '(Google Places の URL は末尾に `&key=<apiKey>` を含むため。)\n\n'
            '修正例:\n'
            '  // 修正前\n'
            '  \'imageUrl\': s.restaurant.imageUrl ?? \'\',\n'
            '  // 修正後\n'
            '  \'imageUrl\': PhotoRef.toRef(s.restaurant.imageUrl ?? \'\'),\n\n'
            '違反箇所:\n'
            '${violations.map((v) => '  $v').join('\n')}',
      );
    });
  });
}

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
