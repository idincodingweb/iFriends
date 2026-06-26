import 'package:flutter/material.dart';

import '../models/post_model.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import '../theme/app_theme.dart';
import '../widgets/feed_post_card.dart';

/// Lists every post tagged with a given hashtag. Opened by tapping a `#tag`
/// link in a caption or comment.
class HashtagScreen extends StatelessWidget {
  final String tag;
  const HashtagScreen({super.key, required this.tag});

  @override
  Widget build(BuildContext context) {
    final myUid = AuthService.instance.currentUser?.uid ?? '';
    return Scaffold(
      backgroundColor: AppColors.bgWhite,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: AppColors.textDark,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                gradient: AppColors.vibrant,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.tag, color: Colors.white, size: 18),
            ),
            const SizedBox(width: 10),
            Flexible(
              child: Text('#$tag',
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      ),
      body: StreamBuilder<AppUser?>(
        stream: myUid.isEmpty
            ? const Stream<AppUser?>.empty()
            : FirestoreService.instance.userStream(myUid),
        initialData: myUid.isEmpty
            ? null
            : FirestoreService.instance.cachedUser(myUid),
        builder: (context, meSnap) {
          final me = meSnap.data;
          return StreamBuilder<List<Post>>(
            stream: FirestoreService.instance.hashtagPostsStream(tag),
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              final posts = snap.data ?? const <Post>[];
              if (posts.isEmpty) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Text(
                      'No posts with #$tag yet.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: AppColors.textMuted),
                    ),
                  ),
                );
              }
              return ListView.builder(
                padding: const EdgeInsets.only(top: 8, bottom: 24),
                itemCount: posts.length,
                itemBuilder: (_, i) =>
                    FeedPostCard(post: posts[i], currentUser: me),
              );
            },
          );
        },
      ),
    );
  }
}
