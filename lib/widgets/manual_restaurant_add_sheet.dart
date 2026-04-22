import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/reserved_restaurant.dart';
import '../models/visited_restaurant.dart';
import '../providers/reserved_restaurants_provider.dart';
import '../providers/visited_restaurants_provider.dart';
import '../theme/app_theme.dart';

/// 予約済み / 行ったお店に手動でお店を追加するボトムシート。
/// 理由: Hotpepper に載っていないお店（個人店・新店・Google Maps で見つけた店）も
/// 記録できるようにするため。保存先は呼び出し側で initialTarget 指定、
/// 内部でトグル可能。店名をコピー済みの状態で Google Maps を開くボタンを用意し、
/// ユーザーが住所や位置を確認しつつ手入力で埋められる導線を提供する。
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
  final _stationCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  String _category = 'その他';

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
    _stationCtrl.dispose();
    _addressCtrl.dispose();
    super.dispose();
  }

  Future<void> _openGoogleMaps() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('先にお店の名前を入力してください'),
        behavior: SnackBarBehavior.floating,
      ));
      return;
    }
    // 名前をコピーして、Google Maps で検索しやすく
    await Clipboard.setData(ClipboardData(text: name));
    final uri =
        Uri.parse('https://www.google.com/maps/search/?api=1&query='
            '${Uri.encodeComponent(name)}');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
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
    final station = _stationCtrl.text.trim();
    final address = _addressCtrl.text.trim();

    if (_target == AddTarget.reserved) {
      ref.read(reservedRestaurantsProvider.notifier).add(
            ReservedRestaurant(
              id: id,
              restaurantName: name,
              category: _category,
              reservedAt: DateTime.now(),
              nearestStation: station,
              address: address,
            ),
          );
    } else {
      ref.read(visitedRestaurantsProvider.notifier).add(
            VisitedRestaurant(
              id: id,
              restaurantName: name,
              category: _category,
              visitedAt: DateTime.now(),
              groupNames: const [],
              nearestStation: station,
              address: address,
            ),
          );
    }

    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(_target == AddTarget.reserved
          ? '予約済みに追加しました'
          : '行ったお店に追加しました'),
      backgroundColor: AppColors.primary,
      behavior: SnackBarBehavior.floating,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final viewInsets = MediaQuery.of(context).viewInsets;
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
            // 保存先トグル
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Expanded(
                      child: _targetTab('予約済み', AddTarget.reserved)),
                  Expanded(
                      child: _targetTab('行ったお店', AddTarget.visited)),
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
            Row(
              children: [
                Expanded(
                  child: Text('ジャンル',
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textSecondary)),
                ),
              ],
            ),
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
            const SizedBox(height: 10),
            TextField(
              controller: _stationCtrl,
              decoration: InputDecoration(
                labelText: '最寄り駅（任意）',
                hintText: '例: 渋谷',
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _addressCtrl,
              decoration: InputDecoration(
                labelText: '住所（任意）',
                hintText: '例: 東京都渋谷区…',
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 12),
            // Google Maps で場所を調べる
            OutlinedButton.icon(
              onPressed: _openGoogleMaps,
              icon: const Icon(Icons.map_outlined, size: 18),
              label: const Text('Google マップで検索（名前はコピー済み）'),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF1A73E8),
                side: const BorderSide(color: Color(0xFF1A73E8)),
                padding: const EdgeInsets.symmetric(vertical: 10),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
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
