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
    sb.writeln('まんなかで見つけました');
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
        'まんなかでみんなの中間地点からお店を提案\n'
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
    sb.writeln('まんなかで決めました');
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
      subject: 'まんなかでお店を見つけました',
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

  /// 複数候補を選んで LINE でシェアするためのテキスト組み立て
  /// - 集合駅・集合時刻・参加者移動時間を上部に
  /// - 各候補は箇条書き（名前・ジャンル・価格・評価・Googleマップ）
  /// - shareUrl が渡された場合は末尾に追加（Web 共有ページへのリンク）
  static String buildLineTextForCandidates(
    SearchState state,
    List<ScoredRestaurant> candidates, {
    String? shareUrl,
  }) {
    final point = state.selectedMeetingPoint;
    if (point == null || candidates.isEmpty) return '';

    final sb = StringBuffer();
    sb.writeln('🍽 お店の候補を共有します');
    sb.writeln('');
    sb.writeln('📍 ${point.stationName}駅周辺');
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
    final participantLines = point.participantTimes.entries
        .map((e) => '${e.key} ${e.value}分')
        .join(' / ');
    if (participantLines.isNotEmpty) {
      sb.writeln('⏱ $participantLines');
    }
    sb.writeln('');
    sb.writeln('候補のお店（${candidates.length}件）');
    for (final sr in candidates) {
      final r = sr.restaurant;
      sb.writeln('');
      sb.writeln('・${r.name}');
      final meta = <String>[r.category, r.priceStr];
      if (r.rating > 0) meta.add('★${r.rating.toStringAsFixed(1)}');
      sb.writeln('  ${meta.join(' / ')}');
      if (r.lat != null && r.lng != null) {
        sb.writeln('  https://maps.google.com/maps?q=${r.lat},${r.lng}');
      }
    }
    sb.writeln('');
    if (shareUrl != null && shareUrl.isNotEmpty) {
      sb.writeln('🌐 Webで見る（アプリ不要）');
      sb.writeln(shareUrl);
      sb.writeln('');
    }
    sb.writeln('まんなか（無料）');
    sb.write(appStoreUrl);
    return sb.toString();
  }

  /// 候補を LINE で共有する。
  /// shareUrl はオプションで、Web 共有ページが生成できた場合に付加する。
  static Future<void> shareCandidatesToLine(
    SearchState state,
    List<ScoredRestaurant> candidates, {
    String? shareUrl,
  }) async {
    final text =
        buildLineTextForCandidates(state, candidates, shareUrl: shareUrl);
    if (text.isEmpty) return;
    final encoded = Uri.encodeComponent(text);
    final lineUrl = Uri.parse('https://line.me/R/share?text=$encoded');
    if (await canLaunchUrl(lineUrl)) {
      await launchUrl(lineUrl, mode: LaunchMode.externalApplication);
    }
  }
}
