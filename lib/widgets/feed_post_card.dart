import 'package:flutter/material.dart';

import '../models/post_model.dart';
import '../models/user_model.dart';
import '../screens/edit_post_screen.dart';
import '../screens/post_detail_screen.dart';
import '../screens/profile_screen.dart';
import '../screens/share_to_chat_screen.dart';
import '../services/firestore_service.dart';
import '../theme/app_theme.dart';
import 'linked_text.dart';
import 'live_user_avatar.dart';
import 'post_image_carousel.dart';

class FeedPostCard extends StatelessWidget {
  final Post post;
  final AppUser? currentUser;
  const FeedPostCard({super.key, required this.post, this.currentUser});

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

  void _showMenu(BuildContext context) {
    final isOwner = currentUser != null && currentUser!.uid == post.authorId;
    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetCtx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.send_outlined),
                title: const Text('Share to chat'),
                onTap: () {
                  Navigator.pop(sheetCtx);
                  ShareToChatSheet.show(context, post);
                },
              ),
              if (isOwner) ...[
                ListTile(
                  leading: const Icon(Icons.edit_outlined),
                  title: const Text('Edit caption'),
                  onTap: () {
                    Navigator.pop(sheetCtx);
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => EditPostScreen(
                          postId: post.id,
                          initialCaption: post.caption,
                        ),
                      ),
                    );
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.archive_outlined),
                  title: const Text('Archive post'),
                  subtitle: const Text(
                    'Hide from your feed and profile. You can restore it later.',
                    style: TextStyle(fontSize: 11),
                  ),
                  onTap: () async {
                    Navigator.pop(sheetCtx);
                    await FirestoreService.instance
                        .setPostArchived(post.id, true);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Post archived')),
                      );
                    }
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.delete_outline, color: Colors.red),
                  title: const Text('Delete post',
                      style: TextStyle(color: Colors.red)),
                  onTap: () async {
                    Navigator.pop(sheetCtx);
                    await _confirmDelete(context);
                  },
                ),
              ] else ...[
                ListTile(
                  leading: const Icon(Icons.flag_outlined),
                  title: const Text('Report post'),
                  onTap: () async {
                    Navigator.pop(sheetCtx);
                    await _reportPost(context);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.block, color: Colors.red),
                  title: Text(
                    'Block @${post.authorUsername.isEmpty ? post.authorName : post.authorUsername}',
                    style: const TextStyle(color: Colors.red),
                  ),
                  onTap: () async {
                    Navigator.pop(sheetCtx);
                    await _confirmBlock(context);
                  },
                ),
              ],

            ],
          ),
        );
      },
    );
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete post?'),
        content: const Text('This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (ok == true) {
      await FirestoreService.instance.deletePost(post.id);
    }
  }

  Future<void> _reportPost(BuildContext context) async {
    final me = currentUser;
    if (me == null) return;
    final reason = await showModalBottomSheet<String>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        const reasons = [
          'Spam',
          'Konten dewasa / tidak pantas',
          'Pelecehan / kebencian',
          'Informasi salah',
          'Lainnya',
        ];
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Text('Laporkan post',
                    style: TextStyle(fontWeight: FontWeight.w700)),
              ),
              for (final r in reasons)
                ListTile(
                  title: Text(r),
                  onTap: () => Navigator.pop(ctx, r),
                ),
            ],
          ),
        );
      },
    );
    if (reason == null) return;
    await FirestoreService.instance.reportPost(
      postId: post.id,
      reporterUid: me.uid,
      reason: reason,
      authorId: post.authorId,
    );
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Laporan terkirim. Terima kasih.')),
      );
    }
  }

  Future<void> _confirmBlock(BuildContext context) async {
    final me = currentUser;
    if (me == null) return;
    final name = post.authorUsername.isEmpty
        ? post.authorName
        : '@${post.authorUsername}';
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Block $name?'),
        content: const Text(
            'Mereka tidak akan bisa melihat profil/postmu, dan kamu tidak akan melihat konten mereka.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Batal')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Block', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await FirestoreService.instance.blockUser(
      currentUid: me.uid,
      targetUid: post.authorId,
    );
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$name diblokir.')),
      );
    }
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
                      trailing: ' · ${_ago(post.createdAt)}'
                          '${post.isEdited ? ' · edited' : ''}',
                      nameStyle:
                          const TextStyle(fontWeight: FontWeight.w600),
                      subStyle: const TextStyle(
                          color: AppColors.textMuted, fontSize: 12),
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: () => _showMenu(context),
                  behavior: HitTestBehavior.opaque,
                  child: const Padding(
                    padding: EdgeInsets.all(4),
                    child:
                        Icon(Icons.more_horiz, color: AppColors.textMuted),
                  ),
                ),
              ],
            ),
          ),
          PostImageCarousel(
            images: post.images,
            height: 240,
            margin: const EdgeInsets.symmetric(horizontal: 12),
            onTap: () => _openDetail(context),
          ),
          if (post.caption.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: LinkedText(
                post.caption,
                style: const TextStyle(
                    fontSize: 13.5, height: 1.4, color: AppColors.textDark),
              ),
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
                _BookmarkButton(postId: post.id, currentUser: currentUser),
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

class _BookmarkButton extends StatelessWidget {
  final String postId;
  final AppUser? currentUser;
  const _BookmarkButton({required this.postId, required this.currentUser});

  @override
  Widget build(BuildContext context) {
    final me = currentUser;
    if (me == null) {
      return const Icon(Icons.bookmark_border, color: AppColors.textDark);
    }
    return StreamBuilder<AppUser?>(
      stream: FirestoreService.instance.userStream(me.uid),
      initialData: FirestoreService.instance.cachedUser(me.uid) ?? me,
      builder: (context, snap) {
        final saved = (snap.data?.saved ?? me.saved).contains(postId);
        return GestureDetector(
          onTap: () => FirestoreService.instance.toggleSavePost(
            uid: me.uid,
            postId: postId,
          ),
          child: Icon(
            saved ? Icons.bookmark : Icons.bookmark_border,
            color: saved ? AppColors.primaryCoral : AppColors.textDark,
          ),
        );
      },
    );
  }
}
