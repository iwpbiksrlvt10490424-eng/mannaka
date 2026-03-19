import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

// ─── スプラッシュ: 地図ピン集合イラスト ────────────────────────────────────────
class SplashIllustration extends StatelessWidget {
  const SplashIllustration({super.key, this.size = 180});
  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: _SplashPainter()),
    );
  }
}

class _SplashPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;

    // 背景の大きな薄い円
    final bgPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.15)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(cx, cy), size.width * 0.45, bgPaint);

    // 中間の円
    final midPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.12)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(cx, cy), size.width * 0.32, midPaint);

    // 外側の人物ピン（3つ）
    final pinPositions = [
      Offset(cx - size.width * 0.28, cy - size.height * 0.1),
      Offset(cx + size.width * 0.28, cy - size.height * 0.1),
      Offset(cx, cy + size.height * 0.32),
    ];

    // 点線で中心へ繋ぐ
    final linePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.5)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    for (final pos in pinPositions) {
      _drawDashedLine(canvas, pos, Offset(cx, cy), linePaint);
    }

    // 人物ピン
    final personPinPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.9)
      ..style = PaintingStyle.fill;
    for (final pos in pinPositions) {
      // ピン本体（丸み）
      canvas.drawCircle(pos, size.width * 0.075, personPinPaint);
      // ピンの先
      final path = Path()
        ..moveTo(pos.dx - 5, pos.dy + size.width * 0.06)
        ..lineTo(pos.dx + 5, pos.dy + size.width * 0.06)
        ..lineTo(pos.dx, pos.dy + size.width * 0.12)
        ..close();
      canvas.drawPath(path, personPinPaint);
      // 人物アイコン（小さな円）
      canvas.drawCircle(
        pos,
        size.width * 0.042,
        Paint()..color = AppColors.primary.withValues(alpha: 0.8),
      );
    }

    // 中央の集合ピン（大きめ、白）
    final centerPinPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    final centerPinShadow = Paint()
      ..color = Colors.black.withValues(alpha: 0.15)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);

    // ピンの影
    canvas.drawCircle(
      Offset(cx, cy - size.width * 0.005 + 3),
      size.width * 0.115,
      centerPinShadow,
    );

    // 中央ピン本体
    canvas.drawCircle(Offset(cx, cy - size.width * 0.005), size.width * 0.11, centerPinPaint);
    final centerPath = Path()
      ..moveTo(cx - 7, cy + size.width * 0.095)
      ..lineTo(cx + 7, cy + size.width * 0.095)
      ..lineTo(cx, cy + size.width * 0.155)
      ..close();
    canvas.drawPath(centerPath, centerPinPaint);

    // 中央ピンの内側（primary色）
    canvas.drawCircle(
      Offset(cx, cy - size.width * 0.005),
      size.width * 0.063,
      Paint()..color = AppColors.primary,
    );

    // 中央の小さなドット（白）
    canvas.drawCircle(
      Offset(cx - 3, cy - size.width * 0.025),
      size.width * 0.018,
      Paint()..color = Colors.white.withValues(alpha: 0.9),
    );
  }

  void _drawDashedLine(Canvas canvas, Offset start, Offset end, Paint paint) {
    const dashLen = 5.0;
    const gapLen = 4.0;
    final dx = end.dx - start.dx;
    final dy = end.dy - start.dy;
    final dist = _sqrt(dx * dx + dy * dy);
    final steps = (dist / (dashLen + gapLen)).floor();
    final ux = dx / dist;
    final uy = dy / dist;
    for (int i = 0; i < steps; i++) {
      final s = i * (dashLen + gapLen);
      final e = s + dashLen;
      canvas.drawLine(
        Offset(start.dx + ux * s, start.dy + uy * s),
        Offset(start.dx + ux * e, start.dy + uy * e),
        paint,
      );
    }
  }

  double _sqrt(double x) {
    if (x <= 0) return 0;
    double r = x / 2;
    for (int i = 0; i < 20; i++) {
      r = (r + x / r) / 2;
    }
    return r;
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ─── オンボーディング1: 複数の出発地 ──────────────────────────────────────────
class OnboardingIllustration1 extends StatelessWidget {
  const OnboardingIllustration1({super.key});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 240,
      height: 200,
      child: CustomPaint(painter: _Onboarding1Painter()),
    );
  }
}

