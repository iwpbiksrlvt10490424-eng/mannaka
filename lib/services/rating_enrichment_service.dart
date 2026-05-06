import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:math';

import 'package:http/http.dart' as http;

import '../models/restaurant.dart';

/// Hotpepper 等で取得した rating=null のお店を Google Places で照合し、
/// 実際の星評価・営業時間を取得して付与する。
///
/// マッチ条件: 距離 50m 以内 + 店名類似度 0.7 以上。
/// マッチしなかった店は rating null のまま（ダミー値禁止ルール）。
///
/// コスト管理: セッション内 in-memory キャッシュで同じ店を 2 回叩かない。
/// Places API (New) Text Search = $0.032/呼び出し。
class RatingEnrichmentService {
  RatingEnrichmentService._();

  static const _endpoint =
      'https://places.googleapis.com/v1/places:searchText';

  /// 必要最低限のフィールドだけ取得して課金を抑える。
  /// photos.name は画像 URL を組み立てるために必要（最大 3 枚）。
  static const _fieldMask =
      'places.id,places.displayName,places.location,places.rating,'
      'places.userRatingCount,places.regularOpeningHours.weekdayDescriptions,'
      'places.regularOpeningHours.openNow,places.photos';

  /// Place Photos の取得最大枚数。1 位ヒーロー & 詳細画面で 5 枚スワイプ表示する想定。
  static const _maxPhotosPerPlace = 5;
  static const _photoMaxHeightPx = 600;

  /// 地球半径（km）。Haversine 公式用。
  static const _earthRadiusKm = 6371.0;

  /// セッション内キャッシュ。キーは Hotpepper の id。
  /// 値は (rating, openHoursText)。null は「マッチしなかった」を意味する。
  static final Map<String, _EnrichResult> _cache = {};

  /// メイン関数。restaurants の rating==null の店を補完する。
  /// 1 回の検索で同じ id の店を再呼び出ししないためにキャッシュを使う。
  ///
  /// 並列化: 全店分の HTTP 呼び出しを Future.wait で同時発行する。
  /// 逐次 await だと N 件 × 500ms ≒ 数秒〜10 秒だが、
  /// 並列なら最遅 1 件分（≒ 1 秒前後）に短縮される。
  static Future<List<Restaurant>> enrich({
    required String apiKey,
    required List<Restaurant> restaurants,
  }) async {
    if (apiKey.isEmpty) {
      developer.log(
        'enrich SKIP: apiKey empty',
        name: 'RatingEnrichmentService',
      );
      return restaurants;
    }

    int callsMade = 0;
    int matched = 0;
    int totalPhotosAdded = 0;
    int alreadyHasRating = 0;
    int noCoords = 0;

    // 各店ごとの非同期処理を Future にまとめる。
    final futures = restaurants.map((r) async {
      if (r.rating != null) {
        alreadyHasRating++;
        return r;
      }
      if (r.lat == null || r.lng == null) {
        noCoords++;
        return r;
      }

      final cached = _cache[r.id];
      if (cached != null) {
        if (cached.rating != null) matched++;
        totalPhotosAdded += cached.photoUrls.length;
        return _apply(r, cached);
      }

      callsMade++;
      final fetched = await _fetchOne(
        apiKey: apiKey,
        name: r.name,
        lat: r.lat!,
        lng: r.lng!,
      );
      _cache[r.id] = fetched;
      if (fetched.rating != null) matched++;
      totalPhotosAdded += fetched.photoUrls.length;
      return _apply(r, fetched);
    }).toList();

    final result = await Future.wait(futures);

    developer.log(
      'enrich done: total=${restaurants.length}, alreadyHasRating=$alreadyHasRating, noCoords=$noCoords, apiCalls=$callsMade, matched=$matched, photosAdded=$totalPhotosAdded',
      name: 'RatingEnrichmentService',
    );

    return result;
  }

