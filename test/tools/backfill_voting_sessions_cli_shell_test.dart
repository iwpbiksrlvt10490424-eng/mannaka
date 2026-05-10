// TDD Red フェーズ — Cycle 44 / ISSUE-Q2 対応:
// `tools/backfill_voting_sessions.dart` の CLI shell（stdin / exit / stdout / stderr 経路）
// が一度も実行されないまま carry-over していたため、shell wiring 退化を
// `Process.run` 統合テストで構造的に担保する。
//
// 背景（review_feedback.md / qa_report.md / 2026-05-07）:
//   Cycle 43 の logic 層 (`runBackfillCli`) は in-memory で十分テストされているが、
//   shell 本体（`main()` の stdin 読込・summary stderr 出力・exit code・--apply の
//   stdout JSON 出力）は一度もプロセス起動されたことがない。CLI shell が
//   logic 層を素通しで呼ぶだけだとしても、stdin / exit / stdout の wiring を
//   無契約のまま放置すると将来 1 行の手違い（exit を呼び忘れる、stdout/stderr
//   を逆にする等）で運用事故が起きる。
//
// このファイルが固定する契約:
//   CLI-S1 dry-run 既定        → exit 0 / stderr に summary / stdout は空
//   CLI-S2 --apply             → exit 0 / stdout に正規化済み JSON / stderr に summary
//   CLI-S3 --apply --dry-run   → exit 64 / stderr に invalid arguments
//   CLI-S4 不正な入力 JSON      → exit 65 / stderr に failed to parse
//
//   shell 本体 (`tools/backfill_voting_sessions.dart`) のシグネチャは不変。
//
// 注意:
//   `Process.run` で `dart run tools/backfill_voting_sessions.dart` を起動するため
//   実行時間がローカルで数秒かかる。`@Timeout` で余裕を持たせる。

@Timeout(Duration(minutes: 2))
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  // 全ケースで共有する healthy doc 入力（runBackfillCli が確実に exit 0 を返すペイロード）
  String mkInput() {
    return jsonEncode(<String, dynamic>{
      'docs': <Map<String, dynamic>>[
        <String, dynamic>{
          'id': 'd1',
          'data': <String, dynamic>{
            'candidates': <Map<String, dynamic>>[
              <String, dynamic>{
                'id': 'A',
                'name': 'Restaurant A',
                'category': 'cafe',
                'priceStr': '~¥1000',
                'address': 'Tokyo',
                'imageUrl': '',
                'voters': <String>['u1'],
                'votes': 1,
              },
            ],
          },
        },
      ],
    });
  }

  Future<ProcessResult> runShell(String inputJson, List<String> args) async {
    // CWD はプロジェクトルートで起動される前提（flutter test の挙動）。
    final proc = await Process.start(
      'dart',
      <String>['run', 'tools/backfill_voting_sessions.dart', ...args],
    );
    proc.stdin.add(utf8.encode(inputJson));
    await proc.stdin.close();

    final stdoutFuture = proc.stdout.transform(utf8.decoder).join();
    final stderrFuture = proc.stderr.transform(utf8.decoder).join();
    final exitCode = await proc.exitCode;
    final out = await stdoutFuture;
    final err = await stderrFuture;
    return ProcessResult(proc.pid, exitCode, out, err);
  }

  group('backfill CLI shell — Process.run 統合 (Cycle 44 / ISSUE-Q2)', () {
    test('[CLI-S1] 引数なし (dry-run 既定) — exit 0 / stderr に summary / stdout 空', () async {
      final res = await runShell(mkInput(), const <String>[]);

      expect(res.exitCode, 0,
          reason: 'dry-run 既定で healthy doc → exit 0 で完走\nstdout=${res.stdout}\nstderr=${res.stderr}');
      // stderr に backfill summary 行が出ること
      expect(
        (res.stderr as String),
        contains('backfill summary:'),
        reason: 'CLI shell は summary を stderr に書き出すこと',
      );
      expect((res.stderr as String), contains('total=1'));
      expect((res.stderr as String), contains('healthy=1'));
      // dry-run なので stdout に書き込み JSON を出さない
      expect(
        (res.stdout as String).trim(),
        isEmpty,
        reason: 'dry-run 既定では stdout に出力 JSON を書かない',
      );
    });

    test('[CLI-S2] --apply — exit 0 / stdout に正規化済み JSON / stderr に summary', () async {
      final res = await runShell(mkInput(), const <String>['--apply']);

      expect(res.exitCode, 0,
          reason: '--apply で healthy doc → exit 0\nstdout=${res.stdout}\nstderr=${res.stderr}');
      expect((res.stderr as String), contains('backfill summary:'));

      // stdout は JSON で、`docs` 配列を持ち id/data が保たれていること
      final stdoutStr = (res.stdout as String).trim();
      expect(stdoutStr, isNotEmpty, reason: '--apply 時 stdout に出力 JSON が出ること');
      final decoded = jsonDecode(stdoutStr);
      expect(decoded, isA<Map<String, dynamic>>());
      final docs = (decoded as Map<String, dynamic>)['docs'];
      expect(docs, isA<List>());
      expect((docs as List).length, 1);
      final d0 = docs.first as Map<String, dynamic>;
      expect(d0['id'], 'd1');
      expect(d0['data'], isA<Map<String, dynamic>>());
    });

    test('[CLI-S3] --apply と --dry-run 同時指定 — exit 64 / stderr に invalid arguments', () async {
      final res = await runShell(mkInput(), const <String>['--apply', '--dry-run']);

      expect(res.exitCode, 64,
          reason: '矛盾フラグは ArgumentError → exit 64 (sysexits.h EX_USAGE)\nstderr=${res.stderr}');
      expect(
        (res.stderr as String),
        contains('invalid arguments'),
        reason: 'shell は ArgumentError 由来メッセージを stderr に流す',
      );
      // 失敗時は stdout に何も書かない
      expect((res.stdout as String).trim(), isEmpty);
    });

    test('[CLI-S4] 不正な入力 JSON — exit 65 / stderr に failed to parse', () async {
      final res = await runShell('this is not json {', const <String>[]);

      expect(res.exitCode, 65,
          reason: 'JSON parse 失敗は exit 65 (sysexits.h EX_DATAERR)\nstderr=${res.stderr}');
      expect(
        (res.stderr as String),
        contains('failed to parse'),
        reason: 'shell は parse 失敗メッセージを stderr に流す',
      );
      expect((res.stdout as String).trim(), isEmpty);
    });
  });
}
