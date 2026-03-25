import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/participant.dart';
import '../models/meeting_point.dart';
import '../models/restaurant.dart';
import '../models/scored_restaurant.dart';
import '../data/station_data.dart';
import '../services/midpoint_service.dart';
import '../services/hotpepper_service.dart';
import '../services/overpass_service.dart';
import '../services/foursquare_service.dart';
import '../config/api_config.dart';
import '../data/restaurant_data.dart';
import '../services/notification_service.dart';
import '../services/analytics_service.dart';
import '../services/restaurant_cache_service.dart';
import '../services/location_service.dart';

enum Occasion {
  none,
  girlsNight,
  birthday,
  lunch,
  mixer,
  welcome,
  date,
}

extension OccasionExt on Occasion {
  String get label => switch (this) {
        Occasion.none => 'なし',
        Occasion.girlsNight => '女子会',
        Occasion.birthday => '誕生日',
        Occasion.lunch => 'ランチ',
        Occasion.mixer => '合コン',
        Occasion.welcome => '歓迎会',
        Occasion.date => 'デート',
      };
  String get emoji => switch (this) {
        Occasion.none => '',
        Occasion.girlsNight => '👑',
        Occasion.birthday => '🎂',
        Occasion.lunch => '🥗',
        Occasion.mixer => '🥂',
        Occasion.welcome => '🎉',
        Occasion.date => '💕',
      };
  bool get filterFemale =>
      this == Occasion.girlsNight || this == Occasion.mixer || this == Occasion.date;
  bool get filterPrivate =>
      this == Occasion.birthday || this == Occasion.girlsNight || this == Occasion.welcome;
  bool get filterLunch => this == Occasion.lunch;
}

enum TimeSlot { all, lunch, cafe, dinner, drinking }

enum SortOption { recommended, distance, rating, budget }

extension SortOptionExt on SortOption {
  String get label => switch (this) {
        SortOption.recommended => 'おすすめ順',
        SortOption.distance => '距離順',
        SortOption.rating => '評価順',
        SortOption.budget => '価格順',
      };
}

extension TimeSlotExt on TimeSlot {
  String get label => switch (this) {
        TimeSlot.all => 'すべて',
        TimeSlot.lunch => 'ランチ',
        TimeSlot.cafe => 'カフェ',
        TimeSlot.dinner => 'ディナー',
        TimeSlot.drinking => '飲み',
      };
  String get shortLabel => switch (this) {
        TimeSlot.all => '時間帯を選択',
        TimeSlot.lunch => 'ランチ（11-14時）',
        TimeSlot.cafe => 'カフェ（14-17時）',
        TimeSlot.dinner => 'ディナー（17-22時）',
        TimeSlot.drinking => '飲み（18-23時）',
      };
  String get chipLabel => switch (this) {
        TimeSlot.all => '今夜 ディナー',
        TimeSlot.lunch => 'ランチ',
        TimeSlot.cafe => 'カフェタイム',
        TimeSlot.dinner => 'ディナー',
        TimeSlot.drinking => '飲み',
      };
}

class SearchState {
  SearchState({
    this.participants = const [],
    this.results = const [],
    this.isCalculating = false,
    this.hasCalculated = false,
    this.selectedMeetingPoint,
    this.restaurantCategories = const {},
    this.showFemaleFriendly = false,
    this.showPrivateRoom = false,
    this.occasion = Occasion.none,
    this.timeSlot = TimeSlot.all,
    this.maxBudget = 0,
    this.centroidLat,
    this.centroidLng,
    this.hotpepperRestaurants = const [],
    this.sortOption = SortOption.recommended,
    this.errorMessage,
    this.restaurantCache = const {},
    this.loadingMessage,
    this.selectedDate,
    this.groupRelation,
    List<ScoredRestaurant>? scoredCache,
    List<ScoredRestaurant>? sortedCache,
  })  : _scoredCache = scoredCache,
        _sortedCache = sortedCache;

