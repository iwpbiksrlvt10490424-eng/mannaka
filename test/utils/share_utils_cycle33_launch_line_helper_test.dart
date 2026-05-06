// TDD Red フェーズ — Cycle 33: LINE 起動共通ヘルパ `launchLineWithText` を share_utils に集約
//
// 背景（Critic CRITICAL 3 件の根因 = Cycle 32 の取りこぼし）:
//   Cycle 32 で `share_utils.dart` 内の 2 箇所
//   （`shareSelectionsToLine` / `shareMeetingPointsToLine`）の LINE 起動 URL は
//   `line://msg/text/?<encoded>` に切替え済み。しかし同 root cause の
//   `https://line.me/R/share?text=...` を直接組み立てるコードが
//   3 つの screen ファイルに残っており、iOS 実機で **canLaunchUrl(https://...)
//   が常に true になる**ため未インストール時の無反応 UX バグが 3 画面に残存:
//     - lib/screens/saved_drafts_screen.dart:136
//     - lib/screens/restaurant_detail_screen.dart:786
//     - lib/screens/settings_screen.dart:586
//
//   CLAUDE.md「同パターンの全箇所を検索して一括修正」「依存関係を可視化（共通処理は
//   1 箇所のみ・コピペ禁止）」明示違反。
//
// このサイクルの意図:
//   - 共通ヘルパ `ShareUtils.launchLineWithText(String text)` を 1 箇所に集約する。
//   - 既存 5 箇所（share_utils 2 + screens 3）が同ヘルパに集約される。
//   - canLaunch=false のとき false を返し、呼び出し元で SnackBar を出せる契約を保つ。
//
// このテストの責務（unit-level）:
//   [A] launchLineWithText の **存在 + 4 つの基本契約**を機械担保する。
//       1) 空文字列 → false（canLaunch 呼ばない・launch 呼ばない）
//       2) 通常テキスト + canLaunch=true → true 返り line: スキームで launch
//       3) canLaunch=false → false 返り launch 呼ばない
//       4) URL は `line://msg/text/?<encoded>` 形式で encoded 部分が一致
//
// 期待される Red 失敗:
//   現在の `ShareUtils` に `launchLineWithText` メソッドは存在しないので、
//   コンパイル時に "The method 'launchLineWithText' isn't defined" で全テスト失敗。
//
// 不変項（このテストでは検証しないが侵してはならない）:
//   - Cycle 27〜30 の characterization snapshot 全 49 サブテストの **出力 1 バイト不変**
//   - Cycle 31 の Future<bool> 早期 false 契約 A/B/C
//   - Cycle 32 の line: スキーム移行（share_utils 2 関数）

import 'package:flutter_test/flutter_test.dart';
import 'package:mannaka/utils/share_utils.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:url_launcher_platform_interface/link.dart';
import 'package:url_launcher_platform_interface/url_launcher_platform_interface.dart';

class _FakeUrlLauncher extends UrlLauncherPlatform
    with MockPlatformInterfaceMixin {
  _FakeUrlLauncher({this.canLaunchResult = true});
  bool canLaunchResult;
  final List<String> canLaunchCalls = [];
  final List<String> launchCalls = [];

  @override
  LinkDelegate? get linkDelegate => null;

  @override
  Future<bool> canLaunch(String url) async {
    canLaunchCalls.add(url);
    return canLaunchResult;
  }

  @override
  Future<bool> launchUrl(String url, LaunchOptions options) async {
    launchCalls.add(url);
    return true;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late UrlLauncherPlatform originalInstance;
  late _FakeUrlLauncher fake;

  setUp(() {
    originalInstance = UrlLauncherPlatform.instance;
    fake = _FakeUrlLauncher(canLaunchResult: true);
    UrlLauncherPlatform.instance = fake;
  });

  tearDown(() {
    UrlLauncherPlatform.instance = originalInstance;
  });

  group('Cycle 33: ShareUtils.launchLineWithText 共通ヘルパの基本契約', () {
    test('空文字列を渡すと false が返り canLaunch / launchUrl は呼ばれない', () async {
      final ok = await ShareUtils.launchLineWithText('');

      expect(ok, isFalse,
          reason: '空テキストは「送る内容なし」なので false を返す契約。');
      expect(fake.canLaunchCalls, isEmpty,
          reason: '空テキストで canLaunch を叩く必要はない（無駄な OS コール禁止）。');
      expect(fake.launchCalls, isEmpty,
          reason: '空テキストでは LINE を起動してはならない。');
    });

    test('通常テキスト + canLaunch=true のとき true 返り line: スキームで launchUrl が呼ばれる', () async {
      const text = 'Aimachiで決まったお店を共有します';

      final ok = await ShareUtils.launchLineWithText(text);

      expect(ok, isTrue, reason: '起動成功時は true を返す契約。');
      expect(fake.canLaunchCalls, hasLength(1));
      expect(fake.launchCalls, hasLength(1));

      final canLaunchUri = Uri.parse(fake.canLaunchCalls.single);
      final launchUri = Uri.parse(fake.launchCalls.single);
      expect(canLaunchUri.scheme, equals('line'),
          reason: 'iOS で未インストール検知が効くスキームでなければならない。'
              'https は Safari が居るため常に true を返し検知不能。');
      expect(launchUri.scheme, equals('line'),
          reason: 'launchUrl も同じ line: スキームで呼ばれる必要がある。');
    });

    test('canLaunch=false のとき false が返り launchUrl は呼ばれない（Cycle 31 早期 false 契約）',
        () async {
      fake.canLaunchResult = false;

      final ok = await ShareUtils.launchLineWithText('共有テキスト');

      expect(ok, isFalse,
          reason: 'LINE 未インストール時は false を返し、呼び出し元で SnackBar を出す契約。');
      expect(fake.canLaunchCalls, hasLength(1));
      expect(fake.launchCalls, isEmpty,
          reason: 'canLaunch=false で launchUrl を呼ぶと「アプリが無いのに起動を試みる」UX バグになる。');
      expect(Uri.parse(fake.canLaunchCalls.single).scheme, equals('line'),
          reason: '存在チェック自体も line: スキームで行う必要がある。');
    });

    test('URL は line://msg/text/?<encoded> 形式で、encoded はテキストの URL エンコード結果と一致する',
        () async {
      const text = 'お店：渋谷のイタリアン 5/1 19:30';

      await ShareUtils.launchLineWithText(text);

      final raw = fake.launchCalls.single;
      expect(raw, startsWith('line://'),
          reason: 'LINE アプリ起動 URL は line:// から始まる必要がある。');
      expect(raw, contains('msg'),
          reason: 'LINE アプリ専用「メッセージ送信」エンドポイント msg を含む。');
      expect(raw, contains('text'),
          reason: '「テキスト共有」アクション text を含む。');
      expect(raw, contains('?'),
          reason: '共有テキストはクエリ文字列で渡される。');
      expect(raw, contains(Uri.encodeComponent(text)),
          reason: '共有テキストは URL エンコードされて URL に含まれる。'
              '生テキストや別エンコーダの結果が混じってはならない。');
      expect(raw, isNot(contains('line.me/R/share')),
          reason: '回帰ガード: https://line.me/R/share への退化を防ぐ。');
    });
  });
}
