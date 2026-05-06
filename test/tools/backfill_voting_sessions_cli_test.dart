// TDD Red フェーズ — Cycle 41 / Critic ISSUE-C1（MEDIUM）対応:
// CLI 層 `tools/backfill_voting_sessions.dart` の「dry-run 既定 / `--apply` 明示」
// 受け入れ条件を pure 関数 `parseBackfillCliFlags(args)` で機械担保する。
//
// 背景:
//   既存 Red は logic 層（classifyDoc / applyDocPlan / summarize）のみ。
//   CLI 引数解釈層が無契約のままだと「dry-run のはずが本番書き込みする」
//   事故を Red で防げない。current_task.md L13-14（C11）の Red をここで固定する。
//
// 設計:
//   CLI の主実行（Firestore 接続）と引数解釈を分離し、
//   `lib/tools/voting_sessions_backfill_logic.dart` に
//   `BackfillCliFlags parseBackfillCliFlags(List<String> args)` を export させる。
//   `tools/backfill_voting_sessions.dart` 本体はそれを呼んで Firestore に
//   接続するだけの薄い shell にし、本ファイルはロジックのみテストする。

import 'package:flutter_test/flutter_test.dart';
import 'package:mannaka/tools/voting_sessions_backfill_logic.dart';

void main() {
  group('parseBackfillCliFlags', () {
    test('[C11-1] 引数なし — dryRun=true（既定で書き込まない契約）', () {
      final flags = parseBackfillCliFlags(const <String>[]);
      expect(flags.dryRun, isTrue);
    });

    test('[C11-2] `--dry-run` 明示 — dryRun=true', () {
      final flags = parseBackfillCliFlags(const <String>['--dry-run']);
      expect(flags.dryRun, isTrue);
    });

    test('[C11-3] `--apply` 明示 — dryRun=false（書き込み実行モード）', () {
      final flags = parseBackfillCliFlags(const <String>['--apply']);
      expect(flags.dryRun, isFalse);
    });

    test('[C11-4] `--apply` と `--dry-run` 同時指定 — ArgumentError（曖昧フラグ拒否）', () {
      // Critic ISSUE-C1 の根因「dry-run のはずが書き込む事故」を構造的に潰す。
      // 同時指定は人間ミスの強い兆候なので、黙って片方を採用せず即停止させる。
      expect(
        () => parseBackfillCliFlags(const <String>['--apply', '--dry-run']),
        throwsArgumentError,
      );
    });

    test('[C11-5] 未知フラグ — ArgumentError（typo を黙って既定 dry-run にしない）', () {
      // `--aplly`（typo）が黙って dry-run 扱いされると、運用者は書き込んだつもりが
      // 何も起きない逆事故が起きる。typo は即停止させる。
      expect(
        () => parseBackfillCliFlags(const <String>['--aplly']),
        throwsArgumentError,
      );
    });

    test('[C11-6] BackfillCliFlags は `dryRun` を public フィールドとして公開する', () {
      // 構造ガード: CLI 出力ロジックが `flags.dryRun` を参照しても
      // 将来の rename / private 化を契約違反として検出する。
      final flags = parseBackfillCliFlags(const <String>[]);
      expect(flags, isA<BackfillCliFlags>());
      expect(flags.dryRun, isA<bool>());
    });
  });
}
