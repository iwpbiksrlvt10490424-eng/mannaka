import '../providers/search_provider.dart';

class ShareUtils {
  static String buildMeetingPointText(SearchState state) {
    final point = state.selectedMeetingPoint;
    if (point == null) return '';

    final occasionLabel = state.occasion != Occasion.none
        ? '【${state.occasion.emoji}${state.occasion.label}】\n'
        : '';

    final participantLines = point.participantTimes.entries
        .map((e) => '  ${e.key}：${e.value}分')
        .join('\n');

    final topRestaurants = state.restaurants.take(3).toList();
    final restaurantSection = topRestaurants.isNotEmpty
        ? '\n\n🍽️ おすすめのお店（${point.stationName}駅周辺）\n'
            '${topRestaurants.map((r) => '  ${r.emoji} ${r.name}（${r.ratingStr}⭐ ${r.priceStr}）').join('\n')}'
        : '';

    return '$occasionLabel🗺️ まんなかで集合場所を見つけました！\n\n'
        '📍 集合場所：${point.stationEmoji} ${point.stationName}駅\n'
        '⏱️ 公平度：${point.fairnessLabel}\n\n'
        '各自の移動時間：\n'
        '$participantLines'
        '$restaurantSection\n\n'
        '#まんなか #集合場所 #女子会';
  }
}
