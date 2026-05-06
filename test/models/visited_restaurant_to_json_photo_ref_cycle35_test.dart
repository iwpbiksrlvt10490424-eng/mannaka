// TDD Red フェーズ — Cycle 35: VisitedRestaurant.toJson が API キーを Firestore に書き出さない
//
// 背景（Critic CRITICAL ISSUE-A）:
//   `rating_enrichment_service.dart:141-142` が rating null のレストランに対し
//   Hotpepper の単一 `imageUrl` が無いとき Google Places の `&key=...` 付き URL を
//   Restaurant.imageUrl にフォールバック書き戻しする。
//   ユーザーが「行ったお店」に登録すると `VisitedRestaurant.toJson()` が
//   その `imageUrl` を素通しし、`users/{uid}/visited_restaurants/...` 配下に
//   API キー入りの URL が永続化される。
//
//   Cycle 34 で `Restaurant.toJson` 側は `PhotoRef.toRef` 経由に修正済みだが、
//   `VisitedRestaurant.toJson` は素通しのまま残っている（同パターン全箇所一括修正
//   違反）。本サイクルで同方針に揃える。
//
// 受入条件:
//   [A] toJson() の `imageUrl` に `&key=` が一切含まれない
//   [B] toJson() 全体（toString）にも `&key=` が一度も現れない
//   [C] toJson() は Google Places URL を `places/.../photos/...` reference に変換
//   [D] toJson() は Hotpepper の URL（キー不要）はそのまま保存
//   [E] imageUrl が null のときも toJson / fromJson が安全に動く
//   [F] fromJson(toJson(r)) ラウンドトリップで imageUrl が表示可能な URL に復元
//       （= 既存 UI で `r.imageUrl` を直接画像 URL として使っている画面が壊れない）
//
// 不変項（侵してはならない）:
//   - VisitedRestaurant の他フィールド（visitedAt, photoRefs, lat/lng 等）は影響なし
//   - photoRefs は既に reference 形式で保存される構造のため変更しない

import 'package:flutter_test/flutter_test.dart';
import 'package:mannaka/models/visited_restaurant.dart';

const _googleUrl =
    'https://places.googleapis.com/v1/places/ChIJvisited01/photos/AeYy_VisitA/media?maxHeightPx=600&key=DUMMY_LEAKED_KEY_VISITED_111';
const _hotpepperUrl = 'https://imgfp.hotp.jp/IMGH/visited/example.jpg';

VisitedRestaurant _make({String? imageUrl}) => VisitedRestaurant(
      id: 'v1',
      restaurantName: 'Visited Cafe',
      category: 'カフェ',
      visitedAt: DateTime.utc(2026, 4, 30, 12, 0),
      groupNames: const ['友人A'],
      address: '東京都千代田区',
      nearestStation: '東京',
      hotpepperUrl: 'https://www.hotpepper.jp/visited',
      imageUrl: imageUrl,
      lat: 35.68,
      lng: 139.76,
    );

