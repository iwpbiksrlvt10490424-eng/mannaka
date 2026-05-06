/// voting_sessions backfill 純粋ロジック層。
///
/// firestore.rules deploy 前に既存 voting_sessions doc を分類・正規化するための
/// 副作用なし関数群。CLI shell (`tools/backfill_voting_sessions.dart`) と
/// Firestore I/O を分離するため、ここでは `Map<String, dynamic>` 入出力のみ扱う。
///
/// 設計（current_task.md / 2026-05-01）:
///   Q2 = X — voters.length が votes を超える場合は voters[0:votes] へ切り詰め
///   その他の不整合（voters.size() < votes / 旧スキーマ / 異常型 / 重複・空文字 /
///   votes < 0）は manualReview に倒し 1 バイト不変で素通す。
library;

import 'dart:convert';

enum BackfillAction { healthy, truncate, manualReview }

class CandidateBackfillPlan {
  CandidateBackfillPlan({
    required this.candidateIndex,
    required this.action,
    this.originalVotersSize,
    this.targetVotes,
    this.truncatedVoters,
  });

  final int candidateIndex;
  final BackfillAction action;
  final int? originalVotersSize;
  final int? targetVotes;
  final List<String>? truncatedVoters;
}

class DocBackfillPlan {
  DocBackfillPlan({
    required this.docId,
    required this.action,
    required this.perCandidate,
  });

  final String docId;
  final BackfillAction action;
  final List<CandidateBackfillPlan> perCandidate;
}

class BackfillSummary {
  BackfillSummary({
    required this.totalDocs,
    required this.healthyDocs,
    required this.truncateDocs,
    required this.manualReviewDocs,
    required this.healthyDocIds,
    required this.truncateDocIds,
    required this.manualReviewDocIds,
  });

  final int totalDocs;
  final int healthyDocs;
  final int truncateDocs;
  final int manualReviewDocs;
  final List<String> healthyDocIds;
  final List<String> truncateDocIds;
  final List<String> manualReviewDocIds;
}

class BackfillCliFlags {
  BackfillCliFlags({required this.dryRun});

  final bool dryRun;
}

DocBackfillPlan classifyDoc(String docId, Map<String, dynamic> doc) {
  // C23: candidates キー欠損は手動レビュー対象（運用者に明示的に拾わせる）。
  // 空配列扱いで healthy に倒すと「対象ゼロだから安全」と誤って rules を deploy する。
  if (!doc.containsKey('candidates')) {
    return DocBackfillPlan(
      docId: docId,
      action: BackfillAction.manualReview,
      perCandidate: const <CandidateBackfillPlan>[],
    );
  }
  final candidatesRaw = doc['candidates'];
  if (candidatesRaw is! List) {
    return DocBackfillPlan(
      docId: docId,
      action: BackfillAction.manualReview,
      perCandidate: const <CandidateBackfillPlan>[],
    );
  }

  final perCandidate = <CandidateBackfillPlan>[];
  for (var i = 0; i < candidatesRaw.length; i++) {
    final cand = candidatesRaw[i];
    // C19 / C19-2: 候補は Map<String, dynamic> でなければ TypeError を漏らさず
    // manualReview に倒す。Firestore 由来 Map<dynamic, dynamic> もここで弾く。
    if (cand is! Map<String, dynamic>) {
      perCandidate.add(CandidateBackfillPlan(
        candidateIndex: i,
        action: BackfillAction.manualReview,
      ));
      continue;
    }
    perCandidate.add(_classifyCandidate(i, cand));
  }

  final action = _aggregate(perCandidate);
  return DocBackfillPlan(docId: docId, action: action, perCandidate: perCandidate);
}

