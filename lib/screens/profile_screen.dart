import 'package:flutter/material.dart';

import '../models/post_model.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import '../theme/app_theme.dart';
import '../widgets/user_avatar.dart';
import 'chat_screen.dart';
import 'edit_profile_screen.dart';
import 'post_detail_screen.dart';

class ProfileScreen extends StatelessWidget {
  final String uid;
  final bool isMe;
  const ProfileScreen({super.key, required this.uid, required this.isMe});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgWhite,
      body: StreamBuilder<AppUser?>(
        stream: FirestoreService.instance.userStream(uid),
        // Paint instantly from cache. The shared broadcast stream does not
        // replay its last value to new subscribers, so without initialData a
        // re-entered profile would hang on the spinner forever.
        initialData: FirestoreService.instance.cachedUser(uid),
        builder: (context, snap) {
          final user = snap.data;
          if (user == null) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            return const Center(child: Text('User not found'));
          }
          return _ProfileBody(user: user, isMe: isMe);
        },
      ),
    );
  }
}

class _ProfileBody extends StatelessWidget {
  final AppUser user;
  final bool isMe;
  const _ProfileBody({required this.user, required this.isMe});

  @override
  Widget build(BuildContext context) {
    final myUid = AuthService.instance.currentUser?.uid;
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(child: _header(context, myUid)),
        SliverToBoxAdapter(child: _stats()),
        SliverToBoxAdapter(child: _bio()),
        const SliverToBoxAdapter(child: SizedBox(height: 8)),
        StreamBuilder<List<Post>>(
          stream: FirestoreService.instance.userPostsStream(user.uid),
          builder: (context, s) {
            final posts = s.data ?? const [];
            if (posts.isEmpty) {
              return const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: Center(
                    child: Text('No posts yet.',
                        style: TextStyle(color: AppColors.textMuted)),
                  ),
                ),
              );
            }
            return SliverPadding(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 24),
              sliver: SliverGrid(
                gridDelegate:
                    const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: 6,
                  mainAxisSpacing: 6,
                ),
                delegate: SliverChildBuilderDelegate(
                  (_, i) => _GridTile(post: posts[i]),
                  childCount: posts.length,
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _header(BuildContext context, String? myUid) {

    return Container(
      decoration: const BoxDecoration(
        gradient: AppColors.vibrant,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(32)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 60, 20, 24),
      child: Column(
        children: [
          Row(
            children: [
              if (!isMe)
                IconButton(
                  onPressed: () => Navigator.of(context).maybePop(),
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                )
              else
                const SizedBox(width: 4),
              const Spacer(),
              Text(
                isMe ? 'My Profile' : '@${user.username}',
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w600),
              ),
              const Spacer(),
              if (isMe)
                IconButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => EditProfileScreen(user: user),
                    ),
                  ),
                  icon: const Icon(Icons.edit, color: Colors.white),
                )
              else
                const SizedBox(width: 4),
            ],
          ),
          const SizedBox(height: 12),
          UserAvatar(
            avatarUrl: user.avatarUrl,
            seed: user.username,
            size: 96,
            ring: true,
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Flexible(
                child: Text(
                  user.displayName,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w700),
                ),
              ),
              if (user.isVerified) ...[
                const SizedBox(width: 6),
                const Icon(Icons.verified, color: Colors.white, size: 20),
              ],
            ],
          ),
          Text('@${user.username}',
              style: const TextStyle(color: Colors.white70)),
          const SizedBox(height: 14),
          if (!isMe && myUid != null) _otherActions(context, myUid),
        ],
      ),
    );
  }

  Widget _otherActions(BuildContext context, String myUid) {
    return StreamBuilder<AppUser?>(
      stream: FirestoreService.instance.userStream(myUid),
      initialData: FirestoreService.instance.cachedUser(myUid),
      builder: (context, s) {
        final me = s.data;
        final following = me?.following.contains(user.uid) ?? false;
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            GestureDetector(
              onTap: () => FirestoreService.instance.toggleFollow(
                currentUid: myUid,
                targetUid: user.uid,
              ),
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 22, vertical: 10),
                decoration: BoxDecoration(
                  color: following
                      ? Colors.white.withOpacity(.25)
                      : Colors.white,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(
                  following ? 'Following' : 'Follow',
                  style: TextStyle(
                    color: following ? Colors.white : AppColors.primaryCoral,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            GestureDetector(
              onTap: () async {
                final chat = await FirestoreService.instance
                    .ensureChat(myUid, user.uid);
                if (!context.mounted) return;
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => ChatScreen(
                      chatId: chat.id,
                      otherUser: user,
                    ),
                  ),
                );
              },
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.send,
                    color: AppColors.primaryCoral, size: 22),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _stats() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
      child: StreamBuilder<List<Post>>(
        stream: FirestoreService.instance.userPostsStream(user.uid),
        builder: (context, snap) {
          final count = snap.data?.length ?? 0;
          return Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _stat('$count', 'Posts'),
              _stat('${user.followers.length}', 'Followers'),
              _stat('${user.following.length}', 'Following'),
            ],
          );
        },
      ),
    );
  }

  Widget _stat(String value, String label) {
    return Column(
      children: [
        Text(value,
            style: const TextStyle(
                fontSize: 18, fontWeight: FontWeight.w700)),
        Text(label,
            style: const TextStyle(
                color: AppColors.textMuted, fontSize: 12)),
      ],
    );
  }

  Widget _bio() {
    if (user.bio.isEmpty && user.location.isEmpty) {
      return const SizedBox(height: 8);
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 6, 20, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (user.bio.isNotEmpty)
            Text(user.bio, style: const TextStyle(fontSize: 13.5, height: 1.4)),
          if (user.location.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Row(
                children: [
                  const Icon(Icons.location_on,
                      size: 14, color: AppColors.primaryCoral),
                  const SizedBox(width: 4),
                  Text(user.location,
                      style: const TextStyle(
                          color: AppColors.textMuted, fontSize: 12)),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _GridTile extends StatelessWidget {
  final Post post;
  const _GridTile({required this.post});
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => PostDetailScreen(
            postId: post.id,
            currentUser: null,
          ),
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: post.imageUrl.isNotEmpty
            ? Image.network(post.imageUrl,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _fallback())
            : _fallback(),
      ),
    );
  }

  Widget _fallback() => Container(
        decoration: const BoxDecoration(gradient: AppColors.sunset),
        alignment: Alignment.center,
        child: const Icon(Icons.image, color: Colors.white, size: 28),
      );
}
