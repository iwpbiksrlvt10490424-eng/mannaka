// TDD Red フェーズ — Cycle 34: Restaurant.toJson が API キーを Firestore に書き出さない
//
// 背景（security_report.md ISSUE-1 / CRITICAL）:
//   rating_enrichment_service が Google Places の写真 URL（末尾に `&key=$apiKey`）を
//   Restaurant.imageUrls に格納し、`RestaurantCacheService.set()` 経由で
//   Firestore `restaurant_cache` コレクションに書き込む。当該コレクションは
//   `firestore.rules:38` で `allow read: if true;` のため、未認証で誰でも
//   API キーを読める漏洩経路が出ている。
//
//   Cycle 33 で `lib/utils/photo_ref.dart`（PhotoRef.toRef / toUrl / listToRefs / listToUrls）
//   は半完成済み。本サイクル(34)で `Restaurant.toJson` / `fromJson` 側に適用する。
//
// 受入条件:
//   [A] toJson() の imageUrls 要素に `&key=` が一切含まれない（API キー漏洩経路ゼロ）
//   [B] toJson() は Google Places URL を reference 形式 `places/.../photos/...` に変換
//   [C] toJson() は Hotpepper の URL（キー不要）はそのまま保存
//   [D] toJson() は Google + Hotpepper 混在も要素単位で正しく処理
//   [E] fromJson(toJson(r)) ラウンドトリップで imageUrls は表示可能な URL に復元される
//       （= 既存 UI 経路 `r.imageUrls` を直接画像 URL として使っている画面が壊れない）
//
// このテストの責務（runtime contract）:
//   構造ガードではなく実際の値を検証する。`Restaurant.toJson` の中で
//   `PhotoRef.listToRefs` を適用しているかどうか自体は内部実装なので強制せず、
//   出力結果（=外部に書き出される JSON）が安全であることだけを担保する。
//
// 不変項（侵してはならない）:
//   - Cycle 27〜30 snapshot サブテスト 1 バイト不変（buildLineTextFor* 純関数は
//     Restaurant.toJson に依存しないので影響なし）
//   - Cycle 33 ShareUtils.launchLineWithText 4 契約 + 構造ガード
//   - imageUrls の **個数**（順序保持・件数保持）

import 'package:flutter_test/flutter_test.dart';
import 'package:mannaka/models/restaurant.dart';

const _googleUrl =
    'https://places.googleapis.com/v1/places/ChIJplaceA/photos/AeYy_AbCdEfG/media?maxHeightPx=800&key=DUMMY_LEAKED_KEY_123';
const _googleUrl2 =
    'https://places.googleapis.com/v1/places/ChIJplaceB/photos/AeXx_HiJkLmN/media?maxHeightPx=400&key=DUMMY_LEAKED_KEY_999';
const _hotpepperUrl = 'https://imgfp.hotp.jp/IMGH/01/02/example.jpg';

Restaurant _makeRestaurant({required List<String> imageUrls}) {
  return Restaurant(
    id: 'r1',
    name: 'Test Cafe',
    stationIndex: 0,
    category: 'カフェ',
    reviewCount: 0,
    priceLabel: '',
    priceAvg: 0,
    tags: const [],
    emoji: '☕',
    description: '',
    distanceMinutes: 5,
    address: '',
    openHours: '',
    imageUrls: imageUrls,
  );
}

