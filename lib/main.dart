import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:app_links/app_links.dart';
import 'firebase_options.dart';
import 'app.dart';
import 'models/restaurant.dart';
import 'screens/location_share_screen.dart';
import 'screens/restaurant_detail_screen.dart';
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
    } else if (uri.scheme == 'mannaka' && uri.host == 'restaurant') {
      _handleRestaurantDeepLink(uri);
    }
  });

  // アプリが閉じている状態から起動した場合の初期リンク処理
  final initialUri = await appLinks.getInitialLink();
  if (initialUri != null &&
      initialUri.scheme == 'mannaka' &&
      initialUri.host == 'restaurant') {
    // スプラッシュ完了後に処理するため遅延
    Future.delayed(const Duration(seconds: 2), () {
      _handleRestaurantDeepLink(initialUri);
    });
  }

  runApp(const ProviderScope(child: MannakApp()));
}

/// `mannaka://restaurant?name=...&lat=...&lng=...&address=...&category=...&url=...`
/// を受け取ってお店の詳細画面へ遷移する。
void _handleRestaurantDeepLink(Uri uri) {
  final p = uri.queryParameters;
  final name = p['name'] ?? '';
  if (name.isEmpty) return;

  // 文字列サニタイズ（制御文字除去、長さ制限）
  String clean(String? s, {int max = 200}) {
    if (s == null) return '';
    final c = s.replaceAll(RegExp(r'[\x00-\x1F\x7F]'), '').trim();
    return c.length > max ? c.substring(0, max) : c;
  }

  final lat = double.tryParse(p['lat'] ?? '');
  final lng = double.tryParse(p['lng'] ?? '');

  // 緯度経度の範囲バリデーション
  if (lat != null && (lat < -90 || lat > 90)) return;
  if (lng != null && (lng < -180 || lng > 180)) return;

  final restaurant = Restaurant(
    id: clean(p['id'], max: 100).isNotEmpty ? clean(p['id'], max: 100) : 'shared',
    name: clean(name, max: 100),
    stationIndex: 0,
    category: clean(p['category'], max: 50),
    rating: double.tryParse(p['rating'] ?? '') ?? 0,
    reviewCount: 0,
    priceLabel: clean(p['price'], max: 50),
    priceAvg: 0,
    tags: const [],
    emoji: '🍽',
    description: '',
    distanceMinutes: 0,
    address: clean(p['address'], max: 200),
    openHours: clean(p['hours'], max: 200),
    lat: lat,
    lng: lng,
    hotpepperUrl: () {
      final url = p['url'];
      if (url == null) return null;
      final uri2 = Uri.tryParse(url);
      return (uri2 != null && uri2.scheme == 'https') ? url : null;
    }(),
    isReservable: p['url'] != null,
    accessInfo: clean(p['access'], max: 200),
    stationName: clean(p['station'], max: 50),
    closeDay: clean(p['closeDay'], max: 100),
  );

  navigatorKey.currentState?.push(MaterialPageRoute(
    builder: (_) => RestaurantDetailScreen(restaurant: restaurant),
  ));
}