void main() {
  group('Cycle 35: VisitedRestaurant.toJson が Firestore へ API キーを書き出さない', () {
    // ──────────────────────────────────────────────────────────────────
    // [A] `&key=` 完全排除
    // ──────────────────────────────────────────────────────────────────
    test('Google Places URL を toJson() しても、imageUrl に `&key=` が一切含まれない', () {
      final r = _make(imageUrl: _googleUrl);
      final json = r.toJson();
      final saved = json['imageUrl'] as String?;

      expect(saved, isNotNull, reason: 'imageUrl を渡したのに保存されていない');
      expect(
        saved!.contains('&key='),
        isFalse,
        reason: 'VisitedRestaurant.toJson() の imageUrl に `&key=` が残っています:\n  $saved\n\n'
            'toJson 内で PhotoRef.toRef(imageUrl!) を適用してください。',
      );
      expect(
        saved.contains('DUMMY_LEAKED_KEY_VISITED_'),
        isFalse,
        reason: 'toJson() 出力に元のキー文字列がそのまま入っています:\n  $saved',
      );
    });

    // ──────────────────────────────────────────────────────────────────
    // [B] toJson 全体に `&key=` ゼロ
    // ──────────────────────────────────────────────────────────────────
    test('toJson() 全体の文字列表現にも `&key=` が一度も現れない', () {
      final r = _make(imageUrl: _googleUrl);
      final whole = r.toJson().toString();

      expect(
        whole.contains('&key='),
        isFalse,
        reason: 'toJson() 結果のどこかに `&key=` が残っています:\n$whole',
      );
      expect(
        whole.contains('DUMMY_LEAKED_KEY_VISITED_111'),
        isFalse,
        reason: 'toJson() 結果のどこかに元の API キー文字列が残っています。',
      );
    });

    // ──────────────────────────────────────────────────────────────────
    // [C] Google Places URL → reference 形式
    // ──────────────────────────────────────────────────────────────────
    test('toJson() は Google Places URL を `places/{id}/photos/{photoId}` reference に変換する', () {
      final r = _make(imageUrl: _googleUrl);
      final saved = r.toJson()['imageUrl'] as String?;

      expect(
        saved,
        equals('places/ChIJvisited01/photos/AeYy_VisitA'),
        reason: 'Google Places の写真 URL は reference 形式に正規化して保存してください。\n'
            '実値: $saved',
      );
    });

    // ──────────────────────────────────────────────────────────────────
    // [D] Hotpepper URL（キー不要）はそのまま保存
    // ──────────────────────────────────────────────────────────────────
    test('toJson() は Hotpepper の URL（キー不要）をそのまま保存する', () {
      final r = _make(imageUrl: _hotpepperUrl);
      final saved = r.toJson()['imageUrl'] as String?;

      expect(
        saved,
        equals(_hotpepperUrl),
        reason: 'Hotpepper の写真 URL は API キーを含まないのでそのまま保存して問題ない。',
      );
    });

    // ──────────────────────────────────────────────────────────────────
    // [E] imageUrl が null
    // ──────────────────────────────────────────────────────────────────
    test('imageUrl が null のときも toJson / fromJson が安全に動く', () {
      final r = _make(imageUrl: null);
      final json = r.toJson();
      // 既存挙動互換: imageUrl は null のまま保存される（キー自体はあっても値が null）
      expect(json.containsKey('imageUrl'), isTrue);
      expect(json['imageUrl'], isNull);

      final restored = VisitedRestaurant.fromJson(json);
      expect(restored.imageUrl, isNull);
    });

    // ──────────────────────────────────────────────────────────────────
    // [F] ラウンドトリップで in-memory URL を復元（既存 UI 互換）
    // ──────────────────────────────────────────────────────────────────
    test('fromJson(toJson(r)) で Google Places の imageUrl が表示可能な URL に復元される', () {
      final original = _make(imageUrl: _googleUrl);
      final json = original.toJson();
      final restored = VisitedRestaurant.fromJson(json);

      expect(restored.imageUrl, isNotNull);
      expect(
        restored.imageUrl!.startsWith(
            'https://places.googleapis.com/v1/places/ChIJvisited01/photos/AeYy_VisitA/media'),
        isTrue,
        reason: 'fromJson が reference を Google Places media URL に再構築できていません。\n'
            'PhotoRef.toUrl を fromJson 側で適用し、Secrets.placesApiKey で\n'
            'URL を組み立て直してください。\n'
            '実値: ${restored.imageUrl}',
      );
      expect(
        restored.imageUrl!.contains('&key='),
        isTrue,
        reason: '再構築された URL に `&key=` が付いていません。\n'
            'CachedNetworkImage で表示するためにはキーが必要です。',
      );
    });

    test('fromJson(toJson(r)) で Hotpepper の imageUrl はそのまま', () {
      final original = _make(imageUrl: _hotpepperUrl);
      final restored = VisitedRestaurant.fromJson(original.toJson());
      expect(restored.imageUrl, equals(_hotpepperUrl));
    });
  });
}