class _Onboarding1Painter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;

    // グリッド背景（地図っぽく）
    final gridPaint = Paint()
      ..color = AppColors.divider.withValues(alpha: 0.6)
      ..strokeWidth = 0.8;
    for (double x = 0; x <= size.width; x += 28) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }
    for (double y = 0; y <= size.height; y += 28) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    // 3人の出発地ピン
    final people = [
      (Offset(cx - 68, cy + 20), const Color(0xFF3B82F6), 'A'),
      (Offset(cx + 68, cy + 20), const Color(0xFF10B981), 'B'),
      (Offset(cx, cy - 60), AppColors.primary, 'C'),
    ];

    // 中央点線
    for (final (pos, color, _) in people) {
      _drawDashedLine(
        canvas,
        pos,
        Offset(cx, cy + 10),
        Paint()
          ..color = color.withValues(alpha: 0.4)
          ..strokeWidth = 1.5,
      );
    }

    // 中央の集合点（温かみのある丸）
    canvas.drawCircle(
      Offset(cx, cy + 10),
      20,
      Paint()..color = AppColors.primaryLight,
    );
    canvas.drawCircle(
      Offset(cx, cy + 10),
      20,
      Paint()
        ..color = AppColors.primary
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
    // 中央のフォーク+ナイフアイコン代わりに★
    final starPaint = Paint()..color = AppColors.primary;
    _drawStar(canvas, Offset(cx, cy + 10), 9, starPaint);

    // 各出発地ピン
    for (final (pos, color, label) in people) {
      _drawPin(canvas, pos, color, label);
    }
  }

  void _drawPin(Canvas canvas, Offset pos, Color color, String label) {
    final fill = Paint()..color = color;

    // ピン丸
    canvas.drawCircle(pos, 16, Paint()..color = color.withValues(alpha: 0.15));
    canvas.drawCircle(pos, 12, fill);
    // ピン先
    final path = Path()
      ..moveTo(pos.dx - 5, pos.dy + 10)
      ..lineTo(pos.dx + 5, pos.dy + 10)
      ..lineTo(pos.dx, pos.dy + 18)
      ..close();
    canvas.drawPath(path, fill);
    // ラベル
    final tp = TextPainter(
      text: TextSpan(
        text: label,
        style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(pos.dx - tp.width / 2, pos.dy - tp.height / 2));
  }

  void _drawStar(Canvas canvas, Offset center, double r, Paint paint) {
    final path = Path();
    for (int i = 0; i < 5; i++) {
      final outerAngle = (i * 72 - 90) * 3.14159 / 180;
      final innerAngle = outerAngle + 36 * 3.14159 / 180;
      final outer = Offset(
        center.dx + r * _cos(outerAngle),
        center.dy + r * _sin(outerAngle),
      );
      final inner = Offset(
        center.dx + r * 0.4 * _cos(innerAngle),
        center.dy + r * 0.4 * _sin(innerAngle),
      );
      if (i == 0) {
        path.moveTo(outer.dx, outer.dy);
      } else {
        path.lineTo(outer.dx, outer.dy);
      }
      path.lineTo(inner.dx, inner.dy);
    }
    path.close();
    canvas.drawPath(path, paint);
  }

  double _cos(double a) {
    double r = 1, t = 1;
    for (int i = 1; i <= 8; i++) {
      t *= -a * a / ((2 * i - 1) * (2 * i));
      r += t;
    }
    return r;
  }

  double _sin(double a) {
    double r = a, t = a;
    for (int i = 1; i <= 8; i++) {
      t *= -a * a / ((2 * i) * (2 * i + 1));
      r += t;
    }
    return r;
  }

  void _drawDashedLine(Canvas canvas, Offset start, Offset end, Paint paint) {
    const dashLen = 6.0;
    const gapLen = 4.0;
    final dx = end.dx - start.dx;
    final dy = end.dy - start.dy;
    final dist = _sqrt(dx * dx + dy * dy);
    if (dist == 0) return;
    final steps = (dist / (dashLen + gapLen)).floor();
    final ux = dx / dist;
    final uy = dy / dist;
    for (int i = 0; i < steps; i++) {
      final s = i * (dashLen + gapLen);
      final e = s + dashLen;
      canvas.drawLine(
        Offset(start.dx + ux * s, start.dy + uy * s),
        Offset(start.dx + ux * e, start.dy + uy * e),
        paint,
      );
    }
  }

  double _sqrt(double x) {
    if (x <= 0) return 0;
    double r = x / 2;
    for (int i = 0; i < 20; i++) {
      r = (r + x / r) / 2;
    }
    return r;
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ─── オンボーディング2: ちょうどいい場所 ──────────────────────────────────────
class OnboardingIllustration2 extends StatelessWidget {
  const OnboardingIllustration2({super.key});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 240,
      height: 200,
      child: CustomPaint(painter: _Onboarding2Painter()),
    );
  }
}

