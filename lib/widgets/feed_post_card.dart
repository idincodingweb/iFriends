import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../models/post_model.dart';
import '../models/user_model.dart';
import '../screens/post_detail_screen.dart';
import '../screens/profile_screen.dart';
import '../screens/share_to_chat_screen.dart';
import '../services/firestore_service.dart';
import '../theme/app_theme.dart';
import 'live_user_avatar.dart';

class FeedPostCard extends StatelessWidget {
  final Post post;
  final AppUser? currentUser;
  const FeedPostCard({super.key, required this.post, required this.currentUser});

  void _openProfile(BuildContext context) {
    if (post.authorId.isEmpty) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ProfileScreen(
          uid: post.authorId,
          isMe: currentUser?.uid == post.authorId,
        ),
      ),
    );
  }

  void _openDetail(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PostDetailScreen(
          postId: post.id,
          currentUser: currentUser,
        ),
      ),
    );
  }

  void _toggleLike() {
    final me = currentUser;
    if (me == null) return;
    FirestoreService.instance.toggleLike(postId: post.id, uid: me.uid);
  }

  @override
  Widget build(BuildContext context) {
    final liked = currentUser != null && post.likes.contains(currentUser!.uid);
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(.05),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                GestureDetector(
                  onTap: () => _openProfile(context),
                  child: LiveUserAvatar(
                    uid: post.authorId,
                    fallbackAvatarUrl: post.authorAvatarUrl,
                    fallbackSeed: post.authorUsername.isEmpty
                        ? post.authorName
                        : post.authorUsername,
                    size: 38,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: GestureDetector(
                    onTap: () => _openProfile(context),
                    child: LiveUserName(
                      uid: post.authorId,
                      fallbackDisplayName: post.authorName,
                      fallbackUsername: post.authorUsername,
                      trailing: ' · ${_ago(post.createdAt)}',
                      nameStyle:
                          const TextStyle(fontWeight: FontWeight.w600),
                      subStyle: const TextStyle(
                          color: AppColors.textMuted, fontSize: 12),
                    ),
                  ),
                ),
                const Icon(Icons.more_horiz, color: AppColors.textMuted),
              ],
            ),
          ),
          GestureDetector(
            onTap: () => _openDetail(context),
            child: Container(
              height: 240,
              margin: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                color: AppColors.softBg,
              ),
              clipBehavior: Clip.antiAlias,
              child: post.imageUrl.isNotEmpty
                  ? CachedNetworkImage(
                      imageUrl: post.imageUrl,
                      fit: BoxFit.cover,
                      width: double.infinity,
                      placeholder: (_, __) => Container(
                        color: AppColors.softBg,
                        alignment: Alignment.center,
                        child: const CircularProgressIndicator(strokeWidth: 2),
                      ),
                      errorWidget: (_, __, ___) => Container(
                        decoration: const BoxDecoration(gradient: AppColors.sunset),
                        alignment: Alignment.center,
                        child: const Icon(Icons.broken_image,
                            color: Colors.white, size: 48),
                      ),
                    )
                  : Container(
                      decoration: const BoxDecoration(gradient: AppColors.sunset),
                      alignment: Alignment.center,
                      child: const Icon(Icons.image,
                          color: Colors.white, size: 64),
                    ),
            ),
          ),
          if (post.caption.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Text(post.caption,
                  style: const TextStyle(fontSize: 13.5, height: 1.4)),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 6, 12, 10),
            child: Row(
              children: [
                GestureDetector(
                  onTap: _toggleLike,
                  child: Row(
                    children: [
                      Icon(
                        liked ? Icons.favorite : Icons.favorite_border,
                        color: AppColors.primaryPink,
                        size: 22,
                      ),
                      const SizedBox(width: 4),
                      Text('${post.likesCount}',
                          style: const TextStyle(fontSize: 12.5)),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                GestureDetector(
                  onTap: () => _openDetail(context),
                  child: Row(
                    children: [
                      const Icon(Icons.mode_comment_outlined,
                          color: AppColors.textDark, size: 22),
                      const SizedBox(width: 4),
                      Text('${post.commentsCount}',
                          style: const TextStyle(fontSize: 12.5)),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                GestureDetector(
                  onTap: () => ShareToChatSheet.show(context, post),
                  child: const Icon(Icons.send_outlined,
                      color: AppColors.textDark, size: 22),
                ),
                const Spacer(),
                const Icon(Icons.bookmark_border, color: AppColors.textDark),
              ],
            ),
          ),
        ],
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
