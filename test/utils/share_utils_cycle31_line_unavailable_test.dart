// TDD Red フェーズ
// Cycle 31: shareSelectionsToLine / shareMeetingPointsToLine の
//          「LINE 未インストール時のサイレント失敗」を返り値で顕在化する。
//
// 背景:
//   現在の実装（share_utils.dart:218-229 / 296-304）は
//
//     if (await canLaunchUrl(lineUrl)) {
//       await launchUrl(lineUrl, mode: LaunchMode.externalApplication);
//     }
//
//   というガードを持つが、`canLaunchUrl == false` のとき **黙って return**
//   する。呼び出し側（candidate_share_sheet.dart:61 / results_screen.dart:202）
//   は何も検知できないため、ユーザーが LINE ボタンをタップしても画面に
//   何の変化もない（無反応 UX バグ）。
//
//   Cycle 31 では返り値で成否を呼び出し元に伝え、SnackBar 通知できるよう
//   にする。具体的な契約:
//
//     [契約 A] 戻り値型は `Future<bool>` に変える
//             - true  = LINE 起動に成功した（launchUrl が呼ばれた）
//             - false = LINE 起動に失敗した、または送信内容が空
//
//     [契約 B] canLaunchUrl == false のとき launchUrl を呼ばずに false を返す
//
//     [契約 C] 送信テキストが空（empty selections / empty results）のとき
//             canLaunchUrl は問い合わせず false を返す（CTA 行を投げない）
//
//   呼び出し元（candidate_share_sheet / results_screen）は false を受けて
//   SnackBar「LINE がインストールされていません」を出す（呼び出し側修正は
//   別タスクで feature-implementer が対応）。
//
// 期待される Red 失敗:
//   現在 `Future<void>` のため `final bool ok = await ShareUtils.xxx(...)`
//   は型エラーで **コンパイルできない**。これが Red の証拠。
//   Engineer が `Future<bool>` に変えて canLaunch=false の早期 false を
//   実装した時点で Green になる。
//
// 注:
//   - production の動作仕様変更を伴う（characterization snapshot ではない）
//   - canLaunchUrl / launchUrl は url_launcher の `UrlLauncherPlatform.instance`
//     を fake 実装に差し替えてユニットテストする。
//   - 既存の Cycle 27〜30 characterization snapshot（buildLineTextFor*）の
//     出力バイト列は **不変** であるべき（純関数 build 系は触らない）。

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

