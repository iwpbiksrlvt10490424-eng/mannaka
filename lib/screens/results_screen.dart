import 'dart:math';
import 'package:flutter/material.dart';
// LINE 共有ボタン用の共通アイコン
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/saved_share_draft.dart';
import '../providers/saved_share_drafts_provider.dart';
import '../providers/search_provider.dart';
import '../providers/history_provider.dart';
import '../models/meeting_point.dart';
import '../models/restaurant.dart';
import '../models/scored_restaurant.dart';
import '../theme/app_theme.dart';
import '../widgets/candidate_share_sheet.dart';
import '../widgets/line_icon.dart';
import '../services/midpoint_service.dart';
import '../utils/photo_ref.dart';
import '../utils/share_utils.dart';
import 'restaurant_detail_screen.dart';

class ResultsScreen extends ConsumerStatefulWidget {
  const ResultsScreen({super.key});

  @override
  ConsumerState<ResultsScreen> createState() => _ResultsScreenState();
}

class _ResultsScreenState extends ConsumerState<ResultsScreen>
    with TickerProviderStateMixin {
  TabController? _tab;
  int _tabCount = 0;
  /// 駅タブを跨いでも保持される選択済み候補。
  /// レストラン ID → (scored, 選択時の集合駅名) のペアを保持し、
  /// LINE 本文で駅ごとにグループ表示できるようにする。
  final Map<String, _SelectedEntry> _sharedSelected = {};

  /// LINE で 1 回に送れる件数の上限。選択UIもこの件数で頭打ち。
  static const int _kMaxSelect = 5;

  void _toggleSelection(ScoredRestaurant sr, String stationName) {
    final id = sr.restaurant.id;
    final alreadySelected = _sharedSelected.containsKey(id);
    if (!alreadySelected && _sharedSelected.length >= _kMaxSelect) {
      HapticFeedback.lightImpact();
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(
          content: Text('1回で送れるのは5件までです'),
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 2),
        ));
      return;
    }
    setState(() {
      // setState 実行までに別イベントで状態が変わる可能性を考慮し、
      // コールバック内でも最新の length を再検証する（連打耐性）。
      if (_sharedSelected.containsKey(id)) {
        _sharedSelected.remove(id);
      } else if (_sharedSelected.length < _kMaxSelect) {
        _sharedSelected[id] =
            _SelectedEntry(scored: sr, stationName: stationName);
      }
    });
  }

  void _clearSelection() => setState(() => _sharedSelected.clear());

  void _rebuildTab(
      int count, List<MeetingPoint> results, SearchNotifier notifier) {
    if (_tabCount == count) return;
    _tab?.dispose();
    _tabCount = count;
    _tab = TabController(length: count, vsync: this);
    _tab!.addListener(() {
      if (_tab!.indexIsChanging) return;
      final idx = _tab!.index;
      if (idx < results.length) {
        notifier.selectMeetingPointAndFetch(results[idx]);
      }
    });
  }

  /// 履歴は「ユーザーが詳細を開くために実際にタップした店」だけを残す方針。
  /// **駅単位で 1 エントリー**にまとめる（YouTube/ブラウザの履歴と同様）。
  /// 同じ検索内でもタブを切替えて違う駅で店をタップしたら、駅ごとに別エントリー。
  ///
  /// _tappedIds: このセッションで既にタップ済みの restaurant id（重複保存防止）
  /// _entryIdByStation: 駅名 → そのセッションで作成済みのエントリー id（追記先）
  /// 検索が新しく完了するたびに両方リセットする。
  ///
  /// なぜ「検索単位」ではなく「駅単位」か:
  /// 1 検索が複数の候補駅（タブ）を持ち、タブ切替時は isCalculating が遷移しない
  /// （キャッシュ済みの場合）。検索単位で束ねると、タブ B でタップした店がタブ A の
  /// エントリーに混ざり、駅表示がズレる。駅単位なら各タブのタップが正しく分離される。
  final Set<String> _tappedIds = {};
  final Map<String, String> _entryIdByStation = {};

  @override
  void initState() {
    super.initState();
    // 新しい検索が完了したら、タップ追跡をリセット。
    // 検索完了時に「保存」はしない（タップされるまで履歴に何も残さない）。
    // ref.listen を build に書かないルールに従い、initState で listenManual を登録。
    ref.listenManual<bool>(
      searchProvider.select((s) => s.isCalculating),
      (prev, next) {
        if (prev == true && next == false) {
          _tappedIds.clear();
          _entryIdByStation.clear();
        }
      },
    );
  }

  /// ユーザーが詳細を開いた店を履歴に保存する。
  /// **駅単位で 1 エントリー**にまとめる：同じ駅で複数タップ → 同エントリーに追記、
  /// 別の駅でタップ → その駅用の新エントリー作成。
  ///
  /// `point` はユーザーが今見ているタブの駅。state.selectedMeetingPoint を
  /// 読まないのは、連続再検索やタブ切替で同期ズレが起き、古い駅で履歴が
  /// 保存されるバグが発生したため（タブ自身が持つ point が信頼できる真実）。
  Future<void> _saveTappedRestaurant(Restaurant r, MeetingPoint point) async {
    if (_tappedIds.contains(r.id)) return; // 同セッション内の同じ店は二重保存しない
    _tappedIds.add(r.id);

    final state = ref.read(searchProvider);

    final hr = HistoryRestaurant(
      name: r.name,
      category: r.category,
      rating: r.rating,
      imageUrl: r.imageUrl,
      photoRefs: PhotoRef.listToRefs(r.imageUrls),
      hotpepperUrl: r.hotpepperUrl,
      lat: r.lat,
      lng: r.lng,
      address: r.address,
    );

    final notifier = ref.read(historyProvider.notifier);
    final stationName = point.stationName;
    final existingId = _entryIdByStation[stationName];
    if (existingId == null) {
      final id = await notifier.add(
        state.participants.map((p) => p.name).toList(),
        point,
        restaurants: [hr],
      );
      _entryIdByStation[stationName] = id;
    } else {
      await notifier.appendRestaurant(existingId, hr);
    }
  }

  @override
  void dispose() {
    _tab?.dispose();
    super.dispose();
  }

  /// 条件変更シートを表示し、ユーザーが適用したら検索条件を更新して再検索する。
  Future<void> _showConditionEditSheet(
      BuildContext context, SearchState state, SearchNotifier notifier) async {
    HapticFeedback.lightImpact();
    // シート表示前の server-side filter 関連値を控えておく
    final prevCategories = Set<String>.from(state.restaurantCategories);
    final prevMaxBudget = state.maxBudget;
    final prevPrivateRoom = state.showPrivateRoom;
    final prevFreeDrink = state.showFreeDrink;
    final prevTimeSlot = state.timeSlot;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _ConditionEditSheet(state: state, notifier: notifier),
    );

    // シート閉じた後の最新 state
    final newState = ref.read(searchProvider);
    // server-side に投げる条件が変わっていたら再取得が必要
    final serverSideChanged =
        !_setEquals(newState.restaurantCategories, prevCategories) ||
            newState.maxBudget != prevMaxBudget ||
            newState.showPrivateRoom != prevPrivateRoom ||
            newState.showFreeDrink != prevFreeDrink ||
            newState.timeSlot != prevTimeSlot;
    if (serverSideChanged) {
      await notifier.calculate();
    }
  }

  bool _setEquals(Set<String> a, Set<String> b) {
    if (a.length != b.length) return false;
    return a.every(b.contains);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(searchProvider);
    final notifier = ref.read(searchProvider.notifier);
    final results = state.results;
    final tabCount = results.isEmpty ? 1 : min(5, results.length);

    // タブ数が変わったら即座に再構築（フレームをまたぐと不一致エラーになる）
    if (_tabCount != tabCount) {
      _rebuildTab(tabCount, results, notifier);
    }

    final tab = _tab!;

    return Scaffold(
      backgroundColor: const Color(0xFFF7F7F7),
      appBar: AppBar(
        toolbarHeight: 56,
        elevation: 0,
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        centerTitle: true,
        title: const Text(
          'Aimaのお店',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
        ),
        actions: [
          // 条件変更ボタン: 探す画面に戻らず、結果画面上で条件を編集できる
          IconButton(
            icon: const Icon(Icons.tune_rounded, size: 22),
            tooltip: '条件を変更',
            onPressed: state.isCalculating
                ? null
                : () => _showConditionEditSheet(context, state, notifier),
          ),
          // 再取得ボタン: 電波復帰後に画像/結果を更新
          IconButton(
            icon: state.isCalculating
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh_rounded, size: 22),
            tooltip: '更新',
            onPressed: state.isCalculating
                ? null
                : () async {
                    HapticFeedback.lightImpact();
                    final point = state.selectedMeetingPoint;
                    if (point != null) {
                      // forceRefresh=true: キャッシュをスキップして再取得
                      await notifier.selectMeetingPointAndFetch(point,
                          forceRefresh: true);
                    } else {
                      await notifier.calculate();
                    }
                  },
          ),
          if (state.results.isNotEmpty) ...[
            // 右上の共有ボタン：**候補の集合駅リスト**を LINE で送る。
            // タイトル領域を圧迫しないようコンパクトに（緑チップ + LINE 文字のみ）。
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: Material(
                color: const Color(0xFF06C755),
                borderRadius: BorderRadius.circular(16),
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () async {
                    HapticFeedback.mediumImpact();
                    final messenger = ScaffoldMessenger.of(context);
                    final ok =
                        await ShareUtils.shareMeetingPointsToLine(state);
                    if (!mounted) return;
                    if (!ok) {
                      messenger.showSnackBar(
                        const SnackBar(
                          content: Text('LINE がインストールされていません'),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    }
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        vertical: 5, horizontal: 8),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        LineIcon(size: 14, filled: false, iconColor: Colors.white),
                        SizedBox(width: 3),
                        Text(
                          'LINE',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ],
        bottom: (!state.isCalculating && results.isNotEmpty)
            ? TabBar(
                controller: tab,
                isScrollable: true,
                tabAlignment: TabAlignment.start,
                labelColor: AppColors.primary,
                unselectedLabelColor: AppColors.textTertiary,
                indicatorColor: AppColors.primary,
                indicatorWeight: 2.5,
                labelPadding: const EdgeInsets.symmetric(horizontal: 16),
                labelStyle: const TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w700),
                unselectedLabelStyle: const TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w500),
                tabs: results.take(5).toList().asMap().entries.map((e) {
                  final i = e.key;
                  final p = e.value;
                  return Tab(
                    height: 44,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (i == 0) ...[
                          const Icon(Icons.star_rounded,
                              size: 13, color: AppColors.primary),
                          const SizedBox(width: 3),
                        ] else ...[
                          Text('${i + 1}位 ',
                              style: const TextStyle(
                                  fontSize: 11, fontWeight: FontWeight.w600)),
                        ],
                        Text(p.stationName),
                      ],
                    ),
                  );
                }).toList(),
              )
            : null,
      ),
      body: Column(
        children: [
          // エラーバナー
          if (state.errorMessage != null)
            Material(
              color: Colors.red.shade50,
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                child: Row(
                  children: [
                    Icon(Icons.wifi_off_rounded,
                        size: 18, color: Colors.red.shade700),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(state.errorMessage!,
                          style: TextStyle(
                              fontSize: 13, color: Colors.red.shade700)),
                    ),
                    GestureDetector(
                      onTap: () {
                        final selected = state.selectedMeetingPoint;
                        if (selected != null &&
                            !state.restaurantCache
                                .containsKey(selected.stationName)) {
                          notifier.selectMeetingPointAndFetch(selected);
                        } else {
                          notifier.calculate();
                        }
                      },
                      child: Text('もう一度試す',
                          style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: Colors.red.shade700)),
                    ),
                  ],
                ),
              ),
            ),
          // 集合場所モード切替（まんなか重視 / 主要駅重視）
          if (!state.isCalculating && results.isNotEmpty)
            _MeetingPreferenceBar(
              preferMajor: state.preferMajorStations,
              onChanged: (value) async {
                if (value == state.preferMajorStations) return;
                HapticFeedback.selectionClick();
                notifier.setPreferMajorStations(value);
                await notifier.calculate();
              },
            ),
          // メインコンテンツ
          Expanded(
            child: state.isCalculating
                ? const _SkeletonTab()
                : results.isEmpty
                    ? _EmptyState(
                        onReset: () => notifier.clearRestaurantCategories())
                    : TabBarView(
                        controller: tab,
                        children: results.take(5).toList().map((point) {
                          return _MeetingPointTab(
                            key: ValueKey(point.stationName),
                            point: point,
                            state: state,
                            notifier: notifier,
                            selectedIds: _sharedSelected.keys.toSet(),
                            onToggleSelect: (sr) =>
                                _toggleSelection(sr, point.stationName),
                            // 詳細を開いた店だけ履歴に保存。
                            // 同セッション内の複数タップは 1 エントリーに束ねる。
                            onFirstDetailOpen: _saveTappedRestaurant,
                          );
                        }).toList(),
                      ),
          ),
        ],
      ),
      bottomSheet: _sharedSelected.isEmpty
          ? null
          : _SelectionShareBar(
              count: _sharedSelected.length,
              onClear: _clearSelection,
              onShare: () {
                HapticFeedback.mediumImpact();
                // 駅は関係なく「選択順」に送る仕様。_sharedSelected.values は
                // insertion order なので、そのまま渡す。
                final selections = _sharedSelected.values
                    .map((e) =>
                        (station: e.stationName, scored: e.scored))
                    .toList();
                showCandidateShareSheet(context, selections: selections);
              },
              onSave: () async {
                HapticFeedback.selectionClick();
                final s = ref.read(searchProvider);
                final point = s.selectedMeetingPoint;
                if (point == null) return;
                final date = s.selectedDate;
                final time = s.selectedMeetingTime;
                final draft = SavedShareDraft(
                  id: 'draft_${DateTime.now().millisecondsSinceEpoch}',
                  createdAt: DateTime.now(),
                  stationName: point.stationName,
                  date: date?.toIso8601String() ?? '',
                  meetingTime: time == null
                      ? ''
                      : '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}',
                  participantTimes: Map.from(point.participantTimes),
                  candidates: _sharedSelected.values.map((e) {
                    final r = e.scored.restaurant;
                    return SavedShareCandidate(
                      name: r.name,
                      category: r.category,
                      priceStr: r.priceStr,
                      rating: r.rating,
                      lat: r.lat,
                      lng: r.lng,
                      address: r.address,
                      imageUrl: r.imageUrl,
                      hotpepperUrl: r.hotpepperUrl,
                      isReservable: r.isReservable,
                    );
                  }).toList(),
                  note: '',
                );
                await ref
                    .read(savedShareDraftsProvider.notifier)
                    .add(draft);
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                  content:
                      Text('下書きを保存しました。マイページからあとで送れます'),
                  behavior: SnackBarBehavior.floating,
                  duration: Duration(seconds: 2),
                ));
              },
            ),
    );
  }
}

