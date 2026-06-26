import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class GradientAvatar extends StatelessWidget {
  final double size;
  final Widget child;
  final bool ring;
  const GradientAvatar({super.key, required this.child, this.size = 64, this.ring = true});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size, height: size,
      padding: EdgeInsets.all(ring ? 3 : 0),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: ring ? AppColors.vibrant : null,
      ),
      child: Container(
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white,
        ),
        padding: const EdgeInsets.all(2),
        child: ClipOval(child: child),
      ),
    );
  }
}

/// Decorative colored avatar placeholder (no network).
class SeedAvatar extends StatelessWidget {
  final String seed;
  final double size;
  const SeedAvatar({super.key, required this.seed, this.size = 56});

  Color _color() {
    final palette = [
      AppColors.primaryPink, AppColors.primaryCoral, AppColors.primaryOrange,
      AppColors.accentPurple, AppColors.accentBlue, AppColors.accentGreen,
      AppColors.primaryYellow,
    ];
    return palette[seed.hashCode.abs() % palette.length];
  }

  @override
  Widget build(BuildContext context) {
    final c = _color();
    final letter = seed.isNotEmpty ? seed[0].toUpperCase() : '?';
    return Container(
      width: size, height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(colors: [c.withOpacity(.85), c]),
      ),
      alignment: Alignment.center,
      child: Text(letter,
          style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: size * .4)),
    );
  }
}
