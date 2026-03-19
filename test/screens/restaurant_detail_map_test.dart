// TDD Red フェーズ
// Cycle 4: 地図マーカー絵文字UIアイコン違反のテスト
//
// CLAUDE.md: 「絵文字をUIアイコンとして使用禁止 — Material Icons のみ」
//
// 違反箇所:
//   restaurant_detail_screen.dart:413
//     child: Text(restaurant.emoji, style: const TextStyle(fontSize: 20))
//
// Engineer への実装依頼:
//   上記の Text(restaurant.emoji) を
//   Icon(Icons.restaurant_rounded, size: 22, color: AppColors.primary)
//   に置き換える。

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mannaka/models/restaurant.dart';
import 'package:mannaka/screens/restaurant_detail_screen.dart';

const _testRestaurant = Restaurant(
  id: 'map_icon_test_1',
  name: '地図マーカーテスト店',
  stationIndex: 0,
  category: '和食',
  rating: 4.0,
  reviewCount: 40,
  priceLabel: '¥2,500',
  priceAvg: 2500,
  tags: [],
  emoji: '🍱',
  description: 'テスト用店舗',
  distanceMinutes: 5,
  address: '東京都渋谷区1-1-1',
  openHours: '11:00-22:00',
  lat: 35.6812,
  lng: 139.7671,
  isReservable: false,
);

Widget _buildDetailWidget() => const ProviderScope(
      child: MaterialApp(
        home: RestaurantDetailScreen(restaurant: _testRestaurant),
      ),
    );

void main() {
  group('地図マーカー — UIアイコンルール (CLAUDE.md)', () {
    testWidgets(
        '地図マーカーに絵文字 Text が表示されないとき UIアイコンルールに準拠する',
        (tester) async {
      await tester.pumpWidget(_buildDetailWidget());
      await tester.pump();

      final mapFinder = find.byType(FlutterMap);
      expect(mapFinder, findsOneWidget,
          reason: 'FlutterMap が見つかりません。lat/lng を持つ店舗で _MapCard が表示されます。');

      // FlutterMap 内に絵文字 Text が存在しないことを確認
      final textsInMap = tester
          .widgetList<Text>(
            find.descendant(of: mapFinder, matching: find.byType(Text)),
          )
          .where((t) => t.data == _testRestaurant.emoji)
          .toList();

      expect(
        textsInMap,
        isEmpty,
        reason: '地図マーカーに絵文字 Text(restaurant.emoji) が使われています。'
            'CLAUDE.md: 「絵文字をUIアイコンとして使用禁止」。'
            'Icon(Icons.restaurant_rounded) に変更してください。'
            '違反箇所: restaurant_detail_screen.dart:413',
      );
    });

    testWidgets(
        '地図マーカーに Icons.restaurant_rounded が表示されるとき UIアイコンルールに準拠する',
        (tester) async {
      await tester.pumpWidget(_buildDetailWidget());
      await tester.pump();

      final mapFinder = find.byType(FlutterMap);
      expect(mapFinder, findsOneWidget);

      // FlutterMap 内に Icons.restaurant_rounded Icon があることを確認
      final iconsInMap = tester
          .widgetList<Icon>(
            find.descendant(of: mapFinder, matching: find.byType(Icon)),
          )
          .where((i) => i.icon == Icons.restaurant_rounded)
          .toList();

      expect(
        iconsInMap,
        isNotEmpty,
        reason: '地図マーカーに Icon(Icons.restaurant_rounded) が見つかりません。'
            'Text(restaurant.emoji) を Icon(Icons.restaurant_rounded) に'
            '置き換えてください。'
            '違反箇所: restaurant_detail_screen.dart:413',
      );
    });
  });
}