/// 選択中の候補をまとめて共有する固定フッタ。駅タブを跨いで常時表示。
class _SelectionShareBar extends StatefulWidget {
  const _SelectionShareBar({
    required this.count,
    required this.onClear,
    required this.onShare,
    required this.onSave,
  });
  final int count;
  final VoidCallback onClear;
  final VoidCallback onShare;
  /// `await` できるように Future を返す関数にし、完了まで多重発火を抑止する。
  final Future<void> Function() onSave;

  @override
  State<_SelectionShareBar> createState() => _SelectionShareBarState();
}

/// 駅タブを跨いで保持する選択のエントリ。どの駅タブから選ばれたかを記録し、
/// LINE 本文では駅ごとにまとめて表示する。
class _SelectedEntry {
  const _SelectedEntry({required this.scored, required this.stationName});
  final ScoredRestaurant scored;
  final String stationName;
}

class _SelectionShareBarState extends State<_SelectionShareBar> {
  /// 保存処理中は true。ボタン表示を無効化し多重発火を防ぐ。
  bool _saving = false;

  Future<void> _handleSave() async {
    if (_saving) return; // 連打ガード
    setState(() => _saving = true);
    try {
      await widget.onSave();
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
        decoration: BoxDecoration(
          color: AppColors.surface,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: Row(
          children: [
            GestureDetector(
              onTap: widget.onClear,
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 10),
                child: const Text('解除',
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textTertiary)),
              ),
            ),
            const SizedBox(width: 4),
            // 下書き保存（あとで送る）。保存中は無効化＋スピナー表示。
            GestureDetector(
              onTap: _saving ? null : _handleSave,
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 13),
                decoration: BoxDecoration(
                  color: _saving
                      ? AppColors.primaryLight.withValues(alpha: 0.5)
                      : AppColors.primaryLight,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_saving)
                      const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: AppColors.primary),
                      )
                    else
                      const Icon(Icons.bookmark_add_outlined,
                          size: 18, color: AppColors.primary),
                    const SizedBox(width: 6),
                    Text(_saving ? '保存中…' : '保存',
                        style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: AppColors.primary)),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: GestureDetector(
                onTap: widget.onShare,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  decoration: BoxDecoration(
                    color: const Color(0xFF06C755),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const LineIcon(
                          size: 20, filled: false, iconColor: Colors.white),
                      const SizedBox(width: 8),
                      Text(
                        '${widget.count}件をLINEで送る',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
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
    );
  }
}

