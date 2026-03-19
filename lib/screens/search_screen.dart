import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import '../models/participant.dart';
import '../providers/search_provider.dart';
import '../providers/group_provider.dart';
import '../data/station_data.dart';
import '../providers/favorites_provider.dart';
import '../services/location_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/location_session_service.dart';
import '../theme/app_theme.dart';
import '../widgets/station_search_sheet.dart';
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
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'お店を探す',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: Colors.white,
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.25),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '${state.participants.length}人',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              HapticFeedback.lightImpact();
              showDialog(
                context: context,
                builder: (_) => AlertDialog(
                  title: const Text('リセットしますか？'),
                  content: const Text('入力した出発地がすべて消えます。'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('キャンセル'),
                    ),
                    TextButton(
                      onPressed: () {
                        Navigator.pop(context);
                        notifier.reset();
                      },
                      child: const Text(
                        'リセット',
                        style: TextStyle(color: Colors.red),
                      ),
                    ),
                  ],
                ),
              );
            },
            child: const Text(
              'リセット',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          const SizedBox(height: 4),

          // ─── STEP 1 ───────────────────────────────────────────
          const _StepHeader(step: 1, title: '出発地を入力'),

          // ─── よく使う駅 ───────────────────────────────────────
          _FavoriteStationsRow(
            favorites: ref.watch(favoritesProvider),
            onTap: (idx) {
              // 常に先頭の参加者（自分）にのみ反映する
              final target = state.participants.firstOrNull;
              if (target != null) {
                notifier.setStation(target.id, idx, kStations[idx]);
              }
            },
          ),

          // ─── 参加者 ──────────────────────────────────────────
          _SectionLabel(label: 'みんなの出発地'),
          Container(
            color: AppColors.surface,
            child: Column(
              children: [
                const SizedBox(height: 1, child: ColoredBox(color: Color(0xFFEEEEEE))),
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
                    onGpsTap: (idx, name) =>
                        notifier.setStation(p.id, idx, name),
                    onMapTap: (lat, lng) =>
                        notifier.setLocationDirect(p.id, lat, lng),
                    hostName: state.participants.first.name,
                    onLocationReceived: (lat, lng) =>
                        notifier.setLocationDirect(p.id, lat, lng),
                  );
                }),
                if (state.participants.length < 6) ...[
                  const SizedBox(height: 1, child: ColoredBox(color: Color(0xFFEEEEEE))),
                  Semantics(
                    button: true,
                    label: 'もう一人追加',
                    child: InkWell(
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
                              'もう一人追加',
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
                  ),
                ],
                const SizedBox(height: 1, child: ColoredBox(color: Color(0xFFEEEEEE))),
              ],
            ),
          ),

          // ─── グループ保存・読み込み ──────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      HapticFeedback.lightImpact();
                      _showSaveGroupDialog(context, ref);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.divider),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.group_add_rounded,
                              size: 18, color: AppColors.primary),
                          SizedBox(width: 6),
                          Text(
                            'グループ保存',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AppColors.primary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      HapticFeedback.lightImpact();
                      _showSavedGroupsSheet(context, ref);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.divider),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.groups_rounded,
                              size: 18, color: AppColors.textSecondary),
                          SizedBox(width: 6),
                          Text(
                            '保存済みグループ',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ─── STEP 2 ───────────────────────────────────────────
          const _StepHeader(step: 2, title: '条件を設定'),

          // ─── 日時選択 ─────────────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
            child: _DateTimeChip(
              state: state,
              onTap: () => _showTimeSlotSheet(context, ref),
            ),
          ),

          // ─── 今日は誰と行く ───────────────────────────────────
          _SectionLabel(label: '今日は誰と行く'),
          _GroupRelationChips(
            selected: state.groupRelation,
            onSelect: (r) {
              HapticFeedback.selectionClick();
              notifier.setGroupRelation(
                state.groupRelation == r ? null : r,
              );
            },
          ),

          const SizedBox(height: 12),
          // ─── 今日のシーン ─────────────────────────────────────
          _SectionLabel(label: '今日のシーン'),
          Container(
            color: AppColors.surface,
            child: Column(
              children: [
                const SizedBox(height: 1, child: ColoredBox(color: Color(0xFFEEEEEE))),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      ...[
                        (Occasion.none, 'なし'),
                        (Occasion.girlsNight, '女子会'),
                        (Occasion.birthday, '誕生日'),
                        (Occasion.lunch, 'ランチ'),
                        (Occasion.mixer, '合コン'),
                        (Occasion.welcome, '歓迎会'),
                        (Occasion.date, 'デート'),
                      ].map((item) {
                        final (occ, label) = item;
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
                                  ? const Color(0xFFF7F5F0)
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
                              label,
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
                const SizedBox(height: 1, child: ColoredBox(color: Color(0xFFEEEEEE))),
              ],
            ),
          ),

          // ─── 女子会モード ─────────────────────────────────────
          const SizedBox(height: 12),
          _SectionLabel(label: '女子会モード'),
          _GirlsNightToggle(
            active: state.occasion == Occasion.girlsNight,
            onToggle: () {
              HapticFeedback.lightImpact();
              notifier.setOccasion(
                state.occasion == Occasion.girlsNight
                    ? Occasion.none
                    : Occasion.girlsNight,
              );
            },
          ),

          const SizedBox(height: 100),
        ],
      ),
      bottomNavigationBar: _SearchButton(state: state, notifier: notifier),
    );
  }

  void _showSaveGroupDialog(BuildContext context, WidgetRef ref) {
    final participants = ref.read(searchProvider).participants;
    if (participants.isEmpty) return;

    final controller = TextEditingController();
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text(
          'グループを保存',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'メンバー: ${participants.map((p) => p.name).join(', ')}',
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: controller,
              autofocus: true,
              decoration: const InputDecoration(
                hintText: '例: 女子会メンバー',
                labelText: 'グループ名',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('キャンセル'),
          ),
          TextButton(
            onPressed: () {
              final name = controller.text.trim();
              if (name.isEmpty) return;
              final names = participants.map((p) => p.name).toList();
              ref.read(groupProvider.notifier).add(name, names);
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('「$name」を保存しました'),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
            child: const Text('保存'),
          ),
        ],
      ),
    ).then((_) => controller.dispose());
  }

  void _showSavedGroupsSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => const _SavedGroupsSheet(),
    );
  }

  void _showTimeSlotSheet(BuildContext context, WidgetRef ref) {
    HapticFeedback.lightImpact();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _TimeSlotSheet(
        currentSlot: ref.read(searchProvider).timeSlot,
        currentDate: ref.read(searchProvider).selectedDate,
        onSlotSelected: (slot) {
          ref.read(searchProvider.notifier).setTimeSlot(slot);
        },
        onDateSelected: (date) {
          ref.read(searchProvider.notifier).setDate(date);
        },
      ),
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

    final result = await showModalBottomSheet<SelectedStation>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => StationSearchSheet(
        currentIndex: currentStation,
        favorites: favorites,
      ),
    );

    if (result != null) {
      if (result.kIndex != null) {
        // kStations に含まれる駅
        ref
            .read(searchProvider.notifier)
            .setStation(participantId, result.kIndex!, result.name);
        ref.read(favoritesProvider.notifier).add(FavoriteStation(
              stationIndex: result.kIndex!,
              stationName: result.name,
              emoji: kStationEmojis[result.kIndex!],
            ));
      } else {
        // kStations に含まれない駅（小さな駅など）
        ref
            .read(searchProvider.notifier)
            .setStationWithCoords(participantId, result.name, result.lat, result.lng);
      }
    }
  }
}

