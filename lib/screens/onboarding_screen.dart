import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../providers/onboarding_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/illustrations.dart';

class _Slide {
  const _Slide({required this.title, required this.body});
  final String title;
  final String body;
}

// UX critique を反映: オンボーディングは Aimachi の「価値」を 4 枚に圧縮。
// 操作説明（GPS 設定 / 保存 / 予約記録）は使い方ガイドや FAQ で補完する。
// 4 枚に絞る理由: 8 枚は離脱率が高い。Aimachi が普通のグルメ検索ではなく
// 「集合場所を計算するアプリ」だと最初に伝えることが最重要。
const _slides = [
  _Slide(
    title: 'みんなの真ん中で、\nお店を探そう。',
    body: '友達それぞれの出発駅から、\nみんなが集まりやすい場所を提案します。',
  ),
  _Slide(
    title: '移動時間のバランスを\n見える化。',
    body: '誰かだけ遠くならないように、\n集合駅ごとの移動時間を比較できます。',
  ),
  _Slide(
    title: '条件に合うお店をまとめて表示。',
    body: 'ジャンル・予算・個室・予約可などで、\nちょうどいいお店を探せます。',
  ),
  _Slide(
    title: 'LINEで共有して、\nみんなで決める。',
    body: '候補のお店や集合場所を、\n友達にそのまま送れます。',
  ),
];

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _pageCtrl = PageController();
  int _page = 0;

  void _next() {
    if (_page < _slides.length - 1) {
      _pageCtrl.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      _finish();
    }
  }

  Future<void> _finish() async {
    ref.read(onboardingCompletedProvider.notifier).state = true;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarding_completed', true);
    if (!mounted) return;
    Navigator.of(context).pushReplacementNamed('/main');
  }

  @override
  void dispose() {
    _pageCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: Alignment.topRight,
              child: TextButton(
                onPressed: _finish,
                child: const Text('スキップ', style: TextStyle(color: Colors.grey)),
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _pageCtrl,
                itemCount: _slides.length,
                onPageChanged: (i) => setState(() => _page = i),
                itemBuilder: (ctx, i) => _SlidePage(slide: _slides[i], slideIndex: i),
              ),
            ),
            // Dots
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(_slides.length, (i) {
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: _page == i ? 24 : 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: _page == i ? AppColors.primary : Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(4),
                  ),
                );
              }),
            ),
            const SizedBox(height: 24),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: GestureDetector(
                onTap: _next,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    _page == _slides.length - 1 ? 'はじめる' : 'つぎへ',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}

class _SlidePage extends StatelessWidget {
  const _SlidePage({required this.slide, required this.slideIndex});
  final _Slide slide;
  final int slideIndex;

  @override
  Widget build(BuildContext context) {
    final illustrations = [
      const AnimatedInputIllustration(),
      const AnimatedMidpointIllustration(size: 200),
      const AnimatedResultIllustration(),
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          illustrations[slideIndex],
          const SizedBox(height: 40),
          Text(
            slide.title,
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Text(
            slide.body,
            style: TextStyle(fontSize: 15, color: Colors.grey.shade600, height: 1.6),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
