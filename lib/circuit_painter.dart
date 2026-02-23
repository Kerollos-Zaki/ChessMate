// lib/circuit_painter.dart
import 'package:flutter/material.dart';

class CircuitPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.1) // Subtle technical lines
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    final path = Path();
    // Top-left decorative lines
    path.moveTo(0, 40);
    path.lineTo(40, 0);
    path.lineTo(100, 0);

    // Bottom-right decorative lines
    path.moveTo(size.width, size.height - 40);
    path.lineTo(size.width - 40, size.height);
    path.lineTo(size.width - 100, size.height);

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}