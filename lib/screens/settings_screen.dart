import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import '../theme/app_theme.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _haptic = true;
  bool _notification = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('設定', style: TextStyle(fontWeight: FontWeight.w800)),
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _ProfileCard(),
          const SizedBox(height: 16),
          _SectionLabel('アプリ設定'),
          _SettingsGroup(
            children: [
              _SwitchItem(
                icon: Icons.vibration_rounded,
                label: '触覚フィードバック',
                color: AppColors.primary,
                value: _haptic,
                onChanged: (v) => setState(() => _haptic = v),
              ),
              _SwitchItem(
                icon: Icons.notifications_rounded,
                label: '通知',
                color: const Color(0xFF3B82F6),
                value: _notification,
                onChanged: (v) => setState(() => _notification = v),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _SectionLabel('計算設定'),
          _SettingsGroup(
            children: [
              _NavItem(
                icon: Icons.tune_rounded,
                label: '重み設定',
                color: AppColors.secondary,
                subtitle: '効率性 40% / 公平性 60%',
                onTap: () => _showWeightInfo(context),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _SectionLabel('サポート'),
          _SettingsGroup(
            children: [
              _NavItem(
                icon: Icons.help_outline_rounded,
                label: 'ヘルプ・使い方',
                color: const Color(0xFF10B981),
                onTap: () {},
              ),
              _NavItem(
                icon: Icons.star_outline_rounded,
                label: 'アプリを評価する',
                color: const Color(0xFFF59E0B),
                onTap: () {},
              ),
              _NavItem(
                icon: Icons.mail_outline_rounded,
                label: 'お問い合わせ',
                color: Colors.grey,
                onTap: () {},
              ),
            ],
          ),
          const SizedBox(height: 16),
          _SectionLabel('情報'),
          _SettingsGroup(
            children: [
              _NavItem(
                icon: Icons.privacy_tip_outlined,
                label: 'プライバシーポリシー',
                color: Colors.grey,
                onTap: () {},
              ),
              _NavItem(
                icon: Icons.description_outlined,
                label: '利用規約',
                color: Colors.grey,
                onTap: () {},
              ),
              _InfoItem(label: 'バージョン', value: '1.0.0'),
            ],
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  void _showWeightInfo(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('計算の重みについて'),
        content: const Text(
          '集合場所のスコアは以下の重みで計算されます。\n\n'
          '• 効率性（移動時間の合計）: 40%\n'
          '• 公平性（移動時間のばらつき）: 60%\n\n'
          '全員がなるべく同じ時間で来られる場所を優先しています。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('閉じる'),
          ),
        ],
      ),
    );
  }
}

class _ProfileCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: AppColors.primaryGradient,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.3),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.25),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: const Text('🗺️', style: TextStyle(fontSize: 30)),
          ),
          const SizedBox(width: 16),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'まんなか',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'みんなが集まりやすい場所へ',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: Colors.grey.shade500,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

class _SettingsGroup extends StatelessWidget {
  const _SettingsGroup({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: children.asMap().entries.map((e) {
          final Widget child = e.value;
          if (e.key < children.length - 1) {
            return Column(
              children: [child, const Divider(height: 1, indent: 52)],
            );
          }
          return child;
        }).toList(),
      ),
    );
  }
}

class _SwitchItem extends StatelessWidget {
  const _SwitchItem({
    required this.icon,
    required this.label,
    required this.color,
    required this.value,
    required this.onChanged,
  });
  final IconData icon;
  final String label;
  final Color color;
  final bool value;
  final void Function(bool) onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 18, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(child: Text(label, style: const TextStyle(fontSize: 15))),
          CupertinoSwitch(
            value: value,
            onChanged: onChanged,
            activeTrackColor: AppColors.primary,
          ),
        ],
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
    this.subtitle,
  });
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, size: 18, color: color),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: const TextStyle(fontSize: 15)),
                  if (subtitle != null)
                    Text(subtitle!, style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: Colors.grey.shade400, size: 20),
          ],
        ),
      ),
    );
  }
}

class _InfoItem extends StatelessWidget {
  const _InfoItem({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Expanded(child: Text(label, style: const TextStyle(fontSize: 15))),
          Text(value, style: TextStyle(fontSize: 14, color: Colors.grey.shade500)),
        ],
      ),
    );
  }
}
