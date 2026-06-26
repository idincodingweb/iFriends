import 'package:flutter/material.dart';

import '../models/post_model.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import '../theme/app_theme.dart';
import '../widgets/live_user_avatar.dart';
import 'post_detail_screen.dart';
import 'profile_screen.dart';

/// In-app "Activity" feed. Lists every notification (likes, comments,
/// replies, follows) and marks them all as read the moment the screen opens.
class ActivityScreen extends StatefulWidget {
  const ActivityScreen({super.key});

  @override
  State<ActivityScreen> createState() => _ActivityScreenState();
}

class _ActivityScreenState extends State<ActivityScreen> {
  @override
  void initState() {
    super.initState();
    final uid = AuthService.instance.currentUser?.uid;
    if (uid != null && uid.isNotEmpty) {
      // Fire-and-forget; the badge updates from the realtime counter.
      FirestoreService.instance.markAllNotificationsRead(uid);
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid = AuthService.instance.currentUser?.uid ?? '';
    return Scaffold(
      backgroundColor: AppColors.bgWhite,
      appBar: AppBar(
        title: const Text('Activity'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: AppColors.textDark,
      ),
      body: StreamBuilder<List<AppNotification>>(
        stream: FirestoreService.instance.notificationsStream(uid),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final items = snap.data ?? const <AppNotification>[];
          if (items.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Text(
                  'No activity yet.\nLikes, comments and new followers will show up here.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.textMuted),
                ),
              ),
            );
          }
          return ListView.separated(
            itemCount: items.length,
            separatorBuilder: (_, __) => const Divider(
                height: 1, color: AppColors.divider, indent: 70),
            itemBuilder: (_, i) => _NotifTile(n: items[i]),
          );
        },
      ),
    );
  }
}

class _NotifTile extends StatelessWidget {
  final AppNotification n;
  const _NotifTile({required this.n});

  IconData get _icon {
    switch (n.type) {
      case 'like':
        return Icons.favorite;
      case 'comment':
        return Icons.mode_comment;
      case 'reply':
        return Icons.reply;
      case 'follow':
        return Icons.person_add_alt_1;
      case 'mention':
        return Icons.alternate_email;
    }
    return Icons.notifications;
  }

  Color get _iconColor {
    switch (n.type) {
      case 'like':
        return AppColors.primaryPink;
      case 'follow':
        return AppColors.primaryCoral;
    }
    return AppColors.textDark;
  }

  String _headline() {
    switch (n.type) {
      case 'like':
        return n.text.isEmpty ? 'liked your post' : n.text;
      case 'comment':
        return n.text.isEmpty ? 'commented on your post' : n.text;
      case 'reply':
        return n.text.isEmpty ? 'replied to your comment' : n.text;
      case 'follow':
        return 'started following you';
      case 'mention':
        return 'mentioned you';
    }
    return n.text;
  }

  void _open(BuildContext context) {
    if (n.postId.isNotEmpty) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) =>
              PostDetailScreen(postId: n.postId, currentUser: null),
        ),
      );
    } else if (n.fromUid.isNotEmpty) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ProfileScreen(uid: n.fromUid, isMe: false),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => _open(context),
      child: Container(
        color: n.read ? Colors.transparent : const Color(0xFFFFF3EE),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                LiveUserAvatar(
                  uid: n.fromUid,
                  fallbackAvatarUrl: n.fromAvatarUrl,
                  fallbackSeed: n.fromName,
                  size: 44,
                ),
                Positioned(
                  right: -2,
                  bottom: -2,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(.08),
                          blurRadius: 4,
                        ),
                      ],
                    ),
                    child: Icon(_icon, size: 14, color: _iconColor),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  RichText(
                    text: TextSpan(
                      style: const TextStyle(
                          color: AppColors.textDark, fontSize: 14),
                      children: [
                        TextSpan(
                          text: n.fromName.isEmpty ? 'Someone' : n.fromName,
                          style:
                              const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        const TextSpan(text: ' '),
                        TextSpan(text: _headline()),
                      ],
                    ),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _ago(n.createdAt),
                    style: const TextStyle(
                        color: AppColors.textMuted, fontSize: 11.5),
                  ),
                ],
              ),
            ),
            if (n.postImageUrl.isNotEmpty) ...[
              const SizedBox(width: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                  n.postImageUrl,
                  width: 44,
                  height: 44,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    width: 44,
                    height: 44,
                    color: AppColors.softBg,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  static String _ago(DateTime t) {
    final d = DateTime.now().difference(t);
    if (d.inMinutes < 1) return 'now';
    if (d.inMinutes < 60) return '${d.inMinutes}m';
    if (d.inHours < 24) return '${d.inHours}h';
    if (d.inDays < 7) return '${d.inDays}d';
    return '${d.inDays ~/ 7}w';
  }
}
