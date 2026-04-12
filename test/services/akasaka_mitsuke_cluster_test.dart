// TDD テスト: 赤坂見附圏クラスタの重複排除
//
// 受け入れ条件:
//   1. 国会議事堂前 → 赤坂見附 としてクラスタマッピングされる
//   2. 永田町 → 赤坂見附 としてクラスタマッピングされる
//   3. 溜池山王 → 赤坂見附 としてクラスタマッピングされる
//   4. calculate() の結果に赤坂見附圏の駅が2つ以上含まれない
//
// 背景: deduplication_test.dart で距離ベースの排除はテスト済みだが、
//        クラスタマッピング（_kClusterMap）の正当性は未検証。
//        永田町・溜池山王は新規追加のため特にテストが必要。

import 'package:flutter_test/flutter_test.dart';
import 'package:mannaka/models/participant.dart';
import 'package:mannaka/services/midpoint_service.dart';

void main() {
  // ─────────────────────────────────────────────────────
  // 赤坂見附圏: 国会議事堂前・永田町・溜池山王
  // ─────────────────────────────────────────────────────
  group('MidpointService.calculate() 赤坂見附圏クラスタ排除', () {
    // 渋谷(0) と 東京(4) の中間地点として赤坂見附エリアが候補に上がりやすい
    final participants = [
      const Participant(
          id: '1', name: 'Alice', stationIndex: 0, stationName: '渋谷'),
      const Participant(
          id: '2', name: 'Bob', stationIndex: 4, stationName: '東京'),
    ];

    /// 赤坂見附圏の全駅名
    final akasakaCluster = {'赤坂見附', '国会議事堂前', '永田町', '溜池山王'};

    test('結果に赤坂見附圏の駅が最大1つしか含まれないとき（クラスタ排除）', () {
      final results = MidpointService.calculate(participants);
      expect(results, isNotEmpty);

      final names = results.map((r) => r.stationName).toSet();
      final akasakaInResults = names.intersection(akasakaCluster);

      expect(
        akasakaInResults.length,
        lessThanOrEqualTo(1),
        reason: '赤坂見附圏の駅が ${akasakaInResults.length} 件含まれています: '
            '$akasakaInResults。クラスタマッピングにより最大1件に絞られるべき。',
      );
    });

    test('永田町と赤坂見附が同時に結果に含まれないとき', () {
      final results = MidpointService.calculate(participants);
      expect(results, isNotEmpty);

      final names = results.map((r) => r.stationName).toList();
      final hasAkasaka = names.contains('赤坂見附');
      final hasNagatacho = names.contains('永田町');

      expect(
        hasAkasaka && hasNagatacho,
        isFalse,
        reason: '永田町は赤坂見附圏にクラスタマッピングされているため、'
            '両方が結果に含まれてはいけない。',
      );
    });

    test('溜池山王と赤坂見附が同時に結果に含まれないとき', () {
      final results = MidpointService.calculate(participants);
      expect(results, isNotEmpty);

      final names = results.map((r) => r.stationName).toList();
      final hasAkasaka = names.contains('赤坂見附');
      final hasTameike = names.contains('溜池山王');

      expect(
        hasAkasaka && hasTameike,
        isFalse,
        reason: '溜池山王は赤坂見附圏にクラスタマッピングされているため、'
            '両方が結果に含まれてはいけない。',
      );
    });

    test('国会議事堂前と永田町が同時に結果に含まれないとき', () {
      final results = MidpointService.calculate(participants);
      expect(results, isNotEmpty);

      final names = results.map((r) => r.stationName).toList();
      final hasKokkai = names.contains('国会議事堂前');
      final hasNagatacho = names.contains('永田町');

      expect(
        hasKokkai && hasNagatacho,
        isFalse,
        reason: '国会議事堂前と永田町は両方とも赤坂見附圏のため、'
            '同時に結果に含まれてはいけない。',
      );
    });

    test('3参加者ケースでも赤坂見附圏は最大1駅のとき', () {
      final participants3 = [
        const Participant(
            id: '1', name: 'Alice', stationIndex: 0, stationName: '渋谷'),
        const Participant(
            id: '2', name: 'Bob', stationIndex: 4, stationName: '東京'),
        const Participant(
            id: '3', name: 'Carol', stationIndex: 2, stationName: '池袋'),
      ];
      final results = MidpointService.calculate(participants3);
      expect(results, isNotEmpty);

      final names = results.map((r) => r.stationName).toSet();
      final akasakaInResults = names.intersection(akasakaCluster);

      expect(
        akasakaInResults.length,
        lessThanOrEqualTo(1),
        reason: '3参加者ケースでも赤坂見附圏は最大1駅のみ。'
            '結果: $akasakaInResults',
      );
    });
  });
}
