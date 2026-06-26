import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../models/post_model.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import '../theme/app_theme.dart';
import 'post_detail_screen.dart';

/// Grid of posts the current user archived. Tapping a tile opens it in
/// detail view with an "Unarchive" option, so users can restore posts
/// back to their feed/profile.
class ArchiveScreen extends StatelessWidget {
  const ArchiveScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = AuthService.instance.currentUser?.uid ?? '';
    return Scaffold(
      backgroundColor: AppColors.bgWhite,
      appBar: AppBar(
        title: const Text('Archive'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: AppColors.textDark,
      ),
      body: uid.isEmpty
          ? const Center(child: Text('Sign in to see your archive.'))
          : StreamBuilder<List<Post>>(
              stream: FirestoreService.instance.archivedPostsStream(uid),
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final posts = snap.data ?? const <Post>[];
                if (posts.isEmpty) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(32),
                      child: Text(
                        'No archived posts.\nArchive a post from its three-dot menu to hide it from your feed.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: AppColors.textMuted),
                      ),
                    ),
                  );
                }
                return GridView.builder(
                  padding: const EdgeInsets.all(12),
                  gridDelegate:
                      const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    mainAxisSpacing: 6,
                    crossAxisSpacing: 6,
                  ),
                  itemCount: posts.length,
                  itemBuilder: (_, i) {
                    final p = posts[i];
                    return _ArchiveTile(post: p, ownerUid: uid);
                  },
                );
              },
            ),
    );
  }
}

class _ArchiveTile extends StatelessWidget {
  final Post post;
  final String ownerUid;
  const _ArchiveTile({required this.post, required this.ownerUid});

  void _open(BuildContext context) {
    final me = FirestoreService.instance.cachedUser(ownerUid);
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => Scaffold(
          appBar: AppBar(
            title: const Text('Archived post'),
            backgroundColor: Colors.transparent,
            elevation: 0,
            foregroundColor: AppColors.textDark,
            actions: [
              TextButton.icon(
                onPressed: () async {
                  await FirestoreService.instance
                      .setPostArchived(post.id, false);
                  if (context.mounted) {
                    Navigator.of(context).pop();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Post restored')),
                    );
                  }
                },
                icon: const Icon(Icons.unarchive_outlined,
                    color: AppColors.primaryCoral),
                label: const Text(
                  'Unarchive',
                  style: TextStyle(color: AppColors.primaryCoral),
                ),
              ),
            ],
          ),
          body: PostDetailScreen(postId: post.id, currentUser: me),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final img = post.images.isNotEmpty ? post.images.first : '';
    return GestureDetector(
      onTap: () => _open(context),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (img.isNotEmpty)
              CachedNetworkImage(imageUrl: img, fit: BoxFit.cover)
            else
              Container(
                color: AppColors.softBg,
                child:
                    const Icon(Icons.image, color: AppColors.textMuted),
              ),
            Positioned(
              top: 6,
              left: 6,
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(.55),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.archive,
                        size: 12, color: Colors.white),
                    SizedBox(width: 4),
                    Text('Archived',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
