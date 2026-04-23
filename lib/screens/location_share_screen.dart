import 'dart:developer' as developer;

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../providers/auth_provider.dart';
import '../services/location_session_service.dart';
import '../theme/app_theme.dart';

class LocationShareScreen extends StatefulWidget {
  const LocationShareScreen({super.key, required this.sessionId});
  final String sessionId;

  @override
  State<LocationShareScreen> createState() => _LocationShareScreenState();
}

class _LocationShareScreenState extends State<LocationShareScreen> {
  String _hostName = '';
  bool _loading = true;
  bool _submitting = false;
  bool _done = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadSession();
  }

  Future<void> _loadSession() async {
    try {
      // 送信側の UID を確定させてから owner チェックする。
      // 未ログインだと uid が null で比較が壊れるため。
      await ensureUid();
      final data = await LocationSessionService.getSession(widget.sessionId);
      if (data == null) {
        if (!mounted) return;
        setState(() {
          _error = 'このリンクは無効または期限切れです';
          _loading = false;
        });
        return;
      }
      // 自分（host）が自分の招待リンクを開いた場合は送信させない。
      // Firestore rules でも update は owner 以外のみ許可するが、
      // UI でも早期に案内を出して誤操作を防ぐ。
      final ownerUid = data['ownerUid'] as String?;
      final myUid = FirebaseAuth.instance.currentUser?.uid;
      if (ownerUid != null && myUid != null && ownerUid == myUid) {
        if (!mounted) return;
        setState(() {
          _error = 'このリンクは相手に送って使ってもらうための招待です。\n'
              '自分の現在地を追加したい場合は、探す画面の駅入力欄で設定してください。';
          _loading = false;
        });
        return;
      }
      if (!mounted) return;
      setState(() {
        _hostName = data['hostName'] as String? ?? '';
        _loading = false;
      });
    } catch (e, st) {
      developer.log(
        '_loadSession failed - ${e.runtimeType}',
        name: 'LocationShareScreen',
        error: e,
        stackTrace: st,
      );
      if (!mounted) return;
      setState(() {
        _error = 'このリンクを開けませんでした。通信状況を確認してもう一度お試しください。';
        _loading = false;
      });
    }
  }

  Future<void> _submit() async {
    setState(() => _submitting = true);
    try {
      // GPS取得
      LocationPermission perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.deniedForever) {
        if (!mounted) return;
        setState(() {
          _error = '現在地を設定すると最寄駅が自動入力できます。設定 > プライバシー > 位置情報 から有効にしてください。';
          _submitting = false;
        });
        return;
      }
      final pos = await Geolocator.getCurrentPosition(
        locationSettings:
            const LocationSettings(accuracy: LocationAccuracy.high),
      );
      await LocationSessionService.submitLocation(
        sessionId: widget.sessionId,
        lat: pos.latitude,
        lng: pos.longitude,
      );
      if (!mounted) return;
      setState(() {
        _done = true;
        _submitting = false;
      });
    } catch (e, st) {
      developer.log(
        '_submit failed - ${e.runtimeType}',
        name: 'LocationShareScreen',
        error: e,
        stackTrace: st,
      );
      if (!mounted) return;
      setState(() {
        _error = '送信に失敗しました。通信状況を確認してもう一度お試しください。';
        _submitting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.pageBackground,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _done
                  ? _buildDone()
                  : _error != null
                      ? _buildError()
                      : _buildMain(),
        ),
      ),
    );
  }

  Widget _buildMain() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            color: AppColors.primaryLight,
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.location_on_rounded,
              size: 40, color: AppColors.primary),
        ),
        const SizedBox(height: 24),
        Text(
          '$_hostNameさんが\n出発エリアを聞いています',
          textAlign: TextAlign.center,
          style: const TextStyle(
              fontSize: 22, fontWeight: FontWeight.w800, height: 1.4),
        ),
        const SizedBox(height: 8),
        Text(
          'みんなにとってちょうどいいお店を\n一緒に探しています',
          textAlign: TextAlign.center,
          style: TextStyle(
              fontSize: 14, color: Colors.grey.shade600, height: 1.5),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: const Color(0xFFF0FDF4),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFF86EFAC)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.shield_outlined, size: 16, color: Color(0xFF16A34A)),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  '正確な現在地は相手に見えません\n最寄りエリアの情報のみ使用されます',
                  style: const TextStyle(
                      fontSize: 12, color: Color(0xFF15803D), height: 1.5),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 32),
        SizedBox(
          width: double.infinity,
          height: 56,
          child: ElevatedButton.icon(
            onPressed: _submitting ? null : _submit,
            icon: _submitting
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.near_me_rounded, size: 20),
            label: Text(
              _submitting ? '取得中...' : '出発エリアを共有する',
              style: const TextStyle(
                  fontSize: 16, fontWeight: FontWeight.w700),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          '現在地を設定すると最寄駅が自動入力できます',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 12, color: Colors.grey.shade400),
        ),
      ],
    );
  }

  Widget _buildDone() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 80,
          height: 80,
          decoration: const BoxDecoration(
              color: Color(0xFFD1FAE5), shape: BoxShape.circle),
          child: const Icon(Icons.check_rounded,
              size: 44, color: Color(0xFF059669)),
        ),
        const SizedBox(height: 24),
        const Text(
          '送信しました！',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 8),
        Text(
          '$_hostNameさんのアプリに\n出発エリアが届きました',
          textAlign: TextAlign.center,
          style: TextStyle(
              fontSize: 15,
              color: Colors.grey.shade600,
              height: 1.5),
        ),
        const SizedBox(height: 32),
        OutlinedButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('閉じる'),
        ),
      ],
    );
  }

  Widget _buildError() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.error_outline_rounded,
            size: 64, color: Colors.grey),
        const SizedBox(height: 16),
        Text(
          _error!,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 15),
        ),
        const SizedBox(height: 16),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('戻る'),
        ),
      ],
    );
  }
}