  final List<ScoredRestaurant>? _scoredCache;
  final List<ScoredRestaurant>? _sortedCache;

  final List<Participant> participants;
  final List<MeetingPoint> results;
  final bool isCalculating;
  final bool hasCalculated;
  final MeetingPoint? selectedMeetingPoint;
  final Set<String> restaurantCategories;
  final bool showFemaleFriendly;
  final bool showPrivateRoom;
  final Occasion occasion;
  final TimeSlot timeSlot;
  final int maxBudget;
  final double? centroidLat;
  final double? centroidLng;
  final List<Restaurant> hotpepperRestaurants;
  final SortOption sortOption;
  final String? errorMessage;
  final String? loadingMessage;
  final DateTime? selectedDate;
  // キャッシュ: stationIndex → restaurants
  final Map<int, List<Restaurant>> restaurantCache;
  // グループ関係性（おすすめ改善用）
  final String? groupRelation; // 'friends' | 'couple' | 'colleagues' | 'family'

  bool get canCalculate => participants.where((p) => p.hasStation).length >= 2;
  bool get hasCentroid => centroidLat != null && centroidLng != null;

  bool get _effectiveFemale => showFemaleFriendly || occasion.filterFemale;
  bool get _effectivePrivate => showPrivateRoom || occasion.filterPrivate;
  TimeSlot get _effectiveTimeSlot =>
      occasion.filterLunch ? TimeSlot.lunch : timeSlot;

  /// 重心ベースのスコアリング済みレストラン（フィルター適用済み・キャッシュ付き）
  late final List<ScoredRestaurant> scoredRestaurants = _scoredCache ?? _computeScored();

  List<ScoredRestaurant> _computeScored() {
    if (!hasCentroid) return [];

    // APIデータがない場合は計算された集合地点の駅のレストランのみに絞る
    // （全駅一括スコアリングだと遠い駅の高評価店が上位に来てしまうため）
    List<Restaurant>? base;
    if (hotpepperRestaurants.isNotEmpty) {
      base = hotpepperRestaurants;
    } else if (results.isNotEmpty) {
      final stationIndices = results.map((r) => r.stationIndex).toSet();
      base = kRestaurants
          .where((r) => stationIndices.contains(r.stationIndex))
          .toList();
    }

    return MidpointService.scoreRestaurants(
      participants: participants,
      centroidLat: centroidLat!,
      centroidLng: centroidLng!,
      baseRestaurants: base,
      categories: restaurantCategories,
      femaleFriendly: _effectiveFemale,
      hasPrivateRoom: _effectivePrivate,
      timeSlot: _effectiveTimeSlot,
      maxBudget: maxBudget,
      occasion: occasion != Occasion.none ? occasion.label : null,
      groupRelation: groupRelation,
      selectedDate: selectedDate, // 日付指定時は予約可能店舗のみ表示
    );
  }

  /// ソート済みレストラン（表示用・キャッシュ付き）
  late final List<ScoredRestaurant> sortedRestaurants = _sortedCache ?? _computeSorted();

  List<ScoredRestaurant> _computeSorted() {
    final base = scoredRestaurants;
    return switch (sortOption) {
      SortOption.recommended => base,
      SortOption.distance =>
        [...base]..sort((a, b) => a.distanceKm.compareTo(b.distanceKm)),
      SortOption.rating => [...base]
        ..sort((a, b) =>
            b.restaurant.rating.compareTo(a.restaurant.rating)),
      SortOption.budget => [...base]
        ..sort((a, b) =>
            a.restaurant.priceAvg.compareTo(b.restaurant.priceAvg)),
    };
  }

