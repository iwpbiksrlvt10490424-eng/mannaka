import 'package:flutter_test/flutter_test.dart';
import 'package:mannaka/utils/geo_utils.dart';

void main() {
  group('GeoUtils.distKm()', () {
    test('同じ座標間の距離が0である', () {
      final d = GeoUtils.distKm(35.6812, 139.7671, 35.6812, 139.7671);
      expect(d, equals(0.0));
    });

    test('東京駅〜新宿駅間が約6-7kmである', () {
      // 東京駅: 35.6812, 139.7671
      // 新宿駅: 35.6896, 139.7006
      final d = GeoUtils.distKm(35.6812, 139.7671, 35.6896, 139.7006);
      expect(d, greaterThan(6.0));
      expect(d, lessThan(7.0));
    });

    test('東京駅〜横浜駅間が約25-30kmである', () {
      // 東京駅: 35.6812, 139.7671
      // 横浜駅: 35.4660, 139.6222
      final d = GeoUtils.distKm(35.6812, 139.7671, 35.4660, 139.6222);
      expect(d, greaterThan(25.0));
      expect(d, lessThan(30.0));
    });

    test('距離は対称的である（A→B == B→A）', () {
      final ab = GeoUtils.distKm(35.6812, 139.7671, 35.6896, 139.7006);
      final ba = GeoUtils.distKm(35.6896, 139.7006, 35.6812, 139.7671);
      expect(ab, closeTo(ba, 0.0001));
    });

    test('距離は常に0以上である', () {
      final d = GeoUtils.distKm(0.0, 0.0, 90.0, 180.0);
      expect(d, greaterThanOrEqualTo(0.0));
    });
  });
}
