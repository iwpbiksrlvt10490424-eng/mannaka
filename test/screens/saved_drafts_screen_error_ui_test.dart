// TDD Red フェーズ
// Cycle 23: saved_drafts_screen.dart の LINE 本文ブランド表記を
//           「まんなか（無料）」→「Aimachi（無料）」へ差し戻す（commit 9d3e746 整合化）。
//
// 経緯:
//   - 2026-04-23 commit 9d3e746（ユーザー本人）で UI 全域は「Aimachi」に確定。
//     概念語のみ「まんなか」で残す方針が確立した。
//   - 2026-04-24 Cycle 16（未コミット）が backlog の旧 Cycle 11〜13 記載を根拠に
//     `saved_drafts_screen.dart:187` を `Aimachi（無料）` → `まんなか（無料）` に機械的置換し、
//     方針を局所的に破壊した。
//   - 同 commit で本テストの [3] 群も「Aimachi 禁止 / まんなか（無料）必須」に書き換えられたため、
//     本番だけ戻しても [3] 群が再 Red 化する。本サイクルではテスト期待値を反転させてから
//     本番を Green 化する（テストファースト）。
//
// 現状（Cycle 16 直後）:
//   - L187: `sb.writeln('あなたもまんなか（無料）で同じ条件のお店を探してみましょう👇');`
//     → 直後の `appStoreUrl` の slug が `app/aimachi/` のため、LINE 受信者は「まんなか」で
//        検索して見つからず「Aimachi」ページに着地し、ブランド整合性が毀損する。
//   - 本テスト [3] 群が「Aimachi 禁止 / まんなか（無料）必須」で固定化されている。
//
// 修正方針（feature-implementer への引き継ぎ）:
//   A. saved_drafts_screen.dart L187 の LINE 誘導文を
//      `'あなたもAimachi（無料）で同じ条件のお店を探してみましょう👇'` に戻す。
//      （share_utils.dart:194 と完全一致させ、ブランド表記の単一の真実源を作る）
//   B. ShareUtils.appStoreUrl 経由の URL 一元参照は維持する（[3] のテスト2・3 は変更なし）。
//   C. error UI が _empty() から分離されている回帰テスト [1][2] 群は変更なし
//      （Cycle 16 で導入された _errorUi 分岐は仕様として残す）。
//
// スコープ外:
//   - 他ファイルの Aimachi 表記（既に share_utils.dart 等で整合済み）
//   - 未コミットの Cycle 16〜22 差分の棚卸し（別タスク）

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
  // [3] ソース静的契約（LINE 誘導文のブランド表記 = Aimachi 必須 / まんなか禁止）
  // ══════════════════════════════════════════════════════════════════════

  group('saved_drafts_screen.dart ソース契約 — LINE 誘導文のブランド整合', () {
    test('LINE 誘導文は ShareUtils.lineDownloadCta 経由で参照していること（Cycle 24 方針）', () {
      final src = _readSource();

      // Cycle 24 で誘導文は share_utils.dart の lineDownloadCta 定数に集約された。
      // ブランド表記（Aimachi）の整合性は定数側で担保され、本ファイルは
      // 定数を参照することで自動的に整合する。リテラル直書きは禁止。
      expect(
        src.contains('ShareUtils.lineDownloadCta'),
        isTrue,
        reason: 'saved_drafts_screen.dart は ShareUtils.lineDownloadCta を参照していません。\n'
            'Cycle 24 の方針（誘導文の単一所在）に従い、リテラル直書きを定数参照に置き換えてください。',
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

    test('「まんなか（無料）」表記が LINE 本文に残っていないこと（Cycle 16 誤置換の差し戻し）', () {
      final src = _readSource();

      // Cycle 16（未コミット）が L187 を `Aimachi（無料）` → `まんなか（無料）` に
      // 機械的置換した。本サイクルで差し戻すため、誘導文に「まんなか（無料）」は
      // 残っていてはならない（概念語としての「まんなか」は本ファイルでは使わない）。
      expect(
        src.contains('まんなか（無料）'),
        isFalse,
        reason: 'saved_drafts_screen.dart の LINE 誘導文に「まんなか（無料）」が残っています。\n'
            'commit 9d3e746 の方針（UI=Aimachi）に差し戻し、share_utils.dart:194 と同一表記にしてください。',
      );
    });
  });
}