  /// 後方互換：選択中のMeetingPointのレストラン（集合エリアタブ用）
  List<Restaurant> get restaurants {
    if (selectedMeetingPoint == null) return [];
    return MidpointService.getRestaurants(
      stationIndex: selectedMeetingPoint!.stationIndex,
      categories: restaurantCategories,
      femaleFriendly: _effectiveFemale,
      hasPrivateRoom: _effectivePrivate,
      timeSlot: _effectiveTimeSlot,
      maxBudget: maxBudget,
    );
  }

  SearchState copyWith({
    List<Participant>? participants,
    List<MeetingPoint>? results,
    bool? isCalculating,
    bool? hasCalculated,
    MeetingPoint? selectedMeetingPoint,
    Set<String>? restaurantCategories,
    bool? showFemaleFriendly,
    bool? showPrivateRoom,
    Occasion? occasion,
    TimeSlot? timeSlot,
    int? maxBudget,
    double? centroidLat,
    double? centroidLng,
    List<Restaurant>? hotpepperRestaurants,
    SortOption? sortOption,
    String? errorMessage,
    String? loadingMessage,
    Map<int, List<Restaurant>>? restaurantCache,
    bool clearMeetingPoint = false,
    bool clearCategory = false,
    bool clearCentroid = false,
    bool clearError = false,
    bool clearLoadingMessage = false,
    DateTime? selectedDate,
    bool clearDate = false,
    String? groupRelation,
    bool clearGroupRelation = false,
  }) {
    // スコアリング入力が1つも変わっていない場合は計算済みキャッシュを引き継ぐ
    final isScoringUnchanged = participants == null &&
        results == null &&
        hotpepperRestaurants == null &&
        centroidLat == null &&
        centroidLng == null &&
        !clearCentroid &&
        restaurantCategories == null &&
        !clearCategory &&
        showFemaleFriendly == null &&
        showPrivateRoom == null &&
        occasion == null &&
        timeSlot == null &&
        maxBudget == null &&
        groupRelation == null &&
        !clearGroupRelation &&
        selectedDate == null &&
        !clearDate;

    final isSortUnchanged = isScoringUnchanged && sortOption == null;

    return SearchState(
      participants: participants ?? this.participants,
      results: results ?? this.results,
      isCalculating: isCalculating ?? this.isCalculating,
      hasCalculated: hasCalculated ?? this.hasCalculated,
      selectedMeetingPoint:
          clearMeetingPoint ? null : (selectedMeetingPoint ?? this.selectedMeetingPoint),
      restaurantCategories: clearCategory ? const {} : (restaurantCategories ?? this.restaurantCategories),
      showFemaleFriendly: showFemaleFriendly ?? this.showFemaleFriendly,
      showPrivateRoom: showPrivateRoom ?? this.showPrivateRoom,
      occasion: occasion ?? this.occasion,
      timeSlot: timeSlot ?? this.timeSlot,
      maxBudget: maxBudget ?? this.maxBudget,
      centroidLat: clearCentroid ? null : (centroidLat ?? this.centroidLat),
      centroidLng: clearCentroid ? null : (centroidLng ?? this.centroidLng),
      hotpepperRestaurants: hotpepperRestaurants ?? this.hotpepperRestaurants,
      sortOption: sortOption ?? this.sortOption,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      loadingMessage: clearLoadingMessage ? null : (loadingMessage ?? this.loadingMessage),
      restaurantCache: restaurantCache ?? this.restaurantCache,
      selectedDate: clearDate ? null : (selectedDate ?? this.selectedDate),
      groupRelation: clearGroupRelation ? null : (groupRelation ?? this.groupRelation),
      scoredCache: isScoringUnchanged ? scoredRestaurants : null,
      sortedCache: isSortUnchanged ? sortedRestaurants : null,
    );
  }
}

class SearchNotifier extends Notifier<SearchState> {
  @override
  SearchState build() {
    Future.microtask(_autoFillHomeStation);
    return SearchState(
      participants: const [Participant(id: '1', name: '自分')],
    );
  }

