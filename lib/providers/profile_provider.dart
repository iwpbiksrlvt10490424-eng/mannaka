import 'package:flutter_riverpod/flutter_riverpod.dart';

// ─── プロフィールプロバイダー ─────────────────────────────────────────────────
// settings_screen.dartから移動。ホーム画面など複数箇所から参照するため providers/ に配置。

final nicknameProvider = StateProvider<String>((ref) => '');
final homeStationProvider = StateProvider<int?>((ref) => null);
final ageGroupProvider = StateProvider<String?>((ref) => null);
final profileImagePathProvider = StateProvider<String?>((ref) => null);
