import 'package:flutter_test/flutter_test.dart';
// ignore: unused_import
import 'package:mannaka/data/station_data.dart';
import 'package:mannaka/models/participant.dart';
import 'package:mannaka/services/midpoint_service.dart';
import 'package:mannaka/utils/geo_utils.dart';

void main() {
  group('MidpointService.calculate() 近接駅重複排除', () {
    // 新宿(1): (35.6896, 139.7006)
    // 代々木(55): (35.6830, 139.7022)
    // → 約 0.74km → 1.2km 閾値以内なので重複排除される

    test('新宿と代々木が同時に結果に含まれないとき（1.2km未満を排除）', () {
      // 池袋(2)と横浜(7)の中間として新宿・代々木エリアがスコアされやすい状況
      final participants = [
        const Participant(id: '1', name: 'Alice', stationIndex: 2, stationName: '池袋'),
        const Participant(id: '2', name: 'Bob', stationIndex: 7, stationName: '横浜'),
      ];
      final results = MidpointService.calculate(participants);
      expect(results, isNotEmpty);

      final names = results.map((r) => r.stationName).toList();
      final hasShinjuku = names.contains('新宿');
      final hasYoyogi = names.contains('代々木');
      // 新宿と代々木（約0.74km）は同時に上位5件に含まれるべきでない
      expect(
        hasShinjuku && hasYoyogi,
        isFalse,
        reason: '新宿と代々木は約0.74kmで1.2km未満。重複排除後に両方含まれてはいけない',
      );
    });

    test('渋谷が選ばれた場合に代々木が結果に含まれない（約0.74km）', () {
      // 新宿(1): (35.6896, 139.7006)
      // 代々木(55): (35.6830, 139.7022) → 約0.74km → 1.2km未満なので重複排除される
      // ここでは 新宿(1) と 代々木(55) が近いことをさらに明確に確認するテスト
      final participants = [
        const Participant(id: '1', name: 'Alice', stationIndex: 0, stationName: '渋谷'),
        const Participant(id: '2', name: 'Bob', stationIndex: 2, stationName: '池袋'),
      ];
      final results = MidpointService.calculate(participants);
      expect(results, isNotEmpty);

      final names = results.map((r) => r.stationName).toList();
      final hasShinjuku = names.contains('新宿');
      final hasYoyogi = names.contains('代々木');
      if (hasShinjuku) {
        expect(hasYoyogi, isFalse,
            reason: '新宿が選ばれた場合、代々木（約0.74km）は除外されるべき');
      }
    });

    test('結果内の全駅ペアが1.2km以上の距離を保つ', () {
      final participants = [
        const Participant(id: '1', name: 'Alice', stationIndex: 0, stationName: '渋谷'),
        const Participant(id: '2', name: 'Bob', stationIndex: 4, stationName: '東京'),
      ];
      final results = MidpointService.calculate(participants);
      expect(results.length, greaterThanOrEqualTo(2));

      // 全ペアで距離を確認
      for (int i = 0; i < results.length; i++) {
        for (int j = i + 1; j < results.length; j++) {
          final a = (results[i].lat, results[i].lng);
          final b = (results[j].lat, results[j].lng);
          final dist = GeoUtils.distKm(a.$1, a.$2, b.$1, b.$2);
          expect(
            dist,
            greaterThanOrEqualTo(1.2),
            reason:
                '${results[i].stationName}と${results[j].stationName}の距離が'
                '${dist.toStringAsFixed(2)}kmで1.2km未満。重複排除が機能していない',
          );
        }
      }
    });

    test('3参加者ケースでも全駅ペアが1.2km以上の距離を保つ', () {
      final participants = [
        const Participant(id: '1', name: 'Alice', stationIndex: 0, stationName: '渋谷'),
        const Participant(id: '2', name: 'Bob', stationIndex: 4, stationName: '東京'),
        const Participant(id: '3', name: 'Carol', stationIndex: 2, stationName: '池袋'),
      ];
      final results = MidpointService.calculate(participants);
      expect(results, isNotEmpty);
      expect(results.length, lessThanOrEqualTo(5));

      for (int i = 0; i < results.length; i++) {
        for (int j = i + 1; j < results.length; j++) {
          final a = (results[i].lat, results[i].lng);
          final b = (results[j].lat, results[j].lng);
          final dist = GeoUtils.distKm(a.$1, a.$2, b.$1, b.$2);
          expect(
            dist,
            greaterThanOrEqualTo(1.2),
            reason:
                '${results[i].stationName}と${results[j].stationName}の距離が'
                '${dist.toStringAsFixed(2)}kmで1.2km未満',
          );
        }
      }
    });

    test('重複排除後も最大5件以内を返す', () {
      final participants = [
        const Participant(id: '1', name: 'Alice', stationIndex: 0, stationName: '渋谷'),
        const Participant(id: '2', name: 'Bob', stationIndex: 4, stationName: '東京'),
        const Participant(id: '3', name: 'Carol', stationIndex: 2, stationName: '池袋'),
      ];
      final results = MidpointService.calculate(participants);
      expect(results.length, lessThanOrEqualTo(5));
    });

    test('新橋と銀座が同時に結果に含まれないとき（0.88km は 1.2km 未満）', () {
      // 銀座(13): (35.6716, 139.7647)
      // 新橋(14): (35.6656, 139.7583) → 約0.88km → 1.2km 閾値以内なので重複排除される
      // 品川(5)と秋葉原(6)の中間として銀座・新橋エリアがスコアされやすい状況
      final participants = [
        const Participant(id: '1', name: 'Alice', stationIndex: 5, stationName: '品川'),
        const Participant(id: '2', name: 'Bob', stationIndex: 6, stationName: '秋葉原'),
      ];
      final results = MidpointService.calculate(participants);
      expect(results, isNotEmpty);

      final names = results.map((r) => r.stationName).toList();
      final hasGinza = names.contains('銀座');
      final hasShinbashi = names.contains('新橋');
      // 銀座と新橋（約0.88km）は1.2km未満なので同時に上位5件に含まれるべきでない
      expect(
        hasGinza && hasShinbashi,
        isFalse,
        reason: '銀座と新橋は約0.88kmで1.2km未満。重複排除後に両方含まれてはいけない',
      );
    });

    test('赤坂見附と国会議事堂前が同時に結果に含まれないとき（0.91km は 1.2km 未満）', () {
      // 赤坂見附: (35.6797, 139.7368)
      // 国会議事堂前: (35.6735, 139.7434) → 約0.91km → 1.2km 閾値以内なので重複排除される
      // 渋谷(0)と東京(4)の中間として赤坂見附・国会議事堂前エリアがスコアされやすい状況
      final participants = [
        const Participant(id: '1', name: 'Alice', stationIndex: 0, stationName: '渋谷'),
        const Participant(id: '2', name: 'Bob', stationIndex: 4, stationName: '東京'),
      ];
      final results = MidpointService.calculate(participants);
      expect(results, isNotEmpty);

      final names = results.map((r) => r.stationName).toList();
      final hasAkasaka = names.contains('赤坂見附');
      final hasKokkai = names.contains('国会議事堂前');
      // 赤坂見附と国会議事堂前（約0.91km）は1.2km未満なので同時に上位5件に含まれるべきでない
      expect(
        hasAkasaka && hasKokkai,
        isFalse,
        reason: '赤坂見附と国会議事堂前は約0.91kmで1.2km未満。重複排除後に両方含まれてはいけない',
      );
    });

    test('候補が1.2km内しかない場合でも最低1件は返す', () {
      // 1人参加者のみ → その近辺の駅群しかスコアされないが、
      // 最上位駅は必ず返されることを確認
      final participants = [
        const Participant(id: '1', name: 'Alice', stationIndex: 1, stationName: '新宿'),
      ];
      final results = MidpointService.calculate(participants);
      expect(results, isNotEmpty);
      expect(results.length, greaterThanOrEqualTo(1));
    });
  });
}