  Future<void> _autoFillHomeStation() async {
    final prefs = await SharedPreferences.getInstance();
    final homeIdx = prefs.getInt('home_station');
    if (homeIdx == null || homeIdx >= kStations.length) return;
    if (state.participants.isEmpty) return;
    final first = state.participants.first;
    if (first.stationIndex != null) return; // 既にセット済み
    setStation(first.id, homeIdx, kStations[homeIdx]);
  }

  /// マイページでホーム駅が変更されたとき、自分（先頭参加者）の駅を更新する
  void setHomeStation(int stationIndex) {
    if (stationIndex >= kStations.length) return;
    if (state.participants.isEmpty) return;
    final first = state.participants.first;
    setStation(first.id, stationIndex, kStations[stationIndex]);
  }

  void addParticipant() {
    // IDは現在の最大IDより1大きい値を使用（削除後の重複を防ぐ）
    final maxId = state.participants
        .map((p) => int.tryParse(p.id) ?? 0)
        .fold(0, (a, b) => a > b ? a : b);
    final newId = maxId + 1;
    final names = ['友達A', '友達B', '友達C', '友達D', '友達E'];
    final count = state.participants.length + 1;
    final name = count <= names.length ? names[count - 1] : '参加者$count';
    state = state.copyWith(
      participants: [...state.participants, Participant(id: '$newId', name: name)],
    );
  }

  void removeParticipant(String id) {
    if (state.participants.length <= 1) return;
    state = state.copyWith(
      participants: state.participants.where((p) => p.id != id).toList(),
    );
  }

  void updateParticipantName(String id, String name) {
    state = state.copyWith(
      participants:
          state.participants.map((p) => p.id == id ? p.copyWith(name: name) : p).toList(),
    );
  }

  void setStation(String id, int stationIndex, String stationName) {
    final (lat, lng) = kStationLatLng[stationIndex];
    state = state.copyWith(
      participants: state.participants.map((p) {
        return p.id == id
            ? p.copyWith(
                stationIndex: stationIndex,
                stationName: stationName,
                lat: lat,
                lng: lng,
              )
            : p;
      }).toList(),
      hasCalculated: false,
      clearCentroid: true,
    );
  }

  /// kStations に含まれない駅を名前+座標で設定（全駅検索対応）
  void setStationWithCoords(
      String id, String stationName, double lat, double lng) {
    final idx = _nearestStation(lat, lng);
    state = state.copyWith(
      participants: state.participants.map((p) {
        return p.id == id
            ? p.copyWith(
                stationIndex: idx,
                stationName: stationName,
                lat: lat,
                lng: lng,
              )
            : p;
      }).toList(),
      hasCalculated: false,
      clearCentroid: true,
    );
  }

  /// 地図タップで緯度経度を直接指定（最寄り駅を自動判定）
  void setLocationDirect(String id, double lat, double lng) {
    final idx = _nearestStation(lat, lng);
    state = state.copyWith(
      participants: state.participants.map((p) {
        return p.id == id
            ? p.copyWith(
                stationIndex: idx,
                stationName: kStations[idx],
                lat: lat,
                lng: lng,
              )
            : p;
      }).toList(),
      hasCalculated: false,
      clearCentroid: true,
    );
  }

  int _nearestStation(double lat, double lng) {
    return LocationService.nearestStationIndex(lat, lng);
  }

  void clearStation(String id) {
    state = state.copyWith(
      participants: state.participants.map((p) => p.id == id ? p.clearStation() : p).toList(),
      hasCalculated: false,
    );
  }

  void setOccasion(Occasion o) {
    state = state.copyWith(occasion: o);
  }

  void setGroupRelation(String? relation) {
    state = state.copyWith(
      groupRelation: relation,
      clearGroupRelation: relation == null,
    );
  }

  void setTimeSlot(TimeSlot t) {
    state = state.copyWith(timeSlot: t);
  }

  void setMaxBudget(int budget) {
    state = state.copyWith(maxBudget: budget);
  }

