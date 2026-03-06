import 'dart:math';
import '../data/station_data.dart';
import '../data/restaurant_data.dart';
import '../models/meeting_point.dart';
import '../models/participant.dart';
import '../models/restaurant.dart';
import '../providers/search_provider.dart';

class MidpointService {
  static List<MeetingPoint> calculate(List<Participant> participants) {
    final active = participants.where((p) => p.hasStation).toList();
    if (active.isEmpty) return [];

    final results = <MeetingPoint>[];

    for (int c = 0; c < kStations.length; c++) {
      final times = <String, int>{};
      for (final p in active) {
        times[p.name] = kTransitMatrix[p.stationIndex!][c];
      }

      final values = times.values.toList();
      final total = values.fold(0, (a, b) => a + b);
      final avg = total / values.length;
      final maxVal = values.reduce((a, b) => a > b ? a : b);
      final minVal = values.reduce((a, b) => a < b ? a : b);

      final variance =
          values.map((v) => pow(v - avg, 2)).reduce((a, b) => a + b) / values.length;
      final stdDev = sqrt(variance);

      results.add(MeetingPoint(
        stationIndex: c,
        stationName: kStations[c],
        stationEmoji: kStationEmojis[c],
        totalMinutes: total,
        maxMinutes: maxVal,
        minMinutes: minVal,
        averageMinutes: avg,
        fairnessScore: 0,
        overallScore: 0,
        participantTimes: times,
        stdDev: stdDev,
      ));
    }

    // Normalize scores
    final minTotal = results.map((r) => r.totalMinutes).reduce(min);
    final maxTotal = results.map((r) => r.totalMinutes).reduce(max);
    final minStd = results.map((r) => r.stdDev).reduce(min);
    final maxStd = results.map((r) => r.stdDev).reduce(max);

    final scored = results.map((r) {
      final effScore = maxTotal == minTotal
          ? 1.0
          : (maxTotal - r.totalMinutes) / (maxTotal - minTotal);
      final fairScore =
          maxStd == minStd ? 1.0 : (maxStd - r.stdDev) / (maxStd - minStd);
      final overall = 0.4 * effScore + 0.6 * fairScore;

      return MeetingPoint(
        stationIndex: r.stationIndex,
        stationName: r.stationName,
        stationEmoji: r.stationEmoji,
        totalMinutes: r.totalMinutes,
        maxMinutes: r.maxMinutes,
        minMinutes: r.minMinutes,
        averageMinutes: r.averageMinutes,
        fairnessScore: fairScore,
        overallScore: overall,
        participantTimes: r.participantTimes,
        stdDev: r.stdDev,
      );
    }).toList();

    scored.sort((a, b) => b.overallScore.compareTo(a.overallScore));
    return scored.take(5).toList();
  }

  static List<Restaurant> getRestaurants({
    required int stationIndex,
    String? category,
    int? maxBudget,
    bool femaleFriendly = false,
    bool hasPrivateRoom = false,
    TimeSlot timeSlot = TimeSlot.all,
  }) {
    var list = kRestaurants.where((r) => r.stationIndex == stationIndex).toList();

    if (category != null && category.isNotEmpty) {
      list = list.where((r) => r.category == category).toList();
    }
    if (maxBudget != null && maxBudget > 0) {
      list = list.where((r) => r.priceAvg <= maxBudget).toList();
    }
    if (femaleFriendly) {
      list = list.where((r) => r.isFemalePopular).toList();
    }
    if (hasPrivateRoom) {
      list = list.where((r) => r.hasPrivateRoom).toList();
    }
    if (timeSlot == TimeSlot.lunch) {
      list = list.where((r) => r.isLunchAvailable).toList();
    } else if (timeSlot == TimeSlot.dinner) {
      list = list.where((r) => r.isDinnerAvailable).toList();
    }

    list.sort((a, b) => b.rating.compareTo(a.rating));
    return list;
  }

  static List<String> getCategories(int stationIndex) {
    return kRestaurants
        .where((r) => r.stationIndex == stationIndex)
        .map((r) => r.category)
        .toSet()
        .toList()
      ..sort();
  }
}
