import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mannaka/models/saved_share_draft.dart';
import 'package:mannaka/providers/saved_share_drafts_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Cycle 15: `saved_share_drafts_provider` のデータ損失レース修正 TDD テスト
///
/// 現状 (`Notifier` + `build()` 内 `_load()` fire-and-forget) では、
/// 初期ロード完了前に `add()` が呼ばれると:
///   1. `state = [draft]` で `_save()` が走り、SharedPreferences が新 draft 1 件で上書きされる
///      → 既存下書きが全消失
///   2. その後 `_load()` が走り `state = (旧 prefs の内容)` で上書きされる
///      → 新 draft も state から消える
/// という双方向のデータ損失が発生する。
///
/// 修正方針: `Notifier` → `AsyncNotifier` 化し、`build()` で `await` してから
/// `state` を返す。`add()` / `remove()` は `await future` で初期ロード完了を
/// 待ってから state を更新する。
///
/// このテストは修正後の契約（`AsyncNotifierProvider<_, List<SavedShareDraft>>`
/// として `.future` が解決可能 / state は `AsyncValue<List<SavedShareDraft>>`）
/// を前提としているため、現行実装ではコンパイルエラー / API 不一致で Red になる。

const _key = 'saved_share_drafts_v1';

SavedShareDraft _draft(String id, {String station = '渋谷'}) => SavedShareDraft(
      id: id,
      createdAt: DateTime(2026, 4, 23, 12, 0),
      stationName: station,
      date: '',
      meetingTime: '',
      participantTimes: const {},
      candidates: const [],
      note: '',
    );

String _encode(SavedShareDraft d) => jsonEncode(d.toJson());

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('saved_share_drafts_provider レース修正（Cycle 15 TDD）', () {
    test('型が AsyncNotifierProvider であり build() が List<SavedShareDraft> を返すとき .future を await できる',
        () async {
      SharedPreferences.setMockInitialValues({});
      final container = ProviderContainer();
      addTearDown(container.dispose);

      // `.future` 取得は AsyncNotifierProvider の専用 API。
      // Notifier のままだとコンパイルエラーになり Red。
      final future = container.read(savedShareDraftsProvider.future);
      expect(future, isA<Future<List<SavedShareDraft>>>());

      final list = await future;
      expect(list, isEmpty, reason: 'prefs が空なら初期状態は [] である');

      // state が AsyncValue として公開されていることも契約の一部。
      final state = container.read(savedShareDraftsProvider);
      expect(state, isA<AsyncValue<List<SavedShareDraft>>>());
      expect(state.hasValue, isTrue);
    });

    test('既存 1 件ある状態で build() 完了後 add() すると 既存+新規 の 2 件が state と prefs に残る',
        () async {
      SharedPreferences.setMockInitialValues({
        _key: [_encode(_draft('existing-1'))],
      });
      final container = ProviderContainer();
      addTearDown(container.dispose);

      // 初期ロードを確実に待つ。
      await container.read(savedShareDraftsProvider.future);

      await container
          .read(savedShareDraftsProvider.notifier)
          .add(_draft('new-1'));

      final list =
          container.read(savedShareDraftsProvider).valueOrNull ?? const [];
      expect(
        list.map((d) => d.id).toList(),
        ['new-1', 'existing-1'],
        reason: '新規は先頭・既存は保持（正常系）',
      );

      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getStringList(_key) ?? const [];
      expect(raw.length, 2, reason: 'SharedPreferences にも 2 件保存されている');
    });

    test('初期ロード完了を await せず add() を呼んでも 既存データは失われない（レース本丸）',
        () async {
      SharedPreferences.setMockInitialValues({
        _key: [_encode(_draft('existing-1'))],
      });
      final container = ProviderContainer();
      addTearDown(container.dispose);

      // .future を await せずに即 add() を呼ぶ ＝ 現行実装ではデータ損失が起きるシナリオ。
      // 修正後は add() 内で初期ロード完了を待つので、既存が失われない。
      await container
          .read(savedShareDraftsProvider.notifier)
          .add(_draft('new-1'));

      final list =
          container.read(savedShareDraftsProvider).valueOrNull ?? const [];
      expect(
        list.map((d) => d.id).toSet(),
        {'new-1', 'existing-1'},
        reason: '既存 existing-1 がレースで消滅していないこと',
      );

      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getStringList(_key) ?? const [];
      expect(
        raw.length,
        2,
        reason: 'SharedPreferences も existing-1 + new-1 の 2 件（上書き消失していない）',
      );
    });

    test('連続して add() を呼び出したとき すべての下書きが保存される',
        () async {
      SharedPreferences.setMockInitialValues({});
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await container.read(savedShareDraftsProvider.future);

      final notifier = container.read(savedShareDraftsProvider.notifier);
      await notifier.add(_draft('a'));
      await notifier.add(_draft('b'));
      await notifier.add(_draft('c'));

      final list =
          container.read(savedShareDraftsProvider).valueOrNull ?? const [];
      expect(
        list.map((d) => d.id).toList(),
        ['c', 'b', 'a'],
        reason: '新しい順に prepend されている',
      );

      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getStringList(_key) ?? const [];
      expect(raw.length, 3);
    });

    test('remove() で指定 id のみ消え、他は state と prefs の両方に残る',
        () async {
      SharedPreferences.setMockInitialValues({
        _key: [
          _encode(_draft('a')),
          _encode(_draft('b')),
          _encode(_draft('c')),
        ],
      });
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await container.read(savedShareDraftsProvider.future);

      await container
          .read(savedShareDraftsProvider.notifier)
          .remove('b');

      final list =
          container.read(savedShareDraftsProvider).valueOrNull ?? const [];
      expect(list.map((d) => d.id).toSet(), {'a', 'c'});

      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getStringList(_key) ?? const [];
      expect(raw.length, 2, reason: 'prefs からも b が削除されている');
    });

    test('初期ロード完了前に remove() を呼び出しても 残るべき既存データは失われない',
        () async {
      SharedPreferences.setMockInitialValues({
        _key: [
          _encode(_draft('keep-1')),
          _encode(_draft('target')),
        ],
      });
      final container = ProviderContainer();
      addTearDown(container.dispose);

      // .future を待たずに即 remove()
      await container
          .read(savedShareDraftsProvider.notifier)
          .remove('target');

      final list =
          container.read(savedShareDraftsProvider).valueOrNull ?? const [];
      expect(
        list.map((d) => d.id).toList(),
        ['keep-1'],
        reason: 'target だけが削除され、keep-1 は保持される',
      );

      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getStringList(_key) ?? const [];
      expect(raw.length, 1);
    });
  });
}
