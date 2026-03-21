import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
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

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _showHowToIfNeeded());
  }

  Future<void> _showHowToIfNeeded() async {
    final prefs = await SharedPreferences.getInstance();
    final shown = prefs.getBool('howto_shown') ?? false;
    if (!shown && mounted) {
      await prefs.setBool('howto_shown', true);
      if (mounted) {
        showModalBottomSheet(
          context: context,
          backgroundColor: Colors.transparent,
          isScrollControlled: true,
          builder: (_) => const _HowToSheet(),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(searchProvider);
    final notifier = ref.read(searchProvider.notifier);
    final located = state.participants.where((p) => p.hasLocation).length;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: Colors.white.withValues(alpha: 0.2)),
        ),
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              '集合場所を探す',
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
                  title: const Text('最初からやり直す'),
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
                        'やり直す',
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
          // ─── 使い方ガイド ─────────────────────────────────────
          Builder(builder: (_) {
            final located = state.participants.where((p) => p.hasLocation).length;
            final hasCondition = state.groupRelation != null ||
                state.restaurantCategory != null ||
                state.occasion != Occasion.none ||
                state.timeSlot != TimeSlot.all;
            // activeStep は 1〜3 の進捗。step n は activeStep >= n のとき光る。
            // → ②が点灯するとき①も残ったまま、③が点灯するとき①②も残る。
            final activeStep = hasCondition ? 3 : (located >= 2 ? 2 : 1);
            return Container(
              color: AppColors.primary,
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
              child: Row(
                children: [
                  _StepBadge('1', '駅を入れよう', isActive: activeStep >= 1),
                  const _StepArrow(),
                  _StepBadge('2', '好みを選ぼう', isActive: activeStep >= 2),
                  const _StepArrow(),
                  _StepBadge('3', '探す', isActive: activeStep >= 3),
                ],
              ),
            );
          }),

          const SizedBox(height: 8),

          // ─── 参加者 ──────────────────────────────────────────
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
                    onStationTap: () => _pickStation(p.id, isFirst: e.key == 0),
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
                    label: '友達を追加',
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
                              '友達を追加',
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
                      _showSaveGroupDialog();
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
                            'このメンバーを保存',
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
                      _showSavedGroupsSheet();
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.divider),
                      ),
                      child: const Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.groups_rounded,
                              size: 18, color: AppColors.textSecondary),
                          SizedBox(height: 4),
                          Text(
                            '保存済みグループ\nを使用する',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: AppColors.textSecondary,
                              height: 1.4,
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

          const SizedBox(height: 16),

          // ─── ステップ区切り（2人未満のときのみ表示） ────────────────────
          if (located < 2)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Expanded(child: Divider(thickness: 1, color: Color(0xFFE0E0E0))),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 10),
                    child: Text('先にメンバーの駅を入れてね',
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFFBBBBBB))),
                  ),
                  Expanded(child: Divider(thickness: 1, color: Color(0xFFE0E0E0))),
                ],
              ),
            ),
          if (located < 2) const SizedBox(height: 8),

          // ─── 好みを選ぼう（ステップ2：駅が2人分入力されるまでロック） ────
          IgnorePointer(
            ignoring: located < 2,
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 300),
              opacity: located >= 2 ? 1.0 : 0.35,
              child: Column(
                children: [
                  // ─── 日程・時間帯 ─────────────────────────────────────
                  Container(
                    color: AppColors.surface,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                          child: Text(
                            '日程・時間帯',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey.shade500,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                        _DateTimeChip(
                          state: state,
                          onTap: () => _showTimeSlotSheet(),
                        ),
                      ],
                    ),
                  ),

                  // ─── ご飯ジャンル ─────────────────────────────────────
                  const SizedBox(height: 8),
                  _FoodCategoryChips(
                    selected: state.restaurantCategory,
                    onSelect: (cat) => notifier.setRestaurantCategory(
                        cat == state.restaurantCategory ? null : cat),
                  ),

                  // ─── 誰と行く？ ───────────────────────────────────────
                  const SizedBox(height: 8),
                  _GroupRelationChips(
                    selected: state.groupRelation,
                    onSelect: (relation) =>
                        notifier.setGroupRelation(relation),
                  ),

                  // ─── シーン選択 ───────────────────────────────────────
                  const SizedBox(height: 8),
                  _OccasionChips(
                    selected: state.occasion,
                    onSelect: (o) {
                      notifier.setOccasion(
                          state.occasion == o ? Occasion.none : o);
                    },
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 80),
        ],
      ),
      bottomNavigationBar: _SearchButton(state: state, notifier: notifier),
    );
  }

  void _showSaveGroupDialog() {
    final participants = ref.read(searchProvider).participants;
    if (participants.isEmpty) return;

    showDialog<void>(
      context: context,
      builder: (ctx) => _SaveGroupDialog(
        participants: participants.map((p) => p.name).toList(),
        onSave: (name, names) async {
          final stations = participants.map((p) => p.stationName).toList();
          final indices = participants.map((p) => p.stationIndex).toList();
          await ref.read(groupProvider.notifier).add(
            name, names,
            memberStations: stations,
            memberStationIndices: indices,
          );
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('「$name」を保存しました'),
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        },
      ),
    );
  }

  void _showSavedGroupsSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => const _SavedGroupsSheet(),
    );
  }

  void _showTimeSlotSheet() {
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

  void _pickStation(String participantId, {bool isFirst = false}) async {
    HapticFeedback.lightImpact();
    // よく使う駅は自分（先頭参加者）にのみ表示
    final favorites = isFirst ? ref.read(favoritesProvider) : const <FavoriteStation>[];
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
            content: Text('共有リンクの作成に失敗しました。ネット接続を確認してもう一度お試しください'),
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
            content: Text('現在地を取得できませんでした。設定から位置情報を許可してください'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } on TimeoutException catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('少し時間がかかっています。もう一度タップしてみてください'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('現在地を取得できませんでした。設定から位置情報を許可してください'),
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
                    hintText: '例: あや',
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
                    child: const Icon(Icons.close,
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
                          ? '${state.occasion.label}のお店を見つける'
                          : 'ちょうどいいお店を探す',
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
                            'まだ保存したグループがありません',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w500,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'よく集まるメンバーを保存しておくと\n次回からすぐ使えます',
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
                              .setParticipantsFromHistory(
                                group.memberNames,
                                stations: group.memberStations,
                                stationIndices: group.memberStationIndices,
                              );
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
        color: _isDefault ? AppColors.surface : AppColors.primaryLight,
        child: Column(
          children: [
            const SizedBox(height: 1, child: ColoredBox(color: Color(0xFFEEEEEE))),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  Icon(
                    Icons.calendar_today_rounded,
                    size: 18,
                    color: _isDefault ? AppColors.textSecondary : AppColors.primary,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '$_dateLabel・$_slotLabel',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: _isDefault ? AppColors.textPrimary : AppColors.primary,
                          ),
                        ),
                        if (_isDefault)
                          const Text(
                            '日程・時間帯を選択してください',
                            style: TextStyle(
                              fontSize: 11,
                              color: AppColors.textTertiary,
                            ),
                          ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.expand_more_rounded,
                    size: 20,
                    color: _isDefault ? AppColors.textTertiary : AppColors.primary,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 1, child: ColoredBox(color: Color(0xFFEEEEEE))),
          ],
        ),
      ),
    );
  }
}

