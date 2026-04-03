import 'dart:math';
import 'package:flutter/material.dart';

class WavePageRoute<T> extends PageRouteBuilder<T> {
  final WidgetBuilder builder;

  WavePageRoute({required this.builder})
      : super(
          pageBuilder: (context, animation, secondaryAnimation) =>
              builder(context),
          transitionDuration: const Duration(milliseconds: 500),
          reverseTransitionDuration: const Duration(milliseconds: 400),
          transitionsBuilder:
              (context, animation, secondaryAnimation, child) {
            return ClipPath(
              clipper: _WaveClipper(animation.value),
              child: child,
            );
          },
        );
}

class _WaveClipper extends CustomClipper<Path> {
  final double progress;
  _WaveClipper(this.progress);

  @override
  Path getClip(Size size) {
    if (progress >= 1.0) return Path()..addRect(Offset.zero & size);

    final path = Path();
    final edge = size.width * progress * 1.2;

    path.moveTo(0, 0);
    path.lineTo(edge, 0);

    final waveWidth = 40.0;
    final steps = 6;
    final stepH = size.height / steps;

    for (int i = 0; i < steps; i++) {
      final y1 = stepH * i;
      final y2 = stepH * (i + 1);
      final mid = (y1 + y2) / 2;
      final dir = i.isEven ? 1.0 : -1.0;
      path.quadraticBezierTo(
        edge + waveWidth * dir * sin(progress * pi),
        mid,
        edge,
        y2,
      );
    }

    path.lineTo(0, size.height);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(_WaveClipper old) => old.progress != progress;
}
