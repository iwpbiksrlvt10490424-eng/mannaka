import 'package:flutter_test/flutter_test.dart';
import 'package:mannaka/providers/history_provider.dart';
import 'package:mannaka/models/meeting_point.dart';

void main() {
  group('HistoryEntry', () {
    MeetingPoint createTestMeetingPoint() {
      return const MeetingPoint(
        stationIndex: 0,
        stationName: '渋谷',
        stationEmoji: '🛍️',
        lat: 35.6580,
        lng: 139.7016,
        totalMinutes: 45,
        maxMinutes: 30,
        minMinutes: 15,
        averageMinutes: 22.5,
        fairnessScore: 0.85,
        overallScore: 0.9,
        participantTimes: {'Alice': 15, 'Bob': 30},
        stdDev: 7.5,
      );
    }

    test('toJson()とfromJson()のラウンドトリップ', () {
      final original = HistoryEntry(
        id: 'h1',
        createdAt: DateTime(2026, 3, 11, 14, 30, 0),
        participantNames: ['Alice', 'Bob', 'Carol'],
        meetingPoint: createTestMeetingPoint(),
      );

      final json = original.toJson();
      final restored = HistoryEntry.fromJson(json);

      expect(restored.id, equals(original.id));
      expect(restored.createdAt, equals(original.createdAt));
      expect(restored.participantNames, equals(original.participantNames));
      expect(restored.meetingPoint.stationName,
          equals(original.meetingPoint.stationName));
      expect(restored.meetingPoint.stationIndex,
          equals(original.meetingPoint.stationIndex));
      expect(restored.meetingPoint.totalMinutes,
          equals(original.meetingPoint.totalMinutes));
      expect(restored.meetingPoint.maxMinutes,
          equals(original.meetingPoint.maxMinutes));
      expect(restored.meetingPoint.minMinutes,
          equals(original.meetingPoint.minMinutes));
      expect(restored.meetingPoint.averageMinutes,
          closeTo(original.meetingPoint.averageMinutes, 0.001));
      expect(restored.meetingPoint.fairnessScore,
          closeTo(original.meetingPoint.fairnessScore, 0.001));
      expect(restored.meetingPoint.overallScore,
          closeTo(original.meetingPoint.overallScore, 0.001));
      expect(restored.meetingPoint.stdDev,
          closeTo(original.meetingPoint.stdDev, 0.001));
      expect(restored.meetingPoint.participantTimes,
          equals(original.meetingPoint.participantTimes));
    });

    test('toJsonが正しいキーを含む', () {
      final entry = HistoryEntry(
        id: 'test-id',
        createdAt: DateTime(2026, 1, 1),
        participantNames: ['太郎'],
        meetingPoint: createTestMeetingPoint(),
      );

      final json = entry.toJson();

      expect(json.containsKey('id'), isTrue);
      expect(json.containsKey('createdAt'), isTrue);
      expect(json.containsKey('participantNames'), isTrue);
      expect(json.containsKey('meetingPoint'), isTrue);
      expect(json['meetingPoint'], isA<Map<String, dynamic>>());
    });

    test('日本語の参加者名が正しく保存・復元される', () {
      final original = HistoryEntry(
        id: 'h2',
        createdAt: DateTime(2026, 3, 11),
        participantNames: ['山田太郎', '鈴木花子'],
        meetingPoint: createTestMeetingPoint(),
      );

      final json = original.toJson();
      final restored = HistoryEntry.fromJson(json);

      expect(restored.participantNames, equals(['山田太郎', '鈴木花子']));
    });

    test('MeetingPointのstationEmojiが復元される', () {
      final original = HistoryEntry(
        id: 'h3',
        createdAt: DateTime(2026, 3, 11),
        participantNames: ['A'],
        meetingPoint: createTestMeetingPoint(),
      );

      final json = original.toJson();
      final restored = HistoryEntry.fromJson(json);

      expect(restored.meetingPoint.stationEmoji, equals('🛍️'));
    });
  });
}