class _Onboarding2Painter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;

    // 同心円（公平さのビジュアル）
    for (int i = 3; i >= 1; i--) {
      canvas.drawCircle(
        Offset(cx, cy),
        i * 38.0,
        Paint()
          ..color = AppColors.primary.withValues(alpha: 0.04 * (4 - i))
          ..style = PaintingStyle.fill,
      );
      canvas.drawCircle(
        Offset(cx, cy),
        i * 38.0,
        Paint()
          ..color = AppColors.primary.withValues(alpha: 0.08 * (4 - i))
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1,
      );
    }

    // スケール（天秤）を表現するバランスビーム
    final beamPaint = Paint()
      ..color = AppColors.textSecondary.withValues(alpha: 0.3)
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;

    // 支柱
    canvas.drawLine(Offset(cx, cy - 10), Offset(cx, cy + 36), beamPaint);

    // 水平バー
    canvas.drawLine(
      Offset(cx - 44, cy - 10),
      Offset(cx + 44, cy - 10),
      Paint()
        ..color = AppColors.textPrimary.withValues(alpha: 0.5)
        ..strokeWidth = 2.5
        ..strokeCap = StrokeCap.round,
    );

    // 左皿（人物A）
    canvas.drawCircle(
      Offset(cx - 44, cy - 30),
      16,
      Paint()..color = const Color(0xFF3B82F6).withValues(alpha: 0.15),
    );
    canvas.drawCircle(
      Offset(cx - 44, cy - 30),
      16,
      Paint()
        ..color = const Color(0xFF3B82F6)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
    final tpA = TextPainter(
      text: const TextSpan(
        text: 'A',
        style: TextStyle(color: Color(0xFF3B82F6), fontSize: 12, fontWeight: FontWeight.bold),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tpA.paint(canvas, Offset(cx - 44 - tpA.width / 2, cy - 30 - tpA.height / 2));

    // 右皿（人物B）
    canvas.drawCircle(
      Offset(cx + 44, cy - 30),
      16,
      Paint()..color = const Color(0xFF10B981).withValues(alpha: 0.15),
    );
    canvas.drawCircle(
      Offset(cx + 44, cy - 30),
      16,
      Paint()
        ..color = const Color(0xFF10B981)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
    final tpB = TextPainter(
      text: const TextSpan(
        text: 'B',
        style: TextStyle(color: Color(0xFF10B981), fontSize: 12, fontWeight: FontWeight.bold),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tpB.paint(canvas, Offset(cx + 44 - tpB.width / 2, cy - 30 - tpB.height / 2));

    // 中央の場所マーカー（強調）
    final markerFill = Paint()..color = AppColors.primary;
    canvas.drawCircle(Offset(cx, cy + 58), 18, Paint()..color = AppColors.primaryLight);
    canvas.drawCircle(Offset(cx, cy + 58), 14, markerFill);
    // ピンの先
    final pin = Path()
      ..moveTo(cx - 5, cy + 58 + 12)
      ..lineTo(cx + 5, cy + 58 + 12)
      ..lineTo(cx, cy + 58 + 20)
      ..close();
    canvas.drawPath(pin, markerFill);
    canvas.drawCircle(Offset(cx, cy + 54), 5, Paint()..color = Colors.white);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ─── オンボーディング3: お店・予約 ────────────────────────────────────────────
class OnboardingIllustration3 extends StatelessWidget {
  const OnboardingIllustration3({super.key});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 240,
      height: 200,
      child: CustomPaint(painter: _Onboarding3Painter()),
    );
  }
}

class _Onboarding3Painter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;

    // 建物シルエット（レストラン）
    final buildingPaint = Paint()..color = AppColors.primaryLight;
    final buildingBorder = Paint()
      ..color = AppColors.primaryBorder
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    // メインビル（中央）
    final mainBuilding = RRect.fromRectAndRadius(
      Rect.fromLTWH(cx - 36, cy - 32, 72, 68),
      const Radius.circular(8),
    );
    canvas.drawRRect(mainBuilding, buildingPaint);
    canvas.drawRRect(mainBuilding, buildingBorder);

    // 屋根
    final roofPaint = Paint()..color = AppColors.primary;
    final roof = Path()
      ..moveTo(cx - 42, cy - 32)
      ..lineTo(cx, cy - 60)
      ..lineTo(cx + 42, cy - 32)
      ..close();
    canvas.drawPath(roof, roofPaint);

    // ドア
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(cx - 12, cy + 10, 24, 26),
        const Radius.circular(4),
      ),
      Paint()..color = AppColors.primary.withValues(alpha: 0.3),
    );

    // 窓（左右）
    for (final dx in [-22.0, 10.0]) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(cx + dx, cy - 18, 14, 14),
          const Radius.circular(3),
        ),
        Paint()..color = AppColors.primary.withValues(alpha: 0.2),
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(cx + dx, cy - 18, 14, 14),
          const Radius.circular(3),
        ),
        Paint()
          ..color = AppColors.primary.withValues(alpha: 0.4)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1,
      );
    }

    // 左の小ビル
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(cx - 90, cy - 6, 48, 42),
        const Radius.circular(6),
      ),
      Paint()..color = AppColors.background,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(cx - 90, cy - 6, 48, 42),
        const Radius.circular(6),
      ),
      buildingBorder,
    );

    // 右の小ビル
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(cx + 42, cy - 6, 48, 42),
        const Radius.circular(6),
      ),
      Paint()..color = AppColors.background,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(cx + 42, cy - 6, 48, 42),
        const Radius.circular(6),
      ),
      buildingBorder,
    );

    // 地面ライン
    canvas.drawLine(
      Offset(cx - 100, cy + 36),
      Offset(cx + 100, cy + 36),
      Paint()
        ..color = AppColors.divider
        ..strokeWidth = 1.5,
    );

    // チェックマーク（予約完了バッジ）
    final badgeBg = Paint()..color = const Color(0xFF059669);
    canvas.drawCircle(Offset(cx + 28, cy - 50), 14, badgeBg);
    // チェック
    final checkPaint = Paint()
      ..color = Colors.white
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    final check = Path()
      ..moveTo(cx + 22, cy - 50)
      ..lineTo(cx + 27, cy - 44)
      ..lineTo(cx + 36, cy - 57);
    canvas.drawPath(check, checkPaint);

    // ハート（人気）
    _drawHeart(canvas, Offset(cx - 28, cy - 50), 10, AppColors.primary.withValues(alpha: 0.8));
  }

  void _drawHeart(Canvas canvas, Offset center, double r, Color color) {
    final paint = Paint()..color = color;
    final path = Path();
    path.moveTo(center.dx, center.dy + r * 0.7);
    path.cubicTo(
      center.dx - r * 1.5, center.dy - r * 0.3,
      center.dx - r * 1.5, center.dy - r * 1.2,
      center.dx, center.dy - r * 0.4,
    );
    path.cubicTo(
      center.dx + r * 1.5, center.dy - r * 1.2,
      center.dx + r * 1.5, center.dy - r * 0.3,
      center.dx, center.dy + r * 0.7,
    );
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ─── 履歴空状態: 地図イラスト ─────────────────────────────────────────────────
class EmptyHistoryIllustration extends StatelessWidget {
  const EmptyHistoryIllustration({super.key});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 180,
      height: 160,
      child: CustomPaint(painter: _EmptyHistoryPainter()),
    );
  }
}

