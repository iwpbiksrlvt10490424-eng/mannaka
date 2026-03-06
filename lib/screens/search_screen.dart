import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/search_provider.dart';
import '../data/station_data.dart';
import '../providers/favorites_provider.dart';
import '../theme/app_theme.dart';
import 'results_screen.dart';

class SearchScreen extends ConsumerWidget {
  const SearchScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(searchProvider);
    final notifier = ref.read(searchProvider.notifier);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          '集合場所を探す',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 20),
        ),
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 0,
        actions: [
          TextButton.icon(
            onPressed: () {
              HapticFeedback.lightImpact();
              notifier.reset();
            },
            icon: const Icon(Icons.refresh_rounded, size: 16),
            label: const Text('リセット'),
            style: TextButton.styleFrom(
              foregroundColor: Colors.grey.shade500,
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              children: [
                // ─── STEP 1: 参加者 ───────────────────────────
                _SectionHeader(
                  step: '1',
                  title: '参加者と最寄り駅',
                  trailing: state.participants.length < 6
                      ? GestureDetector(
                          onTap: () {
                            HapticFeedback.lightImpact();
                            notifier.addParticipant();
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.add_rounded,
                                    color: AppColors.primary, size: 16),
                                const SizedBox(width: 4),
                                Text(
                                  '追加',
                                  style: TextStyle(
                                    color: AppColors.primary,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                      : null,
                ),
                const SizedBox(height: 10),
                Container(
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
                  child: Column(
                    children: state.participants.asMap().entries.map((e) {
                      final i = e.key;
                      final p = e.value;
                      final isLast = i == state.participants.length - 1;
                      return _ParticipantRow(
                        key: ValueKey(p.id),
                        participant: p,
                        index: i,
                        showDivider: !isLast,
                        canRemove: state.participants.length > 1,
                        onNameChanged: (name) =>
                            notifier.updateParticipantName(p.id, name),
                        onStationTap: () =>
                            _pickStation(context, ref, p.id),
                        onStationClear: () => notifier.clearStation(p.id),
                        onRemove: () => notifier.removeParticipant(p.id),
                      );
                    }).toList(),
                  ),
                ),

                // ─── STEP 2: 目的（任意） ──────────────────────
                const SizedBox(height: 20),
                const _SectionHeader(step: '2', title: '目的（任意）'),
                const SizedBox(height: 10),
                _OccasionPicker(
                  selected: state.occasion,
                  onSelect: notifier.setOccasion,
                ),

                // ─── STEP 3: 時間帯（任意） ────────────────────
                const SizedBox(height: 20),
                const _SectionHeader(step: '3', title: '時間帯（任意）'),
                const SizedBox(height: 10),
                _TimeSlotPicker(
                  selected: state.timeSlot,
                  onSelect: notifier.setTimeSlot,
                ),

                const SizedBox(height: 100),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: _SearchButton(
        state: state,
        onSearch: () async {
          HapticFeedback.mediumImpact();
          await notifier.calculate();
          if (context.mounted) {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const ResultsScreen()),
            );
          }
        },
      ),
    );
  }

  void _pickStation(BuildContext context, WidgetRef ref, String participantId) async {
    HapticFeedback.lightImpact();
    final favorites = ref.read(favoritesProvider);
    final currentStation = ref
        .read(searchProvider)
        .participants
        .firstWhere((p) => p.id == participantId)
        .stationIndex;

    final result = await showModalBottomSheet<int>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _StationSheet(
        currentIndex: currentStation,
        favorites: favorites,
      ),
    );

    if (result != null) {
      ref
          .read(searchProvider.notifier)
          .setStation(participantId, result, kStations[result]);
      ref.read(favoritesProvider.notifier).add(FavoriteStation(
            stationIndex: result,
            stationName: kStations[result],
            emoji: kStationEmojis[result],
          ));
    }
  }
}

// ─── 検索ボタン ───────────────────────────────────────────────────────────────

class _SearchButton extends StatelessWidget {
  const _SearchButton({required this.state, required this.onSearch});
  final SearchState state;
  final VoidCallback onSearch;

  @override
  Widget build(BuildContext context) {
    final canSearch = state.canCalculate && !state.isCalculating;
    return Container(
      padding: EdgeInsets.fromLTRB(
          16, 12, 16, MediaQuery.of(context).padding.bottom + 12),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!state.canCalculate)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                '2人以上の駅を設定してください',
                style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
              ),
            ),
          SizedBox(
            width: double.infinity,
            height: 54,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: canSearch ? AppColors.primaryGradient : null,
                color: canSearch ? null : Colors.grey.shade200,
                borderRadius: BorderRadius.circular(14),
                boxShadow: canSearch
                    ? [
                        BoxShadow(
                          color: AppColors.primary.withValues(alpha: 0.35),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ]
                    : null,
              ),
              child: TextButton(
                onPressed: canSearch ? onSearch : null,
                style: TextButton.styleFrom(
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                child: state.isCalculating
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2.5),
                      )
                    : Text(
                        state.occasion != Occasion.none
                            ? '${state.occasion.emoji} ${state.occasion.label}の集合場所を探す'
                            : '最適な集合場所を探す',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: canSearch ? Colors.white : Colors.grey.shade400,
                        ),
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── セクションヘッダー ────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.step, required this.title, this.trailing});
  final String step;
  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 24,
          height: 24,
          decoration: const BoxDecoration(
            gradient: AppColors.primaryGradient,
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: Text(
            step,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
        ),
        if (trailing != null) ...[
          const Spacer(),
          trailing!,
        ],
      ],
    );
  }
}