CandidateBackfillPlan _classifyCandidate(int index, Map<String, dynamic> cand) {
  final hasVoters = cand.containsKey('voters');
  final votesRaw = cand['votes'];

  if (!hasVoters || votesRaw is! int) {
    return CandidateBackfillPlan(
      candidateIndex: index,
      action: BackfillAction.manualReview,
    );
  }

  // C20 / C20-2: voters が List 以外の型のときは manualReview に倒す。
  // 強制 cast を残すと voters が String/Map のときに TypeError が漏出するため
  // `is List` の事前ガードを必ず通す。
  final votersRaw = cand['voters'];
  if (votersRaw is! List) {
    return CandidateBackfillPlan(
      candidateIndex: index,
      action: BackfillAction.manualReview,
    );
  }
  // C21 / C21-2: 要素全てが String でなければ manualReview。
  // lazy な要素キャストは後段 iteration で TypeError が漏出するので、
  // `every((v) => v is String)` の事前ガードで弾く。
  if (!votersRaw.every((v) => v is String)) {
    return CandidateBackfillPlan(
      candidateIndex: index,
      action: BackfillAction.manualReview,
    );
  }

  final votes = votesRaw;
  final voters = List<String>.from(votersRaw);

  if (votes < 0) {
    return CandidateBackfillPlan(
      candidateIndex: index,
      action: BackfillAction.manualReview,
      originalVotersSize: voters.length,
      targetVotes: votes,
    );
  }

  if (voters.any((v) => v.isEmpty) || voters.toSet().length != voters.length) {
    return CandidateBackfillPlan(
      candidateIndex: index,
      action: BackfillAction.manualReview,
      originalVotersSize: voters.length,
      targetVotes: votes,
    );
  }

  if (voters.length == votes) {
    return CandidateBackfillPlan(
      candidateIndex: index,
      action: BackfillAction.healthy,
      originalVotersSize: voters.length,
      targetVotes: votes,
    );
  }

  if (voters.length > votes) {
    return CandidateBackfillPlan(
      candidateIndex: index,
      action: BackfillAction.truncate,
      originalVotersSize: voters.length,
      targetVotes: votes,
      truncatedVoters: voters.sublist(0, votes),
    );
  }

  // voters.length < votes — 偽票方向の正規化は禁止
  return CandidateBackfillPlan(
    candidateIndex: index,
    action: BackfillAction.manualReview,
    originalVotersSize: voters.length,
    targetVotes: votes,
  );
}

BackfillAction _aggregate(List<CandidateBackfillPlan> perCandidate) {
  if (perCandidate.any((c) => c.action == BackfillAction.manualReview)) {
    return BackfillAction.manualReview;
  }
  if (perCandidate.any((c) => c.action == BackfillAction.truncate)) {
    return BackfillAction.truncate;
  }
  return BackfillAction.healthy;
}

Map<String, dynamic> applyDocPlan(
  Map<String, dynamic> doc,
  DocBackfillPlan plan,
) {
  if (plan.action != BackfillAction.truncate) {
    return doc;
  }

  final origCands = doc['candidates'] as List;
  final newCands = <Map<String, dynamic>>[];
  for (var i = 0; i < origCands.length; i++) {
    final orig = Map<String, dynamic>.from(origCands[i] as Map<String, dynamic>);
    final cp = plan.perCandidate[i];
    if (cp.action == BackfillAction.truncate) {
      orig['voters'] = List<String>.from(cp.truncatedVoters!);
    }
    newCands.add(orig);
  }
  final result = Map<String, dynamic>.from(doc);
  result['candidates'] = newCands;
  return result;
}

BackfillSummary summarize(List<DocBackfillPlan> results) {
  final healthyIds = <String>[];
  final truncateIds = <String>[];
  final manualIds = <String>[];
  for (final r in results) {
    switch (r.action) {
      case BackfillAction.healthy:
        healthyIds.add(r.docId);
      case BackfillAction.truncate:
        truncateIds.add(r.docId);
      case BackfillAction.manualReview:
        manualIds.add(r.docId);
    }
  }
  return BackfillSummary(
    totalDocs: results.length,
    healthyDocs: healthyIds.length,
    truncateDocs: truncateIds.length,
    manualReviewDocs: manualIds.length,
    healthyDocIds: healthyIds,
    truncateDocIds: truncateIds,
    manualReviewDocIds: manualIds,
  );
}