// ─── ステップヘッダー ─────────────────────────────────────────────────────────

class _StepHeader extends StatelessWidget {
  const _StepHeader({required this.step, required this.title});
  final int step;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
      child: Row(
        children: [
          Container(
            width: 22,
            height: 22,
            decoration: const BoxDecoration(
              color: AppColors.primary,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Text(
              '$step',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            title,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── よく使う駅チップ行 ────────────────────────────────────────────────────────

class _FavoriteStationsRow extends StatelessWidget {
  const _FavoriteStationsRow({
    required this.favorites,
    required this.onTap,
  });
  final List<FavoriteStation> favorites;
  final void Function(int stationIndex) onTap;

  @override
  Widget build(BuildContext context) {
    if (favorites.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.star_rounded, size: 13, color: AppColors.primary),
              const SizedBox(width: 5),
              const Text(
                'よく使う駅',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: favorites.map((f) => GestureDetector(
              onTap: () {
                HapticFeedback.lightImpact();
                onTap(f.stationIndex);
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.divider),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.train_rounded, size: 13, color: AppColors.primary),
                    const SizedBox(width: 5),
                    Text(
                      f.stationName,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
            )).toList(),
          ),
        ],
      ),
    );
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
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

// ─── 日時選択チップ ────────────────────────────────────────────────────────────

class _DateTimeChip extends StatelessWidget {
  const _DateTimeChip({required this.state, required this.onTap});
  final SearchState state;
  final VoidCallback onTap;

  String get _dateLabel {
    final date = state.selectedDate;
    if (date == null) return '今日';
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = today.add(const Duration(days: 1));
    final d = DateTime(date.year, date.month, date.day);
    if (d == today) return '今日';
    if (d == tomorrow) return '明日';
    return '${date.month}/${date.day}';
  }

  String get _slotLabel {
    if (state.timeSlot == TimeSlot.all) return 'ディナー';
    return state.timeSlot.chipLabel;
  }

  bool get _isDefault =>
      state.timeSlot == TimeSlot.all && state.selectedDate == null;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: _isDefault ? AppColors.surface : AppColors.primaryLight,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: _isDefault ? AppColors.divider : AppColors.primary,
            width: _isDefault ? 1 : 1.5,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.calendar_today_rounded,
              size: 16,
              color: _isDefault ? AppColors.textSecondary : AppColors.primary,
            ),
            const SizedBox(width: 8),
            Text(
              '$_dateLabel・$_slotLabel',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: _isDefault ? AppColors.textSecondary : AppColors.primary,
              ),
            ),
            const SizedBox(width: 6),
            Icon(
              Icons.expand_more_rounded,
              size: 18,
              color: _isDefault ? AppColors.textTertiary : AppColors.primary,
            ),
          ],
        ),
      ),
    );
  }
}

