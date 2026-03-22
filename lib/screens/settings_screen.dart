import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:share_plus/share_plus.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import '../theme/app_theme.dart';
import '../providers/favorites_provider.dart';
import '../providers/profile_provider.dart';
import '../providers/nav_provider.dart';
import '../providers/search_provider.dart';
import '../data/station_data.dart';
import '../services/geocoding_service.dart';
import '../services/location_service.dart';
import '../widgets/station_search_sheet.dart';
import 'support_screen.dart';
import 'policy_screen.dart';


final _kAgeGroups = <String>[
  '18歳以下',
  for (int a = 18; a <= 59; a++) '$a歳',
  '60歳以上',
];

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});
  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  late final TextEditingController _nameCtrl;
  final _picker = ImagePicker();
  bool _isNavigating = false;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController();
    _loadPrefs();
  }

  Future<void> _loadPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final name = prefs.getString('user_nickname') ?? '';
    final homeStation = prefs.getInt('home_station');
    final homeStationName = prefs.getString('home_station_name');
    final homeStationLat = prefs.getDouble('home_station_lat');
    final homeStationLng = prefs.getDouble('home_station_lng');
    final ageGroup = prefs.getString('age_group');
    final imagePath = prefs.getString('profile_image_path');
    if (mounted) {
      _nameCtrl.text = name;
      ref.read(nicknameProvider.notifier).state = name;
      ref.read(homeStationProvider.notifier).state = homeStation;
      // 実際の選択駅データを復元（ピン位置の正確性のため）
      if (homeStationName != null && homeStationLat != null && homeStationLng != null) {
        ref.read(homeStationDataProvider.notifier).state = HomeStationData(
          name: homeStationName, lat: homeStationLat, lng: homeStationLng);
      } else if (homeStation != null) {
        // 旧データ: kStations の座標で復元
        final (lat, lng) = kStationLatLng[homeStation];
        ref.read(homeStationDataProvider.notifier).state = HomeStationData(
          name: kStations[homeStation], lat: lat, lng: lng);
      }
      ref.read(ageGroupProvider.notifier).state = ageGroup;
      ref.read(profileImagePathProvider.notifier).state = imagePath;
      setState(() {});
    }
  }

  Future<void> _saveName(String value) async {
    ref.read(nicknameProvider.notifier).state = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_nickname', value);
  }

  Future<void> _pickProfileImage() async {
    if (_isNavigating) return;
    _isNavigating = true;
    HapticFeedback.lightImpact();
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      useRootNavigator: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
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
            const Text('プロフィール画像を変更',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            ListTile(
              leading: const Icon(Icons.photo_library_rounded),
              title: const Text('フォトライブラリから選ぶ'),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt_rounded),
              title: const Text('カメラで撮影する'),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
            SizedBox(height: MediaQuery.of(ctx).padding.bottom + 8),
          ],
        ),
      ),
    );
    if (mounted) _isNavigating = false;
    if (source == null) return;
    final picked = await _picker.pickImage(
      source: source,
      maxWidth: 512,
      maxHeight: 512,
      imageQuality: 80,
    );
    if (picked == null) return;
    if (!mounted) return;
    ref.read(profileImagePathProvider.notifier).state = picked.path;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('profile_image_path', picked.path);
    setState(() {});
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final homeStationIdx = ref.watch(homeStationProvider);
    final ageGroup = ref.watch(ageGroupProvider);
    final imagePath = ref.watch(profileImagePathProvider);
    final favorites = ref.watch(favoritesProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            surfaceTintColor: Colors.transparent,
            scrolledUnderElevation: 0,
            title: const Text(
              'プロフィール',
              style: TextStyle(
                color: Colors.white,
                fontSize: 17,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.3,
              ),
            ),
            centerTitle: true,
          ),

          SliverToBoxAdapter(
            child: Column(
              children: [
                const SizedBox(height: 8),

                // ─── プロフィールカード ────────────────────────────────
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: AppColors.cardShadow,
                    ),
                    child: Row(
                      children: [
                        // プロフィール画像
                        GestureDetector(
                          onTap: _pickProfileImage,
                          child: Stack(
                            children: [
                              Container(
                                width: 72,
                                height: 72,
                                decoration: BoxDecoration(
                                  color: AppColors.primaryLight,
                                  shape: BoxShape.circle,
                                  image: imagePath != null && File(imagePath).existsSync()
                                      ? DecorationImage(
                                          image: FileImage(File(imagePath)),
                                          fit: BoxFit.cover,
                                        )
                                      : null,
                                ),
                                child: imagePath == null || !File(imagePath).existsSync()
                                    ? (_nameCtrl.text.isNotEmpty
                                        ? Center(
                                            child: Text(
                                              _nameCtrl.text[0],
                                              style: const TextStyle(
                                                fontSize: 28,
                                                fontWeight: FontWeight.w700,
                                                color: AppColors.primary,
                                              ),
                                            ),
                                          )
                                        : const Icon(Icons.person_rounded,
                                            size: 32, color: AppColors.primary))
                                    : null,
                              ),
                              Positioned(
                                right: 0,
                                bottom: 0,
                                child: Container(
                                  width: 24,
                                  height: 24,
                                  decoration: BoxDecoration(
                                    color: AppColors.primary,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                        color: Colors.white, width: 2),
                                  ),
                                  child: const Icon(Icons.camera_alt_rounded,
                                      size: 12, color: Colors.white),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              TextField(
                                controller: _nameCtrl,
                                onChanged: _saveName,
                                onTap: () => HapticFeedback.lightImpact(),
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textPrimary,
                                ),
                                decoration: const InputDecoration(
                                  hintText: 'ニックネームを入力',
                                  hintStyle: TextStyle(
                                    fontSize: 15,
                                    color: AppColors.textTertiary,
                                    fontWeight: FontWeight.w400,
                                  ),
                                  isDense: true,
                                  contentPadding: EdgeInsets.zero,
                                  border: InputBorder.none,
                                  enabledBorder: InputBorder.none,
                                  focusedBorder: InputBorder.none,
                                  fillColor: Colors.transparent,
                                  filled: false,
                                ),
                              ),
                              const SizedBox(height: 6),
                              // ホーム駅（タップで選択）
                              GestureDetector(
                                onTap: () => _pickHomeStation(context, ref),
                                child: Text(
                                  homeStationIdx != null
                                      ? '${kStations[homeStationIdx]}駅'
                                      : 'よく出発する駅',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: homeStationIdx != null
                                        ? AppColors.textSecondary
                                        : AppColors.primary,
                                    fontWeight: homeStationIdx != null
                                        ? FontWeight.w400
                                        : FontWeight.w600,
                                    decoration: TextDecoration.underline,
                                    decorationColor: homeStationIdx != null
                                        ? AppColors.textSecondary
                                        : AppColors.primary,
                                  ),
                                ),
                              ),
                              if (ageGroup != null) ...[
                                const SizedBox(height: 6),
                                _MiniChip(ageGroup),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // ─── プロフィール詳細 ──────────────────────────────────
                _SectionLabel('プロフィール詳細'),
                _SettingsGroup(
                  children: [
                    _NavItem(
                      label: '年代',
                      subtitle: ageGroup ?? '未設定',
                      onTap: () => _pickAgeGroup(context, ref),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // ─── よく使う条件 ─────────────────────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 6),
                  child: Text(
                    'よく使う条件',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                _DefaultConditionTile(
                  icon: Icons.people_outline_rounded,
                  label: 'デフォルト人数',
                  prefKey: 'default_group_size',
                  options: const ['2人', '3〜4人', '5人以上'],
                ),
                const SizedBox(height: 1, child: ColoredBox(color: Color(0xFFEEEEEE))),
                _DefaultConditionTile(
                  icon: Icons.schedule_rounded,
                  label: 'よく行くシーン',
                  prefKey: 'default_time_slot',
                  options: const ['ランチ', 'カフェ', 'ディナー', '飲み'],
                ),

                const SizedBox(height: 24),

                // ─── お気に入りの駅 ────────────────────────────────────
                _SectionLabel('よく使う駅'),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: AppColors.cardShadow,
                    ),
                    child: Column(
                      children: [
                        if (favorites.isEmpty)
                          Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 16),
                            child: Row(
                              children: [
                                Text(
                                  'よく使う駅を登録しておくと便利です',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Colors.grey.shade500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ...favorites.asMap().entries.map((e) {
                          final f = e.value;
                          final isLast = e.key == favorites.length - 1;
                          return Column(
                            children: [
                              ListTile(
                                dense: true,
                                contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 4),
                                title: Text(f.stationName,
                                    style: const TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w500)),
                                trailing: IconButton(
                                  icon: const Icon(Icons.close,
                                      size: 18, color: AppColors.textTertiary),
                                  onPressed: () {
                                    HapticFeedback.lightImpact();
                                    ref
                                        .read(favoritesProvider.notifier)
                                        .remove(f.stationIndex);
                                  },
                                ),
                              ),
                              if (!isLast)
                                const Padding(
                                  padding: EdgeInsets.only(left: 16),
                                  child: SizedBox(
                                    height: 1,
                                    child: ColoredBox(
                                        color: Color(0xFFEEEEEE)),
                                  ),
                                ),
                            ],
                          );
                        }),
                        if (favorites.isNotEmpty)
                          const Padding(
                            padding: EdgeInsets.only(left: 16),
                            child: SizedBox(
                              height: 1,
                              child: ColoredBox(color: Color(0xFFEEEEEE)),
                            ),
                          ),
                        ListTile(
                          dense: true,
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 4),
                          leading: Icon(
                            favorites.length >= 3
                                ? Icons.block_rounded
                                : Icons.add_rounded,
                            color: favorites.length >= 3
                                ? Colors.grey.shade400
                                : AppColors.primary,
                            size: 20,
                          ),
                          title: Text(
                            favorites.length >= 3 ? '3件登録済み（上限）' : '駅を追加',
                            style: TextStyle(
                              fontSize: 15,
                              color: favorites.length >= 3
                                  ? Colors.grey.shade400
                                  : AppColors.primary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          trailing: Text(
                            '${favorites.length} / 3',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: favorites.length >= 3
                                  ? AppColors.primary
                                  : Colors.grey.shade400,
                            ),
                          ),
                          onTap: favorites.length >= 3
                              ? null
                              : () => _addFavoriteStation(context, ref),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                // ─── アプリ設定 ────────────────────────────────────────
                _SectionLabel('アプリ設定'),
                _SettingsGroup(
                  children: [
                    _NavItem(
                      icon: Icons.gps_fixed_rounded,
                      label: '位置情報の設定',
                      subtitle: '「現在地」ボタンで最寄り駅\n自動選択します',
                      color: AppColors.primary,
                      trailing: FutureBuilder<LocationPermission>(
                        future: Geolocator.checkPermission(),
                        builder: (context, snap) {
                          final granted =
                              snap.data == LocationPermission.always ||
                                  snap.data == LocationPermission.whileInUse;
                          return Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                granted ? 'オン' : 'オフ',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: granted
                                      ? AppColors.primary
                                      : AppColors.textTertiary,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Icon(Icons.chevron_right_rounded,
                                  size: 18, color: Colors.grey.shade400),
                            ],
                          );
                        },
                      ),
                      onTap: () async {
                        await Geolocator.openAppSettings();
                      },
                    ),
                  ],
                ),

                const SizedBox(height: 24),

                // ─── 友だちに教える ────────────────────────────────────
                _SectionLabel('友だちに教える'),
                _SettingsGroup(
                  children: [
                    _NavItem(
                      icon: Icons.send_rounded,
                      label: 'LINEで紹介する',
                      color: const Color(0xFF06C755),
                      subtitle: '友達にAimaを教えよう',
                      onTap: () async {
                        const text =
                            'Aima — みんなが行きやすいお店を一緒に探せるアプリ！\nhttps://apps.apple.com/app/id0000000000';
                        final encoded = Uri.encodeComponent(text);
                        final lineUrl =
                            Uri.parse('https://line.me/R/share?text=$encoded');
                        if (await canLaunchUrl(lineUrl)) {
                          await launchUrl(lineUrl,
                              mode: LaunchMode.externalApplication);
                        } else {
                          await Share.share(text);
                        }
                      },
                    ),
                    _NavItem(
                      icon: Icons.share_rounded,
                      label: '友達に教える',
                      color: const Color(0xFF3B82F6),
                      subtitle: 'シェアして一緒に使おう',
                      onTap: () async {
                        await Share.share(
                          '【Aima】グループの集合場所が一発で決まるアプリ！\n'
                          'みんなの出発駅を入れるだけで、ちょうどいいお店を提案してくれます。',
                          sharePositionOrigin: Rect.fromCenter(
                            center: Offset(
                              MediaQuery.of(context).size.width / 2,
                              MediaQuery.of(context).size.height / 2,
                            ),
                            width: 100,
                            height: 100,
                          ),
                        );
                      },
                    ),
                  ],
                ),

                const SizedBox(height: 24),

                // ─── サポート ──────────────────────────────────────────
                _SectionLabel('サポート'),
                _SettingsGroup(
                  children: [
                    _NavItem(
                      icon: Icons.email_outlined,
                      label: 'お問い合わせ',
                      color: const Color(0xFF3B82F6),
                      onTap: () => launchUrl(
                        Uri.parse(
                          'mailto:support@mannaka.app?subject=Aima%20%E3%81%8A%E5%95%8F%E3%81%84%E5%90%88%E3%82%8F%E3%81%9B',
                        ),
                        mode: LaunchMode.externalApplication,
                      ),
                    ),
                    _NavItem(
                      icon: Icons.feedback_outlined,
                      label: 'バグ・改善要望を送る',
                      color: const Color(0xFFEF4444),
                      onTap: () => launchUrl(
                        Uri.parse(
                          'mailto:support@mannaka.app?subject=%E4%B8%8D%E5%85%B7%E5%90%88%E3%83%BB%E6%94%B9%E5%96%84%E8%A6%81%E6%9C%9B',
                        ),
                        mode: LaunchMode.externalApplication,
                      ),
                    ),
                    _NavItem(
                      icon: Icons.star_rounded,
                      label: 'レビューを書いて応援する',
                      color: const Color(0xFFF59E0B),
                      onTap: () {
                        // TODO: App Store公開後に実際のApp IDに変更する
                        // 例: https://apps.apple.com/jp/app/id1234567890
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('App Store公開後にご利用いただけます'),
                            duration: Duration(seconds: 2),
                          ),
                        );
                      },
                    ),
                    _NavItem(
                      icon: Icons.quiz_outlined,
                      label: '使い方・よくある質問',
                      color: const Color(0xFF10B981),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const SupportScreen()),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 24),

                // ─── 情報 ──────────────────────────────────────────────
                _SectionLabel('情報'),
                _SettingsGroup(
                  children: [
                    _NavItem(
                      icon: Icons.shield_outlined,
                      label: 'プライバシーポリシー',
                      color: const Color(0xFF6B7280),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const PrivacyPolicyScreen()),
                      ),
                    ),
                    _NavItem(
                      icon: Icons.article_outlined,
                      label: '利用規約',
                      color: const Color(0xFF6B7280),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const TermsScreen()),
                      ),
                    ),
                    _InfoItem(label: 'バージョン', value: '1.0.0'),
                  ],
                ),

                const SizedBox(height: 48),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _pickAgeGroup(BuildContext context, WidgetRef ref) async {
    if (_isNavigating) return;
    _isNavigating = true;
    HapticFeedback.lightImpact();
    final result = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => Container(
        height: MediaQuery.of(ctx).size.height * 0.6,
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
            const Text('年代',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Expanded(
              child: ListView(
                children: [
                  ..._kAgeGroups.map((g) => ListTile(
                    title: Text(g, style: const TextStyle(fontSize: 16)),
                    trailing: ref.watch(ageGroupProvider) == g
                        ? const Icon(Icons.check_rounded,
                            color: AppColors.primary)
                        : null,
                    onTap: () => Navigator.pop(ctx, g),
                  )),
                  ListTile(
                    title: const Text('回答しない',
                        style: TextStyle(
                            fontSize: 16, color: AppColors.textTertiary)),
                    onTap: () => Navigator.pop(ctx, ''),
                  ),
                ],
              ),
            ),
            SizedBox(height: MediaQuery.of(ctx).padding.bottom + 16),
          ],
        ),
      ),
    );
    if (result == null) return;
    final value = result.isEmpty ? null : result;
    ref.read(ageGroupProvider.notifier).state = value;
    final prefs = await SharedPreferences.getInstance();
    if (value != null) {
      await prefs.setString('age_group', value);
    } else {
      await prefs.remove('age_group');
    }
    if (mounted) _isNavigating = false;
  }


  Future<void> _pickHomeStation(BuildContext context, WidgetRef ref) async {
    if (_isNavigating) return;
    _isNavigating = true;
    HapticFeedback.lightImpact();
    final currentHome = ref.read(homeStationProvider);
    final favorites = ref.read(favoritesProvider);
    final result = await showModalBottomSheet<SelectedStation>(
      context: context,
      useRootNavigator: true,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => StationSearchSheet(
        currentIndex: currentHome,
        favorites: favorites,
      ),
    );
    if (mounted) _isNavigating = false;
    if (result != null) {
      // 検索用: kIndex が null の場合は lat/lng から最寄 kStation を特定
      final idx = result.kIndex ?? LocationService.nearestStationIndex(result.lat, result.lng);
      // 暫定座標でまず表示（kIndex がある場合は kStationLatLng を使用）
      final (provisionalLat, provisionalLng) = result.kIndex != null
          ? kStationLatLng[result.kIndex!]
          : (result.lat, result.lng);
      ref.read(homeStationDataProvider.notifier).state = HomeStationData(
        name: result.name, lat: provisionalLat, lng: provisionalLng);
      ref.read(homeStationProvider.notifier).state = idx;
      ref.read(searchProvider.notifier).setHomeStation(idx);
      // ホーム画面へ先に遷移（ユーザーをブロックしない）
      ref.read(navIndexProvider.notifier).state = 0;
      // Geocoding API で Google Maps の正確な座標を取得してピンを更新
      GeocodingService.getStationLatLng(result.name).then((coords) {
        if (coords == null) return;
        final (gLat, gLng) = coords;
        if (mounted) {
          ref.read(homeStationDataProvider.notifier).state = HomeStationData(
            name: result.name, lat: gLat, lng: gLng);
        }
        // prefs にも正確な座標を保存
        SharedPreferences.getInstance().then((prefs) {
          prefs.setInt('home_station', idx);
          prefs.setString('home_station_name', result.name);
          prefs.setDouble('home_station_lat', gLat);
          prefs.setDouble('home_station_lng', gLng);
        });
      });
      // prefs に暫定座標を先に保存（API失敗時のフォールバック）
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('home_station', idx);
      await prefs.setString('home_station_name', result.name);
      await prefs.setDouble('home_station_lat', provisionalLat);
      await prefs.setDouble('home_station_lng', provisionalLng);
    }
  }

  Future<void> _addFavoriteStation(
      BuildContext context, WidgetRef ref) async {
    HapticFeedback.lightImpact();
    final favorites = ref.read(favoritesProvider);
    final result = await showModalBottomSheet<SelectedStation>(
      context: context,
      useRootNavigator: true,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => StationSearchSheet(
        currentIndex: null,
        favorites: favorites,
      ),
    );
    if (result != null && result.kIndex != null) {
      final idx = result.kIndex!;
      ref.read(favoritesProvider.notifier).add(FavoriteStation(
            stationIndex: idx,
            stationName: kStations[idx],
            emoji: kStationEmojis[idx],
          ));
    }
  }

}

// ─── デフォルト条件タイル ─────────────────────────────────────────────────────
class _DefaultConditionTile extends StatefulWidget {
  const _DefaultConditionTile({
    required this.icon,
    required this.label,
    required this.prefKey,
    required this.options,
  });
  final IconData icon;
  final String label;
  final String prefKey;
  final List<String> options;

  @override
  State<_DefaultConditionTile> createState() => _DefaultConditionTileState();
}

class _DefaultConditionTileState extends State<_DefaultConditionTile> {
  String? _selected;

  @override
  void initState() {
    super.initState();
    SharedPreferences.getInstance().then((p) {
      final v = p.getString(widget.prefKey);
      if (mounted) setState(() => _selected = v);
    });
  }

  Future<void> _showPicker() async {
    HapticFeedback.lightImpact();
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              margin: const EdgeInsets.symmetric(vertical: 10),
              width: 36, height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Text(
              widget.label,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 16),
            ...widget.options.map((opt) {
              final isSelected = _selected == opt;
              return GestureDetector(
                onTap: () async {
                  HapticFeedback.selectionClick();
                  final next = _selected == opt ? null : opt;
                  setState(() => _selected = next);
                  final p = await SharedPreferences.getInstance();
                  if (next == null) {
                    p.remove(widget.prefKey);
                  } else {
                    p.setString(widget.prefKey, next);
                  }
                  if (ctx.mounted) Navigator.pop(ctx);
                },
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                  margin: const EdgeInsets.only(bottom: 8),
                  decoration: BoxDecoration(
                    color: isSelected ? AppColors.primaryLight : AppColors.background,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected ? AppColors.primary : AppColors.divider,
                      width: isSelected ? 1.5 : 1,
                    ),
                  ),
                  child: Text(
                    opt,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w400,
                      color: isSelected ? AppColors.primary : AppColors.textPrimary,
                    ),
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _showPicker,
      child: Container(
        color: AppColors.surface,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Icon(widget.icon, size: 18, color: AppColors.textSecondary),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                widget.label,
                style: const TextStyle(fontSize: 15, color: AppColors.textPrimary),
              ),
            ),
            Text(
              _selected ?? '未設定',
              style: TextStyle(
                fontSize: 14,
                color: _selected != null ? AppColors.primary : AppColors.textTertiary,
              ),
            ),
            const SizedBox(width: 6),
            Icon(Icons.chevron_right_rounded, size: 18, color: Colors.grey.shade400),
          ],
        ),
      ),
    );
  }
}

