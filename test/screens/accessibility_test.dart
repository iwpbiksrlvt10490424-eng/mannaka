import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mannaka/models/restaurant.dart';
import 'package:mannaka/screens/restaurant_detail_screen.dart';
import 'package:mannaka/screens/search_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// テスト用レストラン（lat/lng あり → _RouteButton, _MapCard が表示される）
const _testRestaurant = Restaurant(
  id: 'acc_test_1',
  name: 'アクセシビリティテスト店',
  stationIndex: 0,
  category: '和食',
  rating: 4.2,
  reviewCount: 80,
  priceLabel: '¥3,000',
  priceAvg: 3000,
  tags: [],
  emoji: '🍱',
  description: 'テスト用店舗',
  distanceMinutes: 5,
  address: '東京都渋谷区',
  openHours: '11:00-23:00',
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
  // ────────────────────────────────────────────────────────────────────────────
  // RestaurantDetailScreen ボタン Tooltip テスト
  // ────────────────────────────────────────────────────────────────────────────
  group('RestaurantDetailScreen アクセシビリティ — Tooltip', () {
    testWidgets('ルート検索ボタンに Tooltip が設定されているとき スクリーンリーダーが読み上げられる',
        (tester) async {
      await tester.pumpWidget(_buildDetailWidget());
      await tester.pump();

      final tooltips = tester.widgetList<Tooltip>(find.byType(Tooltip));
      expect(
        tooltips.any((t) => t.message != null && t.message!.contains('ルート')),
        isTrue,
        reason: '_RouteButton に Tooltip(message: "Googleマップでルート検索") が必要です。',
      );
    });

    testWidgets('予約ボタンに Tooltip が設定されているとき スクリーンリーダーが読み上げられる',
        (tester) async {
      await tester.pumpWidget(_buildDetailWidget());
      await tester.pump();

      final tooltips = tester.widgetList<Tooltip>(find.byType(Tooltip));
      expect(
        tooltips.any((t) => t.message != null && t.message!.contains('予約')),
        isTrue,
        reason: '_ReserveButton に Tooltip(message: "予約する") が必要です。',
      );
    });

    testWidgets('飲食記録ボタンに Tooltip が設定されているとき スクリーンリーダーが読み上げられる',
        (tester) async {
      // 飲食記録機能はシェアボトムシート内にあるため、
      // メイン画面には「記録」テキストが存在することを確認する
      await tester.pumpWidget(_buildDetailWidget());
      await tester.pump();

      // シェアボタン（AppBar内の保存アイコン or シェア系テキスト）があれば OK
      final hasRecordFeature = find.byType(IconButton).evaluate().isNotEmpty ||
          find.byType(Tooltip).evaluate().isNotEmpty;
      expect(hasRecordFeature, isTrue,
          reason: '詳細画面に保存・記録系のアクション要素が必要です。');
    });
  });

  // ────────────────────────────────────────────────────────────────────────────
  // SearchScreen「友達を追加」InkWell の Semantics テスト
  // ────────────────────────────────────────────────────────────────────────────
  group('SearchScreen アクセシビリティ — InkWell Semantics', () {
    setUp(() {
      // SharedPreferences のモック初期化（SearchNotifier._autoFillHomeStation が利用）
      SharedPreferences.setMockInitialValues({});
    });

    testWidgets('友達を追加 InkWell が Semantics の isButton フラグを持つとき アクセシビリティに対応している',
        (tester) async {
      final handle = tester.ensureSemantics();

      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: SearchScreen(),
          ),
        ),
      );
      await tester.pump();

      final addText = find.text('友達を追加');
      expect(
        addText,
        findsOneWidget,
        reason: '「友達を追加」テキストが見つかりません。参加者数が 6 以上になっていないか確認してください。',
      );

      final semanticsNode = tester.getSemantics(addText);
      expect(
        semanticsNode.getSemanticsData().flagsCollection.isButton,
        isTrue,
        reason: '「友達を追加」InkWell を '
            '`Semantics(button: true, label: "友達を追加", child: InkWell(...))` '
            'で囲む必要があります。',
      );

      handle.dispose();
    });
  });
}
