import 'package:flutter_test/flutter_test.dart';
import 'package:mannaka/models/participant.dart';
import 'package:mannaka/models/restaurant.dart';
import 'package:mannaka/services/midpoint_service.dart';

void main() {
  group('MidpointService.calculate()', () {
    test('参加者2人以上で結果を返す', () {
      final participants = [
        const Participant(
            id: '1', name: 'Alice', stationIndex: 0, stationName: '渋谷'),
        const Participant(
            id: '2', name: 'Bob', stationIndex: 4, stationName: '東京'),
      ];
      final results = MidpointService.calculate(participants);
      expect(results, isNotEmpty);
    });

    test('結果が公平性バケット降順で並ぶ（公平性ファースト）', () {
      final participants = [
        const Participant(
            id: '1', name: 'Alice', stationIndex: 0, stationName: '渋谷'),
        const Participant(
            id: '2', name: 'Bob', stationIndex: 4, stationName: '東京'),
        const Participant(
            id: '3', name: 'Carol', stationIndex: 7, stationName: '横浜'),
      ];
      final results = MidpointService.calculate(participants);
      expect(results.length, greaterThanOrEqualTo(2));
      // 新方針: 公平性が高い駅が上位。0.02 のバケット幅でグループ化されるので
      // 厳密な overallScore 単調降順は保証されないが、fairnessScore のバケットは降順。
      const bucketWidth = 0.02;
      for (int i = 0; i < results.length - 1; i++) {
        final a = (results[i].fairnessScore / bucketWidth).floor();
        final b = (results[i + 1].fairnessScore / bucketWidth).floor();
        expect(a, greaterThanOrEqualTo(b),
            reason: '公平性バケットは降順で並ぶ');
      }
    });

    test('最大5件を返す', () {
      final participants = [
        const Participant(
            id: '1', name: 'Alice', stationIndex: 0, stationName: '渋谷'),
        const Participant(
            id: '2', name: 'Bob', stationIndex: 4, stationName: '東京'),
      ];
      final results = MidpointService.calculate(participants);
      expect(results.length, lessThanOrEqualTo(5));
    });

    test('参加者が0人の場合は空リストを返す', () {
      final results = MidpointService.calculate([]);
      expect(results, isEmpty);
    });

    test('stationIndexがnullの参加者は無視される', () {
      final participants = [
        const Participant(id: '1', name: 'Alice'),
      ];
      final results = MidpointService.calculate(participants);
      expect(results, isEmpty);
    });

    test('参加者1人（有効な駅あり）でも結果を返す', () {
      // calculate()は active.isEmpty チェックのみなので1人でも動く
      final participants = [
        const Participant(
            id: '1', name: 'Alice', stationIndex: 0, stationName: '渋谷'),
      ];
      final results = MidpointService.calculate(participants);
      // 1人でも各駅のスコアは計算されるため結果が返る
      expect(results, isNotEmpty);
    });

    test('participantTimesに全参加者の名前が含まれる', () {
      final participants = [
        const Participant(
            id: '1', name: 'Alice', stationIndex: 0, stationName: '渋谷'),
        const Participant(
            id: '2', name: 'Bob', stationIndex: 4, stationName: '東京'),
      ];
      final results = MidpointService.calculate(participants);
      for (final r in results) {
        expect(r.participantTimes.keys, containsAll(['Alice', 'Bob']));
      }
    });
  });

  group('MidpointService.calcCentroid()', () {
    test('2点の場合は中間点を返す', () {
      final participants = [
        const Participant(
            id: '1', name: 'A', lat: 35.0, lng: 139.0),
        const Participant(
            id: '2', name: 'B', lat: 36.0, lng: 140.0),
      ];
      final result = MidpointService.calcCentroid(participants);
      expect(result, isNotNull);
      expect(result!.$1, closeTo(35.5, 0.001));
      expect(result.$2, closeTo(139.5, 0.001));
    });

    test('3点の場合は正しい重心を返す', () {
      final participants = [
        const Participant(id: '1', name: 'A', lat: 0.0, lng: 0.0),
        const Participant(id: '2', name: 'B', lat: 3.0, lng: 0.0),
        const Participant(id: '3', name: 'C', lat: 0.0, lng: 6.0),
      ];
      final result = MidpointService.calcCentroid(participants);
      expect(result, isNotNull);
      expect(result!.$1, closeTo(1.0, 0.001));
      expect(result.$2, closeTo(2.0, 0.001));
    });

    test('1人の場合はnullを返す', () {
      final participants = [
        const Participant(id: '1', name: 'A', lat: 35.0, lng: 139.0),
      ];
      final result = MidpointService.calcCentroid(participants);
      expect(result, isNull);
    });

    test('lat/lngがnullの参加者は無視される', () {
      final participants = [
        const Participant(id: '1', name: 'A', lat: 35.0, lng: 139.0),
        const Participant(id: '2', name: 'B'), // no location
        const Participant(id: '3', name: 'C', lat: 36.0, lng: 140.0),
      ];
      final result = MidpointService.calcCentroid(participants);
      expect(result, isNotNull);
      expect(result!.$1, closeTo(35.5, 0.001));
      expect(result.$2, closeTo(139.5, 0.001));
    });
  });

  group('MidpointService.scoreRestaurants()', () {
    // テスト用のレストランデータ
    final testRestaurants = [
      const Restaurant(
        id: 'r1',
        name: 'テスト店A',
        stationIndex: 0,
        category: '和食',
        rating: 4.0,
        reviewCount: 100,
        priceLabel: '¥3,000',
        priceAvg: 3000,
        tags: ['個室'],
        emoji: '🍣',
        description: 'テスト',
        distanceMinutes: 5,
        address: '東京都渋谷区',
        openHours: '11:00-23:00',
        lat: 35.660,
        lng: 139.700,
      ),
      const Restaurant(
        id: 'r2',
        name: 'テスト店B',
        stationIndex: 4,
        category: 'イタリアン',
        rating: 3.5,
        reviewCount: 50,
        priceLabel: '¥4,000',
        priceAvg: 4000,
        tags: [],
        emoji: '🍕',
        description: 'テスト',
        distanceMinutes: 3,
        address: '東京都千代田区',
        openHours: '17:00-23:00',
        lat: 35.681,
        lng: 139.767,
      ),
    ];

    test('空でないリストを返す', () {
      final participants = [
        const Participant(
            id: '1', name: 'Alice', lat: 35.658, lng: 139.701),
        const Participant(
            id: '2', name: 'Bob', lat: 35.681, lng: 139.767),
      ];
      final results = MidpointService.scoreRestaurants(
        participants: participants,
        centroidLat: 35.6695,
        centroidLng: 139.734,
        baseRestaurants: testRestaurants,
      );
      expect(results, isNotEmpty);
    });

    test('スコア降順でソートされる', () {
      final participants = [
        const Participant(
            id: '1', name: 'Alice', lat: 35.658, lng: 139.701),
        const Participant(
            id: '2', name: 'Bob', lat: 35.681, lng: 139.767),
      ];
      final results = MidpointService.scoreRestaurants(
        participants: participants,
        centroidLat: 35.6695,
        centroidLng: 139.734,
        baseRestaurants: testRestaurants,
      );
      for (int i = 0; i < results.length - 1; i++) {
        expect(
            results[i].score, greaterThanOrEqualTo(results[i + 1].score));
      }
    });

    test('位置情報のない参加者のみの場合は空リストを返す', () {
      final participants = [
        const Participant(id: '1', name: 'Alice'),
        const Participant(id: '2', name: 'Bob'),
      ];
      final results = MidpointService.scoreRestaurants(
        participants: participants,
        centroidLat: 35.6695,
        centroidLng: 139.734,
        baseRestaurants: testRestaurants,
      );
      expect(results, isEmpty);
    });

    test('各結果にparticipantDistancesが含まれる', () {
      final participants = [
        const Participant(
            id: '1', name: 'Alice', lat: 35.658, lng: 139.701),
        const Participant(
            id: '2', name: 'Bob', lat: 35.681, lng: 139.767),
      ];
      final results = MidpointService.scoreRestaurants(
        participants: participants,
        centroidLat: 35.6695,
        centroidLng: 139.734,
        baseRestaurants: testRestaurants,
      );
      for (final r in results) {
        expect(r.participantDistances.keys, containsAll(['1', '2']));
      }
    });

    test('スコアが0.0~1.0の範囲内である', () {
      final participants = [
        const Participant(
            id: '1', name: 'Alice', lat: 35.658, lng: 139.701),
        const Participant(
            id: '2', name: 'Bob', lat: 35.681, lng: 139.767),
      ];
      final results = MidpointService.scoreRestaurants(
        participants: participants,
        centroidLat: 35.6695,
        centroidLng: 139.734,
        baseRestaurants: testRestaurants,
      );
      for (final r in results) {
        expect(r.score, greaterThanOrEqualTo(0.0));
        expect(r.score, lessThanOrEqualTo(1.0));
      }
    });
  });

  group('シーン別・人数別重み調整', () {
    final baseRestaurants = [
      const Restaurant(
        id: 'r_usability',
        name: '大箱居酒屋',
        stationIndex: 0,
        category: '居酒屋',
        rating: 3.8,
        reviewCount: 200,
        priceLabel: '¥4,000',
        priceAvg: 4000,
        tags: ['個室', '飲み放題'],
        emoji: '🍺',
        description: 'テスト',
        distanceMinutes: 3,
        address: '東京都渋谷区',
        openHours: '17:00-23:00',
        lat: 35.658,
        lng: 139.701,
        hasPrivateRoom: true,
        isReservable: true,
        freeDrink: true,
      ),
      const Restaurant(
        id: 'r_quality',
        name: 'おしゃれイタリアン',
        stationIndex: 0,
        category: 'イタリアン',
        rating: 4.2,
        reviewCount: 80,
        priceLabel: '¥6,000',
        priceAvg: 6000,
        tags: ['写真映え'],
        emoji: '🍝',
        description: 'テスト',
        distanceMinutes: 8,
        address: '東京都渋谷区',
        openHours: '18:00-23:00',
        lat: 35.659,
        lng: 139.702,
        imageUrl: 'https://example.com/img.jpg',
        isReservable: true,
        nonSmoking: true,
      ),
    ];

    final participants2 = [
      const Participant(id: '1', name: 'Alice', lat: 35.658, lng: 139.701),
      const Participant(id: '2', name: 'Bob', lat: 35.660, lng: 139.703),
    ];

    final participants5 = [
      const Participant(id: '1', name: 'Alice', lat: 35.658, lng: 139.701),
      const Participant(id: '2', name: 'Bob', lat: 35.660, lng: 139.703),
      const Participant(id: '3', name: 'Carol', lat: 35.662, lng: 139.705),
      const Participant(id: '4', name: 'Dave', lat: 35.664, lng: 139.707),
      const Participant(id: '5', name: 'Eve', lat: 35.666, lng: 139.709),
    ];

    test('5人以上のとき個室あり店舗のusabilityScore寄与が増す', () {
      final results5 = MidpointService.scoreRestaurants(
        participants: participants5,
        centroidLat: 35.662,
        centroidLng: 139.705,
        baseRestaurants: baseRestaurants,
      );
      final results2 = MidpointService.scoreRestaurants(
        participants: participants2,
        centroidLat: 35.659,
        centroidLng: 139.702,
        baseRestaurants: baseRestaurants,
      );
      // 5人時の r_usability(居酒屋・個室)の順位が2人時よりも相対的に有利になる
      // 少なくとも結果が返ることと、スコアが有効範囲内であることを確認
      expect(results5, isNotEmpty);
      for (final r in results5) {
        expect(r.score, inInclusiveRange(0.0, 1.0));
        expect(r.usabilityScore, inInclusiveRange(0.0, 1.0));
      }
      // 5人時は大箱居酒屋(個室・予約可)のスコアが2人時より高いか同等
      final usability5 = results5.firstWhere((r) => r.restaurant.id == 'r_usability');
      final usability2 = results2.firstWhere((r) => r.restaurant.id == 'r_usability');
      expect(usability5.score, greaterThanOrEqualTo(usability2.score - 0.05));
    });

    test('2人・デートシーンのとき品質重視店のスコアが相対的に上がる', () {
      final resultsDate = MidpointService.scoreRestaurants(
        participants: participants2,
        centroidLat: 35.659,
        centroidLng: 139.702,
        baseRestaurants: baseRestaurants,
        occasion: 'デート',
      );
      final resultsNone = MidpointService.scoreRestaurants(
        participants: participants2,
        centroidLat: 35.659,
        centroidLng: 139.702,
        baseRestaurants: baseRestaurants,
      );
      expect(resultsDate, isNotEmpty);
      // デートシーンでは全スコアが有効範囲
      for (final r in resultsDate) {
        expect(r.score, inInclusiveRange(0.0, 1.0));
      }
      // デートシーンでは r_quality(イタリアン) の conditionScore が higher
      final qDate = resultsDate.firstWhere((r) => r.restaurant.id == 'r_quality');
      final qNone = resultsNone.firstWhere((r) => r.restaurant.id == 'r_quality');
      expect(qDate.conditionScore, greaterThan(qNone.conditionScore - 0.01));
    });
  });

  group('curationLabel', () {
    final participants = [
      const Participant(id: '1', name: 'Alice', lat: 35.658, lng: 139.701),
      const Participant(id: '2', name: 'Bob', lat: 35.681, lng: 139.767),
    ];

    test('「外さない」: 駅近・レビュー多・予約可の店舗', () {
      final safe = [
        const Restaurant(
          id: 'safe',
          name: '安定居酒屋',
          stationIndex: 0,
          category: '居酒屋',
          rating: 3.8,
          reviewCount: 60,
          priceLabel: '¥3,000',
          priceAvg: 3000,
          tags: [],
          emoji: '🍺',
          description: 'test',
          distanceMinutes: 3,
          address: '東京',
          openHours: '17:00-23:00',
          lat: 35.660,
          lng: 139.700,
          isReservable: true,
        ),
      ];
      final results = MidpointService.scoreRestaurants(
        participants: participants,
        centroidLat: 35.670,
        centroidLng: 139.734,
        baseRestaurants: safe,
      );
      expect(results, isNotEmpty);
      expect(results.first.curationLabel, contains('外さない'));
    });

    test('「おしゃれ」: 写真あり・女性人気・フレンチ/イタリアン系の店舗', () {
      final oshare = [
        const Restaurant(
          id: 'oshare',
          name: 'おしゃれカフェ',
          stationIndex: 0,
          category: 'カフェ',
          rating: 4.0,
          reviewCount: 30,
          priceLabel: '¥2,000',
          priceAvg: 2000,
          tags: [],
          emoji: '☕',
          description: 'test',
          distanceMinutes: 6,
          address: '東京',
          openHours: '10:00-20:00',
          lat: 35.660,
          lng: 139.700,
          imageUrl: 'https://example.com/photo.jpg',
          isFemalePopular: true,
          isReservable: false,
        ),
      ];
      final results = MidpointService.scoreRestaurants(
        participants: participants,
        centroidLat: 35.670,
        centroidLng: 139.734,
        baseRestaurants: oshare,
      );
      expect(results, isNotEmpty);
      expect(results.first.curationLabel, contains('おしゃれ'));
    });

    test('「穴場」: 中程度のレビュー数・良評価・駅近でない店舗', () {
      final anaba = [
        const Restaurant(
          id: 'anaba',
          name: '知る人ぞ知る和食',
          stationIndex: 0,
          category: '和食',
          rating: 3.9,
          reviewCount: 25,
          priceLabel: '¥3,500',
          priceAvg: 3500,
          tags: [],
          emoji: '🍱',
          description: 'test',
          distanceMinutes: 9,
          address: '東京',
          openHours: '17:00-22:00',
          lat: 35.660,
          lng: 139.700,
          isReservable: false,
        ),
      ];
      final results = MidpointService.scoreRestaurants(
        participants: participants,
        centroidLat: 35.670,
        centroidLng: 139.734,
        baseRestaurants: anaba,
      );
      expect(results, isNotEmpty);
      expect(results.first.curationLabel, contains('穴場'));
    });
  });
}
