import 'package:flutter/material.dart';

/// LINE 風の吹き出しアイコン。CustomPaint で描画するため asset 追加不要。
/// filled=true（デフォルト）: LINE 緑の丸背景に白い吹き出し
/// filled=false: 指定色（iconColor）で吹き出しのみ描画
class LineIcon extends StatelessWidget {
  const LineIcon({
    super.key,
    this.size = 20,
    this.filled = true,
    this.iconColor,
  });

  final double size;
  final bool filled;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _LineIconPainter(
          filled: filled,
          iconColor: iconColor,
        ),
      ),
    );
  }
}

class _LineIconPainter extends CustomPainter {
  const _LineIconPainter({required this.filled, this.iconColor});
  final bool filled;
  final Color? iconColor;

  @override
  void paint(Canvas canvas, Size size) {
    if (filled) {
      final bg = Paint()..color = const Color(0xFF06C755);
      canvas.drawCircle(
        Offset(size.width / 2, size.height / 2),
        size.width / 2,
        bg,
      );
    }
    final fg = Paint()..color = iconColor ?? (filled ? Colors.white : const Color(0xFF06C755));
    final bubble = RRect.fromRectAndRadius(
      Rect.fromLTWH(
        size.width * 0.18,
        size.height * 0.20,
        size.width * 0.64,
        size.height * 0.44,
      ),
      const Radius.circular(3),
    );
    canvas.drawRRect(bubble, fg);
    final tail = Path()
      ..moveTo(size.width * 0.34, size.height * 0.63)
      ..lineTo(size.width * 0.24, size.height * 0.80)
      ..lineTo(size.width * 0.48, size.height * 0.63)
      ..close();
    canvas.drawPath(tail, fg);
  }

  @override
  bool shouldRepaint(_) => false;
}