  void setDate(DateTime? date) {
    state = date == null
        ? state.copyWith(clearDate: true)
        : state.copyWith(selectedDate: date);
  }

  Future<void> calculate() async {
    if (!state.canCalculate) return;
    state = state.copyWith(isCalculating: true, clearError: true, loadingMessage: '移動時間を計算中...');

    try {
      final results = MidpointService.calculate(state.participants);
      state = state.copyWith(loadingMessage: 'ちょうどいい場所を探しています...');
      // Uber Eats式: 交通最適駅の座標を集合地点として使用
      final centroid = MidpointService.calcCentroid(state.participants, meetingPoints: results);

      List<Restaurant> hotpepperRestaurants = [];
      if (centroid != null) {
        state = state.copyWith(loadingMessage: 'お店を検索中...');

        // カテゴリが1つだけ選択されていればHotpepperのジャンルコードに変換（サーバーサイド絞り込み）
        final selectedGenre = state.restaurantCategories.length == 1
            ? HotpepperService.categoryToGenreCode(state.restaurantCategories.first)
            : null;

        // Check Firebase cache first（ジャンルコードをキーに含める）
        final cached = await RestaurantCacheService.get(centroid.$1, centroid.$2, genre: selectedGenre);
        if (cached != null && cached.isNotEmpty) {
          hotpepperRestaurants = cached;
        } else {
          // Fire Hotpepper and Foursquare in parallel
          final foursquare = ref.read(foursquareServiceProvider);
          final hotpepperFuture = ApiConfig.hotpepperApiKey.isNotEmpty
              ? HotpepperService.searchNearCentroid(
                  apiKey: ApiConfig.hotpepperApiKey,
                  lat: centroid.$1,
                  lng: centroid.$2,
                  genre: selectedGenre, // ジャンルコードをAPIに渡す
                )
              : Future.value(<Restaurant>[]);
          final foursquareFuture = foursquare.searchNearby(centroid.$1, centroid.$2);

          // Start Overpass in background (slower, only used as last resort)
          final overpassFuture = OverpassService.searchNearby(
            lat: centroid.$1,
            lng: centroid.$2,
          );

          // Wait for the two fast APIs first
          final primaryResults = await Future.wait([hotpepperFuture, foursquareFuture]);
          hotpepperRestaurants = primaryResults[0].isNotEmpty
              ? primaryResults[0]
              : primaryResults[1];

          // Only wait for Overpass if primary APIs returned nothing
          if (hotpepperRestaurants.isEmpty) {
            state = state.copyWith(loadingMessage: 'マップデータから検索中...');
            hotpepperRestaurants = await overpassFuture;
          }

          // Store in Firebase cache for future searches (fire and forget)
          if (hotpepperRestaurants.isNotEmpty) {
            RestaurantCacheService.set(centroid.$1, centroid.$2, hotpepperRestaurants, genre: selectedGenre)
                .ignore();
          }
        }
      }

      // Build cache — already fetched for the centroid/best point
      final cache = <int, List<Restaurant>>{};
      if (results.isNotEmpty) {
        cache[results.first.stationIndex] = hotpepperRestaurants;
      }

      // Pre-fetch for remaining candidates in parallel (2〜5位すべて対象, 8s timeout)
      final remaining = results.skip(1).toList();
      final foursquare = ref.read(foursquareServiceProvider);
      final hasHotpepper = ApiConfig.hotpepperApiKey.isNotEmpty;
      final prefetchFutures = remaining.map((point) async {
        final latLng = kStationLatLng[point.stationIndex];
        List<Restaurant> restaurants = [];
        try {
          if (hasHotpepper) {
            restaurants = await HotpepperService.searchNearCentroid(
              apiKey: ApiConfig.hotpepperApiKey,
              lat: latLng.$1,
              lng: latLng.$2,
            ).timeout(const Duration(seconds: 8));
          }
          if (restaurants.isEmpty) {
            restaurants = await foursquare.searchNearby(
              latLng.$1, latLng.$2, limit: 30,
            ).timeout(const Duration(seconds: 8));
          }
        } catch (e) {
          debugPrint('prefetch: ${point.stationName} failed - ${e.runtimeType}');
        }
        cache[point.stationIndex] = restaurants;
      });
      await Future.wait(prefetchFutures, eagerError: false);
      await NotificationService.recordSearch();

      // Firestoreに検索ログを記録（Aima指数ランキング用）
      if (results.isNotEmpty) {
        final bestStation = results.first;
        unawaited(AnalyticsService.logSearch(
          stationName: bestStation.stationName,
          stationIndex: bestStation.stationIndex,
          participantCount: state.participants.length,
        ));
      }

      state = state.copyWith(
        isCalculating: false,
        hasCalculated: true,
        results: results,
        selectedMeetingPoint: results.isNotEmpty ? results.first : null,
        centroidLat: centroid?.$1,
        centroidLng: centroid?.$2,
        hotpepperRestaurants: hotpepperRestaurants,
        restaurantCache: cache,
        clearCategory: true,
        clearError: true,
        clearLoadingMessage: true,
      );
    } on SocketException catch (e) {
      debugPrint('SearchNotifier: ネットワークエラー - ${e.runtimeType}');
      state = state.copyWith(
        isCalculating: false,
        errorMessage: 'オフラインです。ネット接続を確認してください。',
        clearLoadingMessage: true,
      );
    } on TimeoutException catch (e) {
      debugPrint('SearchNotifier: タイムアウト - ${e.runtimeType}');
      state = state.copyWith(
        isCalculating: false,
        errorMessage: '通信がタイムアウトしました。もう一度お試しください。',
        clearLoadingMessage: true,
      );
    } catch (e) {
      debugPrint('SearchNotifier: calculate failed - ${e.runtimeType}');
      state = state.copyWith(
        isCalculating: false,
        errorMessage: 'エラーが発生しました。もう一度お試しください。',
        clearLoadingMessage: true,
      );
    }
  }

