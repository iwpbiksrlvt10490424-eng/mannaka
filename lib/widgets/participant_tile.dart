import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/participant.dart';
import '../data/station_data.dart';
import '../providers/favorites_provider.dart';
import '../theme/app_theme.dart';

class ParticipantTile extends ConsumerStatefulWidget {
  const ParticipantTile({
    super.key,
    required this.participant,
    required this.index,
    required this.onNameChanged,
    required this.onStationSelected,
    required this.onStationCleared,
    required this.onRemove,
    this.canRemove = true,
  });

  final Participant participant;
  final int index;
  final void Function(String name) onNameChanged;
  final void Function(int stationIndex, String stationName) onStationSelected;
  final VoidCallback onStationCleared;
  final VoidCallback onRemove;
  final bool canRemove;

  @override
  ConsumerState<ParticipantTile> createState() => _ParticipantTileState();
}

class _ParticipantTileState extends ConsumerState<ParticipantTile> {
  late final TextEditingController _nameCtrl;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.participant.name);
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  void _pickStation() async {
    HapticFeedback.lightImpact();
    final favorites = ref.read(favoritesProvider);
    final result = await showModalBottomSheet<int>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => _StationPickerSheet(
        currentIndex: widget.participant.stationIndex,
        favorites: favorites,
      ),
    );
    if (result != null) {
      widget.onStationSelected(result, kStations[result]);
      // お気に入りに追加
      ref.read(favoritesProvider.notifier).add(FavoriteStation(
            stationIndex: result,
            stationName: kStations[result],
            emoji: kStationEmojis[result],
          ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final avatarColors = [
      AppColors.primary,
      AppColors.secondary,
      const Color(0xFF3B82F6),
      const Color(0xFF10B981),
      const Color(0xFFF59E0B),
      const Color(0xFF8B5CF6),
    ];
    final color = avatarColors[widget.index % avatarColors.length];

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            CircleAvatar(
              radius: 20,
              backgroundColor: color.withValues(alpha: 0.15),
              child: Text(
                widget.participant.name.isNotEmpty
                    ? widget.participant.name[0]
                    : '?',
                style: TextStyle(
                    color: color, fontWeight: FontWeight.w700, fontSize: 16),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: _nameCtrl,
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 15),
                    decoration: const InputDecoration(
                      isDense: true,
                      contentPadding: EdgeInsets.zero,
                      border: InputBorder.none,
                      hintText: '名前を入力',
                    ),
                    onChanged: widget.onNameChanged,
                  ),
                  const SizedBox(height: 6),
                  GestureDetector(
                    onTap: _pickStation,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: widget.participant.hasStation
                            ? color.withValues(alpha: 0.1)
                            : Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.train_rounded,
                            size: 14,
                            color: widget.participant.hasStation
                                ? color
                                : Colors.grey,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            widget.participant.hasStation
                                ? widget.participant.stationName!
                                : '最寄り駅を選択',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: widget.participant.hasStation
                                  ? color
                                  : Colors.grey.shade500,
                            ),
                          ),
                          if (widget.participant.hasStation) ...[
                            const SizedBox(width: 4),
                            GestureDetector(
                              onTap: widget.onStationCleared,
                              child: Icon(Icons.close_rounded,
                                  size: 14, color: color),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (widget.canRemove)
              GestureDetector(
                onTap: () {
                  HapticFeedback.lightImpact();
                  widget.onRemove();
                },
                child: Container(
                  padding: const EdgeInsets.all(6),
                  child: Icon(Icons.remove_circle_outline_rounded,
                      color: Colors.grey.shade400, size: 22),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ─── Station Picker ───────────────────────────────────────────────────────────

class _StationPickerSheet extends StatefulWidget {
  const _StationPickerSheet({this.currentIndex, required this.favorites});
  final int? currentIndex;
  final List<FavoriteStation> favorites;

  @override
  State<_StationPickerSheet> createState() => _StationPickerSheetState();
}

class _StationPickerSheetState extends State<_StationPickerSheet> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final filtered = List.generate(kStations.length, (i) => i)
        .where((i) => kStations[i].contains(_query))
        .toList();

    return Container(
      height: MediaQuery.of(context).size.height * 0.8,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
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
          const SizedBox(height: 16),
          const Text('最寄り駅を選択',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              autofocus: true,
              decoration: InputDecoration(
                hintText: '駅名で検索',
                prefixIcon: const Icon(Icons.search_rounded),
                filled: true,
                fillColor: Colors.grey.shade100,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
              onChanged: (v) => setState(() => _query = v),
            ),
          ),
          // お気に入り駅
          if (widget.favorites.isNotEmpty && _query.isEmpty) ...[
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.only(left: 16, bottom: 6),
              child: Row(
                children: [
                  Icon(Icons.star_rounded,
                      size: 14, color: Colors.amber.shade400),
                  const SizedBox(width: 4),
                  Text('よく使う駅',
                      style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade500,
                          fontWeight: FontWeight.w600)),
                ],
              ),
            ),
            SizedBox(
              height: 44,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: widget.favorites.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (ctx, i) {
                  final fav = widget.favorites[i];
                  return GestureDetector(
                    onTap: () => Navigator.of(ctx).pop(fav.stationIndex),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        gradient: AppColors.primaryGradient,
                        borderRadius: BorderRadius.circular(22),
                      ),
                      child: Row(
                        children: [
                          Text(fav.emoji,
                              style: const TextStyle(fontSize: 14)),
                          const SizedBox(width: 4),
                          Text(fav.stationName,
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13)),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            const Divider(height: 16),
          ] else
            const SizedBox(height: 8),
          Expanded(
            child: ListView.builder(
              itemCount: filtered.length,
              itemBuilder: (ctx, i) {
                final idx = filtered[i];
                final selected = widget.currentIndex == idx;
                return ListTile(
                  leading: Text(kStationEmojis[idx],
                      style: const TextStyle(fontSize: 22)),
                  title: Text(
                    kStations[idx],
                    style: TextStyle(
                      fontWeight:
                          selected ? FontWeight.w700 : FontWeight.w500,
                      color: selected ? AppColors.primary : null,
                    ),
                  ),
                  trailing: selected
                      ? Icon(Icons.check_rounded, color: AppColors.primary)
                      : null,
                  onTap: () => Navigator.of(ctx).pop(idx),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
