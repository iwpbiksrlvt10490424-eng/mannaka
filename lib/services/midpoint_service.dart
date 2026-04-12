import 'dart:math';
import '../data/station_data.dart';
import '../data/station_coords.dart';
import '../data/transit_graph_data.dart';
import '../data/restaurant_data.dart';
import '../models/meeting_point.dart';
import '../models/participant.dart';
import '../models/restaurant.dart';
import '../models/scored_restaurant.dart';
import '../providers/search_provider.dart';
import '../utils/geo_utils.dart';
import 'transit_router.dart';

/// 中間地点スコアリングモード
/// 参加者の利用シーンや優先度に応じて重みを切り替える
enum ScoringMode {
  /// バランス型（デフォルト）: 効率50% + 最遠者30% + 公平性20%
  balanced,
  /// 効率重視: 合計移動時間最小化を優先
  efficient,
  /// 公平性重視: 全員の移動時間のばらつきを最小化
  fair,
}

class MidpointService {
  /// 駅圏クラスタ定義: 同一圏の駅はTop5に1駅だけ残す
  /// キー = サブ駅名, 値 = 代表駅名
  /// 都心密集ケースも考慮し、近接でも商圏が異なる駅は統合しない
  static const Map<String, String> _kClusterMap = {
    // ─── 新宿圏 ──────────────────────────────────────────────────────
    '代々木':     '新宿',
    '新宿三丁目': '新宿',
    '西新宿':     '新宿',
    '南新宿':     '新宿',
    '参宮橋':     '新宿',
    // ─── 渋谷・表参道圏 ──────────────────────────────────────────────
    '代官山':       '渋谷',
    '明治神宮前':   '表参道',
    '外苑前':       '表参道',
    // ─── 池袋圏 ──────────────────────────────────────────────────────
    '東池袋':   '池袋',
    '雑司が谷': '池袋',
    '北池袋':   '池袋',
    // ─── 上野圏 ──────────────────────────────────────────────────────
    '御徒町':     '上野',
    '仲御徒町':   '上野',
    '湯島':       '上野',
    '上野広小路': '上野',
    // ─── 東京駅圏 ────────────────────────────────────────────────────
    '大手町':   '東京',
    '二重橋前': '東京',
    '竹橋':     '東京',
    // ─── 銀座圏 ──────────────────────────────────────────────────────
    '銀座一丁目': '銀座',
    '東銀座':     '銀座',
    '宝町':       '銀座',
    // ─── 六本木圏 ────────────────────────────────────────────────────
    '六本木一丁目': '六本木',
    '神谷町':       '六本木',
    // ─── 秋葉原圏 ────────────────────────────────────────────────────
    '岩本町': '秋葉原',
    '末広町': '秋葉原',
    '新御茶ノ水': '秋葉原',
    // ─── 神保町・飯田橋圏 ────────────────────────────────────────────
    '水道橋': '飯田橋',
    '九段下': '神保町',
    '小川町': '神保町',
    '淡路町': '神保町',
    // ─── 目黒・五反田圏 ──────────────────────────────────────────────
    '不動前': '目黒',
    '高輪台': '五反田',
    // ─── 品川圏 ──────────────────────────────────────────────────────
    '高輪ゲートウェイ': '品川',
    '泉岳寺':          '品川',
    // ─── 押上圏 ──────────────────────────────────────────────────────
    'とうきょうスカイツリー': '押上',
    '曳舟':                   '押上',
    // ─── 浅草圏 ──────────────────────────────────────────────────────
    '蔵前':   '浅草',
    '田原町': '浅草',
    // ─── 錦糸町・両国圏 ──────────────────────────────────────────────
    '両国': '錦糸町',
    // ─── 三軒茶屋・下北沢圏 ──────────────────────────────────────────
    '世田谷代田': '下北沢',
    '東北沢':     '下北沢',
    // ─── 赤坂見附圏 ──────────────────────────────────────────────────
    '国会議事堂前': '赤坂見附',
    '永田町':       '赤坂見附',
    '溜池山王':     '赤坂見附',
  };

  /// 参加者から候補駅への移動時間（分）を返す
  /// 戻り値: null = 鉄道ネットワーク未接続（候補除外）
  /// GPS 座標のみの参加者は Haversine 推定（信頼度低）
  static int? _transitTimeForParticipantByName(
    Participant p,
    String candidateName,
    (double lat, double lng) candidateCoords,
  ) {
    String? fromName;
    if (p.stationName != null) {
      fromName = p.stationName;
    } else if (p.stationIndex != null && p.stationIndex! < kStations.length) {
      fromName = kStations[p.stationIndex!];
    }

    if (fromName != null) {
      // Dijkstra のみ。未接続なら null を返す（Haversine には落とさない）
      return TransitRouter.instance.travelMinutesByName(fromName, candidateName);
    }

    // 駅名なし・GPS 座標のみの場合のみ Haversine 推定（精度低）
    if (p.lat != null && p.lng != null) {
      return TransitRouter.instance.haversineFallback(
        p.lat!, p.lng!, candidateCoords.$1, candidateCoords.$2,
      );
    }
    return null;
  }

