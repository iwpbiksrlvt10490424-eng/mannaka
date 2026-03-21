import 'package:flutter_riverpod/flutter_riverpod.dart';

// ─── プロフィールプロバイダー ─────────────────────────────────────────────────
// settings_screen.dartから移動。ホーム画面など複数箇所から参照するため providers/ に配置。

final nicknameProvider = StateProvider<String>((ref) => '');
final homeStationProvider = StateProvider<int?>((ref) => null);
final ageGroupProvider = StateProvider<String?>((ref) => null);
final profileImagePathProvider = StateProvider<String?>((ref) => null);

/// ユーザーが実際に選択した駅の情報（ピン表示用）
class HomeStationData {
  const HomeStationData({
    required this.name,
    required this.lat,
    required this.lng,
  });
  final String name;
  final double lat;
  final double lng;
}

/// ホーム駅の実際の座標・名前（kStations に含まれない駅でも正確に保持）
final homeStationDataProvider = StateProvider<HomeStationData?>((ref) => null);
