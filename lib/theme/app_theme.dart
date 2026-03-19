import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

abstract final class AppColors {
  // メインカラー（コーラルピンク）
  static const Color primary = Color(0xFFFF6B81);
  static const Color primaryLight = Color(0xFFFFF0F4);
  static const Color primaryBorder = Color(0xFFFFCDD9);

  // 背景・サーフェス
  static const Color background = Color(0xFFF7F7F8);
  static const Color surface = Color(0xFFFFFFFF);

  // ページ背景（ライトグレー — 白いカードが映える）
  static const Color pageBackground = Color(0xFFF7F7F7);

  // カード背景（ピュアホワイト）
  static const Color cardBg = Colors.white;

  // 統一スペーシング
  static const double spacing4 = 4;
  static const double spacing8 = 8;
  static const double spacing12 = 12;
  static const double spacing16 = 16;
  static const double spacing20 = 20;
  static const double spacing24 = 24;

  // アクセント背景
  static const Color accentBg = Color(0xFFF7F5F0);

  // テキスト
  static const Color textPrimary = Color(0xFF111827);
  static const Color textSecondary = Color(0xFF6B7280);
  static const Color textTertiary = Color(0xFF9CA3AF);

  // ボーダー・デバイダー
  static const Color border = Color(0xFFF3F4F6);
  static const Color divider = Color(0xFFE5E7EB);

  // セマンティックカラー
  static const Color success = Color(0xFF059669);
  static const Color warning = Color(0xFFD97706);
  static const Color star = Color(0xFFF59E0B);

  // カードの標準シャドウ
  static List<BoxShadow> get cardShadow => [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.06),
          blurRadius: 12,
          offset: const Offset(0, 2),
        ),
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.03),
          blurRadius: 3,
          offset: const Offset(0, 0),
        ),
      ];

  // CTAボタンのシャドウ（最小限）
  static List<BoxShadow> get ctaShadow => [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.08),
          blurRadius: 8,
          offset: const Offset(0, 2),
        ),
      ];

  /// カテゴリ別背景色（暖かみのある統一トーン）
  static Color getCategoryBg(String category) => switch (category) {
        'バー' => const Color(0xFF1E293B),
        _ => const Color(0xFFF7F5F0),
      };

  /// カテゴリ別アクセント色（暖かみのある統一トーン）
  static Color getCategoryColor(String category) => switch (category) {
        'バー' => const Color(0xFF64748B),
        _ => const Color(0xFF6B6560),
      };
}

abstract final class AppTheme {
  static ThemeData light() {
    const primary = AppColors.primary;

    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primary,
        brightness: Brightness.light,
        surface: AppColors.surface,
      ),
      scaffoldBackgroundColor: AppColors.background,
      fontFamily: '.SF Pro Text',
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        shadowColor: AppColors.divider,
        surfaceTintColor: Colors.transparent,
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.dark,
          statusBarBrightness: Brightness.light,
        ),
        titleTextStyle: TextStyle(
          color: AppColors.textPrimary,
          fontSize: 17,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.3,
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.border,
        thickness: 1,
        space: 1,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.background,
        hintStyle:
            const TextStyle(color: AppColors.textTertiary, fontSize: 15),
        border: OutlineInputBorder(
          borderRadius: const BorderRadius.all(Radius.circular(12)),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: const BorderRadius.all(Radius.circular(12)),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: const BorderRadius.all(Radius.circular(12)),
          borderSide: const BorderSide(color: primary, width: 1.5),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        shadowColor: AppColors.divider,
        elevation: 0.5,
        indicatorColor: AppColors.primaryLight,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: AppColors.primary,
              letterSpacing: -0.2,
            );
          }
          return const TextStyle(
            fontSize: 11,
            color: AppColors.textTertiary,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const IconThemeData(color: AppColors.primary, size: 22);
          }
          return const IconThemeData(color: AppColors.textTertiary, size: 22);
        }),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
      ),
    );
  }
}