  static List<MeetingPoint> calculate(
    List<Participant> participants, {
    ScoringMode mode = ScoringMode.balanced,
  }) {
    // stationIndex がなくても stationName か座標があれば参加者として含める
    final active = participants
        .where((p) => p.hasStation || p.stationName != null || p.hasLocation)
        .toList();
    if (active.isEmpty) return [];

    // ── 都心密集モード検出 ────────────────────────────────────────────────
    // 参加者の地理的重心と最大散らばり距離を計算
    // 全員が5km圏内 = 都心密集モード（近接駅排除を緩め、クラスタ粒度を細かく）
    final locatedParticipants = active.where((p) => p.lat != null && p.lng != null).toList();
    double? geoCentroidLat;
    double? geoCentroidLng;
    if (locatedParticipants.isNotEmpty) {
      geoCentroidLat = locatedParticipants.map((p) => p.lat!).reduce((a, b) => a + b) / locatedParticipants.length;
      geoCentroidLng = locatedParticipants.map((p) => p.lng!).reduce((a, b) => a + b) / locatedParticipants.length;
    }

    // 参加者間の最大距離
    double maxInterParticipantKm = 0;
    for (int i = 0; i < locatedParticipants.length; i++) {
      for (int j = i + 1; j < locatedParticipants.length; j++) {
        final d = GeoUtils.distKm(
          locatedParticipants[i].lat!, locatedParticipants[i].lng!,
          locatedParticipants[j].lat!, locatedParticipants[j].lng!,
        );
        if (d > maxInterParticipantKm) maxInterParticipantKm = d;
      }
    }
    // 全員が7km以内 = 都心密集モード
    final isDenseCityMode = maxInterParticipantKm < 7.0 && locatedParticipants.length >= 2;

    final results = <MeetingPoint>[];

    // 集合場所の候補は全kTransitGraph駅（~415駅）
    for (final candidateName in kTransitGraph.keys) {
      final coords = kAllStationCoords[candidateName];
      if (coords == null) continue;

      final candidateIdx = kStations.indexOf(candidateName); // -1 if not in kStations

      final times = <String, int>{};
      bool anyUnreachable = false;

      for (final p in active) {
        final t = _transitTimeForParticipantByName(p, candidateName, coords);
        if (t == null) {
          // 駅名あり参加者で Dijkstra 未接続 → この候補は主ランキングから除外
          anyUnreachable = true;
          break;
        }
        times[p.id] = t;
      }

      if (anyUnreachable || times.isEmpty) continue;

      final values = times.values.toList();
      final total = values.fold(0, (a, b) => a + b);
      final avg = total / values.length;
      final maxVal = values.reduce((a, b) => a > b ? a : b);
      final minVal = values.reduce((a, b) => a < b ? a : b);

      final variance =
          values.map((v) => pow(v - avg, 2)).reduce((a, b) => a + b) / values.length;
      final stdDev = sqrt(variance);

      results.add(MeetingPoint(
        stationIndex: candidateIdx,
        stationName: candidateName,
        stationEmoji: candidateIdx >= 0 ? kStationEmojis[candidateIdx] : '🚉',
        lat: coords.$1,
        lng: coords.$2,
        totalMinutes: total,
        maxMinutes: maxVal,
        minMinutes: minVal,
        averageMinutes: avg,
        fairnessScore: 0,
        overallScore: 0,
        participantTimes: times,
        stdDev: stdDev,
        reason: null,
      ));
    }

    if (results.isEmpty) return [];

    // ── コリドーフィルタ（倍率条件 + 絶対時間閾値）──────────────────────────
    // 倍率条件: 最遠者が bestMaxMinutes × 1.5 超、または合計が minTotal × 2.0 超
    // 絶対閾値: 最遠者 60 分超（遠距離ケースでの感度補正）
    //          合計 150 分超（3人の場合 1人平均50分が上限の目安）
    // → 両条件の OR で除外（倍率だけだと近距離ケースで甘くなる）
    final bestMaxMinutes = results.map((r) => r.maxMinutes).reduce(min);
    final minTotalRaw = results.map((r) => r.totalMinutes).reduce(min);
    final maxPersonCount = active.length;
    // 都心密集モードでは絶対時間閾値を緩める（近距離なら全員20〜30分が現実的）
    final absMaxThreshold = isDenseCityMode ? 35 : 60;
    final absTotalThreshold = isDenseCityMode
        ? maxPersonCount * 25
        : maxPersonCount * 50;
    final filtered = results.where((r) {
      final overRelativeMax = r.maxMinutes > (bestMaxMinutes * 1.5).round();
      final overRelativeTotal = r.totalMinutes > (minTotalRaw * 2.0).round();
      final overAbsMax = r.maxMinutes > absMaxThreshold;
      final overAbsTotal = r.totalMinutes > absTotalThreshold;
      // 倍率超過 OR 絶対値超過のどちらかに引っかかれば除外
      return !(overRelativeMax || overRelativeTotal || overAbsMax || overAbsTotal);
    }).toList();

    if (filtered.isEmpty) return [];

    // ── スコア正規化（3軸 × モード別重み）──────────────────────────────────
    final minTotal = filtered.map((r) => r.totalMinutes).reduce(min);
    final maxTotal = filtered.map((r) => r.totalMinutes).reduce(max);
    final minMax  = filtered.map((r) => r.maxMinutes).reduce(min);
    final maxMax  = filtered.map((r) => r.maxMinutes).reduce(max);
    final minStd  = filtered.map((r) => r.stdDev).reduce(min);
    final maxStd  = filtered.map((r) => r.stdDev).reduce(max);
    // 公平性: max-minギャップ（ユーザー体感の不公平感）を主に、stdDevを補助
    final minGap  = filtered.map((r) => r.maxMinutes - r.minMinutes).reduce(min);
    final maxGap  = filtered.map((r) => r.maxMinutes - r.minMinutes).reduce(max);

    // モード別重み [eff, maxTime, fair]
    final (double wEff, double wMax, double wFair) = switch (mode) {
      ScoringMode.efficient => (0.65, 0.25, 0.10),
      ScoringMode.fair      => (0.30, 0.25, 0.45),
      ScoringMode.balanced  => (0.50, 0.30, 0.20),
    };

    final scored = filtered.map((r) {
      // 軸1: 合計移動時間最小化（全体効率）
      final effScore = maxTotal == minTotal ? 1.0
          : (maxTotal - r.totalMinutes) / (maxTotal - minTotal);
      // 軸2: 最遠者の移動時間最小化（主）
      final maxTimeScore = maxMax == minMax ? 1.0
          : (maxMax - r.maxMinutes) / (maxMax - minMax);
      // 軸3: 公平性 = max-minギャップ(70%) + stdDev(30%)
      // ユーザー体感は「1人だけ損すること」への反発が強いため gap を主にする
      final gap = r.maxMinutes - r.minMinutes;
      final gapScore = maxGap == minGap ? 1.0
          : (maxGap - gap) / (maxGap - minGap);
      final stdScore = maxStd == minStd ? 1.0
          : (maxStd - r.stdDev) / (maxStd - minStd);
      final fairScore = 0.7 * gapScore + 0.3 * stdScore;

      final overall = wEff * effScore + wMax * maxTimeScore + wFair * fairScore;

      // ── 方角偏りペナルティ（軽微）────────────────────────────────────────
      // 候補駅が参加者の重心から大きく外れた方向にある場合、小さく減点する
      // 強く効かせると地理重心に戻ってしまうため上限0.08に制限する
      double directionPenalty = 0.0;
      if (geoCentroidLat != null && geoCentroidLng != null) {
        final distFromGeoCentroid = GeoUtils.distKm(
          r.lat, r.lng, geoCentroidLat, geoCentroidLng,
        );
        // 重心から3km超の候補に対して距離に応じた軽微ペナルティ
        if (distFromGeoCentroid > 3.0) {
          directionPenalty = ((distFromGeoCentroid - 3.0) * 0.01).clamp(0.0, 0.08);
        }
      }
      final adjustedOverall = (overall - directionPenalty).clamp(0.0, 1.0);

      return MeetingPoint(
        stationIndex: r.stationIndex,
        stationName: r.stationName,
        stationEmoji: r.stationEmoji,
        lat: r.lat,
        lng: r.lng,
        totalMinutes: r.totalMinutes,
        maxMinutes: r.maxMinutes,
        minMinutes: r.minMinutes,
        averageMinutes: r.averageMinutes,
        fairnessScore: fairScore,
        overallScore: adjustedOverall,
        participantTimes: r.participantTimes,
        stdDev: r.stdDev,
        reason: null,
      );
    }).toList();

    scored.sort((a, b) => b.overallScore.compareTo(a.overallScore));

    // ── 駅圏クラスタによる重複排除 ────────────────────────────────────────
    // クラスタマップ優先: 同一圏の駅はスコア上位1駅だけ残す
    // クラスタ外の近接（0.8km未満）も排除するが、都心密集ケースの誤マージを
    // 防ぐため閾値を 0.8km に絞る（以前の 1.2km は広すぎた）
    final usedClusters = <String>{};
    final deduplicated = <MeetingPoint>[];
    for (final m in scored) {
      final clusterKey = _kClusterMap[m.stationName] ?? m.stationName;
      if (usedClusters.contains(clusterKey)) continue;

      // クラスタ外の純粋な近接チェック
      // 都心密集モードでは近接排除を緩める（0.5km）、通常は0.8km
      final proximityKm = isDenseCityMode ? 0.5 : 0.8;
      bool tooClose = false;
      for (final selected in deduplicated) {
        // 両駅が同一クラスタなら既にクラスタで処理済みのはず。
        // 残るのは別クラスタだが物理的に近い駅（例: 四ッ谷と市ヶ谷）
        if (GeoUtils.distKm(m.lat, m.lng, selected.lat, selected.lng) < proximityKm) {
          tooClose = true;
          break;
        }
      }
      if (tooClose) continue;

      deduplicated.add(m);
      usedClusters.add(clusterKey);
      if (deduplicated.length >= 5) break;
    }

    // reasonフィールドを生成して最終リストを返す
    final bestTotalMinutes = deduplicated.isEmpty
        ? 0
        : deduplicated.map((r) => r.totalMinutes).reduce(min);

    return deduplicated.map((m) {
      final clauses = <String>[];

      // 第1節: 時間特性
      if (m.maxMinutes <= 20) {
        clauses.add('全員20分以内');
      } else if ((m.maxMinutes - m.minMinutes) <= 8) {
        clauses.add('移動時間が均等');
      } else if (m.totalMinutes == bestTotalMinutes) {
        clauses.add('合計移動時間が最短クラス');
      }

      // 第2節: 近さ
      final hasNearParticipant =
          m.participantTimes.values.any((t) => t <= 5);
      if (hasNearParticipant) {
        clauses.add('出発地として近い');
      }

      final reason = clauses.isNotEmpty
          ? clauses.take(2).join('・')
          : '3者間の中間地点';

      return MeetingPoint(
        stationIndex: m.stationIndex,
        stationName: m.stationName,
        stationEmoji: m.stationEmoji,
        lat: m.lat,
        lng: m.lng,
        totalMinutes: m.totalMinutes,
        maxMinutes: m.maxMinutes,
        minMinutes: m.minMinutes,
        averageMinutes: m.averageMinutes,
        fairnessScore: m.fairnessScore,
        overallScore: m.overallScore,
        participantTimes: m.participantTimes,
        stdDev: m.stdDev,
        reason: reason,
      );
    }).toList();
  }