void main() {
  group('Cycle 34: Restaurant.toJson が Firestore へ API キーを書き出さない', () {
    // ──────────────────────────────────────────────────────────────────
    // [A] `&key=` 完全排除 — security_report.md ISSUE-1 の最小要件
    // ──────────────────────────────────────────────────────────────────
    test('Google Places URL を toJson() しても、imageUrls 要素に `&key=` が一切含まれない', () {
      final r = _makeRestaurant(imageUrls: const [_googleUrl, _googleUrl2]);
      final json = r.toJson();
      final saved = (json['imageUrls'] as List).cast<String>();

      for (final s in saved) {
        expect(
          s.contains('&key='),
          isFalse,
          reason: 'toJson() の imageUrls 要素に `&key=` が残っています:\n  $s\n\n'
              'Restaurant.toJson 内で PhotoRef.listToRefs(imageUrls) を適用して、'
              'Firestore に API キーが書き出されない構造にしてください。',
        );
        expect(
          s.contains('DUMMY_LEAKED_KEY_'),
          isFalse,
          reason: 'toJson() 出力に元のキー文字列がそのまま入っています:\n  $s',
        );
      }
    });

    test('toJson() 全体の文字列表現にも `&key=` が一度も現れない', () {
      // Firestore SDK は Map をそのまま JSON 化してアップロードするため、
      // ネスト深くにキーが残っても漏洩する。toString で全体走査して根絶を確認。
      final r = _makeRestaurant(imageUrls: const [_googleUrl]);
      final json = r.toJson();
      final whole = json.toString();

      expect(
        whole.contains('&key='),
        isFalse,
        reason: 'toJson() 結果のどこかに `&key=` が残っています:\n$whole',
      );
      expect(
        whole.contains('DUMMY_LEAKED_KEY_123'),
        isFalse,
        reason: 'toJson() 結果のどこかに元の API キー文字列が残っています。',
      );
    });

    // ──────────────────────────────────────────────────────────────────
    // [B] Google Places URL → reference 形式
    // ──────────────────────────────────────────────────────────────────
    test('toJson() は Google Places URL を `places/{id}/photos/{photoId}` reference に変換する', () {
      final r = _makeRestaurant(imageUrls: const [_googleUrl]);
      final json = r.toJson();
      final saved = (json['imageUrls'] as List).cast<String>();

      expect(saved.length, 1, reason: '件数は変えない（順序保持）');
      expect(
        saved.first,
        equals('places/ChIJplaceA/photos/AeYy_AbCdEfG'),
        reason: 'Google Places の写真 URL は reference 形式に正規化して保存してください。\n'
            '実値: ${saved.first}',
      );
    });

    // ──────────────────────────────────────────────────────────────────
    // [C] Hotpepper URL（キー不要）はそのまま保存
    // ──────────────────────────────────────────────────────────────────
    test('toJson() は Hotpepper の URL（キー不要）をそのまま保存する', () {
      final r = _makeRestaurant(imageUrls: const [_hotpepperUrl]);
      final json = r.toJson();
      final saved = (json['imageUrls'] as List).cast<String>();

      expect(
        saved,
        equals(const [_hotpepperUrl]),
        reason: 'Hotpepper の写真 URL は API キーを含まないのでそのまま保存して問題ない。\n'
            '誤って正規表現に巻き込んで壊さないようにしてください。',
      );
    });

    // ──────────────────────────────────────────────────────────────────
    // [D] 混在ケース
    // ──────────────────────────────────────────────────────────────────
    test('toJson() は Google + Hotpepper 混在を要素単位で正しく分けて処理する', () {
      final r = _makeRestaurant(
        imageUrls: const [_googleUrl, _hotpepperUrl, _googleUrl2],
      );
      final json = r.toJson();
      final saved = (json['imageUrls'] as List).cast<String>();

      expect(saved.length, 3, reason: '件数と順序は保持する');
      expect(saved[0], equals('places/ChIJplaceA/photos/AeYy_AbCdEfG'));
      expect(saved[1], equals(_hotpepperUrl));
      expect(saved[2], equals('places/ChIJplaceB/photos/AeXx_HiJkLmN'));

      // 念押し: 全要素にキー残存なし
      for (final s in saved) {
        expect(s.contains('&key='), isFalse, reason: '残存検出: $s');
      }
    });

    // ──────────────────────────────────────────────────────────────────
    // [E] ラウンドトリップで in-memory URL を復元（既存 UI 互換）
    // ──────────────────────────────────────────────────────────────────
    test('fromJson(toJson(r)) で imageUrls が表示可能な URL に復元される', () {
      // 既存 UI（results_screen / restaurant_detail_screen 等）は r.imageUrls を
      // 直接 CachedNetworkImage の URL として使っているので、in-memory の
      // imageUrls は **URL のまま** であることが互換要件。
      // Firestore 経由のラウンドトリップで URL が壊れないことを確認する。
      final original = _makeRestaurant(
        imageUrls: const [_googleUrl, _hotpepperUrl],
      );
      final json = original.toJson();
      final restored = Restaurant.fromJson(json);

      expect(restored.imageUrls.length, 2);

      // [E-1] Google Places: reference → 表示可能 URL に再構築されている
      expect(
        restored.imageUrls[0].startsWith(
            'https://places.googleapis.com/v1/places/ChIJplaceA/photos/AeYy_AbCdEfG/media'),
        isTrue,
        reason: 'fromJson が reference を Google Places media URL に再構築できていません。\n'
            'PhotoRef.listToUrls を fromJson 側で適用し、Secrets.placesApiKey で\n'
            'URL を組み立て直してください。\n'
            '実値: ${restored.imageUrls[0]}',
      );
      expect(
        restored.imageUrls[0].contains('&key='),
        isTrue,
        reason: '再構築された URL に `&key=` が付いていません。\n'
            'CachedNetworkImage で表示するためにはキーが必要です。',
      );

      // [E-2] Hotpepper: そのまま
      expect(restored.imageUrls[1], equals(_hotpepperUrl));
    });

    // ──────────────────────────────────────────────────────────────────
    // [F] 空配列とエッジケース
    // ──────────────────────────────────────────────────────────────────
    test('imageUrls が空のときも toJson / fromJson が安全に動く', () {
      final r = _makeRestaurant(imageUrls: const []);
      final json = r.toJson();
      expect(json['imageUrls'], isA<List>());
      expect((json['imageUrls'] as List).isEmpty, isTrue);

      final restored = Restaurant.fromJson(json);
      expect(restored.imageUrls, isEmpty);
    });
  });
}
