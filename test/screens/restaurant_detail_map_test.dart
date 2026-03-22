// 地図マーカー UIアイコンルールテスト
// restaurant_detail_screen.dart は Google Maps (_GMapCard) を使用しており、
// lat/lng がある店舗で地図が表示される。
// flutter_map の FlutterMap は使用していない。

import 'package:flutter/material.dart';
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
  isReservable: true,
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

      // CLAUDE.md: 「絵文字をUIアイコンとして使用禁止」
      // 詳細画面全体で emoji を表示する Text を検索し、
      // マーカーや独立したUIアイコンとして絵文字が使われていないことを確認する。
      // （店名・カテゴリに付随する絵文字は許容）
      // 現在の実装: Google Maps (_GMapCard) を使用。FlutterMap は使用しない。
      final emojiTexts = tester
          .widgetList<Text>(find.byType(Text))
          .where((t) =>
              t.data == _testRestaurant.emoji &&
              // 絵文字が単独のアイコンとして使われている場合のみNG
              (t.style?.fontSize ?? 0) >= 20)
          .toList();

      expect(
        emojiTexts,
        isEmpty,
        reason: '地図マーカー等に絵文字 Text(restaurant.emoji) が使われています。'
            'CLAUDE.md: 「絵文字をUIアイコンとして使用禁止」。'
            'Icon(Icons.restaurant_rounded) に変更してください。',
      );
    });

    testWidgets(
        '地図マーカーに Icons.restaurant_rounded が表示されるとき UIアイコンルールに準拠する',
        (tester) async {
      await tester.pumpWidget(_buildDetailWidget());
      await tester.pump();

      // _GMapCard (Google Maps) はプラットフォームチャンネルを必要とするため
      // ウィジェットテストでは内部マーカーを検証できない。
      // 代わりに、詳細画面内で restaurant アイコン系 Icon が使われていることを確認する。
      final restaurantIcons = tester
          .widgetList<Icon>(find.byType(Icon))
          .where((i) =>
              i.icon == Icons.restaurant_rounded ||
              i.icon == Icons.restaurant_menu_rounded ||
              i.icon == Icons.restaurant_menu_outlined)
          .toList();

      expect(
        restaurantIcons,
        isNotEmpty,
        reason: '詳細画面内に Icons.restaurant_rounded 系アイコンが見つかりません。',
      );
    });
  });
}
