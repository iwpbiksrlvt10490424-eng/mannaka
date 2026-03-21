import 'package:flutter_riverpod/flutter_riverpod.dart';

/// アプリ全体のボトムナビゲーションインデックス
/// 設定画面などどこからでも参照・変更できるよう providers/ に配置
final navIndexProvider = StateProvider<int>((ref) => 0);
