// ignore_for_file: avoid_relative_lib_imports
import 'package:flutter_test/flutter_test.dart';
import 'package:mannaka/screens/restaurant_detail_screen.dart';

// TDD Red フェーズ
// buildGoogleMapsRouteUrl() は現時点で restaurant_detail_screen.dart に存在しない。
// Engineer は _openRoute() の URL 構築ロジックを以下のシグネチャで抽出すること:
//   String buildGoogleMapsRouteUrl(double lat, double lng)
// 実装後に destination_place_id パラメータを削除する。

void main() {
  group('buildGoogleMapsRouteUrl()', () {
    test('URLに destination_place_id が含まれないとき 店名がGoogleに送信されない', () {
      // destination_place_id に店名を入れると API に店名文字列が渡り
      // プライバシー・URLインジェクションのリスクがある。
      final url = buildGoogleMapsRouteUrl(35.6812, 139.7671);
      expect(
        url,
        isNot(contains('destination_place_id')),
        reason: '`destination_place_id=店名` は不要なパラメータです。削除してください。',
      );
    });

    test('URLに正しい緯度経度が含まれるとき ルート検索が機能する', () {
      final url = buildGoogleMapsRouteUrl(35.6812, 139.7671);
      expect(
        url,
        contains('destination=35.6812,139.7671'),
        reason: 'destination パラメータは `lat,lng` 形式である必要があります。',
      );
    });

    test('URLに travelmode=walking が含まれるとき 徒歩ルートが表示される', () {
      final url = buildGoogleMapsRouteUrl(35.6812, 139.7671);
      expect(url, contains('travelmode=walking'));
    });

    test('URLが Google Maps dir エンドポイントを指しているとき 正しいサービスに遷移する', () {
      final url = buildGoogleMapsRouteUrl(35.6812, 139.7671);
      expect(url, startsWith('https://www.google.com/maps/dir/'));
    });
  });
}
