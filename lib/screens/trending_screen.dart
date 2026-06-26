import 'package:flutter/material.dart';

import '../models/post_model.dart';
import '../models/user_model.dart';
import '../services/firestore_service.dart';
import '../theme/app_theme.dart';
import '../widgets/feed_post_card.dart';

class TrendingScreen extends StatelessWidget {
  final AppUser? currentUser;
  const TrendingScreen({super.key, required this.currentUser});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgWhite,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      gradient: AppColors.vibrant,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.local_fire_department,
                        color: Colors.white, size: 20),
                  ),
                  const SizedBox(width: 12),
                  const Text('Trending',
                      style: TextStyle(
                          fontSize: 22, fontWeight: FontWeight.w700)),
                  const Spacer(),
                  const Text('Last 7 days',
                      style: TextStyle(color: AppColors.textMuted)),
                ],
              ),
            ),
            Expanded(
              child: StreamBuilder<List<Post>>(
                stream: FirestoreService.instance.trendingStream(),
                builder: (context, snap) {
                  if (snap.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final posts = snap.data ?? const [];
                  if (posts.isEmpty) {
                    return const Center(
                      child: Padding(
                        padding: EdgeInsets.all(32),
                        child: Text(
                          'No trending posts yet.\nBe the first to set the vibe! 🔥',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: AppColors.textMuted),
                        ),
                      ),
                    );
                  }
                  return ListView.builder(
                    padding: const EdgeInsets.only(top: 4, bottom: 24),
                    itemCount: posts.length,
                    itemBuilder: (_, i) => FeedPostCard(
                      post: posts[i],
                      currentUser: currentUser,
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
