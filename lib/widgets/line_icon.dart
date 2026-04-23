import 'package:flutter/material.dart';

/// LINE 公式アプリを想起させるアイコン。
/// 商用ロゴは使えないため、CustomPaint で「緑の角丸正方形に白い吹き出し＋
/// LINE の文字」を描画する。他社アプリの LINE 共有ボタンで広く使われる表現。
///
/// - filled=true（デフォルト）: 緑の角丸矩形の中に白い吹き出し＋LINE文字
/// - filled=false: 指定色（iconColor）で吹き出しのみを描画（コンパクト用途）
class LineIcon extends StatelessWidget {
  const LineIcon({
    super.key,
    this.size = 24,
    this.filled = true,
    this.iconColor,
  });

  final double size;
  final bool filled;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    if (!filled) {
      // シンプル版（白アイコンなど、既に色背景の上に置く用途）
      return SizedBox(
        width: size,
        height: size,
        child: CustomPaint(painter: _BubblePainter(color: iconColor ?? const Color(0xFF06C755))),
      );
    }
    // ブランド版：緑角丸矩形 + 白い吹き出し + LINE 文字
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: const Color(0xFF06C755),
        borderRadius: BorderRadius.circular(size * 0.22),
      ),
      alignment: Alignment.center,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: size * 0.14),
          child: const Text(
            'LINE',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.5,
              fontSize: 11,
              height: 1.0,
            ),
          ),
        ),
      ),
    );
  }
}

/// ブランド塗りではない、シンプルな吹き出しだけのアイコン。
class _BubblePainter extends CustomPainter {
  _BubblePainter({required this.color});
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    final bubble = RRect.fromRectAndRadius(
      Rect.fromLTWH(
        size.width * 0.14,
        size.height * 0.18,
        size.width * 0.72,
        size.height * 0.50,
      ),
      Radius.circular(size.width * 0.10),
    );
    canvas.drawRRect(bubble, paint);
    final tail = Path()
      ..moveTo(size.width * 0.32, size.height * 0.65)
      ..lineTo(size.width * 0.22, size.height * 0.84)
      ..lineTo(size.width * 0.46, size.height * 0.65)
      ..close();
    canvas.drawPath(tail, paint);
  }

  @override
  bool shouldRepaint(covariant _BubblePainter oldDelegate) =>
      oldDelegate.color != color;
}
