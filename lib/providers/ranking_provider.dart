import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/ranking_entry.dart';
import '../services/analytics_service.dart';

final rankingProvider = FutureProvider.autoDispose<List<RankingEntry>>((ref) async {
  return AnalyticsService.fetchRanking(limit: 20);
});