// ─── 参加者行 ─────────────────────────────────────────────────────────────────

class _ParticipantRow extends StatefulWidget {
  const _ParticipantRow({
    super.key,
    required this.participant,
    required this.index,
    required this.showDivider,
    required this.canRemove,
    required this.onNameChanged,
    required this.onStationTap,
    required this.onStationClear,
    required this.onRemove,
  });

  final dynamic participant;
  final int index;
  final bool showDivider;
  final bool canRemove;
  final void Function(String) onNameChanged;
  final VoidCallback onStationTap;
  final VoidCallback onStationClear;
  final VoidCallback onRemove;

  @override
  State<_ParticipantRow> createState() => _ParticipantRowState();
}

class _ParticipantRowState extends State<_ParticipantRow> {
  late final TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.participant.name as String);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = [
      AppColors.primary, AppColors.secondary,
      const Color(0xFF3B82F6), const Color(0xFF10B981),
      const Color(0xFFF59E0B), const Color(0xFF8B5CF6),
    ];
    final color = colors[widget.index % colors.length];
    final p = widget.participant;
    final hasStation = p.stationIndex != null;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              // アバター
              CircleAvatar(
                radius: 18,
                backgroundColor: color.withValues(alpha: 0.15),
                child: Text(
                  (p.name as String).isNotEmpty ? (p.name as String)[0] : '?',
                  style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.w700,
                      fontSize: 14),
                ),
              ),
              const SizedBox(width: 12),
              // 名前
              SizedBox(
                width: 80,
                child: TextField(
                  controller: _ctrl,
                  style: const TextStyle(
                      fontWeight: FontWeight.w600, fontSize: 15),
                  decoration: const InputDecoration(
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                    border: InputBorder.none,
                    hintText: '名前',
                  ),
                  onChanged: widget.onNameChanged,
                ),
              ),
              const SizedBox(width: 8),
              // 駅ボタン
              Expanded(
                child: GestureDetector(
                  onTap: widget.onStationTap,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: hasStation
                          ? color.withValues(alpha: 0.1)
                          : Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.train_rounded,
                          size: 14,
                          color: hasStation ? color : Colors.grey.shade400,
                        ),
                        const SizedBox(width: 5),
                        Expanded(
                          child: Text(
                            hasStation ? p.stationName as String : '駅を選ぶ',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: hasStation
                                  ? color
                                  : Colors.grey.shade400,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (hasStation)
                          GestureDetector(
                            onTap: widget.onStationClear,
                            child: Icon(Icons.close_rounded,
                                size: 14, color: color),
                          )
                        else
                          Icon(Icons.chevron_right_rounded,
                              size: 16, color: Colors.grey.shade400),
                      ],
                    ),
                  ),
                ),
              ),
              // 削除
              if (widget.canRemove) ...[
                const SizedBox(width: 6),
                GestureDetector(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    widget.onRemove();
                  },
                  child: Icon(Icons.remove_circle_outline_rounded,
                      color: Colors.grey.shade400, size: 20),
                ),
              ],
            ],
          ),
        ),
        if (widget.showDivider)
          Divider(
              height: 1,
              indent: 14,
              endIndent: 14,
              color: Colors.grey.shade100),
      ],
    );
  }
}