// ─── 女子会モードトグル ────────────────────────────────────────────────────────

class _GirlsNightToggle extends StatelessWidget {
  const _GirlsNightToggle({required this.active, required this.onToggle});
  final bool active;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.surface,
      child: Column(
        children: [
          const SizedBox(height: 1, child: ColoredBox(color: Color(0xFFEEEEEE))),
          GestureDetector(
            onTap: onToggle,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              color: active
                  ? AppColors.primary.withValues(alpha: 0.05)
                  : AppColors.surface,
              child: Row(
                children: [
                  Icon(
                    Icons.people_alt_rounded,
                    size: 22,
                    color: active ? AppColors.primary : AppColors.textSecondary,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '女子会モード',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: active
                                ? AppColors.primary
                                : AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '個室・女性人気を優先',
                          style: TextStyle(
                            fontSize: 12,
                            color: active
                                ? AppColors.primary.withValues(alpha: 0.7)
                                : AppColors.textTertiary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 44,
                    height: 26,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(13),
                      color: active ? AppColors.primary : const Color(0xFFDDDDDD),
                    ),
                    child: AnimatedAlign(
                      duration: const Duration(milliseconds: 200),
                      alignment: active
                          ? Alignment.centerRight
                          : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.all(3),
                        width: 20,
                        height: 20,
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 1, child: ColoredBox(color: Color(0xFFEEEEEE))),
        ],
      ),
    );
  }
}

// ─── 日時選択ボトムシート ──────────────────────────────────────────────────────

class _TimeSlotSheet extends StatefulWidget {
  const _TimeSlotSheet({
    required this.currentSlot,
    required this.currentDate,
    required this.onSlotSelected,
    required this.onDateSelected,
  });
  final TimeSlot currentSlot;
  final DateTime? currentDate;
  final void Function(TimeSlot) onSlotSelected;
  final void Function(DateTime?) onDateSelected;

  @override
  State<_TimeSlotSheet> createState() => _TimeSlotSheetState();
}

class _TimeSlotSheetState extends State<_TimeSlotSheet> {
  late TimeSlot _slot;
  late DateTime? _date;

  @override
  void initState() {
    super.initState();
    _slot = widget.currentSlot;
    _date = widget.currentDate;
  }

  String _dateKey(DateTime d) => '${d.year}-${d.month}-${d.day}';

  bool _isSameDay(DateTime? a, DateTime? b) {
    if (a == null || b == null) return false;
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = today.add(const Duration(days: 1));
    final daysUntilSat = (6 - today.weekday) % 7;
    final thisSat =
        today.add(Duration(days: daysUntilSat == 0 ? 7 : daysUntilSat));
    final thisSun = thisSat.add(const Duration(days: 1));

    final dateOptions = [
      (today, '今日'),
      (tomorrow, '明日'),
      (thisSat, '今週土曜'),
      (thisSun, '今週日曜'),
    ];

    final timeOptions = [
      (TimeSlot.lunch, 'ランチ', '11〜14時'),
      (TimeSlot.cafe, 'カフェ', '14〜17時'),
      (TimeSlot.dinner, 'ディナー', '17〜22時'),
      (TimeSlot.drinking, '飲み', '18〜23時'),
    ];

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              margin: const EdgeInsets.symmetric(vertical: 12),
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFDDDDDD),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 4, 20, 16),
            child: Text(
              '日時を選択',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 0, 20, 10),
            child: Text(
              '日付',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
                letterSpacing: 0.5,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: dateOptions.map((opt) {
                final (date, label) = opt;
                final isToday = _dateKey(date) == _dateKey(today);
                final isSelected = isToday
                    ? (_date == null || _isSameDay(_date, today))
                    : _isSameDay(_date, date);
                return GestureDetector(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    setState(() {
                      _date = isToday ? null : date;
                    });
                    widget.onDateSelected(isToday ? null : date);
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppColors.primaryLight
                          : AppColors.background,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color:
                            isSelected ? AppColors.primary : AppColors.divider,
                        width: isSelected ? 1.5 : 1,
                      ),
                    ),
                    child: Text(
                      label,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight:
                            isSelected ? FontWeight.w600 : FontWeight.w400,
                        color: isSelected
                            ? AppColors.primary
                            : AppColors.textSecondary,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 20),
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 0, 20, 10),
            child: Text(
              '時間帯',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
                letterSpacing: 0.5,
              ),
            ),
          ),
          ...timeOptions.map((opt) {
            final (slot, label, hours) = opt;
            final selected = _slot == slot;
            return GestureDetector(
              onTap: () {
                HapticFeedback.lightImpact();
                setState(() => _slot = slot);
                widget.onSlotSelected(slot);
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color:
                      selected ? AppColors.primaryLight : AppColors.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: selected ? AppColors.primary : AppColors.divider,
                    width: selected ? 1.5 : 1,
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        label,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight:
                              selected ? FontWeight.w600 : FontWeight.w500,
                          color: selected
                              ? AppColors.primary
                              : AppColors.textPrimary,
                        ),
                      ),
                    ),
                    Text(
                      hours,
                      style: TextStyle(
                        fontSize: 13,
                        color: selected
                            ? AppColors.primary.withValues(alpha: 0.7)
                            : AppColors.textTertiary,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => Navigator.pop(context),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: const Text(
                  '決定',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ),
        ],
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
    this.onGpsTap,
    this.onMapTap,
    this.hostName,
    this.onLocationReceived,
  });

