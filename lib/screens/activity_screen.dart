import 'package:flutter/material.dart';

import '../models/post_model.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import '../theme/app_theme.dart';
import '../widgets/live_user_avatar.dart';
import 'post_detail_screen.dart';
import 'profile_screen.dart';

/// In-app "Activity" feed. Two tabs:
///  - Notifications: things other people did to you (likes, comments,
///    replies, follows, mentions). Marks all read on open.
///  - Your Activity: a Facebook-style timeline of things YOU did
///    (posts, likes given, comments authored).
class ActivityScreen extends StatefulWidget {
  const ActivityScreen({super.key});

  @override
  State<ActivityScreen> createState() => _ActivityScreenState();
}

class _ActivityScreenState extends State<ActivityScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tab;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
    final uid = AuthService.instance.currentUser?.uid;
    if (uid != null && uid.isNotEmpty) {
      FirestoreService.instance.markAllNotificationsRead(uid);
    }
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
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
        bottom: TabBar(
          controller: _tab,
          labelColor: AppColors.primaryCoral,
          unselectedLabelColor: AppColors.textMuted,
          indicatorColor: AppColors.primaryCoral,
          tabs: const [
            Tab(text: 'Notifications'),
            Tab(text: 'Your Activity'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tab,
        children: [
          _NotificationsTab(uid: uid),
          _MyActivityTab(uid: uid),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Notifications tab
// ---------------------------------------------------------------------------
class _NotificationsTab extends StatelessWidget {
  final String uid;
  const _NotificationsTab({required this.uid});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<AppNotification>>(
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
                  ),
                  const SizedBox(height: 2),
                  Text(_ago(n.createdAt),
                      style: const TextStyle(
                          color: AppColors.textMuted, fontSize: 12)),
                ],
              ),
            ),
            if (n.postImageUrl.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(left: 8),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(
                    n.postImageUrl,
                    width: 42,
                    height: 42,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      width: 42,
                      height: 42,
                      color: AppColors.softBg,
                    ),
                  ),
                ),
              ),
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

// ---------------------------------------------------------------------------
// "Your Activity" tab — Facebook-style timeline of things YOU did.
// ---------------------------------------------------------------------------
class _MyActivityTab extends StatelessWidget {
  final String uid;
  const _MyActivityTab({required this.uid});

  @override
  Widget build(BuildContext context) {
    if (uid.isEmpty) {
      return const Center(child: Text('Sign in to see your activity.'));
    }
    return StreamBuilder<List<UserActivity>>(
      stream: FirestoreService.instance.myActivityStream(uid),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting &&
            !snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final items = snap.data ?? const <UserActivity>[];
        if (items.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(32),
              child: Text(
                'Nothing here yet.\nThings you post, like, and comment on will appear in this timeline.',
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
          itemBuilder: (_, i) => _MyActivityTile(a: items[i]),
        );
      },
    );
  }
}

class _MyActivityTile extends StatelessWidget {
  final UserActivity a;
  const _MyActivityTile({required this.a});

  IconData get _icon {
    switch (a.type) {
      case 'like':
        return Icons.favorite;
      case 'comment':
        return Icons.mode_comment;
      case 'post':
        return Icons.add_a_photo_outlined;
    }
    return Icons.history;
  }

  Color get _iconColor {
    switch (a.type) {
      case 'like':
        return AppColors.primaryPink;
      case 'post':
        return AppColors.primaryCoral;
    }
    return AppColors.textDark;
  }

  String _headline() {
    switch (a.type) {
      case 'like':
        return 'You liked a post';
      case 'comment':
        return 'You commented: "${a.text}"';
      case 'post':
        return a.text.isEmpty
            ? 'You shared a new post'
            : 'You posted: "${a.text}"';
    }
    return a.text;
  }

  void _open(BuildContext context) {
    if (a.postId.isEmpty) return;
    final myUid = AuthService.instance.currentUser?.uid ?? '';
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PostDetailScreen(
          postId: a.postId,
          currentUser: FirestoreService.instance.cachedUser(myUid),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => _open(context),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppColors.softBg,
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Icon(_icon, size: 20, color: _iconColor),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _headline(),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: AppColors.textDark, fontSize: 14),
                  ),
                  const SizedBox(height: 2),
                  Text(_ago(a.createdAt),
                      style: const TextStyle(
                          color: AppColors.textMuted, fontSize: 12)),
                ],
              ),
            ),
            if (a.postImageUrl.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(left: 8),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(
                    a.postImageUrl,
                    width: 42,
                    height: 42,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      width: 42,
                      height: 42,
                      color: AppColors.softBg,
                    ),
                  ),
                ),
              ),
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
