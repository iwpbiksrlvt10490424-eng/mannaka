import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Firebase Auth のUIDを返す。
/// 匿名ログインが無効な場合はデバイス固有IDにフォールバック。
Future<String> ensureUid() async {
  // 既にログイン済みならそのUIDを使う
  final user = FirebaseAuth.instance.currentUser;
  if (user != null) return user.uid;

  // 匿名サインインを試みる
  try {
    final cred = await FirebaseAuth.instance.signInAnonymously();
    return cred.user!.uid;
  } catch (_) {
    // 匿名認証が無効の場合 → SharedPreferencesにデバイスIDを保存して使う
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString('_device_uid');
    if (stored != null) return stored;
    final newId = 'device_${DateTime.now().millisecondsSinceEpoch}';
    await prefs.setString('_device_uid', newId);
    return newId;
  }
}
