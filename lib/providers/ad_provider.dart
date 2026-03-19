import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/ad.dart';

// 将来はFirestore/APIから取得する。リリース時はモックデータ非表示。
final adsProvider = Provider<List<AppAd>>((ref) => const []);
