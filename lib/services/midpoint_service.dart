import 'dart:math';
import '../data/station_data.dart';
import '../data/restaurant_data.dart';
import '../models/meeting_point.dart';
import '../models/participant.dart';
import '../models/restaurant.dart';
import '../models/scored_restaurant.dart';
import '../providers/search_provider.dart';
import '../utils/geo_utils.dart';
import 'transit_router.dart';

class MidpointService {
  /// 駅間の移動時間（分）を返す。
  /// 両インデックスがkTransitMatrix範囲内ならマトリクスを使用し、
  /// それ以外はHaversine距離から推定する（約25km/h＋乗り換えオーバーヘッド）。
  static int _transitTime(int fromIdx, int toIdx) {
    if (fromIdx < kTransitMatrix.length && toIdx < kTransitMatrix.length) {
      return kTransitMatrix[fromIdx][toIdx];
    }
    // Dijkstra-based routing for stations outside the pre-computed matrix
    return TransitRouter.instance.travelMinutes(fromIdx, toIdx);
  }

  /// 参加者から候補駅cへの移動時間（分）を返す
  /// stationIndex がある場合はmatrix/Dijkstra、
  /// stationName のみの場合（kStations外駅）はDijkstra+座標フォールバック
  static int _transitTimeForParticipant(Participant p, int candidateIdx) {
    if (p.stationIndex != null) {
      return _transitTime(p.stationIndex!, candidateIdx);
    }
    if (p.stationName != null) {
      return TransitRouter.instance.travelMinutesFromName(
        p.stationName!,
        candidateIdx,
        lat: p.lat,
        lng: p.lng,
      );
    }
    // lat/lng のみの場合はHaversine推定
    if (p.lat != null && p.lng != null) {
      final candidate = kStationLatLng[candidateIdx];
      final distKm = GeoUtils.distKm(p.lat!, p.lng!, candidate.$1, candidate.$2);
      return max(5, (distKm / 25.0 * 60).round());
    }
    return 60;
  }

