import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../data/station_data.dart';

class FavoriteStation {
  const FavoriteStation({
    required this.stationIndex,
    required this.stationName,
    required this.emoji,
  });
  final int stationIndex;
  final String stationName;
  final String emoji;
}

class FavoritesNotifier extends Notifier<List<FavoriteStation>> {
  static const _key = 'favorite_stations';

  @override
  List<FavoriteStation> build() {
    _load();
    return [];
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final indices = prefs.getStringList(_key) ?? [];
    final loaded = indices
        .map(int.tryParse)
        .whereType<int>()
        .where((i) => i >= 0 && i < kStations.length)
        .map((i) => FavoriteStation(
              stationIndex: i,
              stationName: kStations[i],
              emoji: kStationEmojis[i],
            ))
        .toList();
    state = loaded;
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _key,
      state.map((s) => s.stationIndex.toString()).toList(),
    );
  }

  void add(FavoriteStation station) {
    if (state.length >= 3) return;
    if (state.any((s) => s.stationIndex == station.stationIndex)) return;
    state = [station, ...state];
    _save();
  }

  void remove(int stationIndex) {
    state = state.where((s) => s.stationIndex != stationIndex).toList();
    _save();
  }

  bool isFavorite(int stationIndex) =>
      state.any((s) => s.stationIndex == stationIndex);

  void toggle(FavoriteStation station) {
    if (isFavorite(station.stationIndex)) {
      remove(station.stationIndex);
    } else {
      add(station);
    }
  }
}

final favoritesProvider =
    NotifierProvider<FavoritesNotifier, List<FavoriteStation>>(
        FavoritesNotifier.new);