  void selectMeetingPoint(MeetingPoint point) {
    state = state.copyWith(selectedMeetingPoint: point, clearCategory: true);
  }

  Future<void> selectMeetingPointAndFetch(MeetingPoint point) async {
    // Check cache first — instant if cached
    if (state.restaurantCache.containsKey(point.stationIndex)) {
      state = state.copyWith(
        selectedMeetingPoint: point,
        hotpepperRestaurants: state.restaurantCache[point.stationIndex]!,
        clearCategory: true,
      );
      return; // instant, no network call
    }

    // Not cached — fetch with loading indicator
    state = state.copyWith(selectedMeetingPoint: point, clearCategory: true, isCalculating: true);
    try {
      final latLng = kStationLatLng[point.stationIndex];
      List<Restaurant> restaurants = await ref.read(foursquareServiceProvider).searchNearby(
        latLng.$1, latLng.$2,
      );
      if (restaurants.isEmpty) {
        restaurants = await OverpassService.searchNearby(
          lat: latLng.$1, lng: latLng.$2,
        );
      }
      // Add to cache
      final newCache = Map<int, List<Restaurant>>.from(state.restaurantCache);
      newCache[point.stationIndex] = restaurants;
      state = state.copyWith(
        hotpepperRestaurants: restaurants.isNotEmpty ? restaurants : state.hotpepperRestaurants,
        restaurantCache: newCache,
        isCalculating: false,
        clearCategory: true,
      );
    } on SocketException catch (e) {
      debugPrint('SearchNotifier: selectMeetingPointAndFetch ネットワークエラー - ${e.runtimeType}');
      state = state.copyWith(
        isCalculating: false,
        errorMessage: 'オフラインです。ネット接続を確認してください。',
      );
    } on TimeoutException catch (e) {
      debugPrint('SearchNotifier: selectMeetingPointAndFetch タイムアウト - ${e.runtimeType}');
      state = state.copyWith(
        isCalculating: false,
        errorMessage: '通信がタイムアウトしました。もう一度お試しください。',
      );
    } catch (e) {
      debugPrint('SearchNotifier: selectMeetingPointAndFetch failed - ${e.runtimeType}');
      state = state.copyWith(
        isCalculating: false,
        errorMessage: 'エラーが発生しました。もう一度お試しください。',
      );
    }
  }

