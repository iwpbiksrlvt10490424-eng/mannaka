import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/onboarding_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/illustrations.dart';

class _Slide {
  const _Slide({required this.title, required this.body, this.caption});
  final String title;
  final String body;
  final String? caption; // ボタン直前に表示する一言
}

const _slides = [
  _Slide(
    title: '「どこでもいい」は、\nもう終わりにしよう。',
    body: 'あの子は東京、私は横浜、彼女は川崎。\nそんな3人にも、ちょうどいい場所がある。',
  ),
  _Slide(
    title: '「場所どうする？」の\nLINEが、消える。',
    body: '駅を入れて、お店を選んで、リンクを送るだけ。\nあの終わらない「どこでもいいよ〜」の往復が\n一瞬で終わる。',
  ),
  _Slide(
    title: '今日、どこで会おうか。',
    body: '友達と過ごす時間は、場所を決める手間より\nずっと大切なはず。\nまんなかで、そのぶんだけ長く笑っていよう。',
    caption: '準備は、駅の名前だけ。',
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

  void _finish() {
    ref.read(onboardingCompletedProvider.notifier).state = true;
    Navigator.of(context).pushReplacementNamed('/main');
  }

  @override
  void dispose() {
    _pageCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentSlide = _slides[_page];
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
            // キャプション（最終スライドのみ）
            AnimatedOpacity(
              opacity: currentSlide.caption != null ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 300),
              child: Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Text(
                  currentSlide.caption ?? '',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey.shade500,
                    fontWeight: FontWeight.w500,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
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