BackfillCliFlags parseBackfillCliFlags(List<String> args) {
  const known = {'--dry-run', '--apply'};
  for (final a in args) {
    if (!known.contains(a)) {
      throw ArgumentError('Unknown flag: $a');
    }
  }
  final hasApply = args.contains('--apply');
  final hasDryRun = args.contains('--dry-run');
  if (hasApply && hasDryRun) {
    throw ArgumentError('--apply and --dry-run are mutually exclusive');
  }
  return BackfillCliFlags(dryRun: !hasApply);
}

/// CLI 層の実行結果。`runBackfillCli` の返り値。
///
/// CLI shell（`tools/backfill_voting_sessions.dart`）はこの構造体の
/// `exitCode` を `exit(...)` に渡し、`outputJson` を stdout に、
/// `stderr` を stderr に流すだけの薄い層であること。
class BackfillCliResult {
  BackfillCliResult({
    required this.exitCode,
    this.summary,
    this.outputJson,
    this.stderr = '',
  });

  final int exitCode;
  final BackfillSummary? summary;
  final String? outputJson;
  final String stderr;
}

/// JSON I/O ベースの backfill ランナー。Firestore I/O を持たないため
/// テスト容易性が高く、CLI shell は `dart:io` で stdin/file をつなぐだけで済む。
///
/// 入力 JSON は `{ "docs": [ { "id": "...", "data": {...} }, ... ] }` 形式。
/// dry-run 既定で `outputJson` は null（書き込み JSON を生成しない）。
/// `--apply` 指定時のみ正規化済み JSON を `outputJson` に返す。
BackfillCliResult runBackfillCli({
  required String inputJson,
  required List<String> args,
}) {
  final BackfillCliFlags flags;
  try {
    flags = parseBackfillCliFlags(args);
  } on ArgumentError catch (e) {
    return BackfillCliResult(
      exitCode: 64,
      stderr: 'invalid arguments: ${e.message}',
    );
  }

  final Map<String, dynamic> input;
  try {
    final decoded = jsonDecode(inputJson);
    if (decoded is! Map<String, dynamic>) {
      return BackfillCliResult(
        exitCode: 65,
        stderr: 'input JSON root must be an object',
      );
    }
    input = decoded;
  } on FormatException catch (e) {
    return BackfillCliResult(
      exitCode: 65,
      stderr: 'failed to parse input JSON: ${e.message}',
    );
  }

  final docsRaw = input['docs'];
  if (docsRaw is! List) {
    return BackfillCliResult(
      exitCode: 65,
      stderr: 'input JSON missing required "docs" array',
    );
  }

  final ids = <String>[];
  final datas = <Map<String, dynamic>>[];
  final plans = <DocBackfillPlan>[];
  for (final entry in docsRaw) {
    if (entry is! Map<String, dynamic>) {
      return BackfillCliResult(
        exitCode: 65,
        stderr: 'each entry in "docs" must be an object with id/data',
      );
    }
    final id = entry['id'];
    final data = entry['data'];
    if (id is! String || data is! Map<String, dynamic>) {
      return BackfillCliResult(
        exitCode: 65,
        stderr: 'each entry in "docs" must have string "id" and object "data"',
      );
    }
    ids.add(id);
    datas.add(data);
    plans.add(classifyDoc(id, data));
  }

  final summary = summarize(plans);

  String? outputJsonStr;
  if (!flags.dryRun) {
    final outDocs = <Map<String, dynamic>>[];
    for (var i = 0; i < datas.length; i++) {
      outDocs.add(<String, dynamic>{
        'id': ids[i],
        'data': applyDocPlan(datas[i], plans[i]),
      });
    }
    outputJsonStr = jsonEncode(<String, dynamic>{'docs': outDocs});
  }

  return BackfillCliResult(
    exitCode: 0,
    summary: summary,
    outputJson: outputJsonStr,
  );
}
