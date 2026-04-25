// ⚠️ WARNING / 警告: 本テストは Riverpod 2.6.x 依存
// ---------------------------------------------------------------------------
// 本テスト（特に [2]「再読み込みタップで empty UI に遷移」ケース）は、
// flutter_riverpod 2.6.x の以下の挙動に依存している:
//   - `AsyncNotifierProvider.overrideWith(() => factory())` の factory は
//     `ref.invalidate(provider)` で再実行されず、同一 Notifier インスタンスの
//     `build()` のみが再実行される。
// この前提のもと、単一 Notifier の内部カウンタで「1 回目 throw / 2 回目成功」を
// 表現している。
//
// flutter_riverpod を major bump（3.x 以降）に引き上げた場合、
// 上記挙動が変わりテストがサイレントに偽グリーン化するリスクがある。
// その際は本テストを新 Riverpod 仕様に合わせて再設計必須。
// 併置の `saved_drafts_retry_version_guard_test.dart` が
// pubspec.yaml の major が 2 以外になったら赤く落ちるので、再設計の合図にすること。
// ---------------------------------------------------------------------------
//
// TDD 再設計（Cycle 17 Cycle 2 REJECT 受け）
// 対象: lib/screens/saved_drafts_screen.dart の `_errorUi(WidgetRef ref)`
//
// 背景:
//   Cycle 17 Cycle 1 で「再読み込み」ボタンを `_errorUi` に追加し
//   `ref.invalidate(savedShareDraftsProvider)` を呼ぶ実装を入れた。
//   その際の TDD テスト（本ファイル旧版）は Riverpod 2.6.1 の挙動と不整合で
//   `flutter test +406 ~2 -2` となり REJECT された。
//
// Riverpod 2.6.1 の実挙動（implementation_notes.md で再現確認済み）:
//   `AsyncNotifierProvider.overrideWith(() => factory())` に渡した factory は
//   `ref.invalidate(...)` で **再実行されない**。同一 Notifier インスタンスの
//   `build()` だけが再実行される。よって「factory 呼び出し回数」を
//   インスタンス間で切り替える旧設計は成立しない。
//
// 再設計方針:
//   - 旧 test [2]（タップ直後 1 ティックの CircularProgressIndicator 観測）は
//     **削除**。1 ティック未満で実機でも視認不能、要件として過剰。
//   - 旧 test [3] は **単一 Notifier の内部カウンタ**で「1 回目 throw / 2 回目成功」
//     を表現し、`build()` の再実行で empty UI へ遷移することを観測する。
//   - test [1]（再読み込みボタン存在）と test [4]（ソースに `ref.invalidate`
//     を含む静的契約）は維持。
//
// 非目標:
//   - 実装コード（`lib/screens/saved_drafts_screen.dart`）の変更は本サイクルでは
//     行わない。テスト設計のみの差し戻し対応。

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

// ─── AsyncNotifier スタブ
//
// AsyncNotifierProvider.overrideWith は同一 Notifier 型を要求するため
// SavedShareDraftsNotifier を継承する。

/// 常に throw するだけの Notifier。test [1] 用。
class _AlwaysErrorNotifier extends SavedShareDraftsNotifier {
  @override
  Future<List<SavedShareDraft>> build() async {
    throw Exception('simulated load failure');
  }
}

/// 1 回目の `build()` は throw、2 回目以降は空配列を返す Notifier。
///
/// Riverpod 2.6.1 では `ref.invalidate(provider)` により **同一インスタンス** の
/// `build()` が再実行される。内部カウンタ `_buildCount` はインスタンスフィールドなので
/// invalidate 後の 2 回目 build で 1 になっており、throw をスキップして成功パスへ進む。
/// これにより「error UI → empty UI」遷移がテストで観測できる。
class _RecoveringNotifier extends SavedShareDraftsNotifier {
  int _buildCount = 0;

