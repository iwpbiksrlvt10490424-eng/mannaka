import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/reserved_restaurant.dart';
import '../models/visited_restaurant.dart';
import '../models/saved_group.dart';
import '../providers/group_provider.dart';
import '../providers/reserved_restaurants_provider.dart';
import '../providers/visited_restaurants_provider.dart';
import '../theme/app_theme.dart';
import 'station_search_sheet.dart';

/// 予約済み / 行ったお店に手動でお店を追加するボトムシート。
/// 理由: Hotpepper に載っていないお店（個人店・新店）を記録できるように。
/// 住所や駅は後から編集で追えるため、最小入力として
/// 店名・ジャンル・グループ（任意）のみにする。
enum AddTarget { reserved, visited }

class ManualRestaurantAddSheet extends ConsumerStatefulWidget {
  const ManualRestaurantAddSheet({
    super.key,
    this.initialTarget = AddTarget.reserved,
  });

  final AddTarget initialTarget;

  @override
  ConsumerState<ManualRestaurantAddSheet> createState() =>
      _ManualRestaurantAddSheetState();
}

class _ManualRestaurantAddSheetState
    extends ConsumerState<ManualRestaurantAddSheet> {
  late AddTarget _target;
  final _nameCtrl = TextEditingController();
  String _category = 'その他';
  final Set<String> _selectedGroupIds = {};
  /// 任意入力の最寄り駅。StationSearchSheet で選択した駅名を保持。
  String? _nearestStation;

  static const _categories = [
    'カフェ', '居酒屋', 'バー', '和食', '洋食', 'イタリアン', 'フレンチ',
    '中華', '焼肉', '韓国料理', 'ラーメン', 'お好み焼き', 'その他',
  ];

  @override
  void initState() {
    super.initState();
    _target = widget.initialTarget;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  /// 他画面と同じ StationSearchSheet を開いて駅を選択させる。
  /// 選択結果は名前のみを保持（座標は保存データに使わないため）。
  Future<void> _pickStation() async {
    final result = await showModalBottomSheet<SelectedStation>(
      context: context,
      useRootNavigator: true,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => const StationSearchSheet(
        currentIndex: null,
        favorites: [],
      ),
    );
    if (!mounted) return;
    if (result != null) {
      setState(() => _nearestStation = result.name);
    }
  }

  List<String> _groupNamesFromSelection(List<SavedGroup> all) {
    return all
        .where((g) => _selectedGroupIds.contains(g.id))
        .map((g) => g.name)
        .toList();
  }

  void _save() {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('お店の名前を入力してください'),
        behavior: SnackBarBehavior.floating,
      ));
      return;
    }
    HapticFeedback.mediumImpact();
    final id = 'manual_${DateTime.now().millisecondsSinceEpoch}';
    final groups = _groupNamesFromSelection(ref.read(groupProvider));

    final station = _nearestStation ?? '';

    if (_target == AddTarget.reserved) {
      ref.read(reservedRestaurantsProvider.notifier).add(
            ReservedRestaurant(
              id: id,
              restaurantName: name,
              category: _category,
              reservedAt: DateTime.now(),
              groupNames: groups,
              nearestStation: station,
            ),
          );
    } else {
      ref.read(visitedRestaurantsProvider.notifier).add(
            VisitedRestaurant(
              id: id,
              restaurantName: name,
              category: _category,
              visitedAt: DateTime.now(),
              groupNames: groups,
              nearestStation: station,
            ),
          );
    }

    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(_target == AddTarget.reserved
          ? '予定に追加しました'
          : '行ったお店に追加しました'),
      backgroundColor: AppColors.primary,
      behavior: SnackBarBehavior.floating,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final viewInsets = MediaQuery.of(context).viewInsets;
    final groups = ref.watch(groupProvider);

    return Padding(
      padding: EdgeInsets.fromLTRB(20, 12, 20, viewInsets.bottom + 20),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.divider,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'お店を追加',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Expanded(child: _targetTab('予定', AddTarget.reserved)),
                  Expanded(child: _targetTab('行ったお店', AddTarget.visited)),
                ],
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _nameCtrl,
              autofocus: false,
              decoration: InputDecoration(
                labelText: 'お店の名前',
                hintText: '例: まんぷく食堂',
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 10),
            Text('ジャンル',
                style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textSecondary)),
            const SizedBox(height: 6),
            DropdownButtonFormField<String>(
              initialValue: _category,
              items: _categories
                  .map((c) =>
                      DropdownMenuItem(value: c, child: Text(c)))
                  .toList(),
              onChanged: (v) =>
                  setState(() => _category = v ?? 'その他'),
              decoration: InputDecoration(
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 14),
            // 最寄り駅（任意）: 他画面と同じ StationSearchSheet で選ぶ
            const Text('最寄り駅（任意）',
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textSecondary)),
            const SizedBox(height: 6),
            GestureDetector(
              onTap: _pickStation,
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 14),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.divider),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.train_rounded,
                        size: 18, color: AppColors.primary),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _nearestStation ?? '駅を検索して選ぶ',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: _nearestStation == null
                              ? FontWeight.w400
                              : FontWeight.w700,
                          color: _nearestStation == null
                              ? AppColors.textTertiary
                              : AppColors.textPrimary,
                        ),
                      ),
                    ),
                    if (_nearestStation != null)
                      GestureDetector(
                        onTap: () =>
                            setState(() => _nearestStation = null),
                        child: const Icon(Icons.close,
                            size: 16, color: AppColors.textTertiary),
                      )
                    else
                      const Icon(Icons.chevron_right,
                          color: AppColors.textTertiary),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),
            if (groups.isEmpty)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'グループは未登録です。探す画面で検索履歴からグループ保存ができます。',
                  style: TextStyle(
                      fontSize: 12, color: AppColors.textSecondary),
                ),
              )
            else ...[
              const Text('グループ（任意・複数選択可）',
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textSecondary)),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: groups.map((g) {
                  final selected = _selectedGroupIds.contains(g.id);
                  return GestureDetector(
                    onTap: () => setState(() {
                      if (selected) {
                        _selectedGroupIds.remove(g.id);
                      } else {
                        _selectedGroupIds.add(g.id);
                      }
                    }),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: selected
                            ? AppColors.primary
                            : AppColors.background,
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                          color: selected
                              ? AppColors.primary
                              : AppColors.divider,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (selected) ...[
                            const Icon(Icons.check,
                                size: 14, color: Colors.white),
                            const SizedBox(width: 4),
                          ],
                          Text(
                            g.name,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: selected
                                  ? Colors.white
                                  : AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
            const SizedBox(height: 18),
            SizedBox(
              height: 50,
              child: ElevatedButton(
                onPressed: _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('保存する',
                    style: TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w700)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _targetTab(String label, AddTarget target) {
    final selected = _target == target;
    return GestureDetector(
      onTap: () => setState(() => _target = target),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: selected ? AppColors.surface : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: selected ? AppColors.primary : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}

void showManualRestaurantAddSheet(BuildContext context,
    {AddTarget initialTarget = AddTarget.reserved}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) =>
        ManualRestaurantAddSheet(initialTarget: initialTarget),
  );
}
