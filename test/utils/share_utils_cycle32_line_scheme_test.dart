// TDD Red フェーズ — Cycle 32: LINE 起動 URL を `line:` スキームに切替える
//
// 背景（Critic CRITICAL の根因）:
//   Cycle 31 では「`canLaunchUrl == false` のとき false を返して呼び出し元で
//   SnackBar を出す」という早期 false 契約を入れた。しかし URL が
//   `https://line.me/R/share?text=...` のままだと、iOS では Safari が常駐
//   している（=https をハンドリングできるアプリが必ず居る）ため
//   `canLaunchUrl(https://line.me/...)` は **常に true** を返す。結果、
//   Cycle 31 の早期 false 分岐は実機でほぼ発火せず、LINE 未インストール時の
//   無反応 UX バグはまだ残っている。
//
//   解決策は LINE アプリ専用スキーム `line:` を使うこと:
//     - canLaunchUrl(`line://...`) は LSApplicationQueriesSchemes に
//       `line` が登録されており、かつアプリがインストールされている場合のみ
//       true を返す（= 真の存在チェック）。
//     - launchUrl(`line://msg/text/?<encoded>`) は LINE アプリを直接起動して
//       共有シートを開く。
//
//   Info.plist 側で `<string>line</string>` を `LSApplicationQueriesSchemes`
//   に追加する（このテストでは Info.plist は検証しない — feature-implementer
//   が忘れず追加すること）。
//
// このテストの責務:
//   - share_utils が **常に `line:` スキーム** で canLaunch / launchUrl を
//     呼ぶことを機械担保する（scheme 回帰ガード）。
//   - https スキーム経由の LINE 共有が二度と紛れ込まないようにする。
//
// 期待される Red 失敗:
//   現在の実装は `https://line.me/R/share?text=...` を使っているので、
//   `Uri.parse(fake.launchCalls.first).scheme == 'line'` の expect が失敗する。
//
// 不変項（このテストでは検証しないが侵してはならない）:
//   - Cycle 27〜30 の characterization snapshot 全 49 サブテストの **出力
//     1 バイト不変**（buildLineTextFor* 純関数は完全無改変）
//   - Cycle 31 の Future<bool> 契約 A/B/C を維持

import 'package:flutter/material.dart' show TimeOfDay;
import 'package:flutter_test/flutter_test.dart';
import 'package:mannaka/models/meeting_point.dart';
import 'package:mannaka/models/restaurant.dart';
import 'package:mannaka/models/scored_restaurant.dart';
import 'package:mannaka/providers/search_provider.dart';
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

Restaurant _restaurant() => Restaurant(
      id: 'r1',
      name: 'テスト食堂',
      stationIndex: 0,
      category: 'イタリアン',
      rating: 4.0,
      reviewCount: 50,
      priceLabel: '¥¥',
      priceAvg: 3000,
      tags: const [],
      emoji: '🍽️',
      description: 'テスト用',
      distanceMinutes: 5,
      address: '渋谷区1-1',
      openHours: '11:00-23:00',
    );

ScoredRestaurant _scored() => ScoredRestaurant(
      restaurant: _restaurant(),
      score: 0.8,
      distanceKm: 0.4,
      participantDistances: const {},
      fairnessScore: 0.8,
    );

({String station, ScoredRestaurant scored}) _entry() =>
    (station: '新宿', scored: _scored());