// ─── 集合候補タブ ─────────────────────────────────────────────────────────────

class _MeetingPointTab extends ConsumerStatefulWidget {
  const _MeetingPointTab({
    super.key,
    required this.point,
    required this.state,
    required this.notifier,
    required this.selectedIds,
    required this.onToggleSelect,
    required this.onFirstDetailOpen,
  });
  final MeetingPoint point;
  final SearchState state;
  final SearchNotifier notifier;
  /// 親画面が保持する選択済み ID。駅タブを跨いでも維持される。
  final Set<String> selectedIds;
  final void Function(ScoredRestaurant) onToggleSelect;
  /// 閲覧したお店のみ履歴に保存する。
  /// 第 2 引数は「ユーザーが今見ているタブの駅」。
  /// state.selectedMeetingPoint をグローバルに読むと、連続再検索や
  /// タブ切替の同期ズレで違う駅が混入し得るため、必ずタブ自身の point を渡す。
  final void Function(Restaurant, MeetingPoint) onFirstDetailOpen;

  @override
  ConsumerState<_MeetingPointTab> createState() => _MeetingPointTabState();
}

class _MeetingPointTabState extends ConsumerState<_MeetingPointTab> {
  final Set<String> _selectedCategories = {};

  // Score cache — invalidated when relevant state changes
  List<ScoredRestaurant>? _cachedScored;
  int? _cachedHash;