  static List<Restaurant> getRestaurants({
    required int stationIndex,
    Set<String>? categories,
    int? maxBudget,
    bool femaleFriendly = false,
    bool hasPrivateRoom = false,
    TimeSlot timeSlot = TimeSlot.all,
  }) {
    var list = kRestaurants.where((r) => r.stationIndex == stationIndex).toList();

    if (categories != null && categories.isNotEmpty) {
      list = list.where((r) => categories.contains(r.category)).toList();
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

  static List<String> getAllCategories() {
    return kRestaurants.map((r) => r.category).toSet().toList()..sort();
  }

  /// 交通最適な集合地点の座標を返す（Uber Eats式: 合計移動時間最小化）
  /// meetingPoints が渡された場合は最上位駅の座標を使用する。
  /// 渡されない場合は地理的重心にフォールバックする。
  static (double lat, double lng)? calcCentroid(
    List<Participant> participants, {
    List<MeetingPoint>? meetingPoints,
  }) {
    // 交通最適駅がある場合はその座標を集合地点として使用
    if (meetingPoints != null && meetingPoints.isNotEmpty) {
      return (meetingPoints.first.lat, meetingPoints.first.lng);
    }
    // フォールバック: 地理的重心（駅情報がない場合）
    final active = participants.where((p) => p.hasLocation).toList();
    if (active.length < 2) return null;
    final lat = active.map((p) => p.lat!).reduce((a, b) => a + b) / active.length;
    final lng = active.map((p) => p.lng!).reduce((a, b) => a + b) / active.length;
    return (lat, lng);
  }

  /// 表示ジャンルごとのグローバル除外リスト
  /// キー = 表示カテゴリ名, 値 = そのカテゴリ選択時に除外すべきカテゴリSet
  static const Map<String, Set<String>> _kGenreExclusions = {
    'カフェ':  {'居酒屋', 'バー', '焼肉', '韓国料理', 'ラーメン', '中華'},
    '居酒屋':  {'カフェ'},
    '焼肉':    {'カフェ', 'バー'},
  };

  /// スコアリング前の除外フィルタ
  ///
  /// 1. 飲食以外カテゴリ（Hotpepper APIの外れ値）を常に排除
  /// 2. selectedCategories がある場合は _kGenreExclusions の除外ルールを適用
  static List<Restaurant> filterRestaurantsForDisplayGenre(
    List<Restaurant> restaurants,
    Set<String> selectedCategories,
  ) {
    // 施設主体カテゴリ: 全ジャンル表示でハード除外
    const facilityExclusions = <String>{
      'カラオケ', 'パチンコ', 'マッサージ', 'ネットカフェ',
      'アミューズメント', 'ゲームセンター', 'ボウリング', 'スポーツクラブ',
      'エステ', 'ネイル', '整体', 'カットサロン',
    };
    var result = restaurants
        .where((r) => !facilityExclusions.contains(r.category))
        .toList();

    // blockedGenres チェック（店舗固有の禁止ジャンル）
    if (selectedCategories.isNotEmpty) {
      result = result.where((r) {
        // 選択ジャンルが店のblockedGenresに含まれる → 除外
        for (final sel in selectedCategories) {
          if (r.blockedGenres.contains(sel)) return false;
        }
        return true;
      }).toList();
    }

    // ── ジャンル別除外 ────────────────────────────────────────────────────
    // 例: カフェを選択中なら居酒屋・焼肉・ラーメン等は出さない
    if (selectedCategories.isNotEmpty) {
      final blocked = <String>{};
      for (final cat in selectedCategories) {
        blocked.addAll(_kGenreExclusions[cat] ?? const {});
      }
      // 選択カテゴリ自身は除外しない（blockedに自分が入っていても除外しない）
      blocked.removeAll(selectedCategories);
      if (blocked.isNotEmpty) {
        result = result.where((r) => !blocked.contains(r.category)).toList();
      }
    }

    return result;
  }

  /// 4軸スコアリングでレストランを評価・ランク付けして返す
  ///
  /// 軸1 accessScore    集合しやすさ   : 駅からの徒歩時間
  /// 軸2 conditionScore 条件一致       : ジャンル・予算・シーン適合
  /// 軸3 qualityScore   品質           : 評価・写真・コース等のシグナル
  /// 軸4 usabilityScore 利用しやすさ   : 予約可否・個室・禁煙等
  ///
  /// 日付指定時は予約可能な店舗のみを対象とする。
  static List<ScoredRestaurant> scoreRestaurants({
    required List<Participant> participants,
    required double centroidLat,
    required double centroidLng,
    List<Restaurant>? baseRestaurants,
    Set<String>? categories,
    bool femaleFriendly = false,
    bool hasPrivateRoom = false,
    TimeSlot timeSlot = TimeSlot.all,
    int maxBudget = 0,
    String? occasion,
    String? groupRelation,
    DateTime? selectedDate,
  }) {
    final active = participants.where((p) => p.hasLocation).toList();
    if (active.isEmpty) return [];

    var restaurants = (baseRestaurants ?? kRestaurants).toList();

    // ── ハードフィルタ ──────────────────────────────────────────────────────
    if (categories != null && categories.isNotEmpty) {
      restaurants = restaurants.where((r) => categories.contains(r.category)).toList();
    }
    if (maxBudget > 0) {
      restaurants = restaurants.where((r) => r.priceAvg == 0 || r.priceAvg <= maxBudget).toList();
    } else if (maxBudget < 0) {
      final minB = maxBudget.abs();
      restaurants = restaurants.where((r) => r.priceAvg == 0 || r.priceAvg >= minB).toList();
    }
    if (hasPrivateRoom) {
      restaurants = restaurants.where((r) => r.hasPrivateRoom).toList();
    }
    if (timeSlot == TimeSlot.lunch) {
      restaurants = restaurants.where((r) => r.isLunchAvailable).toList();
    } else if (timeSlot == TimeSlot.dinner) {
      restaurants = restaurants.where((r) => r.isDinnerAvailable).toList();
    }
    // 日付指定時: 予約可能な店舗のみ（その日程で予約できるところ）
    if (selectedDate != null) {
      restaurants = restaurants.where((r) => r.isReservable).toList();
    }

    if (restaurants.isEmpty) return [];

    // ── 参加者距離（Haversine、表示用）────────────────────────────────────
    final scored = restaurants.map((r) {
      final (rLat, rLng) = (r.lat != null && r.lng != null)
          ? (r.lat!, r.lng!)
          : kStationLatLng[r.stationIndex];
      final distFromCentroid = GeoUtils.distKm(centroidLat, centroidLng, rLat, rLng);
      final pDists = <String, double>{
        for (final p in active)
          p.id: GeoUtils.distKm(p.lat!, p.lng!, rLat, rLng)
      };

      // ── 軸1: accessScore（集合しやすさ = 駅からの徒歩時間）──────────────
      // distanceMinutes は Hotpepper "徒歩X分" から取得した実データ
      final walkMin = r.distanceMinutes;
      // 滑らかな減衰関数: exp(-0.13 * max(0, walkMin - 1))
      // 1分→0.99, 3分→0.77, 5分→0.60, 8分→0.41, 10分→0.31, 15分→0.17
      // walkMin == 0 はデータなし扱い → ニュートラル 0.55
      final double accessScore = walkMin <= 0
          ? 0.55
          : exp(-0.13 * max(0, walkMin - 1.0)).clamp(0.05, 1.0);

      // ── 軸2: conditionScore（条件一致）──────────────────────────────────
      // ジャンル一致（主ジャンル完全一致 > 副ジャンル部分一致 > 不一致）
      final double genreScore = (categories == null || categories.isEmpty)
          ? 0.7 // ユーザーが未選択 = ニュートラル
          : categories.contains(r.category)
              ? 1.0
              : r.secondaryGenres.any((g) => categories.contains(g))
                  ? 0.60 // 副ジャンル一致（例: バル→居酒屋）
                  : 0.1;
      // 予算一致（priceAvg == 0 はデータなし = ニュートラル）
      final double budgetScore = r.priceAvg == 0
          ? 0.7
          : maxBudget <= 0
              ? 0.7
              : r.priceAvg <= maxBudget
                  ? 1.0
                  : r.priceAvg <= maxBudget * 1.2
                      ? 0.5 // 20%超まで許容
                      : 0.1;
      // シーン適合
      final double occasionScore =
          occasion != null ? _computeOccasionScore(r, occasion) : 0.6;
      final double conditionScore =
          (genreScore * 0.40 + budgetScore * 0.25 + occasionScore * 0.35)
              .clamp(0.0, 1.0);

      // ── 軸3a: trustScore（信頼性）────────────────────────────────────────
      // 評価・レビュー件数を項目ごとの信頼度で評価する
      final double ratingFactor = r.ratingConfidence == 'unknown'
          ? 0.45 // unknown = provisional ニュートラル
          : r.rating >= 4.0 ? 1.0
          : r.rating >= 3.5 ? 0.65
          : r.rating >= 3.0 ? 0.35
          : r.rating > 0    ? 0.10
          : 0.45; // データなし = provisional ニュートラル

      final double reviewFactor = r.reviewConfidence == 'unknown'
          ? 0.40 // unknown = provisional ニュートラル
          : r.reviewCount >= 100 ? 1.0
          : r.reviewCount >= 30  ? 0.70
          : r.reviewCount >= 10  ? 0.40
          : r.reviewCount >= 1   ? 0.15
          : 0.05; // 件数ゼロかつ known = 実績なし

      final double trustScore = (ratingFactor * 0.55 + reviewFactor * 0.45).clamp(0.0, 1.0);

      // ── 軸3b: appealScore（魅力・雰囲気）────────────────────────────────
      // visualAppeal: 写真の量・質による視覚的訴求力
      double visualAppeal = 0.0;
      if (r.imageUrl != null && r.imageUrl!.isNotEmpty) {
        visualAppeal += 0.65;
        if (r.imageUrls.length >= 3) { visualAppeal += 0.20; }
        else if (r.imageUrls.length >= 2) { visualAppeal += 0.10; }
      }
      visualAppeal = visualAppeal.clamp(0.0, 1.0);
      // atmosphereFit: カテゴリとシーンの雰囲気一致度
      final double atmosphereFit = _computeAtmosphereFit(r, occasion);
      // appeal = visual 55% + atmosphere 45%（写真の有無だけで上げすぎない）
      final double appealScore = (visualAppeal * 0.55 + atmosphereFit * 0.45).clamp(0.0, 1.0);

      // ── 軸3c: planFitScore（プラン・宴会実行可能性）──────────────────────
      // 宴会系シーンでは「予約可」もプラン実現に必須のため planFit に寄与させる
      final isPartyScene = occasion == '歓迎会' || occasion == '打ち上げ' || occasion == '誕生日';
      double planFitScore;
      if (r.planInfoConfidence == 'unknown') {
        planFitScore = 0.30; // unknown = provisional ニュートラル
      } else {
        planFitScore = 0.0;
        if (r.course)    planFitScore += 0.38;
        if (r.freeDrink) planFitScore += 0.30;
        if (r.freeFood)  planFitScore += 0.17;
        // 宴会系シーンでは予約可もプラン実行可能性に寄与
        if (isPartyScene && r.isReservable) planFitScore += 0.15;
        planFitScore = planFitScore.clamp(0.0, 1.0);
      }

      // ── 軸4: usabilityScore（純粋な使いやすさ）───────────────────────────
      // 宴会系シーンでは予約可を planFit にも寄与させるため usability 側の重みを下げる
      double usabilityScore = 0.0;
      if (r.isReservable)   usabilityScore += isPartyScene ? 0.35 : 0.50;
      if (r.hasPrivateRoom) usabilityScore += 0.30; // 個室あり
      if (r.nonSmoking)     usabilityScore += 0.15; // 禁煙
      if (r.wifi)           usabilityScore += 0.05; // Wi-Fi
      usabilityScore = usabilityScore.clamp(0.0, 1.0);

      // 6軸直接重み付け: [access, condition, trust, appeal, planFit, usability]
      final baseWeights = _genreWeights(r.category);
      final weights = _applySceneParticipantWeights(
        baseWeights,
        occasion,
        active.length,
      );
      // unknown フィールド数ペナルティ（情報不足の店が中立値で上位に残るのを防ぐ）
      final int unknownCount = [
        r.ratingConfidence,
        r.reviewConfidence,
        r.planInfoConfidence,
      ].where((c) => c == 'unknown').length;
      final double unknownPenalty = unknownCount >= 3 ? 0.90 : unknownCount == 2 ? 0.95 : 1.0;

      final overall = ((weights[0] * accessScore +
                  weights[1] * conditionScore +
                  weights[2] * trustScore +
                  weights[3] * appealScore +
                  weights[4] * planFitScore +
                  weights[5] * usabilityScore) *
              unknownPenalty)
          .clamp(0.0, 1.0);

      // quality = trust 50% + appeal 30% + planFit 20%（ScoredRestaurantコンストラクタ用）
      final double qualityScore = (trustScore * 0.50 + appealScore * 0.30 + planFitScore * 0.20).clamp(0.0, 1.0);

      // ── キュレーションラベル（外さない / おしゃれ / 穴場）────────────────
      final curationLabel = _computeCurationLabel(
        r,
        accessScore: accessScore,
        trustScore: trustScore,
        appealScore: appealScore,
        atmosphereFit: atmosphereFit,
        usabilityScore: usabilityScore,
        occasion: occasion,
        selectedDate: selectedDate,
      );

      return ScoredRestaurant(
        restaurant: r,
        score: overall,
        distanceKm: distFromCentroid,
        participantDistances: pDists,
        fairnessScore: accessScore,
        curationLabel: curationLabel,
        accessScore: accessScore,
        conditionScore: conditionScore,
        qualityScore: qualityScore,
        usabilityScore: usabilityScore,
        trustScore: trustScore,
        appealScore: appealScore,
        planFitScore: planFitScore,
      );
    }).toList();

    scored.sort((a, b) => b.score.compareTo(a.score));

    // ── 多様性制御 ─────────────────────────────────────────────────────
    // ジャンル上限3件 + 価格帯上限4件 でTop15の偏りを抑制する
    const maxSameGenreInTop = 3;
    const maxSamePriceTierInTop = 4;
    final genreCount = <String, int>{};
    final priceTierCount = <int, int>{};
    final diversified = <ScoredRestaurant>[];
    final overflow = <ScoredRestaurant>[];

    for (final sr in scored) {
      final genre = sr.restaurant.category;
      final tier = _priceTierGroup(sr.restaurant.priceAvg);
      final genreC = genreCount[genre] ?? 0;
      final tierC = priceTierCount[tier] ?? 0;
      // 価格不明(tier==0)は価格帯制限を適用しない
      final tierOk = tier == 0 || tierC < maxSamePriceTierInTop;
      if (diversified.length < 15 && genreC < maxSameGenreInTop && tierOk) {
        diversified.add(sr);
        genreCount[genre] = genreC + 1;
        priceTierCount[tier] = tierC + 1;
      } else {
        overflow.add(sr);
      }
    }
    // 不足分を overflow から補完（制限なし）
    for (final sr in overflow) {
      if (diversified.length >= scored.length) break;
      diversified.add(sr);
    }

    return diversified;
  }

  /// ジャンル別スコアリング重み [access, condition, trust, appeal, planFit, usability]
  /// 待ち合わせ用途では集合しやすさ（access）を軸に、ジャンル特性で調整する
  static List<double> _genreWeights(String category) {
    return switch (category) {
      // 居酒屋: 集合しやすさ + 予約・個室（usability）重視
      '居酒屋' => [0.25, 0.15, 0.15, 0.08, 0.17, 0.20],
      // カフェ: 雰囲気（appeal）+ 条件一致 + 信頼性
      'カフェ'  => [0.18, 0.22, 0.22, 0.22, 0.06, 0.10],
      // 焼肉: 予約必須（usability高め） + 信頼性
      '焼肉'   => [0.18, 0.15, 0.20, 0.05, 0.18, 0.24],
      // バー: 雰囲気・appeal 最優先
      'バー'   => [0.12, 0.18, 0.18, 0.28, 0.12, 0.12],
      // フレンチ・イタリアン: 品質・雰囲気重視
      'フレンチ' || 'イタリアン' => [0.12, 0.18, 0.24, 0.26, 0.10, 0.10],
      // 和食: バランス、信頼性重視
      '和食'  => [0.18, 0.18, 0.26, 0.14, 0.12, 0.12],
      // 韓国料理: アクセス + グループ適合
      '韓国料理' => [0.22, 0.20, 0.18, 0.15, 0.12, 0.13],
      // デフォルト
      _ => [0.18, 0.22, 0.20, 0.15, 0.12, 0.13],
    };
  }

  /// シーン別・人数別の重み補正 [access, condition, trust, appeal, planFit, usability]
  ///
  /// ジャンル基本重みに乗数を掛けて正規化することで、
  /// ジャンルの特性を維持しながらシーン・人数に応じた傾斜を与える。
  static List<double> _applySceneParticipantWeights(
    List<double> base,
    String? occasion,
    int participantCount,
  ) {
    // [access, condition, trust, appeal, planFit, usability]
    var m = [1.0, 1.0, 1.0, 1.0, 1.0, 1.0];

    // 人数別乗数
    if (participantCount >= 5) {
      m[5] *= 1.50; // 大人数: 個室・予約重視
      m[4] *= 1.30; // 飲み放題・コースも重要
      m[0] *= 1.10;
      m[3] *= 0.80;
    } else if (participantCount == 2) {
      m[3] *= 1.35; // 2人: 雰囲気・写真重視
      m[1] *= 1.20;
      m[2] *= 1.10;
      m[0] *= 0.80;
    }

    // シーン別乗数
    switch (occasion) {
      case '仕事帰り':
        m[0] *= 1.35; // 駅近必須
        m[5] *= 1.25; // 予約・個室
        m[3] *= 0.70;
      case 'デート':
        m[3] *= 1.50; // 雰囲気最優先
        m[1] *= 1.25; // シーン一致
        m[2] *= 1.15; // 信頼性
        m[0] *= 0.65;
      case '女子会':
        m[3] *= 1.40; // 写真・雰囲気
        m[1] *= 1.20;
        m[5] *= 1.15; // 個室
        m[2] *= 1.10;
      case '歓迎会':
      case '打ち上げ':
        m[5] *= 1.45; // 個室・予約・利便性
        m[4] *= 1.35; // 飲み放題・コース
        m[0] *= 1.10;
        m[3] *= 0.75;
      case '合コン':
        m[3] *= 1.30; // 雰囲気
        m[1] *= 1.30; // シーン一致
        m[5] *= 1.10;
        m[2] *= 1.10;
    }

    final adjusted = List.generate(6, (i) => base[i] * m[i]);
    final sum = adjusted.reduce((a, b) => a + b);
    if (sum == 0) return base;
    return adjusted.map((x) => x / sum).toList();
  }

  /// キュレーションラベルを決定する
  ///
  /// 優先順: 外さない > おしゃれ > 穴場 > 特徴ラベル
  ///
  /// - 外さない: 駅近(accessScore>=0.65) + 評価安定(reviewCount>=30) + 予約可
  /// - おしゃれ: 写真あり + 女性人気/デート向きカテゴリ
  /// - 穴場    : レビュー10〜79件 + 評価3.5以上 + 駅から4分以上
  static String _computeCurationLabel(
    Restaurant r, {
    required double accessScore,
    required double trustScore,
    required double appealScore,
    required double atmosphereFit,
    required double usabilityScore,
    required String? occasion,
    required DateTime? selectedDate,
  }) {
    // ── タイプ判定 ────────────────────────────────────────────────────
    // 外さない: trust + usability の両方が高い店のみ。情報不足店には絶対付与しない
    final isHazusanai = r.hasAdequateInfo &&
        accessScore >= 0.55 &&
        r.reviewCount >= 30 &&
        r.isReservable &&
        r.rating >= 3.5 &&
        trustScore >= 0.55 &&    // 0.50 → 0.55（本スコアとの一貫性を強化）
        usabilityScore >= 0.45;  // usabilityが低い店には付与しない

    final oshareCategories = {'フレンチ', 'イタリアン', 'カフェ', 'バー'};
    // おしゃれ: appealScore + atmosphereFit の両方が基準以上（写真だけでは不十分）
    final isOshare = appealScore >= 0.55 &&
        atmosphereFit >= 0.55 &&   // 雰囲気がシーンに合っていること
        (r.isFemalePopular ||
            oshareCategories.contains(r.category) ||
            occasion == 'デート' ||
            occasion == '女子会');

    // 穴場: 評価安定 + 情報一定あり + 駅近すぎず遠すぎない + trust が一定以上
    final isAnaba = r.hasAdequateInfo &&
        r.reviewCount >= 10 &&
        r.reviewCount < 80 &&
        r.rating >= 3.5 &&
        r.distanceMinutes >= 4 &&
        r.distanceMinutes <= 12 &&
        trustScore >= 0.35; // trustScore が低すぎる店には穴場ラベルを付けない

    String type = '';
    if (isHazusanai) {
      type = '外さない';
    } else if (isOshare) {
      type = 'おしゃれ';
    } else if (isAnaba) {
      type = '穴場';
    }

    // ── サブラベル（特徴）────────────────────────────────────────────
    String sub = '';
    if (selectedDate != null && r.isReservable) {
      sub = '${selectedDate.month}/${selectedDate.day}予約可';
    } else if (r.distanceMinutes <= 3) {
      sub = '駅${r.distanceMinutes}分';
    } else if (r.distanceMinutes <= 5) {
      sub = '駅近';
    } else if (r.hasPrivateRoom) {
      sub = '個室';
    } else if (r.freeDrink) {
      sub = '飲放';
    } else if (r.course) {
      sub = 'コース';
    }

    if (type.isNotEmpty && sub.isNotEmpty) return '$type · $sub';
    if (type.isNotEmpty) return type;
    return sub;
  }

  /// シーンに応じたレストランスコアをカテゴリ・属性から動的に計算する
  /// （APIレストランに occasionTags が存在しないため、カテゴリと属性で代替）
  static double _computeOccasionScore(Restaurant r, String occasion) {
    double base;
    double bonus = 0.0;

    switch (occasion) {
      case '女子会':
        base = switch (r.category) {
          'カフェ' => 1.0,
          'イタリアン' || 'フレンチ' => 0.95,
          '韓国料理' => 0.90,
          '和食' => 0.75,
          '洋食' => 0.70,
          'バー' => 0.45,
          '居酒屋' => 0.25,
          'ラーメン' || '中華' || '焼肉' => 0.10,
          _ => 0.50,
        };
        if (r.hasPrivateRoom) bonus += 0.5;
        if (r.nonSmoking) bonus += 0.3;
        if (r.imageUrl != null && r.imageUrl!.isNotEmpty) bonus += 0.3;
        if (r.course) bonus += 0.15;

      case '誕生日':
        base = switch (r.category) {
          'フレンチ' || 'イタリアン' => 1.0,
          'カフェ' => 0.85,
          '和食' => 0.80,
          '洋食' => 0.70,
          '居酒屋' => 0.35,
          'ラーメン' || '中華' => 0.15,
          _ => 0.55,
        };
        if (r.hasPrivateRoom) bonus += 0.8;
        if (r.course) bonus += 0.5;
        if (r.imageUrl != null && r.imageUrl!.isNotEmpty) bonus += 0.3;

      case 'ランチ':
        final isLunch = r.lunchFromApi || r.isLunchAvailable;
        base = isLunch ? 1.0 : 0.25;
        if (r.category == 'カフェ') bonus += 0.5;

      case '合コン':
        base = switch (r.category) {
          'イタリアン' || 'フレンチ' => 1.0,
          'カフェ' => 0.80,
          '和食' => 0.75,
          'バー' => 0.70,
          '焼肉' => 0.60,
          '居酒屋' => 0.40,
          'ラーメン' || '中華' => 0.15,
          _ => 0.50,
        };
        if (r.nonSmoking) bonus += 0.3;
        if (r.hasPrivateRoom) bonus += 0.5;
        if (r.imageUrl != null && r.imageUrl!.isNotEmpty) bonus += 0.3;

      case 'デート':
        base = switch (r.category) {
          'フレンチ' || 'イタリアン' => 1.0,
          'カフェ' => 0.90,
          '和食' => 0.80,
          'バー' => 0.75,
          '洋食' => 0.70,
          '韓国料理' => 0.55,
          '居酒屋' => 0.30,
          'ラーメン' || '焼肉' => 0.15,
          _ => 0.50,
        };
        if (r.hasPrivateRoom) bonus += 0.7;
        if (r.imageUrl != null && r.imageUrl!.isNotEmpty) bonus += 0.4;
        if (r.nonSmoking) bonus += 0.2;

      case '歓迎会':
      case '打ち上げ':
        base = switch (r.category) {
          '居酒屋' => 1.0,
          '和食' => 0.80,
          '焼肉' => 0.75,
          '韓国料理' => 0.70,
          '中華' => 0.65,
          'カフェ' => 0.20,
          _ => 0.55,
        };
        if (r.freeDrink) bonus += 0.7;
        if (r.hasPrivateRoom) bonus += 0.5;
        if (r.freeFood) bonus += 0.3;

      default:
        return 0.6;
    }

    // 属性加点はカテゴリ基礎点の最大30%まで（逆転防止）
    final maxBonus = base * 0.30;
    final normalizedBonus = bonus > 0 ? (bonus / (bonus + 2.0)) * maxBonus : 0.0;
    return (base + normalizedBonus).clamp(0.0, 1.0);
  }

  /// カテゴリとシーンの雰囲気一致度（atmosphereFit）
  ///
  /// 単純な「写真あり」だけでなく、カテゴリ固有の雰囲気値とシーン一致度を合成する。
  /// デート・女子会ではフレンチ/カフェ/イタリアンを高く評価し、
  /// 宴会系では居酒屋を高く評価するなど、シーンによって評価軸を変える。
  static double _computeAtmosphereFit(Restaurant r, String? occasion) {
    // カテゴリ固有の雰囲気ベース値
    const atmosphericCategories = {'フレンチ', 'イタリアン', 'バー', 'カフェ', '和食'};
    const casualCategories = {'ラーメン', '中華', '焼肉', 'ファストフード'};
    double base;
    if (atmosphericCategories.contains(r.category)) {
      base = 0.78;
    } else if (casualCategories.contains(r.category)) {
      base = 0.30;
    } else {
      base = 0.52; // 居酒屋、洋食、韓国料理 etc.
    }

    // シーン×カテゴリ適合ボーナス
    double bonus = 0.0;
    switch (occasion) {
      case 'デート':
        if ({'フレンチ', 'イタリアン', 'バー', 'カフェ'}.contains(r.category)) bonus += 0.25;
        if (r.isFemalePopular) bonus += 0.10;
      case '女子会':
        if ({'カフェ', 'イタリアン', 'フレンチ', '韓国料理'}.contains(r.category)) bonus += 0.20;
        if (r.isFemalePopular) bonus += 0.15;
      case '合コン':
        if ({'イタリアン', 'フレンチ', 'カフェ', 'バー'}.contains(r.category)) bonus += 0.20;
      case '誕生日':
        if ({'フレンチ', 'イタリアン', '和食'}.contains(r.category)) bonus += 0.25;
        if (r.hasPrivateRoom) bonus += 0.10;
      case '歓迎会':
      case '打ち上げ':
        if (r.category == '居酒屋') bonus += 0.22;
        if (r.hasPrivateRoom) bonus += 0.10;
      case '仕事帰り':
        if ({'居酒屋', 'バー', '和食'}.contains(r.category)) bonus += 0.12;
    }

    return (base + bonus).clamp(0.0, 1.0);
  }

  /// 価格帯グルーピング（多様性制御用）
  /// 0=不明, 1=〜1,500, 2=〜3,000, 3=〜5,000, 4=5,000〜
  static int _priceTierGroup(int priceAvg) {
    if (priceAvg == 0) return 0;
    if (priceAvg < 1500) return 1;
    if (priceAvg < 3000) return 2;
    if (priceAvg < 5000) return 3;
    return 4;
  }

}
