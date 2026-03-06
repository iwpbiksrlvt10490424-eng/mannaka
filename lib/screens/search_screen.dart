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
        title: const Text('集合場所を探す'),
        actions: [
          TextButton(
            onPressed: () {
              HapticFeedback.lightImpact();
              notifier.reset();
            },
            child: const Text(
              'リセット',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          const SizedBox(height: 8),

          // ─── 参加者 ──────────────────────────────────────────
          _SectionLabel(label: '参加者と最寄り駅'),
          Container(
            color: AppColors.surface,
            child: Column(
              children: [
                const Divider(height: 1),
                ...state.participants.asMap().entries.map((e) {
                  final p = e.value;
                  final isLast = e.key == state.participants.length - 1;
                  return _ParticipantRow(
                    key: ValueKey(p.id),
                    participant: p,
                    index: e.key,
                    showDivider: !isLast,
                    canRemove: state.participants.length > 1,
                    onStationTap: () => _pickStation(context, ref, p.id),
                    onStationClear: () => notifier.clearStation(p.id),
                    onNameChanged: (n) =>
                        notifier.updateParticipantName(p.id, n),
                    onRemove: () => notifier.removeParticipant(p.id),
                  );
                }),
                if (state.participants.length < 6) ...[
                  const Divider(height: 1),
                  InkWell(
                    onTap: () {
                      HapticFeedback.lightImpact();
                      notifier.addParticipant();
                    },
                    child: const Padding(
                      padding: EdgeInsets.symmetric(
                          horizontal: 20, vertical: 14),
                      child: Row(
                        children: [
                          Icon(Icons.add_circle_outline,
                              size: 20, color: AppColors.primary),
                          SizedBox(width: 10),
                          Text(
                            '参加者を追加',
                            style: TextStyle(
                              fontSize: 15,
                              color: AppColors.primary,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
                const Divider(height: 1),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // ─── 目的 ─────────────────────────────────────────────
          _SectionLabel(label: '目的（任意）'),
          Container(
            color: AppColors.surface,
            child: Column(
              children: [
                const Divider(height: 1),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      ...[
                        (Occasion.none, 'なし', ''),
                        (Occasion.girlsNight, '女子会', '👑'),
                        (Occasion.birthday, '誕生日', '🎂'),
                        (Occasion.lunch, 'ランチ', '🥗'),
                        (Occasion.mixer, '合コン', '🥂'),
                        (Occasion.welcome, '歓迎会', '🎉'),
                        (Occasion.date, 'デート', '💕'),
                      ].map((item) {
                        final (occ, label, emoji) = item;
                        final selected = state.occasion == occ;
                        return GestureDetector(
                          onTap: () {
                            HapticFeedback.lightImpact();
                            notifier.setOccasion(occ);
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 8),
                            decoration: BoxDecoration(
                              color: selected
                                  ? AppColors.primaryLight
                                  : AppColors.background,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: selected
                                    ? AppColors.primary
                                    : AppColors.divider,
                                width: selected ? 1.5 : 1,
                              ),
                            ),
                            child: Text(
                              occ == Occasion.none
                                  ? label
                                  : '$emoji $label',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: selected
                                    ? FontWeight.w600
                                    : FontWeight.w400,
                                color: selected
                                    ? AppColors.primary
                                    : AppColors.textSecondary,
                              ),
                            ),
                          ),
                        );
                      }),
                    ],
                  ),
                ),
                const Divider(height: 1),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // ─── 時間帯 ───────────────────────────────────────────
          _SectionLabel(label: '時間帯（任意）'),
          Container(
            color: AppColors.surface,
            child: Column(
              children: [
                const Divider(height: 1),
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: TimeSlot.values.map((t) {
                      final selected = state.timeSlot == t;
                      return Expanded(
                        child: GestureDetector(
                          onTap: () {
                            HapticFeedback.lightImpact();
                            notifier.setTimeSlot(t);
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            margin: EdgeInsets.only(
                                right: t != TimeSlot.values.last ? 8 : 0),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            decoration: BoxDecoration(
                              color: selected
                                  ? AppColors.primaryLight
                                  : AppColors.background,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: selected
                                    ? AppColors.primary
                                    : AppColors.divider,
                                width: selected ? 1.5 : 1,
                              ),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              '${t.emoji} ${t.label}',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: selected
                                    ? FontWeight.w600
                                    : FontWeight.w400,
                                color: selected
                                    ? AppColors.primary
                                    : AppColors.textSecondary,
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
                const Divider(height: 1),
              ],
            ),
          ),

          const SizedBox(height: 100),
        ],
      ),
      bottomNavigationBar: _SearchButton(state: state, notifier: notifier),
    );
  }

  void _pickStation(
      BuildContext context, WidgetRef ref, String participantId) async {
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

// ─── セクションラベル ─────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: AppColors.textSecondary,
          letterSpacing: 0.3,
        ),
      ),
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
    required this.onStationTap,
    required this.onStationClear,
    required this.onNameChanged,
    required this.onRemove,
  });

  final dynamic participant;
  final int index;
  final bool showDivider;
  final bool canRemove;
  final VoidCallback onStationTap;
  final VoidCallback onStationClear;
  final void Function(String) onNameChanged;
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
    final p = widget.participant;
    final hasStation = p.stationIndex != null;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Row(
            children: [
              // 名前入力
              SizedBox(
                width: 88,
                child: TextField(
                  controller: _ctrl,
                  style: const TextStyle(
                    fontWeight: FontWeight.w500,
                    fontSize: 15,
                    color: AppColors.textPrimary,
                  ),
                  decoration: const InputDecoration(
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    hintText: '名前',
                    hintStyle: TextStyle(
                        color: AppColors.textTertiary, fontSize: 15),
                  ),
                  onChanged: widget.onNameChanged,
                ),
              ),
              // 駅ボタン
              Expanded(
                child: GestureDetector(
                  onTap: widget.onStationTap,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      if (hasStation) ...[
                        Text(
                          p.stationName as String,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(width: 6),
                        GestureDetector(
                          onTap: widget.onStationClear,
                          child: const Icon(Icons.cancel,
                              size: 16, color: AppColors.textTertiary),
                        ),
                      ] else ...[
                        const Text(
                          '最寄り駅を選ぶ',
                          style: TextStyle(
                            fontSize: 15,
                            color: AppColors.primary,
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Icon(Icons.chevron_right,
                            size: 18, color: AppColors.primary),
                      ],
                    ],
                  ),
                ),
              ),
              if (widget.canRemove) ...[
                const SizedBox(width: 12),
                GestureDetector(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    widget.onRemove();
                  },
                  child: const Icon(Icons.remove_circle,
                      size: 20, color: AppColors.textTertiary),
                ),
              ],
            ],
          ),
        ),
        if (widget.showDivider)
          const Divider(height: 1, indent: 20, endIndent: 0),
      ],
    );
  }
}

// ─── 検索ボタン ───────────────────────────────────────────────────────────────

class _SearchButton extends ConsumerWidget {
  const _SearchButton({required this.state, required this.notifier});
  final SearchState state;
  final SearchNotifier notifier;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final canSearch = state.canCalculate && !state.isCalculating;

    return Container(
      padding: EdgeInsets.fromLTRB(
          16, 12, 16, MediaQuery.of(context).padding.bottom + 12),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!state.canCalculate)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                '2人以上の駅を設定してください',
                style: const TextStyle(
                    fontSize: 13, color: AppColors.textSecondary),
              ),
            ),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: canSearch
                  ? () async {
                      HapticFeedback.mediumImpact();
                      await notifier.calculate();
                      if (context.mounted) {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                              builder: (_) => const ResultsScreen()),
                        );
                      }
                    }
                  : null,
              style: ElevatedButton.styleFrom(
                backgroundColor:
                    canSearch ? AppColors.primary : Colors.grey.shade200,
                foregroundColor:
                    canSearch ? Colors.white : AppColors.textTertiary,
                elevation: 0,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: state.isCalculating
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2),
                    )
                  : Text(
                      state.occasion != Occasion.none
                          ? '${state.occasion.emoji} ${state.occasion.label}の集合場所を探す'
                          : '最適な集合場所を探す',
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w700),
                    ),
            ),
          ),
        ],
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
    final filtered = List.generate(kStations.length, (i) => i)
        .where((i) => kStations[i].contains(_query))
        .toList();

    return Container(
      height: MediaQuery.of(context).size.height * 0.82,
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
                hintText: '駅名を検索',
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
                    onTap: () => Navigator.pop(context, f.stationIndex),
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
          const Divider(height: 1),
          Expanded(
            child: ListView.separated(
              itemCount: filtered.length,
              separatorBuilder: (_, __) =>
                  const Divider(height: 1, indent: 56),
              itemBuilder: (_, i) {
                final idx = filtered[i];
                final isSelected = widget.currentIndex == idx;
                return ListTile(
                  leading: Text(kStationEmojis[idx],
                      style: const TextStyle(fontSize: 22)),
                  title: Text(
                    kStations[idx],
                    style: TextStyle(
                      fontWeight: isSelected
                          ? FontWeight.w700
                          : FontWeight.w400,
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