  List<Restaurant> _baseRestaurants() {
    final state = widget.state;
    final name = widget.point.stationName;
    if (state.selectedMeetingPoint?.stationName == name) {
      return state.hotpepperRestaurants;
    }
    return state.restaurantCache[name] ?? [];
  }

  /// 全スコアリング済みリスト（ローカルカテゴリフィルタ・ソート前）
  List<ScoredRestaurant> get _allScored {
    final state = widget.state;
    final base = _baseRestaurants();
    if (base.isEmpty) return [];

    // キャッシュキー: スコアに影響するすべての要素を含める
    final hash = Object.hashAll([
      base.length,
      ...state.participants.map((p) => '${p.id}${p.lat}${p.lng}'),
      state.occasion.index,
      state.restaurantCategories.join(','),
      state.groupRelation ?? '',
      state.maxBudget,
      state.showPrivateRoom,
      state.showFreeDrink,
      state.excludeChains,
    ]);

    if (_cachedScored == null || _cachedHash != hash) {
      if (state.hasCentroid) {
        _cachedScored = MidpointService.scoreRestaurants(
          participants: state.participants,
          centroidLat: state.centroidLat!,
          centroidLng: state.centroidLng!,
          baseRestaurants: base,
          // 探すステップで選択したカテゴリをハードフィルタとして渡す
          categories: state.restaurantCategories.isEmpty
              ? null
              : state.restaurantCategories,
          occasion: state.occasion != Occasion.none ? state.occasion.label : null,
          groupRelation: state.groupRelation,
          // ハードフィルタはユーザーが明示的にトグルしたものだけ。
          // シーン由来の好み（女子会→個室など）は occasion 経由の
          // スコアリング側に任せる。ハード化すると 0 件になりやすい。
          femaleFriendly: state.showFemaleFriendly,
          hasPrivateRoom: state.showPrivateRoom,
          hasFreeDrink: state.showFreeDrink,
          excludeChains: state.excludeChains,
          timeSlot: state.occasion.filterLunch ? TimeSlot.lunch : state.timeSlot,
          maxBudget: state.maxBudget,
          selectedDate: state.selectedDate,
        );
      } else {
        // centroid なしのフォールバック
        final filtered = base.toList()
          ..sort(compareByRatingWithReviewThreshold);
        _cachedScored = filtered
            .map((r) => ScoredRestaurant(
                  restaurant: r,
                  score: 0,
                  distanceKm: 0,
                  participantDistances: {},
                  fairnessScore: 0,
                ))
            .toList();
      }
      _cachedHash = hash;
    }
    return _cachedScored!;
  }

  /// 表示用リスト（ローカルカテゴリフィルタ + 予約可フィルタ + ソート適用済み）
  List<ScoredRestaurant> get _scoredRestaurants {
    var list = _allScored;
    // 結果画面内のカテゴリチップで絞り込み
    if (_selectedCategories.isNotEmpty) {
      list = list
          .where((s) => _selectedCategories.contains(s.restaurant.category))
          .toList();
    }
    // 予約可のみ絞り込み
    if (widget.state.reservableOnly) {
      list = list.where((s) => s.restaurant.isReservable).toList();
    }
    // ソートオプション適用
    return switch (widget.state.sortOption) {
      SortOption.recommended => list,
      SortOption.distance =>
        [...list]..sort((a, b) => a.distanceKm.compareTo(b.distanceKm)),
      SortOption.rating => [...list]
        ..sort((a, b) =>
            compareByRatingWithReviewThreshold(a.restaurant, b.restaurant)),
      SortOption.budget => [...list]
        ..sort((a, b) =>
            a.restaurant.priceAvg.compareTo(b.restaurant.priceAvg)),
    };
  }

  /// 実際に表示中のレストランから動的に生成したカテゴリリスト
  List<String> get _availableCategories {
    const preferredOrder = [
      'カフェ', 'イタリアン', 'フレンチ', '韓国料理',
      '和食', '洋食', '居酒屋', '焼肉', 'ラーメン', '中華', 'バー',
    ];
    final cats = _allScored.map((s) => s.restaurant.category).toSet().toList();
    cats.sort((a, b) {
      final ai = preferredOrder.indexOf(a);
      final bi = preferredOrder.indexOf(b);
      if (ai == -1 && bi == -1) return a.compareTo(b);
      if (ai == -1) return 1;
      if (bi == -1) return -1;
      return ai.compareTo(bi);
    });
    return cats;
  }

  bool get _isLoading {
    final state = widget.state;
    final name = widget.point.stationName;
    return state.isCalculating ||
        (state.selectedMeetingPoint?.stationName == name &&
            state.hotpepperRestaurants.isEmpty &&
            !state.restaurantCache.containsKey(name));
  }

  @override
  Widget build(BuildContext context) {
    final point = widget.point;
    final scored = _scoredRestaurants;
    final categories = _availableCategories;

    // ─ 集合場所カード + ジャンルフィルタ + 店舗リストを 1 つの ListView に統合 ─
    // 実機 FB 反映: 集合場所カードが固定で画面上部を占有し、店舗がほとんど見えなかった。
    // → カードと絞り込みチップを ListView の先頭要素として配置し、スクロールで上に消す。
    final spotlight = _MeetingPointSpotlightCard(point: point);
    final divider = const SizedBox(
        height: 1, child: ColoredBox(color: Color(0xFFEEEEEE)));
    final genreFilter = Container(
      color: AppColors.surface,
      child: SizedBox(
        height: 44,
        child: ShaderMask(
          shaderCallback: (bounds) => const LinearGradient(
            colors: [
              Colors.transparent,
              Colors.white,
              Colors.white,
              Colors.transparent
            ],
            stops: [0.0, 0.04, 0.96, 1.0],
          ).createShader(bounds),
          blendMode: BlendMode.dstIn,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            children: [
              _filterChip(
                  'すべて',
                  _selectedCategories.isEmpty &&
                      widget.state.restaurantCategories.isEmpty, () {
                widget.notifier.clearRestaurantCategories();
                setState(() => _selectedCategories.clear());
              }),
              ...categories.map((c) => _filterChip(
                    c,
                    _selectedCategories.contains(c),
                    () => setState(() {
                      if (_selectedCategories.contains(c)) {
                        _selectedCategories.remove(c);
                      } else {
                        _selectedCategories.add(c);
                      }
                    }),
                  )),
            ],
          ),
        ),
      ),
    );

