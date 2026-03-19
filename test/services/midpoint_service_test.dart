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

    test('結果がoverallScore降順である', () {
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
      for (int i = 0; i < results.length - 1; i++) {
        expect(results[i].overallScore,
            greaterThanOrEqualTo(results[i + 1].overallScore));
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
        expect(r.participantDistances.keys, containsAll(['Alice', 'Bob']));
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
}
