// TDD Red フェーズ
// Cycle 10: lib/ 全域 `debugPrint` を `developer.log` に置き換える静的回帰テスト
//
// 背景:
//   CLAUDE.md Constraints
//   「debugPrint は本番で `kReleaseMode` 分岐か `developer.log` を使う」
//
//   `flutter/foundation.dart` の `debugPrint` は **本番ビルド** でも
//   console に出力されるため、上記ルールを無条件で満たさない。
//   一方 `dart:developer` の `log()` は DevTools / os_log に流れ、
//   リリースビルドでもユーザーに露出しない。
//
// 違反の現状（2026-04-22 計測）:
//   `grep -rn "debugPrint(" lib/` で 49 ヒット（無ガード呼び出し 43 箇所）。
//   `lib/` 内に `kReleaseMode` / `kDebugMode` のガードは 0 件。
//
// 本テストの責務:
//   [1] `lib/` 配下の全 .dart から `debugPrint(` 呼び出しを完全排除する
//   [2] `lib/screens/location_share_screen.dart` の `catch (_)` ブロック
//       （_loadSession / _submit）で握りつぶされている例外の診断情報を
//       `developer.log(...)` で保全する（Cycle 7 Engineer Follow-ups 解消）
//   [3] 既存のエラーログメッセージ（ランタイムタイプを含む要点文言）が
//       置換後も失われていないことを確認する（回帰防止）
//
// 修正方針（Engineer への引き継ぎ）:
//   - 各ファイルで `import 'package:flutter/foundation.dart';` のうち
//     `debugPrint` のためだけに入れられているものは不要になる
//     （`kDebugMode` 等の他用途が残る場合は保持）
//   - `import 'dart:developer' as developer;` を追加し、
//     `debugPrint('msg')` → `developer.log('msg', name: '<スコープ名>')`
//     に機械的置換する
//   - `location_share_screen.dart` L43/L82 の `catch (_)` を `catch (e, st)` に
//     書き換え、`developer.log('...', name: 'LocationShareScreen', error: e, stackTrace: st)`
//     を追加する（UI 固定文言は Cycle 7 回帰テストで保護されているため変更禁止）
//
// このテストは `lib/` 全域静的スキャンなので、
// 将来新しいファイルに `debugPrint` が再混入した場合も即座に検出できる。

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const _libDir = 'lib';
const _locationShareFile = 'lib/screens/location_share_screen.dart';

/// `lib/` 配下のすべての `.dart` ファイルを再帰的に列挙する。
List<File> _allLibDartFiles() {
  final dir = Directory(_libDir);
  if (!dir.existsSync()) {
    fail(
      '$_libDir/ が存在しません。\n'
      '（ディレクトリ非存在のまま PASS させると偽グリーンになります）',
    );
  }
  return dir
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('.dart'))
      .toList();
}

/// 1 行が実コード（コメントでも文字列でもない）上の `debugPrint(` 呼び出しか判定する。
///
/// - 行頭トリム後 `//` で始まる純粋なコメント行は除外する
/// - `debugPrint(` を含むが、それがコード中の文字列リテラル
///   （`'debugPrint('` や `"debugPrint("`）に含まれるだけの行も除外する
bool _isDebugPrintCallLine(String line) {
  final trimmed = line.trimLeft();
  if (trimmed.startsWith('//')) return false;
  if (!line.contains('debugPrint(')) return false;

  // 文字列リテラル内 `debugPrint(` を簡易除外:
  // 直前 1 文字がクォート（' または "）なら文字列内とみなす
  final idx = line.indexOf('debugPrint(');
  if (idx > 0) {
    final prev = line[idx - 1];
    if (prev == "'" || prev == '"') return false;
  }
  return true;
}

String _readSource(String path) {
  final file = File(path);
  if (!file.existsSync()) {
    fail('$path が存在しません。');
  }
  return file.readAsStringSync();
}

List<String> _readLines(String path) {
  final file = File(path);
  if (!file.existsSync()) {
    fail('$path が存在しません。');
  }
  return file.readAsLinesSync();
}