  final Participant participant;
  final int index;
  final bool showDivider;
  final bool canRemove;
  final VoidCallback onStationTap;
  final VoidCallback onStationClear;
  final void Function(String) onNameChanged;
  final VoidCallback onRemove;
  final void Function(int stationIndex, String stationName)? onGpsTap;
  final void Function(double lat, double lng)? onMapTap;
  // Location sharing (index > 0)
  final String? hostName;
  final void Function(double lat, double lng)? onLocationReceived;

  @override
  State<_ParticipantRow> createState() => _ParticipantRowState();
}

class _ParticipantRowState extends State<_ParticipantRow> {
  late final TextEditingController _ctrl;
  bool _locating = false;
  bool _waitingForLocation = false;
  StreamSubscription<dynamic>? _sessionSub;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.participant.name);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _sessionSub?.cancel();
    super.dispose();
  }

  Future<void> _shareLocation(Rect shareOrigin) async {
    HapticFeedback.lightImpact();
    final hostName = widget.hostName ?? '自分';
    final participantName = widget.participant.name;
    final slotIndex = widget.index;

    String sessionId;
    try {
      sessionId = await LocationSessionService.createSession(
        hostName: hostName,
        slotIndex: slotIndex,
        participantName: participantName,
        ownerUid: FirebaseAuth.instance.currentUser?.uid ?? '',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('リンクの作成に失敗しました。もう一度お試しください。'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    }

    final shareText =
        '📍 出発エリアを教えてください！\n（正確な現在地は共有されません。エリア情報のみ使用します）\nmannaka://location?session=$sessionId';

    await Share.share(shareText, sharePositionOrigin: shareOrigin);

    if (!mounted) return;

    // Start watching for location
    setState(() => _waitingForLocation = true);
    _sessionSub?.cancel();
    _sessionSub =
        LocationSessionService.watchSession(sessionId).listen((snap) {
      if (!snap.exists) return;
      final data = snap.data();
      if (data == null) return;
      final submitted = data['submitted'] as bool? ?? false;
      if (submitted) {
        final lat = (data['lat'] as num?)?.toDouble();
        final lng = (data['lng'] as num?)?.toDouble();
        if (lat != null && lng != null && mounted) {
          widget.onLocationReceived?.call(lat, lng);
          _sessionSub?.cancel();
          _sessionSub = null;
          setState(() => _waitingForLocation = false);
        }
      }
    });
  }

  Future<void> _gpsLocate() async {
    HapticFeedback.lightImpact();
    setState(() => _locating = true);
    try {
      final pos = await LocationService.getCurrentPosition()
          .timeout(const Duration(seconds: 10));
      if (pos != null && mounted) {
        final idx = LocationService.nearestStationIndex(
            pos.latitude, pos.longitude);
        widget.onGpsTap?.call(idx, kStations[idx]);
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('位置情報を取得できませんでした'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } on TimeoutException catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('位置情報の取得がタイムアウトしました。もう一度お試しください'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('位置情報を取得できませんでした'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _locating = false);
    }
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
              // 駅エリア
              Expanded(
                child: GestureDetector(
                  onTap: hasStation ? widget.onStationTap : null,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      if (hasStation) ...[
                        Flexible(
                          child: Text(
                            p.stationName ?? '',
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w500,
                              color: AppColors.textPrimary,
                            ),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                        ),
                        const SizedBox(width: 6),
                        GestureDetector(
                          onTap: widget.onStationClear,
                          child: const Icon(Icons.cancel,
                              size: 16, color: AppColors.textTertiary),
                        ),
                      ] else ...[
                        // GPS ボタン（最初の参加者のみ）
                        if (widget.index == 0 && widget.onGpsTap != null)
                          Semantics(
                            label: '現在地を取得',
                            button: true,
                            child: GestureDetector(
                              onTap: _locating ? null : _gpsLocate,
                              child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 5),
                              decoration: BoxDecoration(
                                color: _locating
                                    ? AppColors.background
                                    : AppColors.primaryLight,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                    color: AppColors.primaryBorder),
                              ),
                              child: _locating
                                  ? const SizedBox(
                                      width: 14,
                                      height: 14,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: AppColors.primary),
                                    )
                                  : const Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.my_location_rounded,
                                            size: 13,
                                            color: AppColors.primary),
                                        SizedBox(width: 3),
                                        Text(
                                          '現在地',
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                            color: AppColors.primary,
                                          ),
                                        ),
                                      ],
                                    ),
                            ),
                            ),
                          ),
                        // シェアボタン（2人目以降、アイコンのみ）
                        if (widget.index > 0)
                          Builder(
                            builder: (btnCtx) => GestureDetector(
                              onTap: _waitingForLocation
                                  ? null
                                  : () {
                                      final box = btnCtx.findRenderObject()
                                          as RenderBox?;
                                      final position =
                                          box != null && box.hasSize
                                              ? box.localToGlobal(
                                                      Offset.zero) &
                                                  box.size
                                              : const Rect.fromLTWH(
                                                  0, 400, 100, 40);
                                      _shareLocation(position);
                                    },
                              child: SizedBox(
                                width: 32,
                                height: 28,
                                child: Center(
                                  child: _waitingForLocation
                                      ? const SizedBox(
                                          width: 14,
                                          height: 14,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: AppColors.primary,
                                          ),
                                        )
                                      : const Icon(
                                          Icons.ios_share,
                                          size: 16,
                                          color: AppColors.textSecondary,
                                        ),
                                ),
                              ),
                            ),
                          ),
                        const SizedBox(width: 4),
                        GestureDetector(
                          onTap: widget.onStationTap,
                          child: const Row(
                            children: [
                              Text(
                                '駅を選択',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: AppColors.primary,
                                ),
                              ),
                              SizedBox(width: 4),
                              Icon(Icons.directions_subway_rounded,
                                  size: 18, color: AppColors.primary),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              if (widget.canRemove) ...[
                const SizedBox(width: 12),
                Semantics(
                  label: '参加者を削除',
                  button: true,
                  child: GestureDetector(
                    onTap: () {
                      HapticFeedback.lightImpact();
                      widget.onRemove();
                    },
                    child: const Icon(Icons.remove_circle,
                        size: 20, color: AppColors.textTertiary),
                  ),
                ),
              ],
            ],
          ),
        ),
        if (widget.showDivider)
          const Padding(padding: EdgeInsets.only(left: 20), child: SizedBox(height: 1, child: ColoredBox(color: Color(0xFFEEEEEE)))),
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
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: canSearch
                  ? () {
                      HapticFeedback.mediumImpact();
                      // 先に画面遷移してスケルトン表示 → 体感速度が向上
                      notifier.calculate();
                      Navigator.of(context).push(
                        MaterialPageRoute(
                            builder: (_) => const ResultsScreen()),
                      );
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
                          ? '${state.occasion.label}のお店を探す'
                          : '検索する',
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w700),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── 駅選択シート ─────────────────────────────────────────────────────────────

