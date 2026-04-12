import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/scored_restaurant.dart';
import '../providers/search_provider.dart';

class ShareUtils {
  static const appStoreUrl =
      'https://apps.apple.com/jp/app/aimachi/id6743108270';

  /// メインのシェアテキスト（レストラン決定後）
  /// [includeBackup]: trueのとき代替案も含める
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

    final timeParts = point?.participantTimes.entries
            .map((e) => '  ${e.key}：${e.value}分')
            .join('\n') ??
        '';

    final sb = StringBuffer();
    sb.writeln('お店が決まりました');
    sb.writeln('');
    sb.writeln(r.name);
    sb.writeln(r.category);
    if (r.priceAvg > 0) sb.writeln('予算 ${r.priceStr}');
    if (r.rating >= 3.0) sb.writeln('評価 ${r.ratingStr}');
    if (timeParts.isNotEmpty) {
      sb.writeln('');
      sb.writeln('全員の移動時間');
      sb.write(timeParts);
      sb.writeln('');
    }

    if (includeBackup && top3.length > 1) {
      sb.writeln('');
      sb.writeln('代替案');
      for (int i = 1; i < top3.length && i <= 2; i++) {
        final alt = top3[i].restaurant;
        sb.writeln('${alt.name}（${alt.category} / ${alt.priceStr}）');
      }
    }

    sb.writeln('');
    sb.writeln('Aimachiで見つけました');
    sb.writeln(appStoreUrl);

    return sb.toString();
  }

  /// 集合場所テキスト（エリアベース）
  static String buildMeetingPointText(SearchState state) {
    final point = state.selectedMeetingPoint;
    if (point == null) return '';

    final participantLines = point.participantTimes.entries
        .map((e) => '  ${e.key}：${e.value}分')
        .join('\n');

    final topRestaurants = state.sortedRestaurants.take(3).toList();
    final restaurantSection = topRestaurants.isNotEmpty
        ? '\n\nおすすめのお店\n'
            '${topRestaurants.map((sr) => '  ${sr.restaurant.name}（${sr.restaurant.priceStr}）').join('\n')}'
        : '';

    final topName = topRestaurants.isNotEmpty
        ? topRestaurants.first.restaurant.name
        : '${point.stationName}駅周辺のお店';

    return 'お店が決まりました\n\n'
        '$topName\n'
        '${point.stationName}駅周辺\n\n'
        '各自の移動時間\n'
        '$participantLines'
        '$restaurantSection\n\n'
        'Aimachiでみんなの中間地点からお店を提案\n'
        '$appStoreUrl';
  }

  static String buildLineText(SearchState state) {
    final point = state.selectedMeetingPoint;
    if (point == null) return '';

    final topRestaurants = state.sortedRestaurants.take(3).toList();
    final restaurantLines = topRestaurants
        .map((sr) =>
            '${sr.restaurant.name}（${sr.restaurant.priceStr}）')
        .join('\n');

    final participantLines = point.participantTimes.entries
        .map((e) => '${e.key} ${e.value}分')
        .join(' / ');

    final topName = topRestaurants.isNotEmpty
        ? topRestaurants.first.restaurant.name
        : '${point.stationName}駅周辺のお店';

    final maxSummary = point.participantTimes.length > 1
        ? '最大${point.maxMinutes}分でアクセス可能\n'
        : '';

    return '$topNameに決まったよ\n\n'
        '${point.stationName}駅周辺\n'
        '$maxSummary'
        '移動時間：$participantLines\n\n'
        '他のおすすめ\n$restaurantLines\n\n'
        'Aimachiで見つけたよ（無料）\n'
        '$appStoreUrl';
  }

  /// ネイティブ共有シートを開く
  static Future<void> share(
    BuildContext context,
    SearchState state, {
    Rect? sharePositionOrigin,
  }) async {
    final text = buildMeetingPointText(state);
    if (text.isEmpty) return;
    await Share.share(
      text,
      subject: 'Aimachiでお店を見つけました',
      sharePositionOrigin: sharePositionOrigin,
    );
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
