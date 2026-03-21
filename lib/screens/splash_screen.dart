import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../providers/onboarding_provider.dart';
import '../providers/profile_provider.dart';
import '../theme/app_theme.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _fade;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 800));
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _scale = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeOutBack),
    );
    // SharedPreferences をアニメーションと並列で先読みしてキャッシュに乗せる
    SharedPreferences.getInstance();
    // アニメーション完了後すぐにナビゲート（固定遅延なし）
    _ctrl.addStatusListener((status) {
      if (status == AnimationStatus.completed) _navigate();
    });
    _ctrl.forward();
  }

  Future<void> _navigate() async {
    if (!mounted) return;
    // プロフィールデータをSharedPreferencesから読み込み
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    final nickname = prefs.getString('user_nickname') ?? '';
    final homeStation = prefs.getInt('home_station');
    final ageGroup = prefs.getString('age_group');
    final profileImagePath = prefs.getString('profile_image_path');
    if (nickname.isNotEmpty) ref.read(nicknameProvider.notifier).state = nickname;
    if (homeStation != null) ref.read(homeStationProvider.notifier).state = homeStation;
    if (ageGroup != null) ref.read(ageGroupProvider.notifier).state = ageGroup;
    if (profileImagePath != null) ref.read(profileImagePathProvider.notifier).state = profileImagePath;

    if (!mounted) return;
    final completed = ref.read(onboardingCompletedProvider);
    if (completed) {
      Navigator.of(context).pushReplacementNamed('/main');
    } else {
      Navigator.of(context).pushReplacementNamed('/onboarding');
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(color: AppColors.primary),
        child: Center(
          child: FadeTransition(
            opacity: _fade,
            child: ScaleTransition(
              scale: _scale,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 160,
                    height: 160,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(36),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.25),
                          blurRadius: 30,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(36),
                      child: Image.asset(
                        'assets/icon/app_icon.png',
                        width: 160,
                        height: 160,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'まんなか',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 36,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 2,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'お店が、集合場所になる。',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.85),
                      fontSize: 15,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