  void toggleRestaurantCategory(String category) {
    final current = Set<String>.from(state.restaurantCategories);
    if (current.contains(category)) {
      current.remove(category);
    } else {
      current.add(category);
    }
    // カテゴリ変更時はFirebaseキャッシュを無効化するため検索結果もクリア
    state = state.copyWith(
      restaurantCategories: current,
      restaurantCache: const {},
    );
  }

  void setFemaleFriendly(bool value) {
    state = state.copyWith(showFemaleFriendly: value);
  }

  void setPrivateRoom(bool value) {
    state = state.copyWith(showPrivateRoom: value);
  }

  void setSortOption(SortOption option) {
    state = state.copyWith(sortOption: option);
  }

  void startWithOccasion(Occasion o) {
    state = state.copyWith(occasion: o, hasCalculated: false);
  }

  void reset() {
    state = SearchState(
      participants: const [Participant(id: '1', name: '自分')],
    );
  }

  /// 検索履歴から結果を復元する。
  /// 参加者名・集合地点・重心座標を復元し、お店データを再フェッチする。
  Future<void> restoreFromHistoryPoint(
    List<String> participantNames,
    MeetingPoint meetingPoint,
  ) async {
    final (lat, lng) = kStationLatLng[meetingPoint.stationIndex];
    final participants = participantNames.asMap().entries
        .map((e) => Participant(id: '${e.key + 1}', name: e.value))
        .toList();
    state = state.copyWith(
      participants: participants,
      results: [meetingPoint],
      selectedMeetingPoint: meetingPoint,
      hasCalculated: true,
      centroidLat: lat,
      centroidLng: lng,
      hotpepperRestaurants: const [],
    );
    await selectMeetingPointAndFetch(meetingPoint);
  }

  Future<void> setParticipantsFromHistory(
    List<String> names, {
    List<String?> stations = const [],
    List<int?> stationIndices = const [],
  }) async {
    final participants = names.asMap().entries.map((e) =>
      Participant(id: '${e.key + 1}', name: e.value),
    ).toList();
    state = state.copyWith(
      participants: participants,
      hasCalculated: false,
      clearCentroid: true,
    );
    // 保存された駅データを復元
    for (int i = 0; i < participants.length; i++) {
      final kIdx = i < stationIndices.length ? stationIndices[i] : null;
      final sName = i < stations.length ? stations[i] : null;
      if (kIdx != null && kIdx < kStations.length) {
        setStation(participants[i].id, kIdx, kStations[kIdx]);
        continue;
      }
      // kIndex がない場合は駅名から kStations を検索してフォールバック
      if (sName != null) {
        final idx = kStations.indexOf(sName);
        if (idx != -1) setStation(participants[i].id, idx, sName);
      }
    }
    // 自分（先頭参加者）に駅が設定されていない場合はホーム駅を適用
    final prefs = await SharedPreferences.getInstance();
    final homeIdx = prefs.getInt('home_station');
    if (homeIdx == null || homeIdx >= kStations.length) return;
    if (state.participants.isEmpty) return;
    final first = state.participants.first;
    if (first.stationIndex == null) {
      setStation(first.id, homeIdx, kStations[homeIdx]);
    }
  }
}

final searchProvider = NotifierProvider<SearchNotifier, SearchState>(SearchNotifier.new);