// ─── 女子会モードトグル ────────────────────────────────────────────────────────

class _OccasionChips extends StatelessWidget {
  const _OccasionChips({required this.selected, required this.onSelect});
  final Occasion selected;
  final ValueChanged<Occasion> onSelect;

  static const _options = [
    (Occasion.girlsNight, '女子会'),
    (Occasion.birthday, '誕生日'),
    (Occasion.lunch, 'ランチ'),
    (Occasion.mixer, '合コン'),
    (Occasion.welcome, '歓迎会'),
    (Occasion.date, 'デート'),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: AppColors.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 1, child: ColoredBox(color: Color(0xFFEEEEEE))),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Text(
              'シーン',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade500,
                letterSpacing: 0.5,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _options.map((opt) {
                final (occasion, label) = opt;
                final isSelected = selected == occasion;
                return GestureDetector(
                  onTap: () => onSelect(occasion),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppColors.primaryLight
                          : Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isSelected ? AppColors.primary : AppColors.divider,
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

// ─── ご飯ジャンルチップ ────────────────────────────────────────────────────────

class _FoodCategoryChips extends StatelessWidget {
  const _FoodCategoryChips({required this.selected, required this.onSelect});
  final String? selected;
  final ValueChanged<String> onSelect;

  static const _options = [
    ('和食', '和食'),
    ('ラーメン', 'ラーメン'),
    ('焼肉', '焼肉'),
    ('イタリアン', 'イタリアン'),
    ('カフェ', 'カフェ'),
    ('居酒屋', '居酒屋'),
    ('中華', '中華'),
    ('フレンチ', 'フレンチ'),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: AppColors.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 1, child: ColoredBox(color: Color(0xFFEEEEEE))),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Text(
              'ジャンル',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade500,
                letterSpacing: 0.5,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
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
                          ? AppColors.primaryLight
                          : Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isSelected ? AppColors.primary : AppColors.divider,
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
      width: double.infinity,
      color: AppColors.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 1, child: ColoredBox(color: Color(0xFFEEEEEE))),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Text(
              'メンバー',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade500,
                letterSpacing: 0.5,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
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
                          ? AppColors.primaryLight
                          : Colors.white,
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

  bool _isSameDay(DateTime? a, DateTime? b) {
    if (a == null || b == null) return false;
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final dates = List.generate(7, (i) => today.add(Duration(days: i)));
    final size = MediaQuery.of(context).size;

    return Container(
      height: size.height * 0.55,
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 8),
          Container(
            width: 40, height: 4,
            decoration: BoxDecoration(
              color: AppColors.divider,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),
          const Text('日程・時間帯を選択',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          const SizedBox(height: 16),
          // 日付選択
          SizedBox(
            height: 64,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: dates.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (_, i) {
                final d = dates[i];
                final isSelected = _isSameDay(_date, d) ||
                    (_date == null && i == 0);
                final label = i == 0
                    ? '今日'
                    : i == 1
                        ? '明日'
                        : '${d.month}/${d.day}';
                return GestureDetector(
                  onTap: () => setState(() => _date = i == 0 ? null : d),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    width: 56,
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppColors.primary
                          : AppColors.background,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected
                            ? AppColors.primary
                            : AppColors.divider,
                      ),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      label,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: isSelected ? Colors.white : AppColors.textSecondary,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 16),
          // 時間帯選択
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: TimeSlot.values.map((slot) {
                final isSelected = _slot == slot;
                return GestureDetector(
                  onTap: () => setState(() => _slot = slot),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppColors.primaryLight
                          : AppColors.background,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected
                            ? AppColors.primary
                            : AppColors.divider,
                        width: isSelected ? 1.5 : 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            slot.label,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: isSelected
                                  ? FontWeight.w700
                                  : FontWeight.w400,
                              color: isSelected
                                  ? AppColors.primary
                                  : AppColors.textPrimary,
                            ),
                          ),
                        ),
                        if (isSelected)
                          const Icon(Icons.check_rounded,
                              color: AppColors.primary, size: 18),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(
                16, 0, 16, MediaQuery.of(context).padding.bottom + 16),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  widget.onSlotSelected(_slot);
                  widget.onDateSelected(_date);
                  Navigator.pop(context);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: const Text('決定',
                    style: TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w700)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── ステップバッジ ────────────────────────────────────────────────────────────

class _StepBadge extends StatelessWidget {
  const _StepBadge(this.step, this.label, {this.isActive = false});
  final String step;
  final String label;
  final bool isActive;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 250),
        opacity: isActive ? 1.0 : 0.45,
        child: Column(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              width: isActive ? 30 : 24,
              height: isActive ? 30 : 24,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: isActive
                    ? [BoxShadow(color: Colors.black26, blurRadius: 6, offset: Offset(0, 2))]
                    : [],
              ),
              alignment: Alignment.center,
              child: Text(
                step,
                style: TextStyle(
                  fontSize: isActive ? 14 : 12,
                  fontWeight: FontWeight.w800,
                  color: AppColors.primary,
                ),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: isActive ? 12 : 11,
                fontWeight: isActive ? FontWeight.w700 : FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StepArrow extends StatelessWidget {
  const _StepArrow();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.only(bottom: 16),
      child: Icon(Icons.chevron_right_rounded, color: Colors.white70, size: 20),
    );
  }
}

// ─── 使い方ガイド（初回のみ表示） ──────────────────────────────────────────────

class _HowToSheet extends StatelessWidget {
  const _HowToSheet();

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).padding.bottom;
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(24, 20, 24, bottom + 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade200,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            '使い方はかんたん、3ステップ',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          Text(
            '準備は駅の名前だけ。あとはAimaにおまかせ。',
            style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          _HowToStep(
            number: '1',
            icon: Icons.train_rounded,
            title: '全員の最寄り駅を入力',
            body: '自分と友達の駅を入れるだけ。GPS自動取得も使えるよ。',
            color: AppColors.primary,
          ),
          const SizedBox(height: 16),
          _HowToStep(
            number: '2',
            icon: Icons.tune_rounded,
            title: '好みを選ぶ（任意）',
            body: '日程・ジャンル・女子会モードなど好みで絞り込める。',
            color: const Color(0xFF7C3AED),
          ),
          const SizedBox(height: 16),
          _HowToStep(
            number: '3',
            icon: Icons.restaurant_rounded,
            title: 'みんなにぴったりなお店を発見',
            body: '全員の移動バランスと予約可否を考えて、最高のお店を提案。LINEでそのまま共有できる。',
            color: const Color(0xFF059669),
          ),
          const SizedBox(height: 28),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
              child: const Text(
                'さっそく使ってみる',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HowToStep extends StatelessWidget {
  const _HowToStep({
    required this.number,
    required this.icon,
    required this.title,
    required this.body,
    required this.color,
  });
  final String number;
  final IconData icon;
  final String title;
  final String body;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 20, color: color),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Step $number  $title',
                style: TextStyle(
                    fontSize: 14, fontWeight: FontWeight.w700, color: color),
              ),
              const SizedBox(height: 3),
              Text(
                body,
                style: TextStyle(fontSize: 13, color: Colors.grey.shade600, height: 1.5),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SaveGroupDialog extends StatefulWidget {
  final List<String> participants;
  final Future<void> Function(String name, List<String> names) onSave;

  const _SaveGroupDialog({required this.participants, required this.onSave});

  @override
  State<_SaveGroupDialog> createState() => _SaveGroupDialogState();
}

class _SaveGroupDialogState extends State<_SaveGroupDialog> {
  final _controller = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text(
        'グループを保存',
        style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'メンバー: ${widget.participants.join(', ')}',
            style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _controller,
            autofocus: true,
            decoration: const InputDecoration(
              hintText: '例: 金曜の飲み仲間 / 大学の友達',
              labelText: 'グループ名',
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context),
          child: const Text('キャンセル'),
        ),
        TextButton(
          onPressed: _saving
              ? null
              : () async {
                  final name = _controller.text.trim();
                  if (name.isEmpty) return;
                  final nav = Navigator.of(context);
                  final messenger = ScaffoldMessenger.of(context);
                  setState(() => _saving = true);
                  try {
                    await widget.onSave(name, widget.participants);
                    if (mounted) nav.pop();
                  } catch (_) {
                    if (mounted) {
                      setState(() => _saving = false);
                      messenger.showSnackBar(
                        const SnackBar(
                          content: Text('保存に失敗しました。もう一度お試しください。'),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    }
                  }
                },
          child: _saving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('保存'),
        ),
      ],
    );
  }
}