class _EmptyHistoryPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;

    // 地図カード
    final mapCard = RRect.fromRectAndRadius(
      Rect.fromLTWH(cx - 60, cy - 55, 120, 90),
      const Radius.circular(12),
    );
    canvas.drawRRect(mapCard, Paint()..color = Colors.white);
    canvas.drawRRect(
      mapCard,
      Paint()
        ..color = AppColors.border
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );

    // グリッド線
    final gridPaint = Paint()
      ..color = AppColors.border
      ..strokeWidth = 0.8;
    for (double x = cx - 40; x <= cx + 40; x += 20) {
      canvas.drawLine(Offset(x, cy - 55), Offset(x, cy + 35), gridPaint);
    }
    for (double y = cy - 35; y <= cy + 35; y += 20) {
      canvas.drawLine(Offset(cx - 60, y), Offset(cx + 60, y), gridPaint);
    }

    // 疑問符ピン（まだ記録なし）
    final pinFill = Paint()..color = AppColors.textTertiary.withValues(alpha: 0.5);
    canvas.drawCircle(Offset(cx, cy - 16), 14, pinFill);
    final pinTip = Path()
      ..moveTo(cx - 5, cy - 4)
      ..lineTo(cx + 5, cy - 4)
      ..lineTo(cx, cy + 4)
      ..close();
    canvas.drawPath(pinTip, pinFill);

    // ?
    final tp = TextPainter(
      text: const TextSpan(
        text: '?',
        style: TextStyle(
          color: Colors.white,
          fontSize: 14,
          fontWeight: FontWeight.w800,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(cx - tp.width / 2, cy - 16 - tp.height / 2 - 1));

    // 下の点線（ルートっぽく）
    final dotPaint = Paint()
      ..color = AppColors.textTertiary.withValues(alpha: 0.4)
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    for (double x = cx - 36; x <= cx + 36; x += 10) {
      canvas.drawCircle(Offset(x, cy + 52), 2, dotPaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ─── ホーム空状態: 人々が集まるイラスト ──────────────────────────────────────
class HomeEmptyIllustration extends StatelessWidget {
  const HomeEmptyIllustration({super.key});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 200,
      height: 140,
      child: CustomPaint(painter: _HomeEmptyPainter()),
    );
  }
}

class _HomeEmptyPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;

    // 中央のお店マーカー（暖かいオレンジ・レストランを表現）
    final centerPaint = Paint()..color = AppColors.primary;

    // 中央の大きな光輪
    canvas.drawCircle(Offset(cx, cy + 8), 34, Paint()..color = AppColors.primaryLight);
    canvas.drawCircle(Offset(cx, cy + 8), 26, centerPaint);

    // フォーク＆ナイフを中央に（白で）
    final whitePaint = Paint()
      ..color = Colors.white
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    // フォーク（左）
    canvas.drawLine(Offset(cx - 6, cy + 0), Offset(cx - 6, cy + 16), whitePaint);
    canvas.drawLine(Offset(cx - 9, cy + 0), Offset(cx - 9, cy + 8), whitePaint);
    canvas.drawLine(Offset(cx - 3, cy + 0), Offset(cx - 3, cy + 8), whitePaint);

    // ナイフ（右）
    canvas.drawLine(Offset(cx + 6, cy + 0), Offset(cx + 6, cy + 16), whitePaint);
    final bladePath = Path()
      ..moveTo(cx + 6, cy + 0)
      ..lineTo(cx + 10, cy + 6)
      ..lineTo(cx + 6, cy + 6);
    canvas.drawPath(bladePath, Paint()..color = Colors.white..style = PaintingStyle.fill);

    // 3人の人物（左・右・上）
    final people = [
      (Offset(cx - 64, cy + 16), const Color(0xFF3B82F6)),
      (Offset(cx + 64, cy + 16), const Color(0xFF10B981)),
      (Offset(cx, cy - 56), AppColors.primary),
    ];

    for (final (pos, color) in people) {
      // 人物の丸（頭）
      canvas.drawCircle(
        pos,
        13,
        Paint()..color = color.withValues(alpha: 0.12),
      );
      canvas.drawCircle(pos, 10, Paint()..color = color.withValues(alpha: 0.8));

      // 人物の白点（顔の輝き）
      canvas.drawCircle(
        Offset(pos.dx - 3, pos.dy - 3),
        2.5,
        Paint()..color = Colors.white.withValues(alpha: 0.7),
      );

      // 点線で中央へ
      final linePaint = Paint()
        ..color = color.withValues(alpha: 0.35)
        ..strokeWidth = 1.5;
      _drawDashedLine(canvas, pos, Offset(cx, cy + 8), linePaint);
    }

    // 中央に重ねて光輪を再描画（点線の上に）
    canvas.drawCircle(Offset(cx, cy + 8), 24, centerPaint);

    // フォーク（左）再描画
    canvas.drawLine(Offset(cx - 6, cy + 0), Offset(cx - 6, cy + 16), whitePaint);
    canvas.drawLine(Offset(cx - 9, cy + 0), Offset(cx - 9, cy + 8), whitePaint);
    canvas.drawLine(Offset(cx - 3, cy + 0), Offset(cx - 3, cy + 8), whitePaint);
    canvas.drawLine(Offset(cx - 6, cy + 8), Offset(cx - 6, cy + 10),
        Paint()..color = Colors.white..strokeWidth = 2.5..strokeCap = StrokeCap.round..style = PaintingStyle.stroke);

    // ナイフ（右）再描画
    canvas.drawLine(Offset(cx + 6, cy + 0), Offset(cx + 6, cy + 16), whitePaint);
  }

  void _drawDashedLine(Canvas canvas, Offset start, Offset end, Paint paint) {
    const dashLen = 5.0;
    const gapLen = 4.0;
    final dx = end.dx - start.dx;
    final dy = end.dy - start.dy;
    final dist = _sqrt(dx * dx + dy * dy);
    if (dist == 0) return;
    final steps = (dist / (dashLen + gapLen)).floor();
    final ux = dx / dist;
    final uy = dy / dist;
    for (int i = 0; i < steps; i++) {
      final s = i * (dashLen + gapLen);
      final e = s + dashLen;
      canvas.drawLine(
        Offset(start.dx + ux * s, start.dy + uy * s),
        Offset(start.dx + ux * e, start.dy + uy * e),
        paint,
      );
    }
  }

  double _sqrt(double x) {
    if (x <= 0) return 0;
    double r = x / 2;
    for (int i = 0; i < 20; i++) {
      r = (r + x / r) / 2;
    }
    return r;
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ─── オンボーディング3: アニメーション中間点計算イラスト ──────────────────────────
class AnimatedMidpointIllustration extends StatefulWidget {
  const AnimatedMidpointIllustration({super.key, this.size = 200});
  final double size;

  @override
  State<AnimatedMidpointIllustration> createState() =>
      _AnimatedMidpointIllustrationState();
}

class _AnimatedMidpointIllustrationState
    extends State<AnimatedMidpointIllustration>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 4000),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (_, __) => CustomPaint(
          painter: _MidpointAnimPainter(progress: _ctrl.value),
        ),
      ),
    );
  }
}

