import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';

class AtmosphericBackground extends StatelessWidget {
  final Widget child;
  const AtmosphericBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    if (isDark) {
      return Container(
        decoration: const BoxDecoration(
          color: AppColors.scaffoldDark,
          gradient: RadialGradient(
            center: Alignment(0.4, -0.6),
            radius: 1.2,
            colors: [
              Color(0xFF221A3B),
              Color(0xFF141120),
              AppColors.scaffoldDark,
            ],
            stops: [0.0, 0.55, 1.0],
          ),
        ),
        child: child,
      );
    }

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.scaffoldLight,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFFEDE6F8), // Top left soft lilac
            Color(0xFFF7F3FB), // Center light tint
            Color(0xFFE9E0F7), // Bottom right soft violet
          ],
          stops: [0.0, 0.45, 1.0],
        ),
      ),
      child: Stack(
        children: [
          // Subtle top-right cloud aura
          Positioned(
            top: -100,
            right: -80,
            width: 380,
            height: 380,
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFFDDD2F5).withValues(alpha: 0.65),
                    const Color(0xFFEFE9FB).withValues(alpha: 0.3),
                    Colors.transparent,
                  ],
                  stops: const [0.0, 0.5, 1.0],
                ),
              ),
            ),
          ),
          // Subtle center-left cloud aura
          Positioned(
            bottom: -80,
            left: -60,
            width: 340,
            height: 340,
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFFE3D8F8).withValues(alpha: 0.55),
                    const Color(0xFFF5EDFA).withValues(alpha: 0.25),
                    Colors.transparent,
                  ],
                  stops: const [0.0, 0.5, 1.0],
                ),
              ),
            ),
          ),
          child,
        ],
      ),
    );
  }
}