  static Restaurant _apply(Restaurant r, _EnrichResult enriched) {
    // rating も photos も無いマッチ失敗ケースは元のまま返す
    if (enriched.rating == null && enriched.photoUrls.isEmpty) return r;
    // 既存写真（Hotpepper の 1 枚）と Google Places の写真をマージ。重複は除く。
    final mergedPhotos = <String>[
      ...r.imageUrls,
      ...enriched.photoUrls.where((u) => !r.imageUrls.contains(u)),
    ];
    return Restaurant(
      id: r.id,
      name: r.name,
      stationIndex: r.stationIndex,
      category: r.category,
      rating: enriched.rating,
      reviewCount: enriched.reviewCount ?? r.reviewCount,
      priceLabel: r.priceLabel,
      priceAvg: r.priceAvg,
      tags: r.tags,
      emoji: r.emoji,
      description: r.description,
      distanceMinutes: r.distanceMinutes,
      address: r.address,
      // openHours が空のときだけ Google から取った文字列で上書き
      openHours: r.openHours.isEmpty
          ? (enriched.openHoursText ?? '')
          : r.openHours,
      isReservable: r.isReservable,
      isFemalePopular: r.isFemalePopular,
      hasPrivateRoom: r.hasPrivateRoom,
      occasionTags: r.occasionTags,
      lat: r.lat,
      lng: r.lng,
      hotpepperUrl: r.hotpepperUrl,
      // imageUrl はサムネイル用の単一画像。Hotpepper のものを優先しつつ
      // 無ければ Google の最初の画像を採用。
      imageUrl: r.imageUrl ??
          (mergedPhotos.isNotEmpty ? mergedPhotos.first : null),
      imageUrls: mergedPhotos,
      accessInfo: r.accessInfo,
      stationName: r.stationName,
      closeDay: r.closeDay,
      nonSmoking: r.nonSmoking,
      freeDrink: r.freeDrink,
      freeFood: r.freeFood,
      lunchFromApi: r.lunchFromApi,
      wifi: r.wifi,
      course: r.course,
      sourceApi: r.sourceApi,
      confidenceLevel: r.confidenceLevel,
      secondaryGenres: r.secondaryGenres,
      blockedGenres: r.blockedGenres,
      ratingConfidence: 'known', // 実評価で上書きしたので known
      reviewConfidence: enriched.reviewCount != null ? 'known' : r.reviewConfidence,
      planInfoConfidence: r.planInfoConfidence,
    );
  }

  static Future<_EnrichResult> _fetchOne({
    required String apiKey,
    required String name,
    required double lat,
    required double lng,
  }) async {
    // 長すぎるクエリは API の 4xx 原因になりうるので 60 文字で切る。
    final safeName = name.length > 60 ? name.substring(0, 60) : name;
    final body = jsonEncode({
      'textQuery': safeName,
      'maxResultCount': 3,
      'languageCode': 'ja',
      'locationBias': {
        'circle': {
          'center': {'latitude': lat, 'longitude': lng},
          // 検索バイアス用の半径。実マッチ判定は 50m 以内で別途絞る。
          'radius': 200.0,
        },
      },
    });
    try {
      final res = await http
          .post(
            Uri.parse(_endpoint),
            headers: {
              'Content-Type': 'application/json',
              'X-Goog-Api-Key': apiKey,
              'X-Goog-FieldMask': _fieldMask,
            },
            body: body,
          )
          .timeout(const Duration(seconds: 8));

      if (res.statusCode != 200) {
        developer.log(
          'fetch HTTP ${res.statusCode} for "$name": ${res.body.substring(0, res.body.length > 200 ? 200 : res.body.length)}',
          name: 'RatingEnrichmentService',
        );
        return const _EnrichResult.empty();
      }
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      final places = (data['places'] as List?) ?? const [];
      if (places.isEmpty) return const _EnrichResult.empty();

      developer.log(
        'fetch "$name" returned ${places.length} candidates',
        name: 'RatingEnrichmentService',
      );

      // 候補から最良マッチを 1 件選ぶ
      _EnrichResult? best;
      double bestScore = -1;
      for (final p in places) {
        final m = p as Map<String, dynamic>;
        final loc = m['location'] as Map<String, dynamic>?;
        if (loc == null) continue;
        final pLat = (loc['latitude'] as num?)?.toDouble();
        final pLng = (loc['longitude'] as num?)?.toDouble();
        if (pLat == null || pLng == null) continue;
        final distKm = _haversineKm(lat, lng, pLat, pLng);
        final placeName =
            (m['displayName'] as Map?)?['text']?.toString() ?? '';

        // Hotpepper と Google の lat/lng は駅構内で 200-300m ずれることが多い
        // （Hotpepper はビル代表点、Google はテナント所在地）。
        // 300m を超えるものはマッチさせない。誤マッチはブランド頭一致で吸収。
        if (distKm > 0.30) {
          developer.log(
            '  reject "$placeName": dist=${(distKm * 1000).toStringAsFixed(0)}m too far',
            name: 'RatingEnrichmentService',
          );
          continue;
        }

        final sim = _nameSimilarity(name, placeName);
        if (sim < 0.7) {
          developer.log(
            '  reject "$placeName": sim=${sim.toStringAsFixed(2)} too low',
            name: 'RatingEnrichmentService',
          );
          continue;
        }
        developer.log(
          '  accept "$placeName": dist=${(distKm * 1000).toStringAsFixed(0)}m sim=${sim.toStringAsFixed(2)}',
          name: 'RatingEnrichmentService',
        );

        // スコア = 名前類似度 - 距離ペナルティ（同類似度なら近い方を採用）
        // 距離 0-200m の範囲で 0〜0.4 のペナルティ。距離係数 2.0/km。
        final score = sim - (distKm * 2.0);
        if (score <= bestScore) continue;
        bestScore = score;
        best = _EnrichResult(
          rating: (m['rating'] as num?)?.toDouble(),
          reviewCount: (m['userRatingCount'] as num?)?.toInt(),
          openHoursText: _formatOpeningHours(m['regularOpeningHours']),
          photoUrls: _extractPhotoUrls(m['photos'], apiKey),
        );
      }
      return best ?? const _EnrichResult.empty();
    } catch (e) {
      developer.log(
        'rating_enrichment failed for "$name": ${e.runtimeType}',
        name: 'RatingEnrichmentService',
      );
      return const _EnrichResult.empty();
    }
  }