MeetingPoint _meetingPoint() => MeetingPoint(
      stationIndex: 0,
      stationName: '新宿',
      stationEmoji: '🚉',
      lat: 35.69,
      lng: 139.70,
      totalMinutes: 20,
      maxMinutes: 12,
      minMinutes: 8,
      averageMinutes: 10,
      fairnessScore: 0.9,
      overallScore: 0.9,
      participantTimes: const {'あや': 12, 'ゆう': 8},
    );

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

  group('Cycle 32: shareSelectionsToLine は line: スキームで起動する', () {
    test('canLaunch / launchUrl が両方とも line: スキームで呼ばれる', () async {
      final state = SearchState(
        selectedDate: DateTime(2026, 4, 24),
        selectedMeetingTime: const TimeOfDay(hour: 19, minute: 30),
      );

      await ShareUtils.shareSelectionsToLine(state, [_entry()]);

      expect(fake.canLaunchCalls, hasLength(1));
      expect(fake.launchCalls, hasLength(1));

      final canLaunchUri = Uri.parse(fake.canLaunchCalls.first);
      final launchUri = Uri.parse(fake.launchCalls.first);

      expect(canLaunchUri.scheme, equals('line'),
          reason: 'iOS で未インストール検知が効くスキームでなければならない。'
              'https は Safari が居るため常に true を返し検知不能。');
      expect(launchUri.scheme, equals('line'),
          reason: 'launchUrl も同じ line: スキームで呼ばれる必要がある。');
    });

    test('launchUrl の URL は line://msg/text/?<encoded> 形式', () async {
      final state = SearchState();

      await ShareUtils.shareSelectionsToLine(state, [_entry()]);

      final raw = fake.launchCalls.first;
      // line:// + msg/text/ パスはアプリで「テキスト共有」を起動する固定形。
      // ホスト名 (msg) とパス (/text/) のどちらに割り当てるかは実装に余地が
      // あるが、`line://msg/text/?...` 全体一致を緩く検査する。
      expect(raw, startsWith('line://'),
          reason: 'LINE アプリ起動 URL は line:// から始まる必要がある。');
      expect(raw, contains('msg'),
          reason: 'LINE アプリ専用「メッセージ送信」エンドポイント msg を含む。');
      expect(raw, contains('text'),
          reason: '「テキスト共有」アクション text を含む。');
      expect(raw, contains('?'),
          reason: '共有テキストはクエリ文字列で渡される。');
    });

    test('https://line.me/R/share は二度と使われない（回帰ガード）', () async {
      await ShareUtils.shareSelectionsToLine(
          SearchState(), [_entry()]);

      final allUrls = [...fake.canLaunchCalls, ...fake.launchCalls];
      for (final u in allUrls) {
        expect(u, isNot(contains('line.me/R/share')),
            reason: 'Cycle 31 まで使っていた https://line.me/R/share?text= 経路は'
                'iOS で常に canLaunch=true となり Cycle 31 の早期 false が発火'
                'しないため、Cycle 32 で完全に廃止する。');
        expect(Uri.parse(u).scheme, isNot(equals('https')),
            reason: 'LINE 共有 URL に https スキームが混入してはならない。');
      }
    });

    test('canLaunch=false のとき launchUrl は呼ばれず false が返る (Cycle 31 契約 B 維持)',
        () async {
      fake.canLaunchResult = false;

      final ok = await ShareUtils.shareSelectionsToLine(
          SearchState(), [_entry()]);

      expect(ok, isFalse);
      expect(fake.launchCalls, isEmpty,
          reason: 'line: スキーム移行後も Cycle 31 の早期 false 契約は維持される。');
      expect(Uri.parse(fake.canLaunchCalls.single).scheme, equals('line'));
    });
  });

  group('Cycle 32: shareMeetingPointsToLine は line: スキームで起動する', () {
    test('canLaunch / launchUrl が両方とも line: スキームで呼ばれる', () async {
      final state = SearchState(results: [_meetingPoint()]);

      await ShareUtils.shareMeetingPointsToLine(state);

      expect(fake.canLaunchCalls, hasLength(1));
      expect(fake.launchCalls, hasLength(1));
      expect(Uri.parse(fake.canLaunchCalls.first).scheme, equals('line'));
      expect(Uri.parse(fake.launchCalls.first).scheme, equals('line'));
    });

    test('https://line.me/R/share は二度と使われない（回帰ガード）', () async {
      await ShareUtils.shareMeetingPointsToLine(
          SearchState(results: [_meetingPoint()]));

      for (final u in [...fake.canLaunchCalls, ...fake.launchCalls]) {
        expect(u, isNot(contains('line.me/R/share')));
        expect(Uri.parse(u).scheme, isNot(equals('https')));
      }
    });

    test('canLaunch=false のとき launchUrl は呼ばれず false が返る (Cycle 31 契約 B 維持)',
        () async {
      fake.canLaunchResult = false;

      final ok = await ShareUtils.shareMeetingPointsToLine(
          SearchState(results: [_meetingPoint()]));

      expect(ok, isFalse);
      expect(fake.launchCalls, isEmpty);
      expect(Uri.parse(fake.canLaunchCalls.single).scheme, equals('line'));
    });
  });

  group('Cycle 32: 共有テキスト（buildLineTextFor*）は不変であることを確認', () {
    // Cycle 27〜30 の snapshot を侵さないことの軽い保険。
    // 詳細な byte-for-byte 比較は cycle27〜30 の characterization テストが担う。
    test('buildLineTextForSelections の出力は line: 化に巻き込まれない', () {
      final state = SearchState();
      final text =
          ShareUtils.buildLineTextForSelections(state, [_entry()]);
      expect(text, contains('Aimachi'),
          reason: '共有テキスト本体（純関数）の中身は LINE URL スキーム変更とは独立。');
      expect(text, isNot(contains('line://')),
          reason: '共有テキスト本体に LINE URL スキームを混入させてはならない。');
    });

    test('buildLineTextForMeetingPoints の出力は line: 化に巻き込まれない', () {
      final state = SearchState(results: [_meetingPoint()]);
      final text = ShareUtils.buildLineTextForMeetingPoints(state);
      expect(text, contains('Aimachi'));
      expect(text, isNot(contains('line://')));
    });
  });
}