// ─── ミニチップ ───────────────────────────────────────────────────────────────
class _MiniChip extends StatelessWidget {
  const _MiniChip(this.label);
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.primaryLight,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: AppColors.primary,
        ),
      ),
    );
  }
}

// ─── セクションラベル ─────────────────────────────────────────────────────────
class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: AppColors.textSecondary,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}

// ─── グループコンテナ ─────────────────────────────────────────────────────────
class _SettingsGroup extends StatelessWidget {
  const _SettingsGroup({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: AppColors.cardShadow,
        ),
        child: Column(
          children: children.asMap().entries.map((e) {
            if (e.key < children.length - 1) {
              return Column(children: [
                e.value,
                const Padding(
                  padding: EdgeInsets.only(left: 52),
                  child: SizedBox(
                      height: 1, child: ColoredBox(color: Color(0xFFEEEEEE))),
                ),
              ]);
            }
            return e.value;
          }).toList(),
        ),
      ),
    );
  }
}

// ─── ナビゲーション行 ─────────────────────────────────────────────────────────
class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.label,
    required this.onTap,
    this.icon,
    this.color = AppColors.primary,
    this.subtitle,
    this.trailing,
  });
  final IconData? icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  final String? subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            if (icon != null) ...[
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 20, color: color),
              ),
              const SizedBox(width: 14),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: const TextStyle(
                          fontSize: 15, color: AppColors.textPrimary)),
                  if (subtitle != null)
                    Text(subtitle!,
                        style: const TextStyle(
                            fontSize: 12, color: AppColors.textSecondary)),
                ],
              ),
            ),
            trailing ??
                Icon(Icons.chevron_right_rounded,
                    color: Colors.grey.shade300, size: 20),
          ],
        ),
      ),
    );
  }
}

// ─── 情報行 ───────────────────────────────────────────────────────────────────
class _InfoItem extends StatelessWidget {
  const _InfoItem({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Expanded(
            child: Text(label,
                style: const TextStyle(
                    fontSize: 15, color: AppColors.textPrimary)),
          ),
          Text(value,
              style: const TextStyle(
                  fontSize: 14, color: AppColors.textSecondary)),
        ],
      ),
    );
  }
}
