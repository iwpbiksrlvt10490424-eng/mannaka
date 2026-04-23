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

  /// LINE 本文に入れる「お店ページへのリンク」を**なるべく短く**返す。
  ///
  /// 優先順:
  /// 1. `hotpepperUrl`（約 40 文字固定、日本語エンコード不要）
  /// 2. Google Maps 検索 URL（日本語エンコードで長くなる）
  ///
  /// Hotpepper 由来のお店は (1)。Google Places フォールバック経由で
  /// hotpepperUrl が null のときだけ (2) に落ちる。
  /// 空白のみの `hotpepperUrl` は意味を持たない URL 扱いで (2) に落とす。
  static String shortStoreUrl(
      String? hotpepperUrl, String name, String stationName) {
    if (hotpepperUrl != null && hotpepperUrl.trim().isNotEmpty) {
      return hotpepperUrl;
    }
    final bits = <String>[
      if (name.isNotEmpty) name,
      if (stationName.isNotEmpty) stationName,
    ];
    return 'https://maps.google.com/?q=${Uri.encodeComponent(bits.join(' '))}';
  }

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

  /// ユーザーが選んだ候補（駅を跨いだ順序付きリスト）を LINE で共有するテキスト。
  ///
  /// 仕様:
  /// - 駅に関係なく **選択順** の上位 5 件のみを本文に含める
  /// - 各店舗は「店名（駅エリア）」「ジャンル / 価格 / ★評価」「Google店舗ページURL」
  /// - 1 回で送れる上限は 5 件。UI 側でも 6 件目以降は選択できないよう制御する
  static String buildLineTextForSelections(
    SearchState state,
    List<({String station, ScoredRestaurant scored})> selections,
  ) {
    if (selections.isEmpty) return '';

    final top = selections.take(5).toList();

    final sb = StringBuffer();
    sb.writeln('Aimachiで探したお店の候補を共有します');
    sb.writeln('');

    // 日時
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

    for (var i = 0; i < top.length; i++) {
      final station = top[i].station;
      final r = top[i].scored.restaurant;
      sb.writeln('');
      sb.writeln('${i + 1}. ${r.name}（$station駅エリア）');
      final meta = <String>[r.category, r.priceStr];
      if (r.rating > 0) meta.add('★${r.rating.toStringAsFixed(1)}');
      sb.writeln('  ${meta.join(' / ')}');
      sb.writeln('  ${shortStoreUrl(r.hotpepperUrl, r.name, r.stationName)}');
    }

    sb.writeln('');
    // 「DLすれば4件目以降が見れる」は実装上できないので謳わない。
    // 代わりに「あなたも同じ条件で検索できる」という価値訴求でDL誘導する。
    sb.writeln('1回で送れるのは5件までです');
    sb.writeln('あなたもAimachi（無料）で同じ条件のお店を探してみましょう👇');
    sb.write(appStoreUrl);
    return sb.toString();
  }

  /// 選択順の候補リストを LINE で共有する（本文の実処理）。
  static Future<void> shareSelectionsToLine(
    SearchState state,
    List<({String station, ScoredRestaurant scored})> selections,
  ) async {
    final text = buildLineTextForSelections(state, selections);
    if (text.isEmpty) return;
    final encoded = Uri.encodeComponent(text);
    final lineUrl = Uri.parse('https://line.me/R/share?text=$encoded');
    if (await canLaunchUrl(lineUrl)) {
      await launchUrl(lineUrl, mode: LaunchMode.externalApplication);
    }
  }


  /// 右上の LINE ボタン用：**候補の集合駅（MeetingPoint）一覧**を共有。
  ///
  /// 責務の線引き:
  /// - 右上ボタン = 候補の**集合駅リスト**（お店は含まない）
  /// - 下部バー = ユーザーが明示的に選んだ**お店**の共有
  ///
  /// 本文構成:
  /// ```
  /// Aimachiで集合場所の候補を共有します
  ///
  /// 🗓 4/24 19:30
  ///
  /// 候補の集合駅
  ///
  /// 📍 新宿駅
  /// ⏱ あや 12分 / ゆう 8分
  ///
  /// 📍 渋谷駅
  /// ⏱ あや 15分 / ゆう 5分
  ///
  /// Aimachiでお店を見つけられます👇
  /// <App Store URL>
  /// ```
  static String buildLineTextForMeetingPoints(SearchState state) {
    if (state.results.isEmpty) return '';

    final sb = StringBuffer();
    sb.writeln('Aimachiで集合場所の候補を共有します');
    sb.writeln('');

    // 日時
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
      sb.writeln('');
    }

    sb.writeln('候補の集合駅');

    for (final point in state.results.take(5)) {
      sb.writeln('');
      sb.writeln('📍 ${point.stationName}駅');
      if (point.participantTimes.isNotEmpty) {
        final line = point.participantTimes.entries
            .map((e) => '${e.key} ${e.value}分')
            .join(' / ');
        sb.writeln('⏱ $line');
      }
    }

    sb.writeln('');
    sb.writeln('Aimachiでお店を見つけられます👇');
    sb.write(appStoreUrl);
    return sb.toString();
  }

  /// 右上の LINE ボタン用：候補の集合駅一覧を LINE に流し込む。
  static Future<void> shareMeetingPointsToLine(SearchState state) async {
    final text = buildLineTextForMeetingPoints(state);
    if (text.isEmpty) return;
    final encoded = Uri.encodeComponent(text);
    final lineUrl = Uri.parse('https://line.me/R/share?text=$encoded');
    if (await canLaunchUrl(lineUrl)) {
      await launchUrl(lineUrl, mode: LaunchMode.externalApplication);
    }
  }
}