    return Column(
      children: [
        // ─ コンテンツエリア ────────────────────────────────────────────
        // ロード中・空のときは集合場所カードを上に固定し、下にスケルトン/空状態。
        // 通常時は ListView の先頭にカード+チップを置き、スクロールで上に消える。
        Expanded(
          child: _isLoading
              ? Column(
                  children: [
                    spotlight,
                    divider,
                    genreFilter,
                    divider,
                    const Expanded(child: _SkeletonTab()),
                  ],
                )
              : scored.isEmpty
                  ? Column(
                      children: [
                        spotlight,
                        divider,
                        genreFilter,
                        divider,
                        Expanded(
                          child: _EmptyState(
                            onReset: () {
                              widget.notifier.clearRestaurantCategories();
                              setState(() => _selectedCategories.clear());
                            },
                          ),
                        ),
                      ],
                    )
                  : Stack(
                      children: [
                        ListView.builder(
                          padding: const EdgeInsets.only(bottom: 32),
                          // +3: spotlight(0) + divider(1) + genreFilter(2)
                          itemCount: scored.length + 3,
                          itemBuilder: (ctx, i) {
                            if (i == 0) return spotlight;
                            if (i == 1) {
                              return Column(children: [divider, genreFilter, divider, const SizedBox(height: 12)]);
                            }
                            if (i == 2) return const SizedBox.shrink(); // padding moved into i==1
                            final storeIdx = i - 3;
                            final s = scored[storeIdx];
                            void openDetail() {
                              widget.onFirstDetailOpen(
                                  s.restaurant, widget.point);
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => RestaurantDetailScreen(
                                      restaurant: s.restaurant),
                                ),
                              );
                            }

                            final id = s.restaurant.id;
                            final selected =
                                widget.selectedIds.contains(id);
                            final card = storeIdx == 0
                                ? _HeroCard(scored: s, onTap: openDetail)
                                : _CompactCard(
                                    scored: s,
                                    rank: storeIdx + 1,
                                    onTap: openDetail,
                                  );
                            // カードは詳細を開く。右上の丸 + ボタンで選択。
                            return Stack(
                              children: [
                                card,
                                Positioned(
                                  top: 10,
                                  right: 10,
                                  child: GestureDetector(
                                    behavior: HitTestBehavior.opaque,
                                    onTap: () {
                                      HapticFeedback.selectionClick();
                                      widget.onToggleSelect(s);
                                    },
                                    child: Container(
                                      width: 34,
                                      height: 34,
                                      decoration: BoxDecoration(
                                        color: selected
                                            ? const Color(0xFF06C755)
                                            : Colors.white,
                                        shape: BoxShape.circle,
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black
                                                .withValues(alpha: 0.08),
                                            blurRadius: 4,
                                            offset: const Offset(0, 1),
                                          ),
                                        ],
                                        border: Border.all(
                                          color: selected
                                              ? const Color(0xFF06C755)
                                              : AppColors.divider,
                                          width: 1.5,
                                        ),
                                      ),
                                      child: Icon(
                                        selected ? Icons.check : Icons.add,
                                        color: selected
                                            ? Colors.white
                                            : AppColors.textSecondary,
                                        size: 20,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                        if (widget.state.isCalculating)
                          Positioned.fill(
                            child: Container(
                              color: Colors.white.withValues(alpha: 0.7),
                              child: const Center(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    CircularProgressIndicator(),
                                    SizedBox(height: 12),
                                    Text('みんなに合うお店を探してます...',
                                        style: TextStyle(fontSize: 14)),
                                  ],
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
        ),
      ],
    );
  }
}


// ─── ヒーローカード（1位） ────────────────────────────────────────────────────

class _HeroCard extends StatelessWidget {
  const _HeroCard({required this.scored, required this.onTap});
  final ScoredRestaurant scored;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final r = scored.restaurant;
    final catBg = AppColors.getCategoryBg(r.category);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 写真（複数枚あれば PageView スクロール、1 枚なら静止画）
            ClipRRect(
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(16)),
              child: _HeroPhotoCarousel(
                imageUrls: _collectImageUrls(r),
                catBg: catBg,
                height: 160,
              ),
            ),
            // コンテンツ
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // おすすめラベル群（長文対応のため Wrap で折り返し可能に）
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: r.isReservable
                              ? AppColors.primaryLight
                              : Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              r.isReservable
                                  ? Icons.check_circle_outline_rounded
                                  : Icons.emoji_events_rounded,
                              size: 12,
                              color: r.isReservable
                                  ? AppColors.success
                                  : AppColors.primary,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              r.isReservable ? '予約可' : 'おすすめ',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: r.isReservable
                                    ? AppColors.success
                                    : AppColors.primary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      // 「外さない」「おしゃれ」「穴場」等の主観ラベル（curationLabel）は
                      // UX critique を受けて削除。ラベルは事実ベース（駅近・予約可・個室）に絞る。
                      // 並び順 1 位は表示順序で示すので「No.1」表記は重複表現として削除。
                    ],
                  ),
                  const SizedBox(height: 10),
                  // 店名（長い名前のオーバーフロー対策）
                  Text(
                    r.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                      letterSpacing: -0.4,
                      height: 1.2,
                    ),
                  ),
                  if (r.sourceApi == 'google_places') ...[
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFF4285F4).withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text(
                        'Googleマップより',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF4285F4),
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 6),
                  // カテゴリ · 価格 · 評価
                  Row(
                    children: [
                      Flexible(
                        child: Text(r.category,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontSize: 13,
                                color: AppColors.textSecondary)),
                      ),
                      const Text('  ·  ',
                          style: TextStyle(
                              fontSize: 13, color: AppColors.textTertiary)),
                      Text(r.priceStr,
                          style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary)),
                      if (r.hasRating && r.rating! > 0) ...[
                        const SizedBox(width: 10),
                        const Icon(Icons.star_rounded,
                            size: 15, color: Color(0xFFF5B301)),
                        const SizedBox(width: 2),
                        Text(r.ratingStr,
                            style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary)),
                        if (r.reviewCount > 0) ...[
                          const SizedBox(width: 4),
                          Text('(${r.reviewCount})',
                              style: const TextStyle(
                                  fontSize: 11,
                                  color: AppColors.textTertiary)),
                        ],
                      ],
                      if ((r.rating ?? 0) >= 4.0) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(5),
                          ),
                          child: const Text('高評価',
                              style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.primary)),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 12),
                  // CTAボタン
                  SizedBox(
                    width: double.infinity,
                    height: 46,
                    child: ElevatedButton(
                      onPressed: onTap,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text(
                        '詳しく見る',
                        style: TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

Widget _imageFallback(Color bg, double iconSize) => Container(
      color: const Color(0xFFEEEEEE),
      child: Center(
        child: Text(
          'NO\nIMAGE',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: iconSize * 0.18,
            fontWeight: FontWeight.w600,
            color: Colors.grey.shade500,
            height: 1.3,
          ),
        ),
      ),
    );

/// ヒーローカード用の写真リストを取得。
/// imageUrls にデータがあればそれを使い、無ければ単一の imageUrl にフォールバック。
List<String> _collectImageUrls(Restaurant r) {
  if (r.imageUrls.isNotEmpty) return r.imageUrls;
  if (r.imageUrl != null && r.imageUrl!.isNotEmpty) return [r.imageUrl!];
  return const [];
}

/// 画像読み込み中の中立的なプレースホルダ。
/// _imageFallback と違い "NO IMAGE" 文字を出さないので、PageView で
/// スワイプした瞬間に文字がチラつかない。
Widget _neutralPlaceholder(double height) => Container(
      height: height,
      width: double.infinity,
      color: const Color(0xFFEEEEEE),
    );

/// ヒーローカードの写真カルーセル。複数枚あれば PageView でスクロール、
/// 1 枚なら静止画、0 枚ならフォールバック。
class _HeroPhotoCarousel extends StatefulWidget {
  const _HeroPhotoCarousel({
    required this.imageUrls,
    required this.catBg,
    required this.height,
  });
  final List<String> imageUrls;
  final Color catBg;
  final double height;

  @override
  State<_HeroPhotoCarousel> createState() => _HeroPhotoCarouselState();
}

class _HeroPhotoCarouselState extends State<_HeroPhotoCarousel> {
  final PageController _ctrl = PageController();
  int _index = 0;
  bool _initialPrecacheDone = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // 初回ビルド時に最初の数枚を裏で先読みしてスワイプを滑らかにする。
    if (!_initialPrecacheDone) {
      _initialPrecacheDone = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _precacheNeighbors(0);
      });
    }
  }

  /// 現在ページの前後 1 枚を裏で先読みする（PageView スワイプ時のチラつき防止）。
  void _precacheNeighbors(int center) {
    final urls = widget.imageUrls;
    final ctx = context;
    for (final i in [center - 1, center + 1, center + 2]) {
      if (i < 0 || i >= urls.length) continue;
      precacheImage(
        CachedNetworkImageProvider(urls[i]),
        ctx,
      ).catchError((_) {});
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final urls = widget.imageUrls;
    if (urls.isEmpty) {
      return SizedBox(
        height: widget.height,
        width: double.infinity,
        child: _imageFallback(widget.catBg, 56),
      );
    }
    if (urls.length == 1) {
      return SizedBox(
        height: widget.height,
        width: double.infinity,
        child: CachedNetworkImage(
          imageUrl: urls.first,
          width: double.infinity,
          height: widget.height,
          fit: BoxFit.cover,
          // 失敗時のみ NO IMAGE 表示。読み込み中は灰色 box（フラッシュ防止）
          errorWidget: (_, __, ___) => _imageFallback(widget.catBg, 56),
          placeholder: (_, __) => _neutralPlaceholder(widget.height),
          fadeInDuration: const Duration(milliseconds: 120),
        ),
      );
    }
    return SizedBox(
      height: widget.height,
      width: double.infinity,
      child: Stack(
        children: [
          PageView.builder(
            controller: _ctrl,
            itemCount: urls.length,
            onPageChanged: (i) {
              setState(() => _index = i);
              _precacheNeighbors(i);
            },
            itemBuilder: (_, i) => CachedNetworkImage(
              imageUrl: urls[i],
              width: double.infinity,
              height: widget.height,
              fit: BoxFit.cover,
              errorWidget: (_, __, ___) =>
                  _imageFallback(widget.catBg, 56),
              placeholder: (_, __) => _neutralPlaceholder(widget.height),
              fadeInDuration: const Duration(milliseconds: 120),
            ),
          ),
          // ページインジケータ
          Positioned(
            bottom: 8,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.55),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${_index + 1} / ${urls.length}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
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

// ─── コンパクトカード（2位以降） ─────────────────────────────────────────────

class _CompactCard extends StatelessWidget {
  const _CompactCard(
      {required this.scored, required this.rank, required this.onTap});
  final ScoredRestaurant scored;
  final int rank;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final r = scored.restaurant;
    final catBg = AppColors.getCategoryBg(r.category);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 写真
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: SizedBox(
                width: 80,
                height: 80,
                child: r.imageUrl != null && r.imageUrl!.isNotEmpty
                    ? CachedNetworkImage(
                        imageUrl: r.imageUrl!,
                        width: 80,
                        height: 80,
                        fit: BoxFit.cover,
                        errorWidget: (_, __, ___) => _imageFallback(catBg, 32),
                        placeholder: (_, __) => _imageFallback(catBg, 32),
                      )
                    : _imageFallback(catBg, 32),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ランク
                  Text(
                    '$rank位',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: rank == 2
                          ? const Color(0xFF9E9E9E)
                          : rank == 3
                              ? const Color(0xFF8B5E3C)
                              : AppColors.textTertiary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  // 店名 + 評価
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          r.name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                            height: 1.2,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      if ((r.rating ?? 0) >= 4.0)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(5),
                          ),
                          child: const Text('おすすめ',
                              style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.primary)),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${r.category}  ·  ${r.priceStr}  ·  徒歩${r.distanceMinutes}分',
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.textSecondary),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 5),
                  // バッジ群は文字数増減に対応するため Wrap で折り返し可能にする。
                  // 「ここから予約可能」のような長いラベルでも溢れずに次行に流れる。
                  Wrap(
                    spacing: 4,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      if (r.hasRating && r.rating! > 0)
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.star_rounded,
                                size: 13, color: Color(0xFFF5B301)),
                            const SizedBox(width: 2),
                            Text(r.ratingStr,
                                style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.textPrimary)),
                          ],
                        ),
                      // ラベルは事実ベースに絞り、最大 2 つまで表示。
                      // 優先順: 駅近(<=5分) > 予約可 > 個室 > 高評価。
                      // 「女性人気」「外さない」「おしゃれ」「穴場」等の主観ラベルは
                      // UX critique を受けて削除（判断コストを下げる）。
                      ..._FactBadges.build(r),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.chevron_right,
                size: 18, color: AppColors.textTertiary),
          ],
        ),
      ),
    );
  }
}

