// TDD Red フェーズ — Cycle 42 / Security WARNING W-1（2 サイクル carry-over 終止）:
//   `lib/services/rating_enrichment_service.dart:265` の `developer.log` で
//   `$e` を直挿入している箇所を `${e.runtimeType}` に置き換える契約を構造担保する。
//
// 背景:
//   Photos URL 組み立て時に `?key=$apiKey` を埋める実装のため、
//   `HttpException` 系の例外メッセージがそのまま `e.toString()` に入ると
//   API キーがログに漏洩する経路がある。HotpepperService と同じ
//   `${e.runtimeType}` 化（Cycle 4〜6 の log_masking_test と同方針）で潰す。
//
// 設計:
//   - log_masking_test と同様、ソースファイルを行単位で読み、
//     `developer.log` を含む行に「$ の直後が { 以外」となる `$e` 様の
//     パターンが残っていないことを assert する。
//   - 同時に、`${e.runtimeType}` を使う行が少なくとも 1 行存在することを
//     assert（修正時に丸ごと削除しても気付ける逆向きガード）。

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('セキュリティ — rating_enrichment_service.dart の例外ログ漏洩防止 (W-1 / Cycle 42)', () {
    const path = 'lib/services/rating_enrichment_service.dart';

    test('[W-1-A] developer.log / debugPrint の行に生 \$e（API キーを含み得る）が無いとき例外メッセージは漏洩しない', () {
      final file = File(path);
      if (!file.existsSync()) {
        fail(
          '$path が存在しません。\n'
          'ファイルパスが正しいか確認してください（ファイル非存在 PASS は偽グリーン）。',
        );
      }

      final lines = file.readAsLinesSync();
      final violations = <String>[];

      // catch (e) ブロック内のログ呼び出しに着目する。
      // ただしソースを単純に「$e を含む行」で検出する：
      //   - `${e.runtimeType}` は `$` の直後が `{` なので除外される
      //   - `$e` 単体（変数 e 直接展開）のみ残骸として検出する
      final loggerRe = RegExp(r'developer\.log|debugPrint');
      final rawDollarERe = RegExp(r'\$e[^{a-zA-Z_]');

      for (var i = 0; i < lines.length; i++) {
        final line = lines[i];
        if (!loggerRe.hasMatch(line)) continue;
        if (rawDollarERe.hasMatch(line)) {
          violations.add('  L${i + 1}: ${line.trim()}');
        }
      }

      // 同 catch 節内（複数行ログ）で次の行に `$e` が残っているケースも検出。
      // log() の引数はカンマ区切りで次行に書かれるため、`developer.log(` 開始から
      // 対応する `)` までを線形に追って `$e` 単体を探す。
      var insideLog = false;
      var startLine = -1;
      var depth = 0;
      for (var i = 0; i < lines.length; i++) {
        final line = lines[i];
        if (!insideLog) {
          if (loggerRe.hasMatch(line) && line.contains('(')) {
            insideLog = true;
            startLine = i;
            depth = '('.allMatches(line).length - ')'.allMatches(line).length;
            if (rawDollarERe.hasMatch(line)) {
              final tag = '  L${i + 1} (in log block from L${startLine + 1}): ${line.trim()}';
              if (!violations.contains(tag)) violations.add(tag);
            }
            if (depth <= 0) insideLog = false;
          }
        } else {
          depth += '('.allMatches(line).length;
          depth -= ')'.allMatches(line).length;
          if (rawDollarERe.hasMatch(line)) {
            final tag = '  L${i + 1} (in log block from L${startLine + 1}): ${line.trim()}';
            if (!violations.contains(tag)) violations.add(tag);
          }
          if (depth <= 0) insideLog = false;
        }
      }

      expect(
        violations,
        isEmpty,
        reason:
            '$path で \$e を直接ログに展開しないでください。\n'
            'HotpepperService と同じく \${e.runtimeType} を使ってください。\n'
            'Place Photos URL に key=<APIKEY> を埋め込む実装のため、\n'
            'HttpException 系の例外メッセージで API キーがログに漏れる恐れがあります。\n'
            '違反行:\n${violations.join('\n')}',
      );
    });

    test('[W-1-B] catch 節のログには \${e.runtimeType} を使っている（修正の存在を逆向きに担保）', () {
      // \$e を全消ししただけで PASS させない。
      // HotpepperService と同じパターンが定着していることを構造的に確認する。
      final file = File(path);
      if (!file.existsSync()) {
        fail('$path が存在しません');
      }

      final src = file.readAsStringSync();
      expect(
        src.contains(r'${e.runtimeType}'),
        isTrue,
        reason:
            '$path の catch 節ログは \${e.runtimeType} を使うこと。\n'
            'HotpepperService:124-125 と統一する。',
      );
    });
  });
}
