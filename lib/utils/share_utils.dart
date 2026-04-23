import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/scored_restaurant.dart';
import '../providers/search_provider.dart';

class ShareUtils {
  static const appStoreId = '6761008332';
  static const appStoreUrl =
      'https://apps.apple.com/jp/app/aimachi/id$appStoreId';
  /// レビューを直接書き込むダイアログを開く iOS ネイティブURL
  static const appStoreReviewUrl =
      'itms-apps://itunes.apple.com/app/id$appStoreId?action=write-review';

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
    sb.writeln('Aimachi で見つけました');
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

    return 'お店の候補を共有します\n\n'
        '$topName\n'
        '${point.stationName}駅周辺\n\n'
        '各自の移動時間\n'
        '$participantLines'
        '$restaurantSection\n\n'
        'Aimachi でみんなの中間地点からお店を提案\n'
        '$appStoreUrl';
  }

  static String buildLineText(SearchState state) {
    final point = state.selectedMeetingPoint;
    if (point == null) return '';

    final topRestaurants = state.sortedRestaurants.take(3).toList();
    final top = topRestaurants.isNotEmpty ? topRestaurants.first : null;
    final topRestaurant = top?.restaurant;

    final topName = topRestaurant?.name ?? '${point.stationName}駅周辺のお店';
    final address = topRestaurant?.address ?? '';

    final mapsUrl = (topRestaurant?.lat != null && topRestaurant?.lng != null)
        ? 'https://maps.google.com/maps?q=${topRestaurant!.lat},${topRestaurant.lng}'
        : '';

    final participantLines = point.participantTimes.entries
        .map((e) => '${e.key} ${e.value}分')
        .join(' / ');

    final otherCandidates = topRestaurants
        .skip(1)
        .map((sr) => '・${sr.restaurant.name}（${sr.restaurant.priceStr}）')
        .join('\n');

    final sb = StringBuffer();
    // まだ予約前（候補の提示）なので「決まった」と断定しない文言にする
    sb.writeln('🍽 ちょうどいいお店の候補が見つかりました');
    sb.writeln('');
    sb.writeln('📍 $topName');
    sb.writeln('${point.stationName}駅周辺');
    if (address.isNotEmpty) sb.writeln(address);
    if (mapsUrl.isNotEmpty) {
      sb.writeln('');
      sb.writeln(mapsUrl);
    }
    if (participantLines.isNotEmpty) {
      sb.writeln('');
      sb.writeln('⏱ 移動時間');
      sb.writeln(participantLines);
    }
    if (otherCandidates.isNotEmpty) {
      sb.writeln('');
      sb.writeln('他の候補');
      sb.writeln(otherCandidates);
    }
    sb.writeln('');
    sb.writeln('Aimachi で決めました');
    sb.write(appStoreUrl);
    return sb.toString();
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
      subject: 'Aimachi でお店を見つけました',
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

  /// 複数のエリア（駅）で選んだ候補を LINE でまとめて共有するためのテキスト。
  ///
  /// 構成:
  /// ```
  /// Aimachiで検索したお店を共有します
  ///
  /// 🗓 4/24 19:30
  /// ⏱ あや 12分 / ゆう 8分
  ///
  /// 📍 渋谷駅周辺
  /// 1. お店A（カフェ / ¥1500〜 / ★4.2）
  ///   Google Maps
  /// 2. ...
  ///
  /// 📍 新宿駅周辺
  /// 1. ...
  ///
  /// 続きは Aimachi（無料）で見れます👇
  /// <App Store URL>
  /// ```
  ///
  /// 各エリアは上位 3 件まで本文に入り、残りは末尾の Aimachi 誘導で補う。
  static String buildLineTextForGroupedCandidates(
    SearchState state,
    Map<String, List<ScoredRestaurant>> grouped,
  ) {
    if (grouped.isEmpty) return '';

    final sb = StringBuffer();
    sb.writeln('Aimachiで検索したお店を共有します');
    sb.writeln('');

    // 日時（エリアに依存しない共通情報を先頭に）
    final date = state.selectedDate;
    final time = state.selectedMeetingTime;
    if (date != null || time != null) {
      final parts = <String>[];
      if (date != null) parts.add('${date.month}/${date.day}');
      if (time != null) {
        parts.add(
            '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}');
      }
      sb.writeln('🗓 ${parts.join(' ')}');
    }

    // 参加者の移動時間は「現在選択中の集合駅」を代表として出す
    final currentPoint = state.selectedMeetingPoint;
    if (currentPoint != null) {
      final participantLines = currentPoint.participantTimes.entries
          .map((e) => '${e.key} ${e.value}分')
          .join(' / ');
      if (participantLines.isNotEmpty) {
        sb.writeln('⏱ $participantLines');
      }
    }

    var totalExtra = 0;
    for (final entry in grouped.entries) {
      final station = entry.key;
      final list = entry.value;
      if (list.isEmpty) continue;
      final top = list.take(3).toList();
      final extra = list.length - top.length;
      totalExtra += extra;

      sb.writeln('');
      sb.writeln('📍 $station駅周辺');
      for (var i = 0; i < top.length; i++) {
        final r = top[i].restaurant;
        sb.writeln('${i + 1}. ${r.name}');
        final meta = <String>[r.category, r.priceStr];
        if (r.rating > 0) meta.add('★${r.rating.toStringAsFixed(1)}');
        sb.writeln('  ${meta.join(' / ')}');
        if (r.lat != null && r.lng != null) {
          sb.writeln('  https://maps.google.com/maps?q=${r.lat},${r.lng}');
        }
      }
      if (extra > 0) {
        sb.writeln('  …ほか$extra件');
      }
    }

    sb.writeln('');
    if (totalExtra > 0) {
      sb.writeln('続きは Aimachi（無料）で見れます👇');
    } else {
      sb.writeln('Aimachi（無料）でお店を探せます👇');
    }
    sb.write(appStoreUrl);
    return sb.toString();
  }

  /// エリアごとにまとめた候補を LINE で共有する。
  static Future<void> shareGroupedCandidatesToLine(
    SearchState state,
    Map<String, List<ScoredRestaurant>> grouped,
  ) async {
    final text = buildLineTextForGroupedCandidates(state, grouped);
    if (text.isEmpty) return;
    final encoded = Uri.encodeComponent(text);
    final lineUrl = Uri.parse('https://line.me/R/share?text=$encoded');
    if (await canLaunchUrl(lineUrl)) {
      await launchUrl(lineUrl, mode: LaunchMode.externalApplication);
    }
  }
}
