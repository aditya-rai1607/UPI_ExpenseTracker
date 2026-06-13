import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../services/app_settings_service.dart';

class ThemeToggle extends StatelessWidget {
  const ThemeToggle({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: () {
        AppSettingsService.setThemeMode(
          isDark ? ThemeMode.light : ThemeMode.dark,
        );
      },
      child: SizedBox(
        width: 150,
        height: 56,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final knobSize = 44.0;
            final leftPos = isDark ? constraints.maxWidth - knobSize - 6 : 6.0;

            return Stack(
              children: [
                // background
                AnimatedContainer(
                  duration: const Duration(milliseconds: 380),
                  curve: Curves.easeInOut,
                  width: constraints.maxWidth,
                  height: constraints.maxHeight,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(999),
                    gradient: isDark
                        ? const LinearGradient(
                            colors: [Color(0xFF2B3444), Color(0xFF1A2233)],
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                          )
                        : const LinearGradient(
                            colors: [Color(0xFFFFF6D6), Color(0xFFFFE082)],
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                          ),
                    border: Border.all(color: Theme.of(context).dividerColor),
                  ),
                ),

                // sun + clouds (left)
                Positioned(
                  left: 12,
                  top: 8,
                  bottom: 8,
                  child: AnimatedOpacity(
                    duration: const Duration(milliseconds: 360),
                    opacity: isDark ? 0.0 : 1.0,
                    child: Row(
                      children: [
                        _Sun(size: 26),
                        const SizedBox(width: 6),
                        _Cloud(size: 28),
                      ],
                    ),
                  ),
                ),

                // moon + stars (right)
                Positioned(
                  right: 12,
                  top: 8,
                  bottom: 8,
                  child: AnimatedOpacity(
                    duration: const Duration(milliseconds: 360),
                    opacity: isDark ? 1.0 : 0.0,
                    child: Row(
                      children: const [
                        _Stars(),
                        SizedBox(width: 6),
                        _Moon(size: 26),
                      ],
                    ),
                  ),
                ),

                // knob
                AnimatedPositioned(
                  duration: const Duration(milliseconds: 380),
                  curve: Curves.easeInOut,
                  left: leftPos,
                  top: 6,
                  child: Container(
                    width: knobSize,
                    height: knobSize,
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF0B0F16) : Colors.white,
                      borderRadius: BorderRadius.circular(999),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x22000000),
                          blurRadius: 8,
                          offset: Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Center(
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 300),
                        transitionBuilder: (child, anim) =>
                            ScaleTransition(scale: anim, child: child),
                        child: isDark
                            ? const Icon(
                                Icons.nightlight_round,
                                key: ValueKey('moon'),
                                color: Colors.white70,
                                size: 20,
                              )
                            : const Icon(
                                Icons.wb_sunny,
                                key: ValueKey('sun'),
                                color: Color(0xFFFFB300),
                                size: 20,
                              ),
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _Sun extends StatelessWidget {
  const _Sun({required this.size});
  final double size;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(size: Size.square(size), painter: _SunPainter());
  }
}

class _SunPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final paint = Paint()..color = const Color(0xFFFFD54F);
    canvas.drawCircle(center, size.width / 2.6, paint);
    final rayPaint = Paint()
      ..color = const Color(0xFFFFE082)
      ..strokeWidth = 1.4
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < 8; i++) {
      final angle = (i / 8) * 2 * 3.14159;
      final p1 =
          center +
          Offset(math.cos(angle), math.sin(angle)) * (size.width / 2.2);
      final p2 =
          center +
          Offset(math.cos(angle), math.sin(angle)) * (size.width / 1.6);
      canvas.drawLine(p1, p2, rayPaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _Cloud extends StatelessWidget {
  const _Cloud({required this.size});
  final double size;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(size: Size(size * 1.2, size), painter: _CloudPainter());
  }
}

class _CloudPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.white;
    final r = size.height * 0.36;
    canvas.drawCircle(Offset(r, size.height * 0.6), r, paint);
    canvas.drawCircle(Offset(r * 2, size.height * 0.45), r * 0.9, paint);
    final rect = Rect.fromLTWH(
      r * 0.6,
      size.height * 0.6,
      size.width - r * 0.9,
      r * 0.8,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, Radius.circular(r * 0.6)),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _Moon extends StatelessWidget {
  const _Moon({required this.size});
  final double size;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(size: Size.square(size), painter: _MoonPainter());
  }
}

class _MoonPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = const Color(0xFFBFC8D6);
    final center = Offset(size.width / 2, size.height / 2);
    canvas.drawCircle(center, size.width / 2.6, paint);
    final craterPaint = Paint()..color = const Color(0xFF9BA6B8);
    canvas.drawCircle(
      center + Offset(-size.width * 0.12, -size.height * 0.08),
      size.width * 0.12,
      craterPaint,
    );
    canvas.drawCircle(
      center + Offset(size.width * 0.08, size.height * 0.12),
      size.width * 0.07,
      craterPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _Stars extends StatelessWidget {
  const _Stars();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 28,
      height: 28,
      child: CustomPaint(painter: _StarsPainter()),
    );
  }
}

class _StarsPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.white70;
    canvas.drawCircle(Offset(size.width * 0.2, size.height * 0.25), 1.8, paint);
    canvas.drawCircle(Offset(size.width * 0.6, size.height * 0.15), 1.4, paint);
    canvas.drawCircle(Offset(size.width * 0.75, size.height * 0.5), 1.6, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
