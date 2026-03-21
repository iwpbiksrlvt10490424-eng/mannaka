import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/scored_restaurant.dart';
import '../providers/search_provider.dart';

class ShareUtils {
  /// メインのシェアテキスト（レストラン決定後）
  /// [includeBackup]: trueのとき代替案①②も含める
  static String buildRestaurantShareText(
    SearchState state, {
    ScoredRestaurant? primaryScored,
    bool includeBackup = true,
  }) {
    final point = state.selectedMeetingPoint;
    final top3 = state.sortedRestaurants.take(3).toList();

    final primary = primaryScored ??
        (top3.isNotEmpty ? top3.first : null);
    if (primary == null) return '';

    final r = primary.restaurant;

    // 移動時間行
    final timeParts = point?.participantTimes.entries
            .map((e) => '  ${e.key}：${e.value}分')
            .join('\n') ??
        '';

    final occasionTag = state.occasion != Occasion.none
        ? ' #${state.occasion.label}'
        : '';

    final sb = StringBuffer();
    sb.writeln('🍽️ お店が決まりました！');
    sb.writeln('');
    sb.writeln('【場所】${r.name}');
    sb.writeln('【カテゴリ】${r.category}');
    if (r.priceAvg > 0) sb.writeln('【予算】${r.priceStr}');
    if (timeParts.isNotEmpty) {
      sb.writeln('');
      sb.writeln('全員の移動時間：');
      sb.write(timeParts);
      sb.writeln('');
    }
    sb.writeln('');
    sb.writeln('Aimaアプリで見つけたよ✨');
    sb.writeln('グループでちょうどいいお店を自動提案！');
    sb.writeln('▶ App Store: https://apps.apple.com/jp/app/mannaka');

    if (includeBackup && top3.length > 1) {
      sb.writeln('');
      sb.writeln('【代替案】');
      for (int i = 1; i < top3.length && i <= 2; i++) {
        final alt = top3[i].restaurant;
        final label = i == 1 ? '代替案①' : '代替案②';
        sb.writeln('$label ${alt.name}（${alt.category} / ${alt.priceStr}）');
      }
    }

    sb.writeln('');
    sb.write('#Aima #グルメ${occasionTag.isNotEmpty ? occasionTag : ' #女子会'}');

    return sb.toString();
  }

  /// 後方互換: 従来の集合場所テキスト（エリアベース）
  static String buildMeetingPointText(SearchState state) {
    final point = state.selectedMeetingPoint;
    if (point == null) return '';

    final occasionLabel = state.occasion != Occasion.none
        ? '【${state.occasion.emoji}${state.occasion.label}】\n'
        : '';

    final participantLines = point.participantTimes.entries
        .map((e) => '  ${e.key}：${e.value}分')
        .join('\n');

    final topRestaurants = state.sortedRestaurants.take(3).toList();
    final restaurantSection = topRestaurants.isNotEmpty
        ? '\n\n🍽️ おすすめのお店\n'
            '${topRestaurants.map((sr) => '  ${sr.restaurant.emoji} ${sr.restaurant.name}（${sr.restaurant.priceStr}）').join('\n')}'
        : '';

    final topName = topRestaurants.isNotEmpty
        ? topRestaurants.first.restaurant.name
        : '${point.stationName}駅周辺のお店';

    return '$occasionLabel🍽️ お店が決まりました！\n\n'
        '【$topName】\n'
        '📍 ${point.stationEmoji} ${point.stationName}駅周辺\n\n'
        '各自の移動時間：\n'
        '$participantLines'
        '$restaurantSection\n\n'
        'Aimaで全員にとってちょうどいいお店を見つけたよ✨\n'
        '#Aima #女子会 #グルメ';
  }

  static String buildLineText(SearchState state) {
    final point = state.selectedMeetingPoint;
    if (point == null) return '';

    final topRestaurants = state.sortedRestaurants.take(3).toList();
    final restaurantLines = topRestaurants
        .map((sr) =>
            '${sr.restaurant.emoji} ${sr.restaurant.name}（${sr.restaurant.priceStr}）')
        .join('\n');

    final participantLines = point.participantTimes.entries
        .map((e) => '${e.key} ${e.value}分')
        .join(' / ');

    final topName = topRestaurants.isNotEmpty
        ? topRestaurants.first.restaurant.name
        : '${point.stationName}駅周辺のお店';

    return '🍽️ 【$topName】に決まったよ！\n\n'
        '📍 ${point.stationName}駅周辺\n'
        '移動時間：$participantLines\n\n'
        '他のおすすめ\n$restaurantLines\n\n'
        '▶ Aima — グループでちょうどいいお店を自動提案するアプリ\nhttps://apps.apple.com/jp/app/mannaka\n\n'
        '#Aima #女子会 #グルメ';
  }

  /// ネイティブ共有シートを開く
  static Future<void> share(BuildContext context, SearchState state) async {
    final text = buildMeetingPointText(state);
    if (text.isEmpty) return;
    await Share.share(text, subject: 'Aimaで集合場所を見つけました！');
  }

  /// LINEアプリで直接共有
  static Future<void> shareToLine(SearchState state) async {
    final text = buildLineText(state);
    if (text.isEmpty) return;
    final encoded = Uri.encodeComponent(text);
    final lineUrl = Uri.parse('https://line.me/R/share?text=$encoded');
    if (await canLaunchUrl(lineUrl)) {
      await launchUrl(lineUrl, mode: LaunchMode.externalApplication);
    }
  }
}
