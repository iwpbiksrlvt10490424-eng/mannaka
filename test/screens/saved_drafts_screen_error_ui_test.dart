// TDD Red フェーズ
// Cycle 16 残件: saved_drafts_screen.dart の
//   1. error UI を empty UI から分離（ISSUE 1: error: (_, __) => _empty() 問題）
//   2. Aimachi ブランド残骸除去（L151「Aimachi（無料）」/ L152 ハードコード App Store URL）
// を静的＋Widget 両面で担保する。
//
// 現状:
//   - L30: `error: (_, __) => _empty()` → AsyncError 時に「保存した候補はありません」が表示され
//     ユーザーが 0 件と誤認。再保存で既存下書きが上書き消失する入口になっている（データ損失リスク）。
//   - L151: `'あなたもAimachi（無料）で同じ条件のお店を探してみましょう👇'` → Cycle 11〜13 で
//     全域「まんなか」統一済のはずが漏れている。
//   - L152: `'https://apps.apple.com/jp/app/aimachi/id6761008332'` → `ShareUtils.appStoreUrl`
//     への一元化が漏れており、App Store ID が変わると追従し忘れる危険。
//
// 修正方針（feature-implementer への引き継ぎ）:
//   A. saved_drafts_screen.dart の `draftsAsync.when(error: ...)` を `_empty()` から
//      エラー専用 UI（例: `_errorUi()` 等の別メソッド）へ分岐させる。
//      - アイコン: `Icons.error_outline_rounded`（empty の bookmark_border_rounded と必ず別物）
//      - 見出し: 「読み込みに失敗しました」等の失敗文言（空状態「保存した候補はありません」と重複禁止）
//      - リトライ UI は本サイクルでは作らない（UX 設計が必要なため別サイクル）
//   B. L151 の UI テキストから `Aimachi` を除去し `まんなか` に統一する（App Store URL の
//      slug "aimachi" は URL 仕様上残してよいが、UI 向け文字列には残さない）。
//   C. L152 のハードコード URL を `ShareUtils.appStoreUrl` に置換する（既に `share_utils.dart`
//      import 済の前提。未 import なら import 文も追加）。
//
// スコープ外:
//   - エラー時のリトライボタン（`ref.invalidate` 呼出）の UX 設計
//   - `share_utils.dart` 側の `Aimachi` 残骸（別サイクルで対応）

import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mannaka/models/saved_share_draft.dart';
import 'package:mannaka/providers/saved_share_drafts_provider.dart';
import 'package:mannaka/screens/saved_drafts_screen.dart';

const _targetFile = 'lib/screens/saved_drafts_screen.dart';

String _readSource() {
  final file = File(_targetFile);
  if (!file.existsSync()) {
    fail('$_targetFile が存在しません。ファイルパスが変わっていないか確認してください。');
  }
  return file.readAsStringSync();
}

// ─── AsyncNotifier スタブ（AsyncLoading / AsyncError / AsyncData を人為的に作る）
// AsyncNotifierProvider.overrideWith は同一 Notifier 型を要求するため
// SavedShareDraftsNotifier を継承する。add/remove は本テストでは触らない。

class _LoadingStubNotifier extends SavedShareDraftsNotifier {
  @override
  Future<List<SavedShareDraft>> build() {
    // 永続的に pending。state は AsyncLoading のまま。
    return Completer<List<SavedShareDraft>>().future;
  }
}

class _ErrorStubNotifier extends SavedShareDraftsNotifier {
  @override
  Future<List<SavedShareDraft>> build() async {
    throw Exception('simulated load failure');
  }
}

class _EmptyDataStubNotifier extends SavedShareDraftsNotifier {
  @override
  Future<List<SavedShareDraft>> build() async => const [];
}

class _DataStubNotifier extends SavedShareDraftsNotifier {
  _DataStubNotifier(this._items);
  final List<SavedShareDraft> _items;
  @override
  Future<List<SavedShareDraft>> build() async => _items;
}

SavedShareDraft _draft(String id) => SavedShareDraft(
      id: id,
      createdAt: DateTime(2026, 4, 24, 12, 0),
      stationName: '渋谷',
      date: '',
      meetingTime: '',
      participantTimes: const {},
      candidates: const [],
      note: 'memo-$id',
    );