  /// Place Photos の `name`（"places/.../photos/..."）を実 URL に変換。
  /// 最大 _maxPhotosPerPlace 枚まで。Google Places Photos API の v1 形式。
  static List<String> _extractPhotoUrls(dynamic photosRaw, String apiKey) {
    if (photosRaw is! List) return const [];
    final urls = <String>[];
    for (final p in photosRaw) {
      if (urls.length >= _maxPhotosPerPlace) break;
      if (p is! Map) continue;
      final pname = p['name']?.toString();
      if (pname == null || pname.isEmpty) continue;
      // Place Photos v1 エンドポイント。skipHttpRedirect=true で URL を文字列で受け取る方式もあるが、
      // CachedNetworkImage はリダイレクトを追えるので直接組み立てた URL でよい。
      final url =
          'https://places.googleapis.com/v1/$pname/media?maxHeightPx=$_photoMaxHeightPx&key=$apiKey';
      urls.add(url);
    }
    return urls;
  }

  static String? _formatOpeningHours(dynamic raw) {
    if (raw is! Map) return null;
    final descs = raw['weekdayDescriptions'] as List?;
    if (descs == null || descs.isEmpty) return null;
    return descs.map((e) => e.toString()).join(' / ');
  }

  /// Haversine 公式で 2 点間の距離（km）を返す。
  /// 学術名の説明: 緯度経度から地球の球面上の最短距離を計算する標準手法。
  static double _haversineKm(
      double lat1, double lng1, double lat2, double lng2) {
    final dLat = _radians(lat2 - lat1);
    final dLng = _radians(lng2 - lng1);
    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_radians(lat1)) *
            cos(_radians(lat2)) *
            sin(dLng / 2) *
            sin(dLng / 2);
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return _earthRadiusKm * c;
  }

  static double _radians(double deg) => deg * pi / 180.0;

  /// 店名類似度（0.0〜1.0）。日本語の長い正式名称に対応する 3 段階判定。
  ///
  /// - 段階 1: 正規化後に**完全一致** → 1.0
  /// - 段階 2: 短い側の**先頭ブランド頭（4 文字以上）が長い側に含まれる** → 0.95
  ///   例: Hotpepper「スターバックス 東京駅丸の内南口店」と
  ///       Google「スターバックス コーヒー 東京駅八重洲北口...」は
  ///       「スターバックス」が両方に含まれるのでマッチ判定
  /// - 段階 3: bigram Jaccard 係数（fallback）
  ///   ブランド頭で照合できないケース（短い片仮名店名等）の保険
  static double _nameSimilarity(String a, String b) {
    if (a.isEmpty || b.isEmpty) return 0;
    final na = _normalize(a);
    final nb = _normalize(b);
    if (na == nb) return 1.0;

    final short = na.length <= nb.length ? na : nb;
    final long = na.length <= nb.length ? nb : na;
    final head = _extractHead(short);
    if (head.length >= 4 && long.contains(head)) {
      return 0.95;
    }

    final ga = _bigrams(na);
    final gb = _bigrams(nb);
    if (ga.isEmpty || gb.isEmpty) return 0;
    final inter = ga.intersection(gb).length;
    final union = ga.union(gb).length;
    return inter / union;
  }

  /// 正規化済み店名の先頭ブランド部分を抽出（最大 6 文字）。
  /// 多くの日本語チェーン店ブランド（スターバックス・モスバーガー等）はこの範囲に収まる。
  static String _extractHead(String normalized) {
    if (normalized.length <= 6) return normalized;
    return normalized.substring(0, 6);
  }

  static String _normalize(String s) {
    return s
        .replaceAll(RegExp(r'\s'), '')
        .replaceAll(RegExp(r'[（）()【】]'), '')
        .toLowerCase();
  }

  static Set<String> _bigrams(String s) {
    if (s.length < 2) return {s};
    final res = <String>{};
    for (var i = 0; i < s.length - 1; i++) {
      res.add(s.substring(i, i + 2));
    }
    return res;
  }
}

class _EnrichResult {
  const _EnrichResult({
    this.rating,
    this.reviewCount,
    this.openHoursText,
    this.photoUrls = const [],
  });
  const _EnrichResult.empty()
      : rating = null,
        reviewCount = null,
        openHoursText = null,
        photoUrls = const [];
  final double? rating;
  final int? reviewCount;
  final String? openHoursText;
  final List<String> photoUrls;
}