// ─── 目的ピッカー ─────────────────────────────────────────────────────────────

class _OccasionPicker extends StatelessWidget {
  const _OccasionPicker({required this.selected, required this.onSelect});
  final Occasion selected;
  final void Function(Occasion) onSelect;

  static const _items = [
    (Occasion.none, 'なし', '–'),
    (Occasion.girlsNight, '女子会', '👑'),
    (Occasion.birthday, '誕生日', '🎂'),
    (Occasion.lunch, 'ランチ', '🥗'),
    (Occasion.mixer, '合コン', '🥂'),
    (Occasion.welcome, '歓迎会', '🎉'),
    (Occasion.date, 'デート', '💕'),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
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
        child: Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _items.map((item) {
            final (occasion, label, emoji) = item;
            final isSelected = selected == occasion;
            return GestureDetector(
              onTap: () {
                HapticFeedback.lightImpact();
                onSelect(occasion);
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  gradient: isSelected ? AppColors.primaryGradient : null,
                  color: isSelected ? null : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  occasion == Occasion.none ? label : '$emoji $label',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: isSelected ? Colors.white : Colors.grey.shade700,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}

// ─── 時間帯ピッカー ───────────────────────────────────────────────────────────

class _TimeSlotPicker extends StatelessWidget {
  const _TimeSlotPicker({required this.selected, required this.onSelect});
  final TimeSlot selected;
  final void Function(TimeSlot) onSelect;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
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
      child: Row(
        children: TimeSlot.values.map((t) {
          final isSelected = selected == t;
          return Expanded(
            child: GestureDetector(
              onTap: () {
                HapticFeedback.lightImpact();
                onSelect(t);
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                margin: EdgeInsets.only(
                    right: t != TimeSlot.values.last ? 8 : 0),
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  gradient: isSelected ? AppColors.primaryGradient : null,
                  color: isSelected ? null : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(12),
                ),
                alignment: Alignment.center,
                child: Column(
                  children: [
                    Text(t.emoji, style: const TextStyle(fontSize: 18)),
                    const SizedBox(height: 3),
                    Text(
                      t.label,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color:
                            isSelected ? Colors.white : Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ─── 駅選択シート ─────────────────────────────────────────────────────────────

class _StationSheet extends StatefulWidget {
  const _StationSheet({this.currentIndex, required this.favorites});
  final int? currentIndex;
  final List<FavoriteStation> favorites;

  @override
  State<_StationSheet> createState() => _StationSheetState();
}

class _StationSheetState extends State<_StationSheet> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final all = List.generate(kStations.length, (i) => i);
    final filtered = all.where((i) => kStations[i].contains(_query)).toList();

    return Container(
      height: MediaQuery.of(context).size.height * 0.82,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 8),
          Container(
            width: 36, height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),
          const Text('最寄り駅を選択',
              style:
                  TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              autofocus: true,
              decoration: InputDecoration(
                hintText: '駅名を検索',
                prefixIcon: const Icon(Icons.search_rounded),
                filled: true,
                fillColor: Colors.grey.shade100,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
              ),
              onChanged: (v) => setState(() => _query = v),
            ),
          ),
          // お気に入り
          if (widget.favorites.isNotEmpty && _query.isEmpty) ...[
            const SizedBox(height: 12),
            SizedBox(
              height: 40,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: widget.favorites.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (_, i) {
                  final fav = widget.favorites[i];
                  return GestureDetector(
                    onTap: () => Navigator.pop(context, fav.stationIndex),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                            color: AppColors.primary.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.star_rounded,
                              size: 12, color: AppColors.primary),
                          const SizedBox(width: 4),
                          Text(fav.stationName,
                              style: TextStyle(
                                  color: AppColors.primary,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
          const SizedBox(height: 8),
          const Divider(height: 1),
          Expanded(
            child: ListView.builder(
              itemCount: filtered.length,
              itemBuilder: (_, i) {
                final idx = filtered[i];
                final isSelected = widget.currentIndex == idx;
                return ListTile(
                  leading: Text(kStationEmojis[idx],
                      style: const TextStyle(fontSize: 22)),
                  title: Text(
                    kStations[idx],
                    style: TextStyle(
                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                      color: isSelected ? AppColors.primary : null,
                    ),
                  ),
                  trailing: isSelected
                      ? Icon(Icons.check_circle_rounded,
                          color: AppColors.primary)
                      : null,
                  onTap: () => Navigator.pop(context, idx),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
