// TDD Red フェーズ — Cycle 35: ReservedRestaurant.toJson が API キーを Firestore に書き出さない
//
// 背景（Critic CRITICAL ISSUE-A）:
//   Visited と同じ経路で Reserved も `imageUrl` を素通ししている
//   （`lib/models/reserved_restaurant.dart:41`）。
//   `users/{uid}/reserved_restaurants/...` に `&key=` 付き URL が保存されうる。
//
// 受入条件は VisitedRestaurant 版と同じ（ただし visitedAt → reservedAt）。

import 'package:flutter_test/flutter_test.dart';
import 'package:mannaka/models/reserved_restaurant.dart';

const _googleUrl =
    'https://places.googleapis.com/v1/places/ChIJreserved22/photos/AeYy_ResB/media?maxHeightPx=600&key=DUMMY_LEAKED_KEY_RESERVED_222';
const _hotpepperUrl = 'https://imgfp.hotp.jp/IMGH/reserved/example.jpg';

ReservedRestaurant _make({String? imageUrl}) => ReservedRestaurant(
      id: 'res1',
      restaurantName: 'Reserved Bistro',
      category: 'イタリアン',
      reservedAt: DateTime.utc(2026, 5, 1, 19, 0),
      address: '東京都港区',
      hotpepperUrl: 'https://www.hotpepper.jp/reserved',
      imageUrl: imageUrl,
      lat: 35.66,
      lng: 139.74,
      nearestStation: '六本木',
      groupNames: const ['同僚A'],
    );

void main() {
  group('Cycle 35: ReservedRestaurant.toJson が Firestore へ API キーを書き出さない', () {
    test('Google Places URL を toJson() しても、imageUrl に `&key=` が一切含まれない', () {
      final r = _make(imageUrl: _googleUrl);
      final saved = r.toJson()['imageUrl'] as String?;

      expect(saved, isNotNull);
      expect(
        saved!.contains('&key='),
        isFalse,
        reason: 'ReservedRestaurant.toJson() の imageUrl に `&key=` が残っています:\n  $saved\n\n'
            'toJson 内で PhotoRef.toRef(imageUrl!) を適用してください。',
      );
      expect(saved.contains('DUMMY_LEAKED_KEY_RESERVED_'), isFalse);
    });

    test('toJson() 全体の文字列表現にも `&key=` が一度も現れない', () {
      final r = _make(imageUrl: _googleUrl);
      final whole = r.toJson().toString();
      expect(whole.contains('&key='), isFalse, reason: '残存検出:\n$whole');
      expect(whole.contains('DUMMY_LEAKED_KEY_RESERVED_222'), isFalse);
    });

    test('toJson() は Google Places URL を `places/{id}/photos/{photoId}` reference に変換する', () {
      final saved = _make(imageUrl: _googleUrl).toJson()['imageUrl'] as String?;
      expect(
        saved,
        equals('places/ChIJreserved22/photos/AeYy_ResB'),
        reason: '実値: $saved',
      );
    });

    test('toJson() は Hotpepper の URL（キー不要）をそのまま保存する', () {
      final saved = _make(imageUrl: _hotpepperUrl).toJson()['imageUrl'] as String?;
      expect(saved, equals(_hotpepperUrl));
    });

    test('imageUrl が null のときも toJson / fromJson が安全に動く', () {
      final r = _make(imageUrl: null);
      final json = r.toJson();
      expect(json.containsKey('imageUrl'), isTrue);
      expect(json['imageUrl'], isNull);
      expect(ReservedRestaurant.fromJson(json).imageUrl, isNull);
    });

    test('fromJson(toJson(r)) で Google Places の imageUrl が表示可能な URL に復元される', () {
      final restored = ReservedRestaurant.fromJson(_make(imageUrl: _googleUrl).toJson());
      expect(restored.imageUrl, isNotNull);
      expect(
        restored.imageUrl!.startsWith(
            'https://places.googleapis.com/v1/places/ChIJreserved22/photos/AeYy_ResB/media'),
        isTrue,
        reason: '実値: ${restored.imageUrl}',
      );
      expect(restored.imageUrl!.contains('&key='), isTrue);
    });

    test('fromJson(toJson(r)) で Hotpepper の imageUrl はそのまま', () {
      final restored =
          ReservedRestaurant.fromJson(_make(imageUrl: _hotpepperUrl).toJson());
      expect(restored.imageUrl, equals(_hotpepperUrl));
    });
  });
}
