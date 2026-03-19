// TDD Red フェーズ
// P2: SizedBox(height:1)+ColoredBox による疑似Divider 禁止ルール違反のテスト
//
// CLAUDE.md: 「Divider 禁止 — SizedBox 8-10px で区切る」
//
// 違反箇所:
//   restaurant_detail_screen.dart:434  → _InfoCard 行区切り
//   restaurant_detail_screen.dart:656  → _NearbySection 上区切り
//   restaurant_detail_screen.dart:674  → ListView.separatorBuilder
//
// Engineer への実装依頼:
//   上記3箇所の `SizedBox(height:1, child: ColoredBox(...))` および
//   `SizedBox(height:4, child: ColoredBox(...))` を
//   `SizedBox(height: 8)` または `SizedBox(height: 10)` に置き換える。
//   _InfoCard のインライン行区切りも同様に SizedBox(height: 8) に変更する。

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mannaka/models/restaurant.dart';
import 'package:mannaka/screens/restaurant_detail_screen.dart';

/// カテゴリ・予算・住所・営業時間が揃っているため _InfoCard で
/// 複数行が描画され、行区切りの ColoredBox が確実に現れる。
const _testRestaurant = Restaurant(
  id: 'design_test_1',
  name: 'デザインルールテスト店',
  stationIndex: 0,
  category: '和食',
  rating: 4.0,
  reviewCount: 50,
  priceLabel: '¥2,000',
  priceAvg: 2000,
  tags: [],
  emoji: '🍱',
  description: 'テスト用店舗',
  distanceMinutes: 5,
  address: '東京都渋谷区1-1-1',
  openHours: '11:00-22:00',
  lat: 35.6812,
  lng: 139.7671,
  isReservable: true,
);

Widget _buildDetailWidget() => const ProviderScope(
      child: MaterialApp(
        home: RestaurantDetailScreen(restaurant: _testRestaurant),
      ),
    );

void main() {
  group('デザインルール — 疑似Divider禁止 (CLAUDE.md)', () {
    testWidgets(
        'RestaurantDetailScreen に ColoredBox が含まれないとき Divider禁止ルールに準拠する',
        (tester) async {
      await tester.pumpWidget(_buildDetailWidget());
      await tester.pump();

      // ColoredBox は疑似Divider用途にしか使われていない。
      // ※ flutter_map の FlutterMap ウィジェットは背景色用に ColoredBox を
      //   1件内部使用するため、それを除いた数が 0 であることを確認する。
      final allCount = tester.widgetList<ColoredBox>(
        find.byType(ColoredBox),
      ).length;
      final mapCount = tester.widgetList<ColoredBox>(
        find.descendant(
          of: find.byType(FlutterMap),
          matching: find.byType(ColoredBox),
        ),
      ).length;
      final pseudoDividerCount = allCount - mapCount;

      expect(
        pseudoDividerCount,
        0,
        reason: 'ColoredBox は疑似Dividerとして使われています。'
            'SizedBox(height: 8) 以上の余白に置き換えてください。'
            '違反箇所: restaurant_detail_screen.dart:434, 656, 674',
      );
    });

    testWidgets(
        '_InfoCard の行区切りが SizedBox(height:1) を含まないとき Divider禁止ルールに準拠する',
        (tester) async {
      await tester.pumpWidget(_buildDetailWidget());
      await tester.pump();

      // height=1 の SizedBox は 1px 区切り線（疑似Divider）とみなす
      final sizedBoxes =
          tester.widgetList<SizedBox>(find.byType(SizedBox)).toList();
      final onePxBoxes = sizedBoxes.where((sb) => sb.height == 1.0).toList();

      expect(
        onePxBoxes,
        isEmpty,
        reason: 'height=1 の SizedBox は疑似Dividerです。'
            'SizedBox(height: 8) 以上に変更してください。',
      );
    });
  });
}
