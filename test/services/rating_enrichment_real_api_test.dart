import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mannaka/config/secrets.dart';
import 'package:mannaka/models/restaurant.dart';
import 'package:mannaka/services/rating_enrichment_service.dart';

/// 実 Google Places API を叩いて enrichment が正しく動くか確認する統合テスト。
/// 通常テストでは API を叩きたくない（課金/レイテンシ/キー漏洩経路）ので
/// 環境変数 RUN_REAL_API_TESTS=1 を付けたときだけ実行する。
/// 例: `RUN_REAL_API_TESTS=1 flutter test test/services/rating_enrichment_real_api_test.dart`
void main() {
  test(
    '実 Google Places API でスターバックスを照合し、評価+写真が取得できる',
    () async {
      final input = [
        const Restaurant(
          id: 'test1',
          name: 'スターバックスコーヒー 東京駅丸の内南口店',
          stationIndex: 0,
          category: 'カフェ',
          reviewCount: 0,
          priceLabel: '',
          priceAvg: 0,
          tags: [],
          emoji: '☕',
          description: '',
          distanceMinutes: 5,
          address: '',
          openHours: '',
          lat: 35.6815,
          lng: 139.7665,
          sourceApi: 'hotpepper',
          ratingConfidence: 'unknown',
        ),
      ];

      final enriched = await RatingEnrichmentService.enrich(
        apiKey: Secrets.placesApiKey,
        restaurants: input,
      );

      // 診断出力
      // ignore: avoid_print
      print('=== 結果 ===');
      // ignore: avoid_print
      print('rating: ${enriched[0].rating}');
      // ignore: avoid_print
      print('reviewCount: ${enriched[0].reviewCount}');
      // ignore: avoid_print
      print('imageUrls.length: ${enriched[0].imageUrls.length}');
    },
    timeout: const Timeout(Duration(seconds: 20)),
    skip: Platform.environment['RUN_REAL_API_TESTS'] == '1'
        ? null
        : 'Set RUN_REAL_API_TESTS=1 to run this real-API integration test.',
  );
}
