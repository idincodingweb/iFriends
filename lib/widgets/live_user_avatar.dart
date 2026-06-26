import 'package:flutter/material.dart';

import '../models/user_model.dart';
import '../services/firestore_service.dart';
import 'user_avatar.dart';

/// Avatar that always reflects the latest `users/{uid}` document. Uses a
/// shared broadcast stream + in-memory cache so multiple avatars for the
/// same uid don't each trigger a Firestore read or flash a placeholder.
class LiveUserAvatar extends StatelessWidget {
  final String uid;
  final String fallbackAvatarUrl;
  final String fallbackSeed;
  final double size;
  final bool ring;

  const LiveUserAvatar({
    super.key,
    required this.uid,
    this.fallbackAvatarUrl = '',
    this.fallbackSeed = '',
    this.size = 38,
    this.ring = false,
  });

  @override
  Widget build(BuildContext context) {
    if (uid.isEmpty) {
      return UserAvatar(
        avatarUrl: fallbackAvatarUrl,
        seed: fallbackSeed,
        size: size,
        ring: ring,
      );
    }
    final cached = FirestoreService.instance.cachedUser(uid);
    return StreamBuilder<AppUser?>(
      stream: FirestoreService.instance.userStream(uid),
      initialData: cached,
      builder: (context, snap) {
        final u = snap.data;
        final url = u?.avatarUrl.isNotEmpty == true
            ? u!.avatarUrl
            : fallbackAvatarUrl;
        final seed = u?.username.isNotEmpty == true
            ? u!.username
            : (u?.displayName.isNotEmpty == true
                ? u!.displayName
                : fallbackSeed);
        return UserAvatar(
          avatarUrl: url,
          seed: seed,
          size: size,
          ring: ring,
        );
      },
    );
  }
}

/// Inline display-name + @username pair that streams from `users/{uid}`.
class LiveUserName extends StatelessWidget {
  final String uid;
  final String fallbackDisplayName;
  final String fallbackUsername;
  final String trailing;
  final TextStyle? nameStyle;
  final TextStyle? subStyle;
  final bool showVerified;
  final double verifiedSize;
  final Color? verifiedColor;

  const LiveUserName({
    super.key,
    required this.uid,
    this.fallbackDisplayName = '',
    this.fallbackUsername = '',
    this.trailing = '',
    this.nameStyle,
    this.subStyle,
    this.showVerified = true,
    this.verifiedSize = 15,
    this.verifiedColor,
  });

  @override
  Widget build(BuildContext context) {
    final cached = uid.isEmpty
        ? null
        : FirestoreService.instance.cachedUser(uid);
    return StreamBuilder<AppUser?>(
      stream: uid.isEmpty
          ? const Stream<AppUser?>.empty()
          : FirestoreService.instance.userStream(uid),
      initialData: cached,
      builder: (context, snap) {
        final u = snap.data;
        final name = u?.displayName.isNotEmpty == true
            ? u!.displayName
            : fallbackDisplayName;
        final username = u?.username.isNotEmpty == true
            ? u!.username
            : fallbackUsername;
        final verified = u?.isVerified ?? false;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: Text(name,
                      style: nameStyle, overflow: TextOverflow.ellipsis),
                ),
                if (showVerified && verified) ...[
                  const SizedBox(width: 4),
                  Icon(Icons.verified,
                      size: verifiedSize,
                      color: verifiedColor ?? const Color(0xFF3897F0)),
                ],
              ],
            ),
            Text('@$username$trailing', style: subStyle),
          ],
        );
      },
    );
  }
}

/// Small standalone verified check that streams `users/{uid}` and shows an
/// Instagram-style badge only when the user is verified. Returns an empty box
/// otherwise so it can be dropped into any Row/Stack.
class LiveVerifiedBadge extends StatelessWidget {
  final String uid;
  final double size;
  final Color color;
  final bool withBackground;

  const LiveVerifiedBadge({
    super.key,
    required this.uid,
    this.size = 16,
    this.color = const Color(0xFF3897F0),
    this.withBackground = false,
  });

  @override
  Widget build(BuildContext context) {
    if (uid.isEmpty) return const SizedBox.shrink();
    return StreamBuilder<AppUser?>(
      stream: FirestoreService.instance.userStream(uid),
      initialData: FirestoreService.instance.cachedUser(uid),
      builder: (context, snap) {
        if (!(snap.data?.isVerified ?? false)) {
          return const SizedBox.shrink();
        }
        final icon = Icon(Icons.verified, size: size, color: color);
        if (!withBackground) return icon;
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
          ),
          padding: const EdgeInsets.all(1),
          child: icon,
        );
      },
    );
  }
}