// ─── 小バッジ ─────────────────────────────────────────────────────────────────

class _SmallBadge extends StatelessWidget {
  const _SmallBadge(this.label, this.color);
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(label,
          style: TextStyle(
              fontSize: 10, fontWeight: FontWeight.w600, color: color)),
    );
  }
}

// ─── 集合場所カード（Spotlight） ───────────────────────────────────────────────
//
// Aimachi の中核 UI。検索結果上部に固定表示する「集合駅の納得感」カード。
// 食べログ / Hotpepper との差別化はここに集約される。
//
// 表示要素:
//   - 「○○駅がおすすめです」: 集合駅名（rank 1 用文言）
//   - 各メンバーの移動時間（参加者数 ≤ 6 のみ）
//   - 移動時間の差: maxMinutes - minMinutes（== timeDifference）
//   - 公平さの一言評価（差分から計算）
//   - 選び方: 「移動時間を公平にする」or「行きやすい駅を優先する」（既定: 公平）
//
// 既存の駅ヘッダー（小さい表示）を置き換え、Aimachi のアイデンティティを前面に出す。

class _MeetingPointSpotlightCard extends ConsumerWidget {
  const _MeetingPointSpotlightCard({required this.point});
  final MeetingPoint point;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hasIndividualTimes = point.participantTimes.isNotEmpty;

