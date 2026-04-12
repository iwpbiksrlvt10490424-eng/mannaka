import 'dart:async';
import 'package:flutter/material.dart';
import '../data/station_data.dart';
import '../data/all_stations_data.dart';
import '../data/station_furigana.dart';
import '../providers/favorites_provider.dart';
import '../services/station_search_service.dart';
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
  List<StationCandidate> _apiResults = [];
  bool _isSearching = false;
  Timer? _debounce;

  // kStations の名前 → インデックスマップ
  static final Map<String, int> _kStationIndex = {
    for (int i = 0; i < kStations.length; i++) kStations[i]: i,
  };

  // ローカル全駅リスト（重複除去済み）
  static final List<TokyoStation> _allLocalStations = () {
    final seen = <String>{};
    final result = <TokyoStation>[];
    for (final s in kAllTokyoStations) {
      if (seen.add(s.name)) result.add(s);
    }
    return result;
  }();

  // ローカル即時フィルタ（前方一致 → 中間一致の順でスコアリング、ふりがな対応）
  List<TokyoStation> get _localFiltered {
    if (_query.isEmpty) return _allLocalStations;
    final q = _query;
    // スコア: 1=名前前方一致, 2=ふりがな前方一致, 3=名前中間一致, 4=ふりがな中間一致
    final buckets = [<TokyoStation>[], <TokyoStation>[], <TokyoStation>[], <TokyoStation>[]];
    for (final s in _allLocalStations) {
      final furigana = kStationFurigana[s.name] ?? '';
      if (s.name.startsWith(q)) {
        buckets[0].add(s);
      } else if (furigana.startsWith(q)) {
        buckets[1].add(s);
      } else if (s.name.contains(q)) {
        buckets[2].add(s);
      } else if (furigana.contains(q)) {
        buckets[3].add(s);
      }
    }
    return [...buckets[0], ...buckets[1], ...buckets[2], ...buckets[3]];
  }

  void _onQueryChanged(String value) {
    setState(() {
      _query = value;
      _apiResults = [];
    });
    _debounce?.cancel();
    if (value.trim().isEmpty) {
      setState(() => _isSearching = false);
      return;
    }
    setState(() => _isSearching = true);
    _debounce = Timer(const Duration(milliseconds: 400), () async {
      final results = await StationSearchService.search(value.trim());
      if (!mounted) return;
      setState(() {
        _apiResults = results;
        _isSearching = false;
      });
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  // ローカル + API の統合リスト（ローカル優先、API で補完）
  List<_StationItem> get _mergedResults {
    final localFiltered = _localFiltered;
    final localNames = {for (final s in localFiltered) s.name};

    // API結果のうちローカルにない駅を追加
    final apiOnly = _apiResults.where((c) => !localNames.contains(c.name));

    final items = <_StationItem>[
      for (final s in localFiltered)
        _StationItem.fromLocal(s, _kStationIndex[s.name]),
      for (final c in apiOnly)
        _StationItem.fromApi(c),
    ];
    return items;
  }

  void _select(_StationItem item) {
    // kIndex が確定している場合はそのまま、API経由は kIndex 解決済み
    Navigator.pop(
      context,
      SelectedStation(
        name: item.name,
        lat: item.lat,
        lng: item.lng,
        kIndex: item.kIndex,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final merged = _mergedResults;
    final hasQuery = _query.isNotEmpty;

    return Container(
      height: MediaQuery.of(context).size.height * 0.70,
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
              autofocus: true,
              decoration: InputDecoration(
                hintText: '駅名を入力（例: 代官山、学芸大学、吉祥寺）',
                prefixIcon: const Icon(Icons.search,
                    color: AppColors.textTertiary, size: 20),
                suffixIcon: _isSearching
                    ? const Padding(
                        padding: EdgeInsets.all(12),
                        child: SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.primary,
                          ),
                        ),
                      )
                    : null,
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
              onChanged: _onQueryChanged,
            ),
          ),

          // お気に入り駅チップ（検索していないときのみ）
          if (widget.favorites.isNotEmpty && !hasQuery) ...[
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

          // 件数 / ステータス表示
          if (hasQuery)
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: Row(
                children: [
                  Text(
                    merged.isEmpty && !_isSearching
                        ? '「$_query」は見つかりませんでした'
                        : '${merged.length}件',
                    style: TextStyle(
                        fontSize: 12, color: Colors.grey.shade500),
                  ),
                ],
              ),
            ),

          Expanded(
            child: merged.isEmpty && !_isSearching && hasQuery
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.train_outlined,
                            size: 40, color: Colors.grey.shade300),
                        const SizedBox(height: 8),
                        Text(
                          '「$_query」は見つかりませんでした',
                          style: TextStyle(
                              fontSize: 14, color: Colors.grey.shade500),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '別の読み方や漢字で試してみてください',
                          style: TextStyle(
                              fontSize: 12, color: Colors.grey.shade400),
                        ),
                      ],
                    ),
                  )
                : ListView.separated(
                    itemCount: merged.length,
                    separatorBuilder: (_, __) => const Padding(
                      padding: EdgeInsets.only(left: 56),
                      child: SizedBox(
                          height: 1,
                          child: ColoredBox(color: Color(0xFFEEEEEE))),
                    ),
                    itemBuilder: (_, i) {
                      final item = merged[i];
                      final isSelected = item.kIndex != null &&
                          widget.currentIndex == item.kIndex;
                      return ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 2),
                        leading: Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: isSelected
                                ? AppColors.primary
                                : AppColors.primary.withValues(alpha: 0.08),
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
                          item.name,
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
                        subtitle: item.line.isNotEmpty
                            ? Text(
                                item.line,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey.shade500,
                                ),
                              )
                            : null,
                        trailing: isSelected
                            ? const Icon(Icons.check_circle,
                                color: AppColors.primary, size: 20)
                            : null,
                        onTap: () => _select(item),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

// ─── 内部DTO ─────────────────────────────────────────────────────────────────

class _StationItem {
  const _StationItem({
    required this.name,
    required this.lat,
    required this.lng,
    required this.line,
    required this.kIndex,
  });

  factory _StationItem.fromLocal(TokyoStation s, int? kIdx) {
    return _StationItem(
      name: s.name,
      lat: s.lat,
      lng: s.lng,
      line: '',
      kIndex: kIdx,
    );
  }

  factory _StationItem.fromApi(StationCandidate c) {
    // kIndexは最近傍解決済みだが、駅名がkStationsと一致しない場合は
    // ピン座標に別の駅の座標が使われてしまうのでnullにする
    final isRealMatch = c.kIndex < kStations.length && kStations[c.kIndex] == c.name;
    return _StationItem(
      name: c.name,
      lat: c.lat,
      lng: c.lng,
      line: c.line,
      kIndex: isRealMatch ? c.kIndex : null,
    );
  }

  final String name;
  final double lat;
  final double lng;
  final String line; // 路線名（API由来のみ非空）
  final int? kIndex;
}
