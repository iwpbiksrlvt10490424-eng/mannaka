import 'package:flutter_riverpod/flutter_riverpod.dart';

class FavoriteStation {
  const FavoriteStation({required this.stationIndex, required this.stationName, required this.emoji});
  final int stationIndex;
  final String stationName;
  final String emoji;
}

class FavoritesNotifier extends Notifier<List<FavoriteStation>> {
  @override
  List<FavoriteStation> build() => [];

  void add(FavoriteStation station) {
    if (state.any((s) => s.stationIndex == station.stationIndex)) return;
    state = [station, ...state];
  }

  void remove(int stationIndex) {
    state = state.where((s) => s.stationIndex != stationIndex).toList();
  }

  bool isFavorite(int stationIndex) => state.any((s) => s.stationIndex == stationIndex);

  void toggle(FavoriteStation station) {
    if (isFavorite(station.stationIndex)) {
      remove(station.stationIndex);
    } else {
      add(station);
    }
  }
}

final favoritesProvider =
    NotifierProvider<FavoritesNotifier, List<FavoriteStation>>(FavoritesNotifier.new);
