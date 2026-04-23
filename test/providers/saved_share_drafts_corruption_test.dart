import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mannaka/models/saved_share_draft.dart';
import 'package:mannaka/providers/saved_share_drafts_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Cycle 16: `saved_share_drafts_provider` 要素単位 try/catch への TDD テスト
///
/// 既存バグ（Cycle 15 Critic ISSUE 2）:
///   `build()` の `try/catch` が配列全体の map/toList を包んでいるため、
///   SharedPreferences に保存された JSON 文字列のうち **1 件でも壊れている** と
///   catch まで飛び、**全件が空配列として返ってしまう**。
///   → 端末で保存した複数下書きが一度に消える UX 崩壊。
///
/// 修正方針:
///   - 各 raw 要素ごとに try/catch する（破損エントリだけスキップ）
///   - 破損検出時に `developer.log(name: 'SavedShareDrafts', error: ...)` で診断
///     ログを出す（解析用。releaseモードでも developer.log は生存）
///
/// このテストは修正後の契約:
///   1. 全件正常 → 順序維持で全件返る
///   2. 混在（正常 + 破損 + 正常）→ 破損のみスキップし正常分は維持
///   3. 全件破損 → 空配列
///   4. ソース上で `developer.log(` が呼ばれている（診断ログ契約）
///
/// いずれも現行実装（配列全体 try/catch + 診断ログ無し）では失敗する。

const _key = 'saved_share_drafts_v1';

SavedShareDraft _draft(String id) => SavedShareDraft(
      id: id,
      createdAt: DateTime(2026, 4, 23, 12, 0),
      stationName: '渋谷',
      date: '',
      meetingTime: '',
      participantTimes: const {},
      candidates: const [],
      note: '',
    );

String _encode(SavedShareDraft d) => jsonEncode(d.toJson());

/// SavedShareDraft.fromJson が parse 失敗する「壊れた JSON 文字列」。
/// - `not-a-json`: そもそも JSON でない（jsonDecode が throw）
/// - `{}`: フィールド欠落（id を `as String` でキャストしようとして throw）
String get _malformedNotJson => 'not-a-json{';
String get _malformedEmptyObject => '{}';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('saved_share_drafts_provider 要素単位 try/catch（Cycle 16 TDD）', () {
    test('全件正常 3 件のとき 順序を維持して 3 件返す', () async {
      SharedPreferences.setMockInitialValues({
        _key: [
          _encode(_draft('a')),
          _encode(_draft('b')),
          _encode(_draft('c')),
        ],
      });
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final list = await container.read(savedShareDraftsProvider.future);

      expect(
        list.map((d) => d.id).toList(),
        ['a', 'b', 'c'],
        reason: '保存順のまま 3 件すべてロードされる（正常系）',
      );
    });

    test('混在（正常 + 破損 + 正常）のとき 破損のみスキップして正常 2 件を返す', () async {
      SharedPreferences.setMockInitialValues({
        _key: [
          _encode(_draft('keep-1')),
          _malformedNotJson,
          _encode(_draft('keep-2')),
        ],
      });
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final list = await container.read(savedShareDraftsProvider.future);

      expect(
        list.map((d) => d.id).toList(),
        ['keep-1', 'keep-2'],
        reason: '現行実装は配列全体 try/catch のため [] を返して FAIL する。'
            '修正後は破損 1 件だけスキップして 2 件返す。',
      );
    });

    test('混在（破損が先頭・末尾にもある）のとき 中央の正常 1 件だけを返す', () async {
      SharedPreferences.setMockInitialValues({
        _key: [
          _malformedNotJson,
          _encode(_draft('only-one')),
          _malformedEmptyObject,
        ],
      });
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final list = await container.read(savedShareDraftsProvider.future);

      expect(
        list.map((d) => d.id).toList(),
        ['only-one'],
        reason: '配列端に破損があっても中央の正常エントリは失われない',
      );
    });

    test('全件破損のとき 空配列を返す（throw しない）', () async {
      SharedPreferences.setMockInitialValues({
        _key: [
          _malformedNotJson,
          _malformedEmptyObject,
          _malformedNotJson,
        ],
      });
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final list = await container.read(savedShareDraftsProvider.future);

      expect(
        list,
        isEmpty,
        reason: '全件破損でも build() は空配列を data として返す（AsyncError にはしない）',
      );
      expect(
        container.read(savedShareDraftsProvider).hasError,
        isFalse,
        reason: '全件破損は想定内の退化であり AsyncError ではない',
      );
    });

    test('破損した後でも add() で新規下書きを追加でき、state と prefs に残る', () async {
      SharedPreferences.setMockInitialValues({
        _key: [
          _encode(_draft('keep-1')),
          _malformedNotJson,
        ],
      });
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await container.read(savedShareDraftsProvider.future);

      await container
          .read(savedShareDraftsProvider.notifier)
          .add(_draft('new-1'));

      final list =
          container.read(savedShareDraftsProvider).valueOrNull ?? const [];
      expect(
        list.map((d) => d.id).toList(),
        ['new-1', 'keep-1'],
        reason: '破損エントリはスキップしつつ 正常分 + 新規 の 2 件になる',
      );

      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getStringList(_key) ?? const [];
      expect(
        raw.length,
        2,
        reason: 'prefs からは破損エントリが排除され 2 件になる（自己修復）',
      );
    });
  });

  // ── ソース契約テスト（診断ログが実装されていることを静的に保証）
  group('saved_share_drafts_provider ソース契約（診断ログ）', () {
    test('build() で developer.log を呼び出す（破損検出時の診断ログ契約）', () {
      final file = File('lib/providers/saved_share_drafts_provider.dart');
      expect(file.existsSync(), isTrue,
          reason: 'saved_share_drafts_provider.dart が見つかりません');

      final src = file.readAsStringSync();

      expect(
        src.contains("import 'dart:developer'"),
        isTrue,
        reason:
            "dart:developer を import していること（debugPrint ではなく developer.log を使う CLAUDE.md 規約）",
      );

      expect(
        RegExp(r'developer\.log\s*\(').hasMatch(src),
        isTrue,
        reason: '破損検出時に developer.log() を呼んで診断ログを出す契約',
      );

      // 正規表現は Raw 文字列内で " や ' を混在させると扱いが煩雑なので
      // 通常文字列で組み立てる。name: 'SavedShareDrafts' か name: "SavedShareDrafts"
      // のいずれかがあれば契約を満たす。
      final hasLogName =
          RegExp('''name:\\s*['"]SavedShareDrafts['"]''').hasMatch(src);
      expect(
        hasLogName,
        isTrue,
        reason:
            "ログフィルタ用に name: 'SavedShareDrafts' をセットする（同一スコープ名で追跡可能にする）",
      );
    });

    test('build() が配列全体を包む try/catch を持たない（要素単位 try/catch の契約）', () {
      final file = File('lib/providers/saved_share_drafts_provider.dart');
      final src = file.readAsStringSync();

      // 現行実装は `} catch (_) {\n      return [];\n    }` という
      // 配列全体 fallback を持つ。これが残っている限り「1 件破損で全件消失」バグは直っていない。
      expect(
        RegExp(r'catch\s*\(\s*_\s*\)\s*\{\s*return\s*\[\s*\]\s*;')
            .hasMatch(src),
        isFalse,
        reason: '配列全体を包む `catch (_) { return []; }` を削除し、要素単位 try/catch に置き換えること',
      );
    });
  });
}
