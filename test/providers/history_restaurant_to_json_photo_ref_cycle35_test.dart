// TDD Red フェーズ — Cycle 35: HistoryRestaurant.toJson が API キーを Firestore に書き出さない
//
// 背景（Critic CRITICAL ISSUE-A）:
//   `lib/providers/history_provider.dart:43` が `imageUrl` を素通ししている。
//   検索履歴は `users/{uid}/search_history/...` に保存されるため、
//   Google Places の `&key=...` 付き URL が永続化される経路が残っている。
//
// 受入条件:
//   [A] toJson() の imageUrl に `&key=` が一切含まれない
//   [B] toJson() 全体（toString）にも `&key=` が一度も現れない
//   [C] toJson() は Google Places URL を reference 形式に変換
//   [D] toJson() は Hotpepper の URL はそのまま保存
//   [E] imageUrl が null のときは toJson から `imageUrl` キー自体が省略される
//       （現行挙動: `if (imageUrl != null) 'imageUrl': imageUrl` を維持）
//   [F] fromJson(toJson(r)) ラウンドトリップで imageUrl が表示可能な URL に復元

import 'package:flutter_test/flutter_test.dart';
import 'package:mannaka/providers/history_provider.dart';

const _googleUrl =
    'https://places.googleapis.com/v1/places/ChIJhistory33/photos/AeYy_HistC/media?maxHeightPx=600&key=DUMMY_LEAKED_KEY_HISTORY_333';
const _hotpepperUrl = 'https://imgfp.hotp.jp/IMGH/history/example.jpg';

HistoryRestaurant _make({String? imageUrl}) => HistoryRestaurant(
      name: 'History Cafe',
      category: 'カフェ',
      rating: 4.2,
      imageUrl: imageUrl,
      photoRefs: const [],
      hotpepperUrl: 'https://www.hotpepper.jp/history',
      lat: 35.69,
      lng: 139.70,
      address: '東京都新宿区',
    );

void main() {
  group('Cycle 35: HistoryRestaurant.toJson が Firestore へ API キーを書き出さない', () {
    test('Google Places URL を toJson() しても、imageUrl に `&key=` が一切含まれない', () {
      final r = _make(imageUrl: _googleUrl);
      final saved = r.toJson()['imageUrl'] as String?;

      expect(saved, isNotNull);
      expect(
        saved!.contains('&key='),
        isFalse,
        reason: 'HistoryRestaurant.toJson() の imageUrl に `&key=` が残っています:\n  $saved\n\n'
            'toJson 内で PhotoRef.toRef(imageUrl!) を適用してください。',
      );
      expect(saved.contains('DUMMY_LEAKED_KEY_HISTORY_'), isFalse);
    });

    test('toJson() 全体の文字列表現にも `&key=` が一度も現れない', () {
      final whole = _make(imageUrl: _googleUrl).toJson().toString();
      expect(whole.contains('&key='), isFalse, reason: '残存検出:\n$whole');
      expect(whole.contains('DUMMY_LEAKED_KEY_HISTORY_333'), isFalse);
    });

    test('toJson() は Google Places URL を `places/{id}/photos/{photoId}` reference に変換する', () {
      final saved = _make(imageUrl: _googleUrl).toJson()['imageUrl'] as String?;
      expect(
        saved,
        equals('places/ChIJhistory33/photos/AeYy_HistC'),
        reason: '実値: $saved',
      );
    });

    test('toJson() は Hotpepper の URL（キー不要）をそのまま保存する', () {
      final saved = _make(imageUrl: _hotpepperUrl).toJson()['imageUrl'] as String?;
      expect(saved, equals(_hotpepperUrl));
    });

    test('imageUrl が null のときは toJson から imageUrl キー自体が省略される（現行挙動維持）', () {
      // HistoryRestaurant は他 2 モデルと違い `if (imageUrl != null)` ガードで
      // キー自体を省略している。Cycle 35 修正後もこの軽量化は維持する。
      final json = _make(imageUrl: null).toJson();
      expect(
        json.containsKey('imageUrl'),
        isFalse,
        reason: '既存挙動: imageUrl が null のときはキー自体を出さない構造を維持してください。',
      );
    });

    test('fromJson(toJson(r)) で Google Places の imageUrl が表示可能な URL に復元される', () {
      final restored =
          HistoryRestaurant.fromJson(_make(imageUrl: _googleUrl).toJson());
      expect(restored.imageUrl, isNotNull);
      expect(
        restored.imageUrl!.startsWith(
            'https://places.googleapis.com/v1/places/ChIJhistory33/photos/AeYy_HistC/media'),
        isTrue,
        reason: '実値: ${restored.imageUrl}',
      );
      expect(restored.imageUrl!.contains('&key='), isTrue);
    });

    test('fromJson(toJson(r)) で Hotpepper の imageUrl はそのまま', () {
      final restored =
          HistoryRestaurant.fromJson(_make(imageUrl: _hotpepperUrl).toJson());
      expect(restored.imageUrl, equals(_hotpepperUrl));
    });
  });
}