void main() {
  // ══════════════════════════════════════════════════════════════
  // [1] lib/ 全域から debugPrint 呼び出しを 0 件にする
  // ══════════════════════════════════════════════════════════════

  group('lib/ 全域 — debugPrint 呼び出しの静的排除 (CLAUDE.md Constraints)', () {
    test('lib/ 配下の全 .dart で debugPrint( 呼び出しが 0 件のとき本番ログ漏洩が発生しない', () {
      final violations = <String>[];
      for (final file in _allLibDartFiles()) {
        final lines = file.readAsLinesSync();
        for (int i = 0; i < lines.length; i++) {
          if (_isDebugPrintCallLine(lines[i])) {
            violations.add('${file.path}:${i + 1}: ${lines[i].trim()}');
          }
        }
      }

      expect(
        violations,
        isEmpty,
        reason: 'lib/ 配下に debugPrint( 呼び出しが残っています。\n'
            'CLAUDE.md: 「debugPrint は本番で kReleaseMode 分岐か developer.log を使う」\n'
            '\n'
            '違反箇所（${violations.length} 件）:\n'
            '${violations.map((l) => '  $l').join('\n')}\n'
            '\n'
            '修正例:\n'
            "  import 'dart:developer' as developer;\n"
            "  developer.log('message', name: 'ScopeName');\n",
      );
    });

    test('lib/ 配下の全 .dart で `import .*foundation.*` が `debugPrint` シンボルのために残っていないとき依存が軽量になる', () {
      // debugPrint だけのために foundation.dart を import しているファイルが
      // 残っていると、修正漏れか dead import の疑いがある。
      // ただし `kDebugMode` / `kReleaseMode` / `ValueListenable` 等の
      // 他用途で foundation.dart が必要なファイルもあるため、
      // foundation.dart を import しているファイルのうち
      // 「debugPrint 以外の用途が見当たらないもの」だけを検出する。
      final suspects = <String>[];
      final foundationSymbols = [
        'kDebugMode',
        'kReleaseMode',
        'kProfileMode',
        'kIsWeb',
        'ValueNotifier',
        'ValueListenable',
        'ChangeNotifier',
        'listEquals',
        'mapEquals',
        'compute',
        'describeIdentity',
        'debugDefault',
        'DiagnosticableTree',
        'Diagnosticable',
        'FlutterError',
        'precisionErrorTolerance',
        'Factory',
      ];

      for (final file in _allLibDartFiles()) {
        final src = file.readAsStringSync();
        final hasFoundationImport = RegExp(
          r'''import\s+['"]package:flutter/foundation\.dart['"]''',
        ).hasMatch(src);
        if (!hasFoundationImport) continue;

        final hasOtherUse = foundationSymbols.any(src.contains);
        if (!hasOtherUse) {
          suspects.add(file.path);
        }
      }

      expect(
        suspects,
        isEmpty,
        reason: '以下のファイルは foundation.dart を import しているが\n'
            '`debugPrint` 以外の用途が見つかりません。\n'
            'debugPrint を developer.log に置き換える際に、\n'
            'この import も削除して依存を軽量化してください。\n'
            '\n'
            '対象:\n${suspects.map((p) => '  $p').join('\n')}',
      );
    });
  });

  // ══════════════════════════════════════════════════════════════
  // [2] location_share_screen.dart の catch (_) で診断ログが保全される
  // ══════════════════════════════════════════════════════════════

  group('location_share_screen — catch ブロックでの例外診断ログ保全', () {
    test('_loadSession の catch ブロックで developer.log が呼ばれているとき例外握りつぶしが発生しない', () {
      final lines = _readLines(_locationShareFile);

      // `_loadSession` メソッド内の `catch` 節を検出
      int methodStart = -1;
      for (int i = 0; i < lines.length; i++) {
        if (RegExp(r'Future<void>\s+_loadSession\(\)').hasMatch(lines[i])) {
          methodStart = i;
          break;
        }
      }
      expect(methodStart, greaterThanOrEqualTo(0),
          reason: '_loadSession() が見つかりません。');

      // メソッド末尾を波括弧深度で探す
      int depth = 0;
      int methodEnd = -1;
      bool started = false;
      for (int i = methodStart; i < lines.length; i++) {
        for (final ch in lines[i].split('')) {
          if (ch == '{') {
            depth++;
            started = true;
          } else if (ch == '}') {
            depth--;
            if (started && depth == 0) {
              methodEnd = i;
              break;
            }
          }
        }
        if (methodEnd >= 0) break;
      }
      expect(methodEnd, greaterThanOrEqualTo(0),
          reason: '_loadSession() の末尾を特定できません。');

      final body = lines.sublist(methodStart, methodEnd + 1).join('\n');

      // catch 節が `catch (e` の形式で例外オブジェクトを捕捉していること
      expect(
        RegExp(r'catch\s*\(\s*e\b').hasMatch(body),
        isTrue,
        reason: '_loadSession の catch 節が `catch (_)` のままで例外が握りつぶされています。\n'
            '`catch (e, st)` または `catch (e)` に書き換え、\n'
            'developer.log(..., error: e, stackTrace: st) で診断情報を記録してください。',
      );

      // catch 節内（または直後の body）で developer.log が呼ばれていること
      expect(
        body.contains('developer.log('),
        isTrue,
        reason: '_loadSession 内で developer.log(...) の呼び出しが見つかりません。\n'
            'catch 節で握りつぶした例外は developer.log で診断記録に残すこと。',
      );
    });

    test('_submit の catch ブロックで developer.log が呼ばれているとき例外握りつぶしが発生しない', () {
      final lines = _readLines(_locationShareFile);

      int methodStart = -1;
      for (int i = 0; i < lines.length; i++) {
        if (RegExp(r'Future<void>\s+_submit\(\)').hasMatch(lines[i])) {
          methodStart = i;
          break;
        }
      }
      expect(methodStart, greaterThanOrEqualTo(0),
          reason: '_submit() が見つかりません。');

      int depth = 0;
      int methodEnd = -1;
      bool started = false;
      for (int i = methodStart; i < lines.length; i++) {
        for (final ch in lines[i].split('')) {
          if (ch == '{') {
            depth++;
            started = true;
          } else if (ch == '}') {
            depth--;
            if (started && depth == 0) {
              methodEnd = i;
              break;
            }
          }
        }
        if (methodEnd >= 0) break;
      }
      expect(methodEnd, greaterThanOrEqualTo(0),
          reason: '_submit() の末尾を特定できません。');

      final body = lines.sublist(methodStart, methodEnd + 1).join('\n');

      expect(
        RegExp(r'catch\s*\(\s*e\b').hasMatch(body),
        isTrue,
        reason: '_submit の catch 節が `catch (_)` のままで例外が握りつぶされています。\n'
            '`catch (e, st)` または `catch (e)` に書き換えること。',
      );

      expect(
        body.contains('developer.log('),
        isTrue,
        reason: '_submit 内で developer.log(...) の呼び出しが見つかりません。\n'
            'GPS 取得 / Firestore 送信で起きた例外を診断ログに残してください。',
      );
    });

    test('location_share_screen.dart が dart:developer を import しているとき log 呼び出しが有効になる', () {
      final src = _readSource(_locationShareFile);
      expect(
        RegExp(r'''import\s+['"]dart:developer['"]''').hasMatch(src),
        isTrue,
        reason: "`import 'dart:developer' as developer;` を追加してください。\n"
            '（名前衝突回避のためプレフィックス付き import を推奨）',
      );
    });
  });

  // ══════════════════════════════════════════════════════════════
  // [3] 既存エラーログ情報の保全（回帰防止）
  // ══════════════════════════════════════════════════════════════
  //
  // debugPrint → developer.log の機械的置換で
  // ログメッセージ本文が消失していないことを確認する。
  // 代表的な「runtimeType を含む要点文言」をスポットチェックする。

  group('lib/ 全域 — debugPrint 置換後もログメッセージ本文が保持される', () {
    test('analytics_service の runtimeType 診断メッセージが保持されているとき解析ログが失われない', () {
      final src = _readSource('lib/services/analytics_service.dart');
      // 代表: Analytics.logSearch の runtimeType ログ
      expect(
        src.contains('Analytics.logSearch'),
        isTrue,
        reason: 'Analytics.logSearch の診断ログ文字列が失われています。\n'
            '置換時にメッセージ本文まで削らないこと。',
      );
      expect(
        src.contains('e.runtimeType'),
        isTrue,
        reason: 'analytics_service の runtimeType 診断情報が失われています。',
      );
    });

    test('search_provider のエラー分類ログが保持されているとき分析不能にならない', () {
      final src = _readSource('lib/providers/search_provider.dart');
      expect(
        src.contains('ネットワークエラー'),
        isTrue,
        reason: 'search_provider のネットワークエラーログが失われています。',
      );
      expect(
        src.contains('タイムアウト'),
        isTrue,
        reason: 'search_provider のタイムアウトログが失われています。',
      );
    });

    test('history_provider / visited / reserved の _load/add/remove ログが保持されているとき永続化障害の切り分けができる', () {
      final files = [
        'lib/providers/history_provider.dart',
        'lib/providers/visited_restaurants_provider.dart',
        'lib/providers/reserved_restaurants_provider.dart',
      ];
      for (final f in files) {
        final src = _readSource(f);
        expect(
          src.contains('_load failed') &&
              src.contains('add failed') &&
              src.contains('remove failed'),
          isTrue,
          reason: '$f の _load/add/remove ログが失われています。',
        );
      }
    });

    test('main.dart の Firebase 初期化エラーログが保持されているとき初期化障害が追えなくなることを防ぐ', () {
      final src = _readSource('lib/main.dart');
      expect(
        src.contains('Firebase初期化エラー'),
        isTrue,
        reason: 'main.dart の Firebase 初期化エラーログが失われています。',
      );
    });
  });
}
