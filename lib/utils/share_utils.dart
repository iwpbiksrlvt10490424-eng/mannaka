import 'package:flutter/material.dart' show TimeOfDay;
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

  /// LINE 共有本文末尾のアプリ DL 誘導 CTA。
  /// 二重定義による片側崩壊（Cycle 16）を防ぐため、参照箇所はこの定数を使う。
  static const lineDownloadCta =
      'あなたもAimachi（無料）で同じ条件のお店を探してみましょう👇';

  /// レストラン決定共有本文末尾の決定 CTA。
  /// share_utils / share_preview_screen の二重定義（Cycle 16 と同型）を
  /// 防ぐため、参照箇所はこの定数を使う。
  static const foundOnAimachiCta = 'Aimachi で見つけました';

  /// Hotpepper 予約後の LINE 本文を組み立てる。
  ///
  /// 「Aimachi で予約した」事実 + 店舗情報 + 予約日時（集合日時）+ チームメンバー
  /// を 1 つのテキストにまとめる。data が無いフィールドは黙って省く。
  ///
  /// 呼び出し元: restaurant_detail_screen の予約完了 → LINE 共有フロー。
  /// 純関数として切り出してあるのでテスト容易（widget 不要）。
  static String buildReservationLineText({
    required String restaurantName,
    required String category,
    required String stationName,
    required int? walkMinutes,
    required double? lat,
    required double? lng,
    required DateTime? meetingDate,
    required TimeOfDay? meetingTime,
    required List<String> groupNames,
  }) {
    final sb = StringBuffer();
    sb.writeln('Aimachiで予約しました');
    sb.writeln('');
    sb.writeln('📍 $restaurantName');
    if (category.isNotEmpty) sb.writeln(category);

    final walkInfo = <String>[
      if (stationName.isNotEmpty) '$stationName駅',
      if (walkMinutes != null && walkMinutes > 0) '徒歩$walkMinutes分',
    ].join('から');
    if (walkInfo.isNotEmpty) sb.writeln(walkInfo);

    if (meetingDate != null || meetingTime != null) {
      final parts = <String>[];
      if (meetingDate != null) {
        parts.add('${meetingDate.month}/${meetingDate.day}');
      }
      if (meetingTime != null) {
        final h = meetingTime.hour.toString().padLeft(2, '0');
        final m = meetingTime.minute.toString().padLeft(2, '0');
        parts.add('$h:$m');
      }
      sb.writeln('');
      sb.writeln('🗓 ${parts.join(' ')}');
    }

    final cleanGroup = groupNames.where((n) => n.isNotEmpty).toList();
    if (cleanGroup.isNotEmpty) {
      sb.writeln('👥 ${cleanGroup.join('、')}');
    }

    if (lat != null && lng != null) {
      sb.writeln('');
      sb.writeln('https://maps.google.com/maps?q=$lat,$lng');
    }

    // DL 誘導：受信した友人が「次は自分の集まりでも使ってみよう」と思える表現に。
    // 押し売り感は出さず、価値（みんなの集合場所が早く決まる）を一行で伝える。
    sb.writeln('');
    sb.writeln('みんなの集合場所、Aimachiならすぐ決まります');
    sb.write(appStoreUrl);
    return sb.toString();
  }

  /// LINE 本文に入れる「お店ページへのリンク」を**なるべく短く**返す。
  ///
  /// 優先順:
  /// 1. `hotpepperUrl`（約 40 文字固定、日本語エンコード不要）
  /// 2. lat/lng があれば緯度経度クエリ（約 40 文字、日本語エンコード不要）
  /// 3. 店名+駅名のテキスト検索（日本語エンコードで長くなる、最終手段）
  ///
  /// 過去は (3) のテキスト検索で 80〜100 文字になっていたが、
  /// lat/lng が分かるならそちらを使えば LINE 本文がスッキリする。
  static String shortStoreUrl(
    String? hotpepperUrl,
    String name,
    String stationName, {
    double? lat,
    double? lng,
  }) {
    if (hotpepperUrl != null && hotpepperUrl.trim().isNotEmpty) {
      return hotpepperUrl;
    }
    if (lat != null && lng != null) {
      return 'https://maps.google.com/?q=$lat,$lng';
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
    if (r.hasRating && r.rating! >= 3.0) sb.writeln('評価 ${r.ratingStr}');
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
    sb.writeln(foundOnAimachiCta);
    sb.writeln(appStoreUrl);

    return sb.toString();
  }

  /// ユーザーが選んだ候補（駅を跨いだ順序付きリスト）を LINE で共有するテキスト。
  ///
  /// 仕様:
  /// - 駅に関係なく **選択順** の上位 5 件のみを本文に含める
  /// - 各店舗は「店名（駅）」「ジャンル / 価格 / ★評価」「Google店舗ページURL」
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
      sb.writeln('${i + 1}. ${r.name}（$station駅）');
      final meta = <String>[r.category, r.priceStr];
      if (r.hasRating && r.rating! > 0) meta.add('★${r.ratingStr}');
      sb.writeln('  ${meta.join(' / ')}');
      sb.writeln('  ${shortStoreUrl(r.hotpepperUrl, r.name, r.stationName, lat: r.lat, lng: r.lng)}');
    }

    sb.writeln('');
    // 「DLすれば4件目以降が見れる」は実装上できないので謳わない。
    // 代わりに「あなたも同じ条件で検索できる」という価値訴求でDL誘導する。
    sb.writeln('1回で送れるのは5件までです');
    sb.writeln(lineDownloadCta);
    sb.write(appStoreUrl);
    return sb.toString();
  }

  /// LINE アプリ起動の共通ヘルパ。
  ///
  /// 5 箇所（share_utils 2 + screens 3）に散らばっていた LINE 起動 URL
  /// 組み立てをこのメソッドに集約する（CLAUDE.md「依存関係を可視化」）。
  ///
  /// iOS で https スキームの LINE 共有 URL は Safari の存在で常に
  /// `canLaunchUrl=true` を返してしまい未インストール検知が効かない。
  /// `line://msg/text/?<encoded>` を使うことで未インストール時に
  /// false を返せる。
  ///
  /// 戻り値:
  /// - true  : LINE 起動に成功した
  /// - false : 送信内容が空、または LINE 未インストール（canLaunchUrl=false）
  static Future<bool> launchLineWithText(String text) async {
    if (text.isEmpty) return false;
    final encoded = Uri.encodeComponent(text);
    final lineUrl = Uri.parse('line://msg/text/?$encoded');
    if (!await canLaunchUrl(lineUrl)) return false;
    await launchUrl(lineUrl, mode: LaunchMode.externalApplication);
    return true;
  }

  /// 選択順の候補リストを LINE で共有する（本文の実処理）。
  ///
  /// 戻り値:
  /// - true  : LINE 起動に成功した
  /// - false : 送信内容が空、または LINE 未インストール（canLaunchUrl=false）
  ///
  /// 呼び出し元は false を受けて SnackBar 等で UI 通知する。
  static Future<bool> shareSelectionsToLine(
    SearchState state,
    List<({String station, ScoredRestaurant scored})> selections,
  ) async {
    return launchLineWithText(buildLineTextForSelections(state, selections));
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
    sb.writeln('みんなで集まれる駅の候補です（Aimachiより）');
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
  ///
  /// 戻り値:
  /// - true  : LINE 起動に成功した
  /// - false : 送信内容が空、または LINE 未インストール（canLaunchUrl=false）
  static Future<bool> shareMeetingPointsToLine(SearchState state) async {
    return launchLineWithText(buildLineTextForMeetingPoints(state));
  }
}
