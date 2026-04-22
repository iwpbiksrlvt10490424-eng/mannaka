import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
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
    title: '集合場所、\nもう迷わない。',
    body: '渋谷、池袋、横浜——バラバラでも大丈夫。\nみんなにちょうどいいお店が、すぐ見つかる。',
  ),
  _Slide(
    title: '「どこにしよう」の\n迷いをなくそう。',
    body: '駅を入れるだけで、\nみんなにちょうどいいお店が見つかる。',
    caption: '探すタブの「+」で参加者を追加',
  ),
  _Slide(
    title: '現在地設定で\nもっとラクに。',
    body: '位置情報を許可すると、\n最寄り駅が自動で入ります。',
    caption: 'マイページ > 位置情報の設定',
  ),
  _Slide(
    title: '予約時間も決められる。',
    body: '日にち・予約したい時間を選べば、\nその時間に開いているお店を提案。',
    caption: '「日程・予約時間を選択」から',
  ),
  _Slide(
    title: '候補を選んでまとめてLINE。',
    body: '気になるお店のカード右上の「+」で候補に追加。\n何件でも選べて、まとめて LINE で送れます。',
    caption: '駅タブを跨いで選択が保持されます',
  ),
  _Slide(
    title: 'アプリがなくても見れる。',
    body: '送った相手がアプリ未インストールでも、\nWeb ページで候補を閲覧できます。',
    caption: 'LINE 本文に Web URL が自動で付きます',
  ),
  _Slide(
    title: 'あとで送りたいときは保存。',
    body: '忙しくて今送れないときは「保存」をタップ。\nマイページから後でまとめて送れます。',
    caption: 'マイページ > 保存した候補',
  ),
  _Slide(
    title: '予約・訪問の記録も。',
    body: '予約できた・行けたお店を手動で追加できます。\nグループ単位で履歴を振り返れます。',
    caption: '予約済み / 行ったお店 画面の「+」',
  ),
  _Slide(
    title: '今日から、もっと\n気軽に集まれる。',
    body: 'Aimachi は無料。\nさっそく今日の集合場所を探してみましょう。',
    caption: null,
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
