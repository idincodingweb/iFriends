import 'package:cached_network_image/cached_network_image.dart';
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

  static const double _coverHeight = 240;
  static const double _avatarSize = 110;

  @override
  Widget build(BuildContext context) {
    final myUid = AuthService.instance.currentUser?.uid;
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(child: _header(context)),
        // Avatar overlaps the cover/sheet boundary: shift content up by half avatar.
        SliverToBoxAdapter(
          child: Transform.translate(
            offset: const Offset(0, -_avatarSize / 2 - 8),
            child: Column(
              children: [
                _identity(),
                const SizedBox(height: 14),
                _statsPill(),
                const SizedBox(height: 16),
                _bio(),
                if (!isMe && myUid != null) ...[
                  const SizedBox(height: 12),
                  _otherActions(context, myUid),
                ],
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
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

  // ----- COVER + TOP BAR -----
  Widget _header(BuildContext context) {
    return SizedBox(
      height: _coverHeight + _avatarSize / 2,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Cover image / gradient fallback
          Positioned.fill(
            bottom: _avatarSize / 2,
            child: ClipRRect(
              borderRadius:
                  const BorderRadius.vertical(bottom: Radius.circular(28)),
              child: user.coverUrl.isNotEmpty
                  ? Stack(
                      fit: StackFit.expand,
                      children: [
                        CachedNetworkImage(
                          imageUrl: user.coverUrl,
                          fit: BoxFit.cover,
                          placeholder: (_, __) => Container(
                              decoration: const BoxDecoration(
                                  gradient: AppColors.vibrant)),
                          errorWidget: (_, __, ___) => Container(
                              decoration: const BoxDecoration(
                                  gradient: AppColors.vibrant)),
                        ),
                        Container(color: Colors.black.withOpacity(.05)),
                      ],
                    )
                  : Container(
                      decoration:
                          const BoxDecoration(gradient: AppColors.vibrant),
                    ),
            ),
          ),
          // Top bar buttons
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            left: 12,
            right: 12,
            child: Row(
              children: [
                _circleBtn(
                  icon: Icons.arrow_back,
                  onTap: () => Navigator.of(context).maybePop(),
                  show: !isMe || Navigator.of(context).canPop(),
                ),
                const Spacer(),
                if (isMe)
                  _circleBtn(
                    icon: Icons.edit,
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => EditProfileScreen(user: user),
                      ),
                    ),
                  )
                else
                  _circleBtn(
                    icon: Icons.more_horiz,
                    onTap: () {},
                  ),
              ],
            ),
          ),
          // Avatar overlapping the bottom of the cover
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(.08),
                      blurRadius: 14,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: UserAvatar(
                  avatarUrl: user.avatarUrl,
                  seed: user.username,
                  size: _avatarSize,
                  ring: false,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _circleBtn({
    required IconData icon,
    required VoidCallback onTap,
    bool show = true,
  }) {
    if (!show) return const SizedBox(width: 40, height: 40);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(.85),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: AppColors.textDark, size: 20),
      ),
    );
  }

  // ----- IDENTITY (name + @username) -----
  Widget _identity() {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Flexible(
              child: Text(
                user.displayName.isEmpty ? user.username : user.displayName,
                style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textDark),
                textAlign: TextAlign.center,
              ),
            ),
            if (user.isVerified) ...[
              const SizedBox(width: 6),
              const Icon(Icons.verified,
                  color: AppColors.accentBlue, size: 20),
            ],
          ],
        ),
        const SizedBox(height: 2),
        Text('@${user.username}',
            style: const TextStyle(color: AppColors.textMuted, fontSize: 14)),
      ],
    );
  }

  // ----- STATS PILL CARD -----
  Widget _statsPill() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
        decoration: BoxDecoration(
          color: AppColors.softBg,
          borderRadius: BorderRadius.circular(18),
        ),
        child: StreamBuilder<List<Post>>(
          stream: FirestoreService.instance.userPostsStream(user.uid),
          builder: (context, snap) {
            final count = snap.data?.length ?? 0;
            return Row(
              children: [
                Expanded(child: _stat('$count', 'Posts')),
                _divider(),
                Expanded(child: _stat('${user.followers.length}', 'Followers')),
                _divider(),
                Expanded(child: _stat('${user.following.length}', 'Following')),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _divider() => Container(
        width: 1,
        height: 28,
        color: Colors.black.withOpacity(.06),
      );

  Widget _stat(String value, String label) {
    return Column(
      children: [
        Text(value,
            style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: AppColors.textDark)),
        const SizedBox(height: 2),
        Text(label,
            style: const TextStyle(
                color: AppColors.textMuted, fontSize: 12)),
      ],
    );
  }

  // ----- BIO + LOCATION -----
  Widget _bio() {
    if (user.bio.isEmpty && user.location.isEmpty) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (user.bio.isNotEmpty)
            Text(user.bio,
                style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textDark)),
          if (user.location.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Row(
                children: [
                  const Icon(Icons.location_on_outlined,
                      size: 16, color: AppColors.textMuted),
                  const SizedBox(width: 4),
                  Text(user.location,
                      style: const TextStyle(
                          color: AppColors.textMuted, fontSize: 13)),
                ],
              ),
            ),
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
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => FirestoreService.instance.toggleFollow(
                    currentUid: myUid,
                    targetUid: user.uid,
                  ),
                  child: Container(
                    height: 46,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      gradient: following ? null : AppColors.vibrant,
                      color: following ? AppColors.softBg : null,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Text(
                      following ? 'Following' : 'Follow',
                      style: TextStyle(
                        color: following
                            ? AppColors.textDark
                            : Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
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
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: AppColors.softBg,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(Icons.send,
                      color: AppColors.primaryCoral, size: 20),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _GridTile extends StatelessWidget {
  final Post post;
  const _GridTile({required this.post});
  @override
  Widget build(BuildContext context) {
    final img = post.images.isNotEmpty ? post.images.first : '';
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
        borderRadius: BorderRadius.circular(12),
        child: img.isNotEmpty
            ? CachedNetworkImage(
                imageUrl: img,
                fit: BoxFit.cover,
                placeholder: (_, __) => Container(color: AppColors.softBg),
                errorWidget: (_, __, ___) => _fallback(),
              )
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