class _MidpointAnimPainter extends CustomPainter {
  const _MidpointAnimPainter({required this.progress});
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;

    final leftPos = Offset(size.width * 0.15, cy);
    final rightPos = Offset(size.width * 0.85, cy);
    final centerPos = Offset(cx, cy);

    final phase1 = (progress / 0.3).clamp(0.0, 1.0);
    final phase2 = ((progress - 0.3) / 0.2).clamp(0.0, 1.0);
    final phase3 = ((progress - 0.5) / 0.25).clamp(0.0, 1.0);

    if (phase1 > 0) {
      final dotRadius = 20.0 * phase1;
      canvas.drawCircle(leftPos, dotRadius,
          Paint()..color = const Color(0xFF3B82F6).withValues(alpha: 0.15 * phase1));
      canvas.drawCircle(leftPos, dotRadius * 0.65,
          Paint()..color = const Color(0xFF3B82F6).withValues(alpha: 0.9 * phase1));
      if (phase1 > 0.6) {
        final lblA = ((phase1 - 0.6) / 0.4).clamp(0.0, 1.0);
        final tpL = TextPainter(
          text: TextSpan(
            text: '渋谷',
            style: TextStyle(
              color: const Color(0xFF3B82F6).withValues(alpha: lblA),
              fontSize: size.width * 0.055,
              fontWeight: FontWeight.w700,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        tpL.paint(canvas, Offset(leftPos.dx - tpL.width / 2, leftPos.dy + dotRadius + 4));
      }
      canvas.drawCircle(rightPos, dotRadius,
          Paint()..color = const Color(0xFF10B981).withValues(alpha: 0.15 * phase1));
      canvas.drawCircle(rightPos, dotRadius * 0.65,
          Paint()..color = const Color(0xFF10B981).withValues(alpha: 0.9 * phase1));
      if (phase1 > 0.6) {
        final lblA = ((phase1 - 0.6) / 0.4).clamp(0.0, 1.0);
        final tpR = TextPainter(
          text: TextSpan(
            text: '新宿',
            style: TextStyle(
              color: const Color(0xFF10B981).withValues(alpha: lblA),
              fontSize: size.width * 0.055,
              fontWeight: FontWeight.w700,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        tpR.paint(canvas, Offset(rightPos.dx - tpR.width / 2, rightPos.dy + 24));
      }
    }

    if (phase2 > 0) {
      final leftEnd = Offset(
        leftPos.dx + (centerPos.dx - leftPos.dx) * phase2,
        leftPos.dy,
      );
      _drawDashedLine(canvas, leftPos, leftEnd,
        Paint()
          ..color = const Color(0xFF3B82F6).withValues(alpha: 0.5)
          ..strokeWidth = 1.8,
      );
      final rightEnd = Offset(
        rightPos.dx + (centerPos.dx - rightPos.dx) * phase2,
        rightPos.dy,
      );
      _drawDashedLine(canvas, rightPos, rightEnd,
        Paint()
          ..color = const Color(0xFF10B981).withValues(alpha: 0.5)
          ..strokeWidth = 1.8,
      );
    }

    if (phase3 > 0) {
      final pulseRadius = 16.0 + 12.0 * phase3;
      canvas.drawCircle(centerPos, pulseRadius,
          Paint()..color = AppColors.primary.withValues(alpha: 0.15 * (1.0 - phase3)));
      canvas.drawCircle(centerPos, 18.0 * phase3,
          Paint()..color = AppColors.primaryLight);
      canvas.drawCircle(centerPos, 14.0 * phase3,
          Paint()..color = AppColors.primary);
      if (phase3 > 0.5) {
        final alpha = ((phase3 - 0.5) / 0.5).clamp(0.0, 1.0);
        final whitePaint = Paint()
          ..color = Colors.white.withValues(alpha: alpha)
          ..strokeWidth = 2.0
          ..strokeCap = StrokeCap.round
          ..style = PaintingStyle.stroke;
        canvas.drawLine(Offset(cx - 4, cy - 6), Offset(cx - 4, cy + 6), whitePaint);
        canvas.drawLine(Offset(cx + 4, cy - 6), Offset(cx + 4, cy + 6), whitePaint);
      }
      if (phase3 > 0.5) {
        final lblAlpha = ((phase3 - 0.5) / 0.3).clamp(0.0, 1.0);
        final tp = TextPainter(
          text: TextSpan(
            text: 'まんなか',
            style: TextStyle(
              color: AppColors.primary.withValues(alpha: lblAlpha),
              fontSize: size.width * 0.055,
              fontWeight: FontWeight.w700,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        tp.paint(canvas, Offset(cx - tp.width / 2, cy + 24));
      }
    }
  }

  void _drawDashedLine(Canvas canvas, Offset start, Offset end, Paint paint) {
    const dashLen = 6.0;
    const gapLen = 4.0;
    final dx = end.dx - start.dx;
    final dy = end.dy - start.dy;
    final dist = math.sqrt(dx * dx + dy * dy);
    if (dist == 0) return;
    final steps = (dist / (dashLen + gapLen)).floor();
    final ux = dx / dist;
    final uy = dy / dist;
    for (int i = 0; i < steps; i++) {
      final s = i * (dashLen + gapLen);
      final e = s + dashLen;
      canvas.drawLine(
        Offset(start.dx + ux * s, start.dy + uy * s),
        Offset(start.dx + ux * e, start.dy + uy * e),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_MidpointAnimPainter old) => old.progress != progress;
}

// ─── オンボーディング1: 参加者入力アニメーション ──────────────────────────────
/// 「自分・友達A・友達Bが駅を選ぶ」様子を1人ずつ順番に表示するアニメーション
class AnimatedInputIllustration extends StatefulWidget {
  const AnimatedInputIllustration({super.key});

  @override
  State<AnimatedInputIllustration> createState() =>
      _AnimatedInputIllustrationState();
}

class _AnimatedInputIllustrationState extends State<AnimatedInputIllustration>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3200),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 260,
      height: 200,
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (_, __) {
          final t = _ctrl.value;
          final row1 = (t / 0.22).clamp(0.0, 1.0);
          final row2 = ((t - 0.28) / 0.22).clamp(0.0, 1.0);
          final row3 = ((t - 0.55) / 0.22).clamp(0.0, 1.0);
          final btnAlpha = t > 0.82 ? ((t - 0.82) / 0.18).clamp(0.0, 1.0) : 0.0;
          final btnPulse = 0.97 + 0.03 * math.sin(t * math.pi * 6);

          return Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _InputRow(
                progress: row1,
                name: '自分',
                station: '渋谷',
                color: const Color(0xFF3B82F6),
              ),
              const SizedBox(height: 6),
              _InputRow(
                progress: row2,
                name: '友達A',
                station: '池袋',
                color: const Color(0xFF10B981),
              ),
              const SizedBox(height: 6),
              _InputRow(
                progress: row3,
                name: '友達B',
                station: '横浜',
                color: AppColors.primary,
              ),
              const SizedBox(height: 10),
              Opacity(
                opacity: btnAlpha,
                child: Transform.scale(
                  scale: btnPulse,
                  child: Container(
                    width: 180,
                    height: 36,
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withValues(alpha: 0.35),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    alignment: Alignment.center,
                    child: const Text(
                      'まんなかを探す',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _InputRow extends StatelessWidget {
  const _InputRow({
    required this.progress,
    required this.name,
    required this.station,
    required this.color,
  });
  final double progress;
  final String name;
  final String station;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: progress.clamp(0.0, 1.0),
      child: Transform.translate(
        offset: Offset(16 * (1 - progress), 0),
        child: Container(
          width: 240,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.07),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.person_rounded, size: 16, color: color),
              ),
              const SizedBox(width: 8),
              Text(
                name,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1F2937),
                ),
              ),
              const Spacer(),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.train_rounded, size: 11, color: color),
                    const SizedBox(width: 3),
                    Text(
                      '$station駅',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: color,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── オンボーディング2: 自動計算 → 結果カード出現アニメーション ────────────────
/// 「計算中...→ 集合エリア決定！→ お店3件表示」の流れをアニメーション
class AnimatedResultIllustration extends StatefulWidget {
  const AnimatedResultIllustration({super.key});

  @override
  State<AnimatedResultIllustration> createState() =>
      _AnimatedResultIllustrationState();
}

class _AnimatedResultIllustrationState
    extends State<AnimatedResultIllustration>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3000),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 260,
      height: 200,
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (_, __) {
          final t = _ctrl.value;

          // Phase1 (0-0.3): ローディングドット
          final loadAlpha = (t < 0.3 ? 1.0 : (t < 0.4 ? (0.4 - t) / 0.1 : 0.0)).clamp(0.0, 1.0);
          // Phase2 (0.35-0.55): 集合エリアバッジ
          final badgeAlpha = t > 0.35 ? ((t - 0.35) / 0.15).clamp(0.0, 1.0) : 0.0;
          final badgeScale = t > 0.35
              ? (0.7 + 0.3 * ((t - 0.35) / 0.15).clamp(0.0, 1.0))
              : 0.7;
          // Phase3 (0.5-0.9): お店リスト（3件順番に）
          final shop1 = t > 0.5 ? ((t - 0.5) / 0.12).clamp(0.0, 1.0) : 0.0;
          final shop2 = t > 0.62 ? ((t - 0.62) / 0.12).clamp(0.0, 1.0) : 0.0;
          final shop3 = t > 0.74 ? ((t - 0.74) / 0.12).clamp(0.0, 1.0) : 0.0;

          return Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // ローディング
              Opacity(
                opacity: loadAlpha,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(3, (i) {
                    final bounce = math.sin(
                            (t * 8 - i * 0.4) * math.pi)
                        .clamp(0.0, 1.0);
                    return Container(
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      child: Transform.translate(
                        offset: Offset(0, -6 * bounce),
                        child: Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(
                                alpha: 0.4 + 0.6 * bounce),
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                    );
                  }),
                ),
              ),

              // 集合エリアバッジ
              Opacity(
                opacity: badgeAlpha,
                child: Transform.scale(
                  scale: badgeScale,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withValues(alpha: 0.3),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.train_rounded,
                            size: 15, color: Colors.white),
                        SizedBox(width: 6),
                        Text(
                          '新宿駅 周辺',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 10),

              // お店リスト
              _ShopRow(
                  progress: shop1,
                  name: '炭火焼き鳥 まんなか',
                  genre: '焼き鳥',
                  color: const Color(0xFFF59E0B)),
              const SizedBox(height: 5),
              _ShopRow(
                  progress: shop2,
                  name: 'イタリアン Trattoria',
                  genre: 'イタリアン',
                  color: const Color(0xFF10B981)),
              const SizedBox(height: 5),
              _ShopRow(
                  progress: shop3,
                  name: '個室居酒屋 はなれ',
                  genre: '居酒屋',
                  color: const Color(0xFF8B5CF6)),
            ],
          );
        },
      ),
    );
  }
}

class _ShopRow extends StatelessWidget {
  const _ShopRow({
    required this.progress,
    required this.name,
    required this.genre,
    required this.color,
  });
  final double progress;
  final String name;
  final String genre;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: progress.clamp(0.0, 1.0),
      child: Transform.translate(
        offset: Offset(0, 10 * (1 - progress)),
        child: Container(
          width: 240,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.06),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(Icons.restaurant_menu_rounded,
                    size: 13, color: color),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  name,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1F2937),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  genre,
                  style: TextStyle(
                      fontSize: 10, color: color, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