    // 実機 FB 反映: 縦領域を圧迫していたため簡素化。
    // 削除: 移動時間の差 box / 選び方 footer / 副題「みんなが集まりやすい場所」
    // 残す: 駅名（やや縮小）+ 参加者チップ + LINE 共有ボタン（コンパクト）
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.primary.withValues(alpha: 0.06),
            AppColors.surface,
          ],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 駅名 + LINE 共有ボタンを 1 行に詰める
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.train_rounded,
                    color: Colors.white, size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  '${point.stationName}駅',
                  style: const TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w900,
                    color: AppColors.textPrimary,
                    letterSpacing: -0.5,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              // LINE 共有: アイコンのみのコンパクトボタンで縦を取らない
              SizedBox(
                height: 32,
                child: OutlinedButton.icon(
                  onPressed: () async {
                    HapticFeedback.mediumImpact();
                    final messenger = ScaffoldMessenger.of(context);
                    final state = ref.read(searchProvider);
                    final ok =
                        await ShareUtils.shareMeetingPointsToLine(state);
                    if (!ok) {
                      messenger.showSnackBar(
                        const SnackBar(
                          content: Text('LINE がインストールされていません'),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    }
                  },
                  icon: const LineIcon(
                      size: 14,
                      filled: false,
                      iconColor: Color(0xFF06C755)),
                  label: const Text('共有',
                      style: TextStyle(
                          fontSize: 12, fontWeight: FontWeight.w700)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF06C755),
                    side: const BorderSide(
                        color: Color(0xFF06C755), width: 1.2),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ),
            ],
          ),
          // 個別の移動時間（最大 6 人まで一覧、それ以上は要約）
          if (hasIndividualTimes) ...[
            const SizedBox(height: 8),
            _ParticipantTimes(times: point.participantTimes),
          ],
        ],
      ),
    );
  }
}

class _ParticipantTimes extends StatelessWidget {
  const _ParticipantTimes({required this.times});
  final Map<String, int> times;

  @override
  Widget build(BuildContext context) {
    // 短い時間の人から順に並べる（最も近い人が左に来る）。
    final entries = times.entries.toList()
      ..sort((a, b) => a.value.compareTo(b.value));
    // 6 人以上は要約（カード崩れ防止）
    final visible = entries.length <= 6 ? entries : entries.take(5).toList();
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        ...visible.map((e) => _PersonChip(name: e.key, minutes: e.value)),
        if (entries.length > 6)
          _PersonChip(name: '他 ${entries.length - 5} 人', minutes: -1),
      ],
    );
  }
}

class _PersonChip extends StatelessWidget {
  const _PersonChip({required this.name, required this.minutes});
  final String name;
  final int minutes;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE5E7EB), width: 1),
      ),
      child: Text(
        minutes >= 0 ? '$name $minutes分' : name,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: AppColors.textPrimary,
        ),
      ),
    );
  }
}

// ─── 事実ベースの店舗ラベル生成（最大2つ） ─────────────────────────────────────

/// 店舗カードの右上に出すラベルは事実ベース（駅近・予約可・個室・高評価）に絞る。
/// 主観ラベル（外さない・おしゃれ・穴場・女性人気）は UX critique を受けて削除。
/// 表示件数は最大 2 つ — 多すぎると判断コストが上がる（Hick's Law）。
class _FactBadges {
  static List<Widget> build(Restaurant r) {
    final badges = <Widget>[];
    if (r.distanceMinutes <= 5) {
      badges.add(_SmallBadge('駅近', AppColors.success));
    }
    if (r.isReservable && badges.length < 2) {
      badges.add(_SmallBadge('予約可', AppColors.success));
    }
    if (r.hasPrivateRoom && badges.length < 2) {
      badges.add(_SmallBadge('個室', const Color(0xFF7C3AED)));
    }
    if ((r.rating ?? 0) >= 4.0 && badges.length < 2) {
      badges.add(_SmallBadge('高評価', AppColors.primary));
    }
    return badges;
  }
}

// ─── スケルトンローディング ────────────────────────────────────────────────────

class _SkeletonTab extends StatefulWidget {
  const _SkeletonTab();

  @override
  State<_SkeletonTab> createState() => _SkeletonTabState();
}

