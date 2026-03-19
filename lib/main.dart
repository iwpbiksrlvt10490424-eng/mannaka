import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:app_links/app_links.dart';
import 'firebase_options.dart';
import 'app.dart';
import 'screens/location_share_screen.dart';
import 'screens/voting_screen.dart';

final navigatorKey = GlobalKey<NavigatorState>();

/// sessionId のバリデーション（英数字大文字+数字、6文字、紛らわしい文字除外）
final _sessionIdPattern = RegExp(r'^[A-HJ-NP-Z2-9]{6}$');

/// voterName のサニタイズ（制御文字除去、20文字制限）
String _sanitizeVoterName(String raw) {
  // 制御文字を除去
  final cleaned = raw.replaceAll(RegExp(r'[\x00-\x1F\x7F]'), '');
  // 20文字に制限
  if (cleaned.length > 20) return cleaned.substring(0, 20);
  return cleaned.isEmpty ? 'ゲスト' : cleaned;
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Deep link handler
  final appLinks = AppLinks();
  appLinks.uriLinkStream.listen((uri) {
    if (uri.scheme == 'mannaka' && uri.host == 'location') {
      final sessionId = uri.queryParameters['session'];
      if (sessionId != null && _sessionIdPattern.hasMatch(sessionId)) {
        navigatorKey.currentState?.push(MaterialPageRoute(
          builder: (_) => LocationShareScreen(sessionId: sessionId),
        ));
      } else {
        debugPrint('Deep link: 不正な sessionId を無視: $sessionId');
      }
    } else if (uri.scheme == 'mannaka' && uri.host == 'vote') {
      final sessionId = uri.queryParameters['session'];
      final rawVoterName = uri.queryParameters['voter'] ?? 'ゲスト';
      if (sessionId != null && _sessionIdPattern.hasMatch(sessionId)) {
        final voterName = _sanitizeVoterName(rawVoterName);
        navigatorKey.currentState?.push(MaterialPageRoute(
          builder: (_) => VotingScreen(sessionId: sessionId, voterName: voterName),
        ));
      } else {
        debugPrint('Deep link: 不正な sessionId を無視: $sessionId');
      }
    }
  });

  runApp(const ProviderScope(child: MannakApp()));
}
