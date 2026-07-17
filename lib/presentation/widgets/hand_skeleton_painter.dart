import 'dart:math';
import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';

class HandSkeletonPainter extends CustomPainter {
  final double animationValue;
  final String status; // 'idle', 'scanning', 'success'
  final List<Offset>? customPoints;

  HandSkeletonPainter({
    required this.animationValue,
    this.status = 'scanning',
    this.customPoints,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    
    // Déterminer la couleur en fonction du statut
    Color jointColor;
    Color boneColor;
    
    switch (status) {
      case 'success':
        jointColor = const Color(0xFF43D4A0);
        boneColor = const Color(0xFF43D4A0).withOpacity(0.6);
        break;
      case 'scanning':
        jointColor = AppColors.secondary;
        boneColor = AppColors.secondary.withOpacity(0.5);
        break;
      case 'idle':
      default:
        jointColor = AppColors.primary;
        boneColor = AppColors.primary.withOpacity(0.4);
        break;
    }

    final jointPaint = Paint()
      ..color = jointColor
      ..style = PaintingStyle.fill
      ..maskFilter = const MaskFilter.blur(BlurStyle.solid, 4);

    final bonePaint = Paint()
      ..color = boneColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.5
      ..strokeCap = StrokeCap.round;

    final glowPaint = Paint()
      ..color = jointColor.withOpacity(0.3)
      ..style = PaintingStyle.fill
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);

    List<Offset> points = [];

    if (customPoints != null && customPoints!.length == 21) {
      points = customPoints!;
    } else {
      // Générer des points de main simulés et animés
      // Index 0: Poignet
      points.add(Offset(center.dx, center.dy + size.height * 0.25));

      // Pouce: 1, 2, 3, 4
      double thumbAngle = -0.6 + sin(animationValue * pi * 2) * 0.05;
      points.add(_getOffset(points[0], thumbAngle, size.height * 0.08));
      points.add(_getOffset(points[1], thumbAngle - 0.2, size.height * 0.06));
      points.add(_getOffset(points[2], thumbAngle - 0.4, size.height * 0.05));
      points.add(_getOffset(points[3], thumbAngle - 0.5, size.height * 0.04));

      // Index: 5, 6, 7, 8
      double indexAngle = -1.3 + cos(animationValue * pi * 2) * 0.04;
      points.add(_getOffset(points[0], -1.4, size.height * 0.08));
      points.add(_getOffset(points[5], indexAngle, size.height * 0.07));
      points.add(_getOffset(points[6], indexAngle, size.height * 0.06));
      points.add(_getOffset(points[7], indexAngle, size.height * 0.05));

      // Majeur: 9, 10, 11, 12
      double middleAngle = -1.55 + sin(animationValue * pi * 2 + 1) * 0.05;
      points.add(_getOffset(points[0], -1.55, size.height * 0.09));
      points.add(_getOffset(points[9], middleAngle, size.height * 0.08));
      points.add(_getOffset(points[10], middleAngle, size.height * 0.07));
      points.add(_getOffset(points[11], middleAngle, size.height * 0.06));

      // Annulaire: 13, 14, 15, 16
      double ringAngle = -1.8 + cos(animationValue * pi * 2 + 2) * 0.06;
      points.add(_getOffset(points[0], -1.7, size.height * 0.085));
      points.add(_getOffset(points[13], ringAngle, size.height * 0.075));
      points.add(_getOffset(points[14], ringAngle, size.height * 0.065));
      points.add(_getOffset(points[15], ringAngle, size.height * 0.055));

      // Auriculaire: 17, 18, 19, 20
      double pinkyAngle = -2.05 + sin(animationValue * pi * 2 + 3) * 0.07;
      points.add(_getOffset(points[0], -1.85, size.height * 0.075));
      points.add(_getOffset(points[17], pinkyAngle, size.height * 0.065));
      points.add(_getOffset(points[18], pinkyAngle, size.height * 0.055));
      points.add(_getOffset(points[19], pinkyAngle, size.height * 0.045));
    }

    // Liaisons osseuses (MediaPipe hand landmark connections)
    final List<List<int>> connections = [
      // Pouce
      [0, 1], [1, 2], [2, 3], [3, 4],
      // Index
      [0, 5], [5, 6], [6, 7], [7, 8],
      // Majeur
      [0, 9], [9, 10], [10, 11], [11, 12],
      // Annulaire
      [0, 13], [13, 14], [14, 15], [15, 16],
      // Auriculaire
      [0, 17], [17, 18], [18, 19], [19, 20],
      // Paume
      [5, 9], [9, 13], [13, 17]
    ];

    // Dessiner les os
    for (final connection in connections) {
      if (connection[0] < points.length && connection[1] < points.length) {
        canvas.drawLine(points[connection[0]], points[connection[1]], bonePaint);
      }
    }

    // Dessiner les articulations
    for (int i = 0; i < points.length; i++) {
      double radius = (i == 0 || i == 4 || i == 8 || i == 12 || i == 16 || i == 20) ? 6.0 : 4.0;
      canvas.drawCircle(points[i], radius + 4, glowPaint);
      canvas.drawCircle(points[i], radius, jointPaint);
    }
  }

  Offset _getOffset(Offset origin, double angle, double distance) {
    return Offset(
      origin.dx + cos(angle) * distance,
      origin.dy + sin(angle) * distance,
    );
  }

  @override
  bool shouldRepaint(covariant HandSkeletonPainter oldDelegate) {
    return oldDelegate.animationValue != animationValue ||
        oldDelegate.status != status ||
        oldDelegate.customPoints != customPoints;
  }
}
