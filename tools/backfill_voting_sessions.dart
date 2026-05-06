// voting_sessions backfill CLI shell（薄い実行エントリ）。
//
// 役割は stdin / ファイルから JSON を読み、`runBackfillCli` に投げ、
// 結果の summary を stderr へ、正規化済み出力 JSON を stdout に流すだけ。
// 分類ロジックは `package:mannaka/tools/voting_sessions_backfill_logic.dart`
// に集約し、ここでは持たない（Cycle 42 / C13・C17 構造担保）。
//
// 運用（current_task.md / 2026-05-01）:
//   1. `gcloud firestore export gs://.../backup` でバックアップ
//   2. export を JSON へ変換し本 CLI に投入
//   3. dry-run: `dart run tools/backfill_voting_sessions.dart < input.json`
//   4. summary を確認し manualReview 件数を人手レビュー
//   5. `dart run tools/backfill_voting_sessions.dart --apply < input.json > output.json`
//   6. `gcloud firestore import` で書き戻し → rules deploy
//
// 依存追加ゼロ（CLAUDE.md）: dart:io / dart:convert / 内部 logic のみ。

import 'dart:convert';
import 'dart:io';

import 'package:mannaka/tools/voting_sessions_backfill_logic.dart';

Future<void> main(List<String> args) async {
  final inputJson = await _readAllStdin();
  final result = runBackfillCli(inputJson: inputJson, args: args);

  final summary = result.summary;
  if (summary != null) {
    stderr.writeln(
      'backfill summary: total=${summary.totalDocs} '
      'healthy=${summary.healthyDocs} '
      'truncate=${summary.truncateDocs} '
      'manualReview=${summary.manualReviewDocs}',
    );
    if (summary.truncateDocs > 0) {
      stderr.writeln('truncate doc ids: ${summary.truncateDocIds.join(", ")}');
    }
    if (summary.manualReviewDocs > 0) {
      stderr.writeln(
        'manualReview doc ids: ${summary.manualReviewDocIds.join(", ")}',
      );
    }
  }

  if (result.stderr.isNotEmpty) {
    stderr.writeln(result.stderr);
  }

  final out = result.outputJson;
  if (out != null) {
    stdout.writeln(out);
  }

  if (result.exitCode != 0) {
    exit(result.exitCode);
  }
}

Future<String> _readAllStdin() async {
  final buf = StringBuffer();
  await for (final chunk in stdin.transform(utf8.decoder)) {
    buf.write(chunk);
  }
  return buf.toString();
}