class _SkeletonTabState extends State<_SkeletonTab>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);
    _anim = Tween(begin: 0.3, end: 0.8)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, __) => ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: 5,
        itemBuilder: (_, i) => _SkeletonCard(opacity: _anim.value),
      ),
    );
  }
}

class _SkeletonCard extends StatelessWidget {
  const _SkeletonCard({required this.opacity});
  final double opacity;

  Widget _box(double w, double h, {double radius = 8}) => Container(
        width: w,
        height: h,
        decoration: BoxDecoration(
          color: Colors.grey.withValues(alpha: opacity),
          borderRadius: BorderRadius.circular(radius),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
          color: Colors.white, borderRadius: BorderRadius.circular(12)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _box(80, 80, radius: 10),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _box(40, 12),
                const SizedBox(height: 6),
                _box(160, 16),
                const SizedBox(height: 6),
                _box(120, 12),
                const SizedBox(height: 6),
                _box(80, 12),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── 空状態 ───────────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onReset});
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: AppColors.background,
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.border, width: 2),
            ),
            child: const Center(
              child: Icon(Icons.restaurant_menu_outlined,
                  size: 36, color: AppColors.textTertiary),
            ),
          ),
          const SizedBox(height: 16),
          const Text('このエリアでは見つかりませんでした',
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary)),
          const SizedBox(height: 6),
          const Text('ジャンルを広げるか、出発駅を変えてみてください',
              style:
                  TextStyle(fontSize: 13, color: AppColors.textSecondary)),
          const SizedBox(height: 20),
          TextButton(
            onPressed: onReset,
            style: TextButton.styleFrom(
              foregroundColor: AppColors.primary,
              backgroundColor: AppColors.primaryLight,
              padding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('ジャンルを絞り込み解除',
                style: TextStyle(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}

// ─── フィルターチップ ─────────────────────────────────────────────────────────

Widget _filterChip(String label, bool sel, VoidCallback onTap) {
  return GestureDetector(
    onTap: onTap,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 120),
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: sel ? AppColors.chipSelectedBg : AppColors.background,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
            color: sel ? AppColors.chipSelectedBg : AppColors.divider,
            width: 1),
      ),
      child: Text(
        label,
        style: TextStyle(
            fontSize: 13,
            fontWeight: sel ? FontWeight.w600 : FontWeight.w400,
            color: sel ? AppColors.chipSelectedText : AppColors.textSecondary),
      ),
    ),
  );
}

/// 結果画面の上部に出す、まんなか重視 / 主要駅重視 の切替バー。
/// タップで即座に再計算がかかる（notifier.calculate()）。
class _MeetingPreferenceBar extends StatelessWidget {
  const _MeetingPreferenceBar({
    required this.preferMajor,
    required this.onChanged,
  });
  final bool preferMajor;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: AppColors.surface,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '集合場所の選び方',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade500,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                  child: _pill('まんなか重視', !preferMajor, () => onChanged(false))),
              const SizedBox(width: 8),
              Expanded(
                  child: _pill('主要駅重視', preferMajor, () => onChanged(true))),
            ],
          ),
        ],
      ),
    );
  }

  Widget _pill(String label, bool sel, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: sel ? AppColors.chipSelectedBg : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: sel ? AppColors.chipSelectedBg : AppColors.divider,
            width: 1,
          ),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: sel ? FontWeight.w700 : FontWeight.w500,
            color:
                sel ? AppColors.chipSelectedText : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}

/// 結果画面で条件を編集するボトムシート。
/// 探す画面に戻らずに主要フィルタを変更でき、閉じた時に自動で再検索がかかる。
class _ConditionEditSheet extends ConsumerStatefulWidget {
  const _ConditionEditSheet({required this.state, required this.notifier});
  final SearchState state;
  final SearchNotifier notifier;

  @override
  ConsumerState<_ConditionEditSheet> createState() =>
      _ConditionEditSheetState();
}

class _ConditionEditSheetState extends ConsumerState<_ConditionEditSheet> {
  static const _budgetOptions = [
    (1500, '〜¥1,500'),
    (3000, '〜¥3,000'),
    (5000, '〜¥5,000'),
    (10000, '〜¥10,000'),
    (-10000, '¥10,000以上'),
  ];

  static const _categoryOptions = [
    '居酒屋', 'カフェ', 'イタリアン', 'フレンチ', '和食', '洋食',
    '中華', '焼肉', '韓国料理', 'ラーメン', 'バー',
  ];

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(searchProvider);
    final viewInsets = MediaQuery.of(context).viewInsets;
    return Padding(
      padding: EdgeInsets.fromLTRB(0, 0, 0, viewInsets.bottom),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 12),
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 20),
                child: Text('条件を変更',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
              ),
              const SizedBox(height: 16),

              _sectionTitle('ジャンル'),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _categoryOptions.map((c) {
                    final selected = state.restaurantCategories.contains(c);
                    return _chip(c, selected, () {
                      widget.notifier.toggleRestaurantCategory(c);
                    });
                  }).toList(),
                ),
              ),

              const SizedBox(height: 20),
              _sectionTitle('予算'),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _budgetOptions.map((opt) {
                    final (budget, label) = opt;
                    final selected = state.maxBudget == budget;
                    return _chip(label, selected, () {
                      widget.notifier.setMaxBudget(selected ? 0 : budget);
                    });
                  }).toList(),
                ),
              ),

              const SizedBox(height: 20),
              _sectionTitle('こだわり'),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _chip('個室あり', state.showPrivateRoom,
                        () => widget.notifier.setPrivateRoom(!state.showPrivateRoom)),
                    _chip('飲み放題あり', state.showFreeDrink,
                        () => widget.notifier.setFreeDrink(!state.showFreeDrink)),
                    _chip('チェーン店を除く', state.excludeChains,
                        () => widget.notifier.setExcludeChains(!state.excludeChains)),
                    _chip('予約可のみ', state.reservableOnly,
                        () => widget.notifier.setReservableOnly(!state.reservableOnly)),
                  ],
                ),
              ),

              const SizedBox(height: 24),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('適用して再検索',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionTitle(String label) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Colors.grey.shade500,
          ),
        ),
      );

  Widget _chip(String label, bool selected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? AppColors.chipSelectedBg : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? AppColors.chipSelectedBg : AppColors.divider,
            width: 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            color: selected ? AppColors.chipSelectedText : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}