// ─── 保存済みグループ一覧シート ────────────────────────────────────────────────

class _SavedGroupsSheet extends ConsumerWidget {
  const _SavedGroupsSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final groups = ref.watch(groupProvider);

    return Container(
      height: MediaQuery.of(context).size.height * 0.55,
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
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
            '保存済みグループ',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: groups.isEmpty
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(32),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.groups_rounded,
                              size: 48, color: AppColors.textTertiary),
                          SizedBox(height: 12),
                          Text(
                            '保存済みグループはありません',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w500,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            '参加者を入力して「グループ保存」で\n保存できます',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 13,
                              color: AppColors.textTertiary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 8),
                    itemCount: groups.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (_, i) {
                      final group = groups[i];
                      return GestureDetector(
                        onTap: () {
                          HapticFeedback.lightImpact();
                          ref
                              .read(searchProvider.notifier)
                              .setParticipantsFromHistory(group.memberNames);
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content:
                                  Text('「${group.name}」を読み込みました'),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        },
                        child: Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color:
                                    Colors.black.withValues(alpha: 0.06),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: AppColors.primaryLight,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Center(
                                  child: Icon(Icons.groups_rounded,
                                      size: 20,
                                      color: AppColors.primary),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      group.name,
                                      style: const TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.textPrimary,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Wrap(
                                      spacing: 6,
                                      runSpacing: 4,
                                      children: group.memberNames
                                          .map(
                                            (name) => Container(
                                              padding:
                                                  const EdgeInsets
                                                      .symmetric(
                                                      horizontal: 10,
                                                      vertical: 4),
                                              decoration: BoxDecoration(
                                                borderRadius:
                                                    BorderRadius.circular(
                                                        22),
                                                border: Border.all(
                                                    color: AppColors
                                                        .divider),
                                              ),
                                              child: Text(
                                                name,
                                                style: const TextStyle(
                                                  fontSize: 12,
                                                  fontWeight:
                                                      FontWeight.w400,
                                                  color: AppColors
                                                      .textSecondary,
                                                ),
                                              ),
                                            ),
                                          )
                                          .toList(),
                                    ),
                                  ],
                                ),
                              ),
                              GestureDetector(
                                onTap: () {
                                  HapticFeedback.lightImpact();
                                  ref
                                      .read(groupProvider.notifier)
                                      .remove(group.id);
                                },
                                child: const Padding(
                                  padding: EdgeInsets.all(4),
                                  child: Icon(Icons.delete_outline_rounded,
                                      size: 20,
                                      color: AppColors.textTertiary),
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
      ),
    );
  }
}

// ─── 誰と行く？チップ ──────────────────────────────────────────────────────────

class _GroupRelationChips extends StatelessWidget {
  const _GroupRelationChips({required this.selected, required this.onSelect});
  final String? selected;
  final ValueChanged<String> onSelect;

  static const _options = [
    ('friends', '友人'),
    ('couple', 'カップル'),
    ('colleagues', '同僚'),
    ('family', '家族'),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 1, child: ColoredBox(color: Color(0xFFEEEEEE))),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _options.map((opt) {
                final (key, label) = opt;
                final isSelected = selected == key;
                return GestureDetector(
                  onTap: () => onSelect(key),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? const Color(0xFFF7F5F0)
                          : AppColors.background,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isSelected
                            ? AppColors.primary
                            : AppColors.divider,
                        width: isSelected ? 1.5 : 1,
                      ),
                    ),
                    child: Text(
                      label,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: isSelected
                            ? FontWeight.w600
                            : FontWeight.w400,
                        color: isSelected
                            ? AppColors.primary
                            : AppColors.textSecondary,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 1, child: ColoredBox(color: Color(0xFFEEEEEE))),
        ],
      ),
    );
  }
}