// ── Fake UrlLauncherPlatform ──────────────────────────────────────
//
// canLaunch / launchUrl の呼び出しを記録し、戻り値を制御する。
// MockPlatformInterfaceMixin で PlatformInterface のトークン検証を回避。
class _FakeUrlLauncher extends UrlLauncherPlatform
    with MockPlatformInterfaceMixin {
  _FakeUrlLauncher({required this.canLaunchResult});

  /// canLaunch の戻り値（true = LINE インストール済を装う）。
  bool canLaunchResult;

  /// canLaunch が呼ばれた URL 履歴。
  final List<String> canLaunchCalls = [];

  /// launchUrl が呼ばれた URL 履歴。canLaunchResult=false のとき
  /// 1 件も入らないことが [契約 B] の機械担保。
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

// ── ヘルパー ──────────────────────────────────────────────
Restaurant _restaurant({String id = 'r1', String name = 'テスト食堂'}) {
  return Restaurant(
    id: id,
    name: name,
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
}

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

  // ════════════════════════════════════════════════════════════════
  // [1] shareSelectionsToLine — LINE 未インストール時の返り値
  // ════════════════════════════════════════════════════════════════
  group('shareSelectionsToLine — LINE 起動成否を Future<bool> で返す', () {
    test('canLaunchUrl=true のとき true を返し、launchUrl が呼ばれる', () async {
      fake.canLaunchResult = true;
      final state = SearchState(
        selectedDate: DateTime(2026, 4, 24),
        selectedMeetingTime: const TimeOfDay(hour: 19, minute: 30),
      );

      final bool ok =
          await ShareUtils.shareSelectionsToLine(state, [_entry()]);

      expect(ok, isTrue,
          reason: '[契約 A] LINE 起動成功時は true を返す。'
              '現在は Future<void> のため bool に代入する時点で型エラー → Red。');
      expect(fake.launchCalls, hasLength(1),
          reason: '成功時は launchUrl が 1 回呼ばれる（line:// scheme）');
      // Cycle 32: iOS では https スキームを `canLaunchUrl` に渡すと
      // Safari が常駐しているため常に true を返してしまい、未インストール検知が
      // 効かない。LINE アプリ専用スキーム `line:` を使うことで
      // LSApplicationQueriesSchemes に登録したアプリの存在チェックが機能する。
      expect(Uri.parse(fake.launchCalls.first).scheme, equals('line'),
          reason:
              '[Cycle 32] LINE 起動 URL は `line:` スキームでなければならない。'
              'https://line.me/R/share は iOS で常に canLaunchUrl=true を返すため'
              'Cycle 31 の未インストール早期 false が発火しない（CRITICAL）。');
      expect(Uri.parse(fake.canLaunchCalls.first).scheme, equals('line'),
          reason:
              '[Cycle 32] canLaunch も同じ `line:` スキームで問い合わせる必要がある。');
    });

    test('canLaunchUrl=false のとき false を返し、launchUrl は呼ばれない', () async {
      fake.canLaunchResult = false;
      final state = SearchState(
        selectedDate: DateTime(2026, 4, 24),
        selectedMeetingTime: const TimeOfDay(hour: 19, minute: 30),
      );

      final bool ok =
          await ShareUtils.shareSelectionsToLine(state, [_entry()]);

      expect(ok, isFalse,
          reason: '[契約 B] LINE 未インストール時はサイレント return せず false を返す。'
              '呼び出し元（candidate_share_sheet.dart:61）はこれを見て SnackBar を出す。');
      expect(fake.launchCalls, isEmpty,
          reason: 'canLaunch=false のときは launchUrl を呼んではならない（外部アプリ起動の試行禁止）');
      expect(fake.canLaunchCalls, hasLength(1),
          reason: 'canLaunch は 1 回問い合わせる（早期 false で短絡）');
    });

    test('selections が空のとき false を返し、canLaunch も呼ばれない', () async {
      final state = SearchState();

      final bool ok =
          await ShareUtils.shareSelectionsToLine(state, const []);

      expect(ok, isFalse,
          reason: '[契約 C] 送信内容が空のとき LINE は開かない → false。');
      expect(fake.canLaunchCalls, isEmpty,
          reason: '空テキストで canLaunch を問い合わせるのは無駄（早期 return）');
      expect(fake.launchCalls, isEmpty);
    });
  });

  // ════════════════════════════════════════════════════════════════
  // [2] shareMeetingPointsToLine — LINE 未インストール時の返り値
  // ════════════════════════════════════════════════════════════════
  group('shareMeetingPointsToLine — LINE 起動成否を Future<bool> で返す', () {
    test('canLaunchUrl=true のとき true を返し、launchUrl が呼ばれる', () async {
      fake.canLaunchResult = true;
      final state = SearchState(results: [_meetingPoint()]);

      final bool ok = await ShareUtils.shareMeetingPointsToLine(state);

      expect(ok, isTrue,
          reason: '[契約 A] LINE 起動成功時は true を返す。');
      expect(fake.launchCalls, hasLength(1));
      expect(Uri.parse(fake.launchCalls.first).scheme, equals('line'),
          reason:
              '[Cycle 32] meeting points 用 LINE 起動も `line:` スキームでなければならない。'
              'https では iOS の canLaunch=true 常成立で未インストール検知不能。');
      expect(Uri.parse(fake.canLaunchCalls.first).scheme, equals('line'));
    });

    test('canLaunchUrl=false のとき false を返し、launchUrl は呼ばれない', () async {
      fake.canLaunchResult = false;
      final state = SearchState(results: [_meetingPoint()]);

      final bool ok = await ShareUtils.shareMeetingPointsToLine(state);

      expect(ok, isFalse,
          reason: '[契約 B] LINE 未インストール時は false を返す。'
              '呼び出し元（results_screen.dart:202）はこれを見て SnackBar を出す。');
      expect(fake.launchCalls, isEmpty);
      expect(fake.canLaunchCalls, hasLength(1));
    });

    test('state.results が空のとき false を返し、canLaunch も呼ばれない', () async {
      final state = SearchState();

      final bool ok = await ShareUtils.shareMeetingPointsToLine(state);

      expect(ok, isFalse,
          reason: '[契約 C] state.results 空 → LINE は開かない → false。');
      expect(fake.canLaunchCalls, isEmpty);
      expect(fake.launchCalls, isEmpty);
    });
  });
}