  @override
  Future<List<SavedShareDraft>> build() async {
    final idx = _buildCount++;
    if (idx == 0) {
      throw Exception('first attempt fails');
    }
    return const [];
  }
}

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
  // [1] Widget: 「再読み込み」ボタン存在
  // ══════════════════════════════════════════════════════════════════════

  group('SavedDraftsScreen._errorUi() — リトライ導線の表示', () {
    testWidgets(
        'error 状態のとき「再読み込み」ラベル + refresh_rounded アイコンの押下可能ボタンが表示される',
        (tester) async {
      await tester.pumpWidget(_wrap(overrides: [
        savedShareDraftsProvider.overrideWith(() => _AlwaysErrorNotifier()),
      ]));
      await tester.pump(); // throw を 1 フレーム消化
      await tester.pump();

      // error UI が出ている前提（Cycle 16 で担保済）。ここが崩れていたら
      // 先に Cycle 16 の error_ui テストを直すこと。
      expect(find.byIcon(Icons.error_outline_rounded), findsOneWidget,
          reason: 'Cycle 16 の error UI が表示されていない。先にそちらを確認。');

      // Cycle 17 で追加された「再読み込み」ボタン。
      expect(
        find.text('再読み込み'),
        findsOneWidget,
        reason: 'error UI に「再読み込み」ラベルが見当たらない。'
            '_errorUi() に TextButton.icon（またはそれ相当の押下可能 Widget）を配置してください。',
      );
      expect(
        find.byIcon(Icons.refresh_rounded),
        findsOneWidget,
        reason: 'error UI のリトライボタンに Icons.refresh_rounded が見当たらない。'
            '既存画面との一貫性のため refresh_rounded を使ってください。',
      );
    });
  });

  // ══════════════════════════════════════════════════════════════════════
  // [2] Widget: タップで provider が再ロードされ empty UI へ遷移
  // （旧 test [3] を Riverpod 2.6.1 の実挙動に合わせて書き直したもの）
  // ══════════════════════════════════════════════════════════════════════

  group('SavedDraftsScreen._errorUi() — リトライで復旧した場合に data UI が描画される', () {
    testWidgets(
        '再読み込みタップで同一 Notifier の build() が再実行され、2 回目の成功で empty UI に遷移する',
        (tester) async {
      await tester.pumpWidget(_wrap(overrides: [
        savedShareDraftsProvider.overrideWith(() => _RecoveringNotifier()),
      ]));
      await tester.pump();
      await tester.pump();

      // 初回 build: throw → error UI 表示。
      expect(find.byIcon(Icons.error_outline_rounded), findsOneWidget,
          reason: '初回 build で throw された結果 error UI が出ている前提');
      expect(find.byIcon(Icons.bookmark_border_rounded), findsNothing,
          reason: '初回はまだ empty UI に遷移していないこと');

      // リトライ押下 → invalidate → 同一 Notifier の build() 再実行 → 2 回目成功。
      await tester.tap(find.text('再読み込み'));
      await tester.pumpAndSettle();

      expect(
        find.byIcon(Icons.bookmark_border_rounded),
        findsOneWidget,
        reason: 'リトライ成功後は empty UI（bookmark_border_rounded）に遷移するはず。'
            'onPressed で ref.invalidate(savedShareDraftsProvider) を呼んでいないと'
            'build() が再実行されず error UI のままになる。',
      );
      expect(
        find.byIcon(Icons.error_outline_rounded),
        findsNothing,
        reason: 'リトライ成功後も error UI が残っているのは異常（invalidate 未発火か state 更新失敗）',
      );
    });
  });

  // ══════════════════════════════════════════════════════════════════════
  // [3] Source 静的契約: ref.invalidate 記述ガード
  // ══════════════════════════════════════════════════════════════════════

  group('saved_drafts_screen.dart ソース契約 — ref.invalidate 記述', () {
    test('ref.invalidate(savedShareDraftsProvider) の呼び出しがソースに含まれていること',
        () {
      final src = _readSource();

      // Widget テストだけでは onPressed 実装（例: `() => () => ref.invalidate(...)`
      // のネスト関数バグ）を見抜けない可能性があるため、ソース文字列でも担保する。
      final hasInvalidate = RegExp(
        r'ref\.invalidate\s*\(\s*savedShareDraftsProvider\s*\)',
      ).hasMatch(src);

      expect(
        hasInvalidate,
        isTrue,
        reason: 'saved_drafts_screen.dart に '
            'ref.invalidate(savedShareDraftsProvider) の呼び出しが見当たりません。\n'
            '_errorUi() のリトライボタンから provider を無効化して再ロードしてください。',
      );
    });
  });
}