Widget _wrap({required List<Override> overrides}) {
  return ProviderScope(
    overrides: overrides,
    child: const MaterialApp(
      home: SavedDraftsScreen(),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // ══════════════════════════════════════════════════════════════════════
  // [1] Widget 回帰テスト（error UI が empty UI から分離されていること）
  // ══════════════════════════════════════════════════════════════════════

  group('SavedDraftsScreen — AsyncValue 分岐ごとの UI 表示', () {
    testWidgets('loading 状態のとき CircularProgressIndicator だけが表示される', (tester) async {
      await tester.pumpWidget(_wrap(overrides: [
        savedShareDraftsProvider.overrideWith(() => _LoadingStubNotifier()),
      ]));
      // pumpAndSettle は loading が永続するため使わない
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget,
          reason: 'loading 状態で進捗インジケータが表示されていない');
      expect(find.text('保存した候補はありません'), findsNothing,
          reason: 'loading 中に empty 文言が漏れ出ていないこと');
      expect(find.byIcon(Icons.error_outline_rounded), findsNothing,
          reason: 'loading 中に error UI が漏れ出ていないこと');
    });

    testWidgets('data(空) 状態のとき empty UI（bookmark_border_rounded + 固定文言）が表示される',
        (tester) async {
      await tester.pumpWidget(_wrap(overrides: [
        savedShareDraftsProvider.overrideWith(() => _EmptyDataStubNotifier()),
      ]));
      await tester.pump(); // build() の await 完了を 1 フレーム進める
      await tester.pump();

      expect(find.byIcon(Icons.bookmark_border_rounded), findsOneWidget,
          reason: '空状態の bookmark アイコンが表示されていない');
      expect(find.text('保存した候補はありません'), findsOneWidget,
          reason: '空状態の固定文言が表示されていない');
      expect(find.byIcon(Icons.error_outline_rounded), findsNothing,
          reason: '空状態では error UI のアイコンが出てはいけない');
    });

    testWidgets('error 状態のとき empty UI ではなく error 専用 UI が表示される（ISSUE 1 の本丸）',
        (tester) async {
      await tester.pumpWidget(_wrap(overrides: [
        savedShareDraftsProvider.overrideWith(() => _ErrorStubNotifier()),
      ]));
      await tester.pump(); // build() の throw を 1 フレーム消化
      await tester.pump();

      // 現行実装は error: (_, __) => _empty() のため、ここで
      //   - bookmark_border_rounded アイコンが出る
      //   - 「保存した候補はありません」が出る
      // という「empty と同一 UI」が表示されてテストが FAIL する。
      expect(
        find.text('保存した候補はありません'),
        findsNothing,
        reason: 'error 時に empty の文言（保存した候補はありません）を流用してはいけない。'
            'ユーザーが 0 件と誤認し、再保存で既存データを上書き消失する入口になる。',
      );
      expect(
        find.byIcon(Icons.bookmark_border_rounded),
        findsNothing,
        reason: 'error 時に empty のアイコン（bookmark_border_rounded）を流用してはいけない。',
      );

      // error 専用 UI のアイコン（error_outline_rounded）が出ていること。
      expect(
        find.byIcon(Icons.error_outline_rounded),
        findsOneWidget,
        reason: 'error 状態では Icons.error_outline_rounded で失敗を明示すること。',
      );
    });

    testWidgets('data(非空) 状態のとき ListView と保存下書きカードが表示される', (tester) async {
      await tester.pumpWidget(_wrap(overrides: [
        savedShareDraftsProvider
            .overrideWith(() => _DataStubNotifier([_draft('a'), _draft('b')])),
      ]));
      await tester.pump();
      await tester.pump();

      expect(find.byType(ListView), findsOneWidget,
          reason: '非空 data 状態で ListView が描画されていない');
      expect(find.textContaining('渋谷駅'), findsWidgets,
          reason: '保存済み下書きのヘッダテキストが見当たらない');
      expect(find.text('保存した候補はありません'), findsNothing,
          reason: '非空 data 状態で empty 文言が漏れ出ていないこと');
      expect(find.byIcon(Icons.error_outline_rounded), findsNothing,
          reason: '非空 data 状態で error UI が漏れ出ていないこと');
    });
  });

  // ══════════════════════════════════════════════════════════════════════
  // [2] ソース静的契約（error 分岐が _empty に戻らないことのガード）
  // ══════════════════════════════════════════════════════════════════════

  group('saved_drafts_screen.dart ソース契約 — error 分岐が empty から独立', () {
    test('when() の error コールバックが _empty() を直接返していないこと', () {
      final src = _readSource();

      // 現行実装: `error: (_, __) => _empty(),`
      // 修正後は _empty() 以外の専用 Widget（例 _errorUi()）へ分岐する。
      final violates = RegExp(
        r'error\s*:\s*\(\s*_\s*,\s*_{1,2}\s*\)\s*=>\s*_empty\s*\(\s*\)',
      ).hasMatch(src);

      expect(
        violates,
        isFalse,
        reason: 'draftsAsync.when(error: ...) が _empty() を返したままです。\n'
            'AsyncError を「0 件」と見せかけるとユーザーが再保存し既存下書きが上書き消失します。\n'
            '専用のエラー UI（例: _errorUi()）に分岐させてください。',
      );
    });

    test('エラー専用 UI として error_outline_rounded アイコンがソースに記述されていること', () {
      final src = _readSource();

      expect(
        src.contains('Icons.error_outline_rounded'),
        isTrue,
        reason: 'saved_drafts_screen.dart に Icons.error_outline_rounded が見当たりません。\n'
            'エラー UI と空 UI を視覚的に区別するため error_outline_rounded を使ってください。',
      );
    });
  });

  // ══════════════════════════════════════════════════════════════════════
  // [3] ソース静的契約（Aimachi ブランド残骸の除去）
  // ══════════════════════════════════════════════════════════════════════

  group('saved_drafts_screen.dart ソース契約 — Aimachi ブランド残骸除去', () {
    test('UI 文字列に大文字 "Aimachi" が残っていないこと', () {
      final src = _readSource();

      // UI に向けた日本語ブランド表記は「まんなか」に統一済み（Cycle 11〜13）。
      // URL slug 'aimachi'（小文字）は appStoreUrl 経由で参照するため、この判定は
      // 「大文字 A で始まる Aimachi」トークンのみ検出する。
      final matches = RegExp(r'Aimachi').allMatches(src).toList();

      expect(
        matches,
        isEmpty,
        reason: 'saved_drafts_screen.dart に "Aimachi" が残っています（検出数: ${matches.length}）。\n'
            'UI 向けブランド名は「まんなか」に統一してください（Cycle 11〜13 の規約）。',
      );
    });

    test('App Store URL がハードコードされていないこと（id6761008332 直書き禁止）', () {
      final src = _readSource();

      expect(
        src.contains('id6761008332'),
        isFalse,
        reason: 'saved_drafts_screen.dart に App Store ID "id6761008332" が直書きされています。\n'
            'ShareUtils.appStoreUrl を参照してください（URL 一元管理の規約）。',
      );
      expect(
        src.contains('apps.apple.com/jp/app/aimachi'),
        isFalse,
        reason: 'saved_drafts_screen.dart に App Store URL が直書きされています。\n'
            'ShareUtils.appStoreUrl を参照してください。',
      );
    });

    test('ShareUtils.appStoreUrl を参照していること（一元化の Green 基準）', () {
      final src = _readSource();

      expect(
        src.contains('ShareUtils.appStoreUrl'),
        isTrue,
        reason: 'ShareUtils.appStoreUrl を参照していません。\n'
            'LINE 本文の App Store 誘導 URL は ShareUtils.appStoreUrl 経由で差し込んでください。',
      );
      expect(
        src.contains("import '../utils/share_utils.dart'"),
        isTrue,
        reason: 'share_utils.dart の import が見当たりません。\n'
            '（既に別用途で import 済のはずなので削除しないでください）',
      );
    });

    test('「まんなか（無料）」表記が LINE 本文に含まれていること', () {
      final src = _readSource();

      // L151 の "Aimachi（無料）" を置換した結果、「まんなか（無料）」で始まる
      // 誘導文言が残っていること。
      expect(
        src.contains('まんなか（無料）'),
        isTrue,
        reason: 'LINE 本文に「まんなか（無料）」の誘導文言が見当たりません。\n'
            'Aimachi 残骸の置換漏れです。',
      );
    });
  });
}
