import 'package:shared_preferences/shared_preferences.dart';

class NotificationService {
  static const _lastSearchKey = 'last_search_timestamp';

  static Future<void> recordSearch() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(
        _lastSearchKey, DateTime.now().millisecondsSinceEpoch);
  }

  static Future<bool> shouldShowRetentionNudge() async {
    final prefs = await SharedPreferences.getInstance();
    final last = prefs.getInt(_lastSearchKey);
    if (last == null) return false;
    final daysSince = DateTime.now()
        .difference(DateTime.fromMillisecondsSinceEpoch(last))
        .inDays;
    return daysSince >= 3; // 3日以上使っていない場合
  }
}
