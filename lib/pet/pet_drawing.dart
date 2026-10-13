import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../core/models.dart';

// Shared by the Flame room, focus companion and floating preview.
void drawPet(
  Canvas canvas,
  Offset at,
  double scale,
  PetState pet, {
  bool sleeping = false,
  double motion = 0,
  bool happy = false,
}) {
  canvas.save();
  canvas.translate(at.dx, at.dy);
  canvas.scale(scale);
  final fur = pet.colorIndex == 1
      ? const Color(0xFFD6D3C8)
      : const Color(0xFFEBA760);
  final shade = pet.colorIndex == 1
      ? const Color(0xFF68615A)
      : const Color(0xFFC47F43);
  final ink = Paint()
    ..color = const Color(0xFF483528)
    ..strokeWidth = 2.7
    ..strokeCap = StrokeCap.round
    ..style = PaintingStyle.stroke;
  final width = 35 + pet.energy * 18;
  final breathing = math.sin(motion * 2) * 1.5;
  canvas.drawOval(
    Rect.fromCenter(center: const Offset(0, 5), width: 115, height: 23),
    Paint()..color = const Color(0x1E6D5036),
  );
  if (pet.dead) {
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(-48, -30, 96, 28),
        const Radius.circular(14),
      ),
      Paint()..color = const Color(0xFFC9BDAF),
    );
    canvas.drawCircle(
      const Offset(0, -47),
      12,
      Paint()..color = const Color(0xFFF3EEE4),
    );
    canvas.restore();
    return;
  }
  final tail = Path()
    ..moveTo(width * .55, -28)
    ..cubicTo(85, -28, 86, -74 + math.sin(motion) * 8, 65, -72);
  canvas.drawPath(
    tail,
    Paint()
      ..color = shade
      ..strokeWidth = 17
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke,
  );
  canvas.drawOval(
    Rect.fromCenter(
      center: Offset(0, -31 + breathing),
      width: width * 1.9,
      height: sleeping ? 44 : 68,
    ),
    Paint()..color = fur,
  );
  for (final x in [-24.0, 24.0]) {
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(x * pet.energy.clamp(.65, 1), -2),
        width: 28,
        height: 15,
      ),
      Paint()..color = const Color(0xFFF7D2A0),
    );
  }
  canvas.translate(0, sleeping ? 13 : 0);
  final ears = Path()
    ..moveTo(-43, -70)
    ..lineTo(-40, -119)
    ..lineTo(-12, -91)
    ..moveTo(43, -70)
    ..lineTo(40, -119)
    ..lineTo(12, -91);
  canvas.drawPath(ears, Paint()..color = fur);
  final inner = Path()
    ..moveTo(-34, -88)
    ..lineTo(-33, -109)
    ..lineTo(-19, -91)
    ..moveTo(34, -88)
    ..lineTo(33, -109)
    ..lineTo(19, -91);
  canvas.drawPath(inner, Paint()..color = const Color(0xFFE7A394));
  canvas.drawOval(const Rect.fromLTWH(-48, -102, 96, 75), Paint()..color = fur);
  canvas.drawOval(
    const Rect.fromLTWH(-27, -61, 54, 27),
    Paint()..color = const Color(0xFFFFE5C0),
  );
  for (final x in [-19.0, 19.0]) {
    if (sleeping || happy || pet.hungryDays >= 5) {
      final eye = Path()
        ..moveTo(x - 6, -68)
        ..quadraticBezierTo(x, happy ? -77 : -63, x + 6, -68);
      canvas.drawPath(eye, ink);
    } else {
      canvas.drawOval(
        Rect.fromCenter(center: Offset(x, -69), width: 7, height: 11),
        Paint()..color = ink.color,
      );
      canvas.drawCircle(Offset(x + 1, -71), 1.3, Paint()..color = Colors.white);
    }
    canvas.drawOval(
      Rect.fromCenter(center: Offset(x * 1.55, -57), width: 11, height: 6),
      Paint()..color = const Color(0xFFD88C74),
    );
  }
  canvas.drawOval(
    const Rect.fromLTWH(-4, -59, 8, 5),
    Paint()..color = const Color(0xFF9D6658),
  );
  canvas.drawPath(
    Path()
      ..moveTo(0, -54)
      ..lineTo(0, -49)
      ..quadraticBezierTo(-4, -44, -9, -49)
      ..moveTo(0, -49)
      ..quadraticBezierTo(4, -44, 9, -49),
    ink,
  );
  for (final side in [-1.0, 1.0]) {
    for (var i = 0; i < 2; i++) {
      canvas.drawLine(
        Offset(side * 34, -51 + i * 6),
        Offset(side * 53, -55 + i * 8),
        ink..strokeWidth = 1.4,
      );
    }
  }
  if (happy) {
    final heart = Path()
      ..moveTo(58, -125)
      ..cubicTo(40, -140, 50, -150, 58, -140)
      ..cubicTo(66, -150, 76, -140, 58, -125);
    canvas.drawPath(heart, Paint()..color = const Color(0xFFC87865));
  }
  canvas.restore();
}

class PetPortrait extends StatelessWidget {
  const PetPortrait({
    super.key,
    required this.pet,
    this.sleeping = false,
    this.size = 110,
  });
  final PetState pet;
  final bool sleeping;
  final double size;
  @override
  Widget build(BuildContext context) => SizedBox(
    width: size,
    height: size,
    child: CustomPaint(painter: _PortraitPainter(pet, sleeping)),
  );
}

class _PortraitPainter extends CustomPainter {
  _PortraitPainter(this.pet, this.sleeping);
  final PetState pet;
  final bool sleeping;
  @override
  void paint(Canvas canvas, Size size) => drawPet(
    canvas,
    Offset(size.width * .5, size.height * .88),
    size.width / 145,
    pet,
    sleeping: sleeping,
  );
  @override
  bool shouldRepaint(_PortraitPainter oldDelegate) =>
      oldDelegate.pet != pet || oldDelegate.sleeping != sleeping;
}
