import 'package:flutter/material.dart';
import '../data/station_data.dart';
import '../data/all_stations_data.dart';
import '../providers/favorites_provider.dart';
import '../theme/app_theme.dart';

/// 駅選択の結果
class SelectedStation {
  const SelectedStation({
    required this.name,
    required this.lat,
    required this.lng,
    this.kIndex, // kStations のインデックス（kStationsに含まれる駅の場合のみ）
  });
  final String name;
  final double lat;
  final double lng;
  final int? kIndex;
}

/// 駅を選択するためのボトムシート。
/// [currentIndex] は現在選択中の駅インデックス（ハイライト表示用）。
/// [favorites] はお気に入り駅リスト（上部チップに表示）。
/// ポップ時に [SelectedStation] を返す。
class StationSearchSheet extends StatefulWidget {
  const StationSearchSheet({
    super.key,
    this.currentIndex,
    required this.favorites,
  });

  final int? currentIndex;
  final List<FavoriteStation> favorites;

  @override
  State<StationSearchSheet> createState() => _StationSearchSheetState();
}

class _StationSearchSheetState extends State<StationSearchSheet> {
  String _query = '';

  /// kStations のインデックスマップ（名前 → index）
  static final Map<String, int> _kStationIndex = {
    for (int i = 0; i < kStations.length; i++) kStations[i]: i,
  };

  /// 全駅リスト（重複除去）
  static final List<TokyoStation> _allStations = () {
    final seen = <String>{};
    final result = <TokyoStation>[];
    for (final s in kAllTokyoStations) {
      if (seen.add(s.name)) result.add(s);
    }
    return result;
  }();

  List<TokyoStation> get _filtered {
    if (_query.isEmpty) return _allStations;
    final q = _query.toLowerCase();
    return _allStations.where((s) => s.name.contains(q)).toList();
  }

  SelectedStation _toSelected(TokyoStation s) {
    final idx = _kStationIndex[s.name];
    return SelectedStation(name: s.name, lat: s.lat, lng: s.lng, kIndex: idx);
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;

    return Container(
      height: MediaQuery.of(context).size.height * 0.82 -
          MediaQuery.of(context).viewInsets.bottom,
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 8),
          Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 14),
          const Text(
            '最寄り駅を選択',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              autofocus: false,
              decoration: InputDecoration(
                hintText: '駅名を検索（例: 学芸大学、代官山）',
                prefixIcon: const Icon(Icons.search,
                    color: AppColors.textTertiary, size: 20),
                filled: true,
                fillColor: AppColors.background,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
              ),
              onChanged: (v) => setState(() => _query = v),
            ),
          ),
          // お気に入り駅チップ
          if (widget.favorites.isNotEmpty && _query.isEmpty) ...[
            const SizedBox(height: 10),
            SizedBox(
              height: 36,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: widget.favorites.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (_, i) {
                  final f = widget.favorites[i];
                  return GestureDetector(
                    onTap: () {
                      // kStations の駅なので lat/lng も取得
                      final (lat, lng) = kStationLatLng[f.stationIndex];
                      Navigator.pop(
                        context,
                        SelectedStation(
                          name: f.stationName,
                          lat: lat,
                          lng: lng,
                          kIndex: f.stationIndex,
                        ),
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppColors.primaryLight,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: AppColors.primaryBorder),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.star,
                              size: 12, color: AppColors.primary),
                          const SizedBox(width: 4),
                          Text(
                            f.stationName,
                            style: const TextStyle(
                              color: AppColors.primary,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
          const SizedBox(height: 8),
          const SizedBox(
              height: 1, child: ColoredBox(color: Color(0xFFEEEEEE))),
          // 件数表示
          if (_query.isNotEmpty)
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  '${filtered.length}件',
                  style: TextStyle(
                      fontSize: 12, color: Colors.grey.shade500),
                ),
              ),
            ),
          Expanded(
            child: filtered.isEmpty
                ? Center(
                    child: Text(
                      '「$_query」は見つかりませんでした',
                      style: TextStyle(
                          fontSize: 14, color: Colors.grey.shade500),
                    ),
                  )
                : ListView.separated(
                    itemCount: filtered.length,
                    separatorBuilder: (_, __) => const Padding(
                        padding: EdgeInsets.only(left: 56),
                        child: SizedBox(
                            height: 1,
                            child: ColoredBox(color: Color(0xFFEEEEEE)))),
                    itemBuilder: (_, i) {
                      final station = filtered[i];
                      final kIdx = _kStationIndex[station.name];
                      final isSelected = kIdx != null &&
                          widget.currentIndex == kIdx;
                      return ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 2),
                        leading: Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: isSelected
                                ? AppColors.primary
                                : AppColors.primary
                                    .withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          alignment: Alignment.center,
                          child: Icon(
                            Icons.train_rounded,
                            size: 18,
                            color: isSelected
                                ? Colors.white
                                : AppColors.primary,
                          ),
                        ),
                        title: Text(
                          station.name,
                          style: TextStyle(
                            fontWeight: isSelected
                                ? FontWeight.w700
                                : FontWeight.w500,
                            color: isSelected
                                ? AppColors.primary
                                : AppColors.textPrimary,
                            fontSize: 15,
                          ),
                        ),
                        trailing: isSelected
                            ? const Icon(Icons.check_circle,
                                color: AppColors.primary, size: 20)
                            : null,
                        onTap: () =>
                            Navigator.pop(context, _toSelected(station)),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
