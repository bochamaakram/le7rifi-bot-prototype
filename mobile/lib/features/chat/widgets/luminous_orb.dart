import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';

class LuminousOrb extends StatefulWidget {
  final double size;
  final bool animate;
  const LuminousOrb({
    super.key,
    this.size = 110,
    this.animate = true,
  });

  @override
  State<LuminousOrb> createState() => _LuminousOrbState();
}

class _LuminousOrbState extends State<LuminousOrb>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3200),
      value: 0.5,
    );
    final isTesting = Platform.environment.containsKey('FLUTTER_TEST');
    if (widget.animate && !isTesting) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final scale = 0.97 + (_controller.value * 0.05);
        final floatOffset = math.sin(_controller.value * math.pi) * 3.0;
        return Transform.translate(
          offset: Offset(0, floatOffset),
          child: Transform.scale(
            scale: scale,
            child: SizedBox(
              width: widget.size,
              height: widget.size,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Outer soft ambient violet halo
                  Container(
                    width: widget.size * 1.35,
                    height: widget.size * 1.35,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          const Color(0xFFC4B5FD).withValues(alpha: 0.65),
                          const Color(0xFFA78BFA).withValues(alpha: 0.35),
                          const Color(0xFF7C3AED).withValues(alpha: 0.0),
                        ],
                        stops: const [0.0, 0.45, 1.0],
                      ),
                    ),
                  ),

                  // 3D Sphere Body with specular lighting offset to top-left
                  Container(
                    width: widget.size,
                    height: widget.size,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF8B5CF6).withValues(alpha: 0.38),
                          blurRadius: 28,
                          spreadRadius: 2,
                          offset: const Offset(0, 10),
                        ),
                      ],
                      gradient: const RadialGradient(
                        center: Alignment(-0.35, -0.38),
                        radius: 0.88,
                        colors: [
                          Color(0xFFFFFFFF), // Specular light highlight
                          Color(0xFFF0E7FE), // Pale lavender
                          Color(0xFFD6BCFA), // Soft purple mid
                          Color(0xFFA855F7), // Rich amethyst
                          Color(0xFF7C3AED), // Deep violet
                          Color(0xFF5B21B6), // Shadowed bottom edge
                        ],
                        stops: [0.0, 0.18, 0.42, 0.70, 0.88, 1.0],
                      ),
                    ),
                  ),

                  // Inner glossy crescent shine on top-left rim
                  Positioned(
                    top: widget.size * 0.12,
                    left: widget.size * 0.16,
                    child: Container(
                      width: widget.size * 0.42,
                      height: widget.size * 0.28,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.all(
                          Radius.elliptical(widget.size * 0.42, widget.size * 0.28),
                        ),
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.white.withValues(alpha: 0.85),
                            Colors.white.withValues(alpha: 0.0),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
