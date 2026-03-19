import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'theme/app_theme.dart';
import 'screens/splash_screen.dart';
import 'screens/onboarding_screen.dart';
import 'screens/main_screen.dart';
import 'main.dart' show navigatorKey;

class MannakApp extends StatelessWidget {
  const MannakApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'まんなか',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      navigatorKey: navigatorKey,
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      supportedLocales: const [Locale('ja', 'JP'), Locale('en', 'US')],
      initialRoute: '/splash',
      routes: {
        '/splash': (_) => const SplashScreen(),
        '/onboarding': (_) => const OnboardingScreen(),
        '/main': (_) => const MainScreen(),
      },
    );
  }
}
