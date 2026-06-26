import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'gradient_avatar.dart';

/// Avatar that prefers a network image, falls back to a colorful seed letter.
class UserAvatar extends StatelessWidget {
  final String avatarUrl;
  final String seed;
  final double size;
  final bool ring;
  final Color? background;

  const UserAvatar({
    super.key,
    required this.avatarUrl,
    required this.seed,
    this.size = 48,
    this.ring = false,
    this.background,
  });

  @override
  Widget build(BuildContext context) {
    final Widget inner = avatarUrl.isNotEmpty
        ? CachedNetworkImage(
            imageUrl: avatarUrl,
            fit: BoxFit.cover,
            width: size,
            height: size,
            placeholder: (_, __) => Container(color: AppColors.softBg),
            errorWidget: (_, __, ___) => SeedAvatar(seed: seed, size: size),
          )
        : SeedAvatar(seed: seed, size: size);

    if (!ring) {
      return ClipOval(
        child: Container(
          width: size,
          height: size,
          color: background ?? AppColors.softBg,
          child: inner,
        ),
      );
    }
    return GradientAvatar(size: size, child: inner);
  }
}