  static List<MeetingPoint> calculate(List<Participant> participants) {
    // stationIndex がなくても stationName か座標があれば参加者として含める
    final active = participants
        .where((p) => p.hasStation || p.stationName != null || p.hasLocation)
        .toList();
    if (active.isEmpty) return [];

    final results = <MeetingPoint>[];

    // 集合場所の候補は全59駅（Dijkstraルーターで全駅に対応）
    for (int c = 0; c < kStations.length; c++) {
      final times = <String, int>{};
      for (final p in active) {
        times[p.id] = _transitTimeForParticipant(p, c);
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

    if (results.isEmpty) return [];

    // Normalize scores
    // Uber Eats式: 合計移動時間50% + 最遅到着者の時間30% + 分散（公平性）20%
    final minTotal = results.map((r) => r.totalMinutes).reduce(min);
    final maxTotal = results.map((r) => r.totalMinutes).reduce(max);
    final minMax = results.map((r) => r.maxMinutes).reduce(min);
    final maxMax = results.map((r) => r.maxMinutes).reduce(max);
    final minStd = results.map((r) => r.stdDev).reduce(min);
    final maxStd = results.map((r) => r.stdDev).reduce(max);

    final scored = results.map((r) {
      // 合計移動時間最小化（全体効率 = Uber Eatsの総ETA最小と同義）
      final effScore = maxTotal == minTotal
          ? 1.0
          : (maxTotal - r.totalMinutes) / (maxTotal - minTotal);
      // 最遅到着者の時間最小化（誰かだけが極端に遠くならないようにする）
      final maxTimeScore =
          maxMax == minMax ? 1.0 : (maxMax - r.maxMinutes) / (maxMax - minMax);
      // 分散最小化（公平性ペナルティ: 偏りを少しならす）
      final fairScore =
          maxStd == minStd ? 1.0 : (maxStd - r.stdDev) / (maxStd - minStd);
      final overall = 0.50 * effScore + 0.30 * maxTimeScore + 0.20 * fairScore;

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
      final coords = kStationLatLng[meetingPoints.first.stationIndex];
      return (coords.$1, coords.$2);
    }
    // フォールバック: 地理的重心（駅情報がない場合）
    final active = participants.where((p) => p.hasLocation).toList();
    if (active.length < 2) return null;
    final lat = active.map((p) => p.lat!).reduce((a, b) => a + b) / active.length;
    final lng = active.map((p) => p.lng!).reduce((a, b) => a + b) / active.length;
    return (lat, lng);
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
      final double accessScore = walkMin <= 3
          ? 1.00
          : walkMin <= 5
              ? 0.85
              : walkMin <= 8
                  ? 0.65
                  : walkMin <= 10
                      ? 0.45
                      : walkMin <= 15
                          ? 0.25
                          : 0.10;

      // ── 軸2: conditionScore（条件一致）──────────────────────────────────
      // ジャンル一致
      final double genreScore = (categories == null || categories.isEmpty)
          ? 0.7 // ユーザーが未選択 = ニュートラル
          : categories.contains(r.category)
              ? 1.0
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

      // ── 軸3: qualityScore（品質シグナル）────────────────────────────────
      double qualityScore = 0.0;
      if (r.imageUrl != null && r.imageUrl!.isNotEmpty) { qualityScore += 0.35; } // 写真あり
      if (r.course) { qualityScore += 0.25; }                                     // コースあり
      if (r.rating >= 4.0) { qualityScore += 0.20; }                              // 高評価
      else if (r.rating >= 3.5) { qualityScore += 0.10; }
      if (r.freeDrink) { qualityScore += 0.15; }                                  // 飲み放題
      if (r.freeFood) { qualityScore += 0.05; }                                   // 食べ放題
      qualityScore = qualityScore.clamp(0.0, 1.0);

      // ── 軸4: usabilityScore（利用しやすさ）──────────────────────────────
      double usabilityScore = 0.0;
      if (r.isReservable) usabilityScore += 0.50;       // 予約可 = 最重要
      if (r.hasPrivateRoom) usabilityScore += 0.25;     // 個室あり
      if (r.nonSmoking) usabilityScore += 0.15;         // 禁煙
      if (r.wifi) usabilityScore += 0.05;               // Wi-Fi
      if (r.freeFood) usabilityScore += 0.05;
      usabilityScore = usabilityScore.clamp(0.0, 1.0);

      // ── 総合スコア（ジャンル別 × シーン別 × 人数別重み）─────────────────
      // [accessW, conditionW, qualityW, usabilityW]
      final baseWeights = _genreWeights(r.category);
      final weights = _applySceneParticipantWeights(
        baseWeights,
        occasion,
        active.length,
      );
      final overall = (weights[0] * accessScore +
              weights[1] * conditionScore +
              weights[2] * qualityScore +
              weights[3] * usabilityScore)
          .clamp(0.0, 1.0);

      // ── キュレーションラベル（外さない / おしゃれ / 穴場）────────────────
      final curationLabel = _computeCurationLabel(
        r,
        accessScore: accessScore,
        qualityScore: qualityScore,
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
      );
    }).toList();

    scored.sort((a, b) => b.score.compareTo(a.score));
    return scored;
  }

  /// ジャンル別スコアリング重み [access, condition, quality, usability]
  /// 待ち合わせ用途では集合しやすさ（access）を軸に、ジャンル特性で調整する
  static List<double> _genreWeights(String category) {
    return switch (category) {
      // 居酒屋: 集合しやすさ高め、利用しやすさ（個室・予約）重視
      '居酒屋' => [0.35, 0.25, 0.15, 0.25],
      // カフェ: ジャンル・雰囲気重視、品質シグナル大事
      'カフェ' => [0.25, 0.35, 0.25, 0.15],
      // 焼肉: 予約必須なので利用しやすさ高め
      '焼肉' => [0.25, 0.25, 0.20, 0.30],
      // バー: 雰囲気・シーン重視
      'バー' => [0.20, 0.35, 0.25, 0.20],
      // フレンチ・イタリアン: 品質・シーン重視
      'フレンチ' || 'イタリアン' => [0.20, 0.35, 0.30, 0.15],
      // 和食: バランス型
      '和食' => [0.25, 0.30, 0.25, 0.20],
      // 韓国料理: アクセス重視（グループ利用が多い）
      '韓国料理' => [0.30, 0.30, 0.20, 0.20],
      // デフォルト: 集合アプリの標準重み
      _ => [0.30, 0.35, 0.20, 0.15],
    };
  }

  /// シーン別・人数別の重み補正 [access, condition, quality, usability]
  ///
  /// ジャンル基本重みに乗数を掛けて正規化することで、
  /// ジャンルの特性を維持しながらシーン・人数に応じた傾斜を与える。
  static List<double> _applySceneParticipantWeights(
    List<double> base,
    String? occasion,
    int participantCount,
  ) {
    // [access, condition, quality, usability]
    var m = [1.0, 1.0, 1.0, 1.0];

    // 人数別乗数
    if (participantCount >= 5) {
      // 大人数: 個室・予約しやすさ(usability) を強化
      m[3] *= 1.45;
      m[0] *= 1.10; // 駅近も依然重要
      m[2] *= 0.85;
    } else if (participantCount == 2) {
      // 2人: 品質(雰囲気・写真)とシーン一致を重視
      m[2] *= 1.30;
      m[1] *= 1.20;
      m[0] *= 0.80;
    }
    // 3〜4人はデフォルト乗数(1.0)のまま

    // シーン別乗数
    switch (occasion) {
      case '仕事帰り':
        m[0] *= 1.30; // 駅近必須
        m[3] *= 1.20; // 予約・個室
        m[2] *= 0.75;
      case 'デート':
        m[2] *= 1.40; // 品質・雰囲気
        m[1] *= 1.25; // シーン一致
        m[0] *= 0.70; // 駅近はやや下げ
      case '女子会':
        m[2] *= 1.30; // 品質・写真映え
        m[1] *= 1.20; // シーン一致
        m[3] *= 1.10; // 個室もプラス
      case '歓迎会':
      case '打ち上げ':
        m[3] *= 1.40; // 個室・予約・飲み放題
        m[0] *= 1.10;
        m[2] *= 0.80;
      case '合コン':
        m[2] *= 1.20; // 品質・雰囲気
        m[1] *= 1.30; // シーン一致
        m[3] *= 1.10;
    }

    // 乗数適用
    final adjusted = List.generate(4, (i) => base[i] * m[i]);
    final sum = adjusted.reduce((a, b) => a + b);
    // sum==0 は理論上あり得ないが安全のため基本重みをそのまま返す
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
    required double qualityScore,
    required String? occasion,
    required DateTime? selectedDate,
  }) {
    // ── タイプ判定 ────────────────────────────────────────────────────
    final isHazusanai = accessScore >= 0.65 &&
        r.reviewCount >= 30 &&
        r.isReservable &&
        r.rating >= 3.5;

    final oshareCategories = {'フレンチ', 'イタリアン', 'カフェ', 'バー'};
    final isOshare = (r.imageUrl != null && r.imageUrl!.isNotEmpty) &&
        (r.isFemalePopular ||
            oshareCategories.contains(r.category) ||
            occasion == 'デート' ||
            occasion == '女子会');

    final isAnaba = r.reviewCount >= 10 &&
        r.reviewCount < 80 &&
        r.rating >= 3.5 &&
        r.distanceMinutes >= 4;

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
    switch (occasion) {
      case '女子会':
        double s = switch (r.category) {
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
        if (r.hasPrivateRoom) s = (s + 0.15).clamp(0.0, 1.0);
        if (r.nonSmoking) s = (s + 0.10).clamp(0.0, 1.0);
        if (r.imageUrl != null && r.imageUrl!.isNotEmpty) s = (s + 0.10).clamp(0.0, 1.0);
        if (r.course) s = (s + 0.05).clamp(0.0, 1.0);
        return s;

      case '誕生日':
        double s = switch (r.category) {
          'フレンチ' || 'イタリアン' => 1.0,
          'カフェ' => 0.85,
          '和食' => 0.80,
          '洋食' => 0.70,
          '居酒屋' => 0.35,
          'ラーメン' || '中華' => 0.15,
          _ => 0.55,
        };
        if (r.hasPrivateRoom) s = (s + 0.25).clamp(0.0, 1.0);
        if (r.course) s = (s + 0.15).clamp(0.0, 1.0);
        if (r.imageUrl != null && r.imageUrl!.isNotEmpty) s = (s + 0.10).clamp(0.0, 1.0);
        return s;

      case 'ランチ':
        final isLunch = r.lunchFromApi || r.isLunchAvailable;
        double s = isLunch ? 1.0 : 0.25;
        if (r.category == 'カフェ') s = (s + 0.15).clamp(0.0, 1.0);
        return s;

      case '合コン':
        double s = switch (r.category) {
          'イタリアン' || 'フレンチ' => 1.0,
          'カフェ' => 0.80,
          '韓国料理' => 0.80,
          '和食' => 0.75,
          'バー' => 0.70,
          '居酒屋' => 0.55,
          'ラーメン' || '中華' => 0.20,
          _ => 0.50,
        };
        if (r.hasPrivateRoom) s = (s + 0.20).clamp(0.0, 1.0);
        if (r.nonSmoking) s = (s + 0.10).clamp(0.0, 1.0);
        return s;

      case '歓迎会':
        double s = switch (r.category) {
          '居酒屋' => 1.0,
          '和食' => 0.90,
          '中華' || '洋食' => 0.70,
          '焼肉' => 0.65,
          'カフェ' || 'フレンチ' => 0.20,
          _ => 0.55,
        };
        if (r.hasPrivateRoom) s = (s + 0.20).clamp(0.0, 1.0);
        if (r.course && r.freeDrink) {
          s = (s + 0.25).clamp(0.0, 1.0);
        } else if (r.course || r.freeDrink) {
          s = (s + 0.12).clamp(0.0, 1.0);
        }
        return s;

      case 'デート':
        double s = switch (r.category) {
          'フレンチ' => 1.0,
          'イタリアン' => 0.95,
          'カフェ' => 0.80,
          '和食' => 0.80,
          'バー' => 0.60,
          '居酒屋' => 0.25,
          'ラーメン' || '焼肉' || '中華' => 0.10,
          _ => 0.50,
        };
        if (r.hasPrivateRoom) s = (s + 0.25).clamp(0.0, 1.0);
        if (r.nonSmoking) s = (s + 0.10).clamp(0.0, 1.0);
        if (r.imageUrl != null && r.imageUrl!.isNotEmpty) s = (s + 0.10).clamp(0.0, 1.0);
        return s;

      default:
        return 0.5;
    }
  }

}
