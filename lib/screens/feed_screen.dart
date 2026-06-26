import 'package:flutter/material.dart';
import '../models/mock_data.dart';
import '../theme/app_theme.dart';
import '../widgets/feed_post_card.dart';
import '../widgets/gradient_avatar.dart';

class FeedScreen extends StatefulWidget {
  const FeedScreen({super.key});
  @override
  State<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends State<FeedScreen> {
  int _tab = 0;
  final _tabs = const [
    (Icons.view_list_rounded, 'List'),
    (Icons.local_fire_department_rounded, 'Hot'),
    (Icons.bar_chart_rounded, 'Analytics'),
    (Icons.bookmark_rounded, 'Saved'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgWhite,
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(child: _buildHeader()),
          SliverToBoxAdapter(child: _buildTabs()),
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (_, i) => FeedPostCard(post: MockData.posts[i]),
              childCount: MockData.posts.length,
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 24)),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      decoration: const BoxDecoration(
        gradient: AppColors.vibrant,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(32)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 60, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.menu, color: Colors.white, size: 28),
              const SizedBox(width: 12),
              const Text('iFriends',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -.5)),
              const Spacer(),
              _circleIcon(Icons.search),
              const SizedBox(width: 8),
              _circleIcon(Icons.notifications_none),
            ],
          ),
          const SizedBox(height: 18),
          SizedBox(
            height: 78,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: MockData.stories.length + 1,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (_, i) {
                if (i == 0) {
                  return Column(
                    children: [
                      Container(
                        width: 60, height: 60,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withOpacity(.3),
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                        child: const Icon(Icons.add, color: Colors.white, size: 28),
                      ),
                      const SizedBox(height: 4),
                      const Text('You',
                          style: TextStyle(color: Colors.white, fontSize: 11)),
                    ],
                  );
                }
                final s = MockData.stories[i - 1];
                return Column(
                  children: [
                    GradientAvatar(
                      size: 60,
                      child: Container(
                        color: s.color.withOpacity(.2),
                        alignment: Alignment.center,
                        child: Icon(s.icon, color: s.color, size: 26),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(s.name,
                        style: const TextStyle(color: Colors.white, fontSize: 11)),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _circleIcon(IconData icon) {
    return Container(
      width: 38, height: 38,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(.2),
        shape: BoxShape.circle,
      ),
      child: Icon(icon, color: Colors.white, size: 20),
    );
  }

  Widget _buildTabs() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
      child: Row(
        children: List.generate(_tabs.length, (i) {
          final selected = i == _tab;
          final (icon, label) = _tabs[i];
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: () => setState(() => _tab = i),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: EdgeInsets.symmetric(
                    horizontal: selected ? 16 : 12, vertical: 10),
                decoration: BoxDecoration(
                  gradient: selected ? AppColors.vibrant : null,
                  color: selected ? null : AppColors.softBg,
                  borderRadius: BorderRadius.circular(30),
                ),
                child: Row(
                  children: [
                    Icon(icon,
                        size: 18,
                        color: selected ? Colors.white : AppColors.textMuted),
                    if (selected) ...[
                      const SizedBox(width: 6),
                      Text(label,
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                              fontSize: 12)),
                    ],
                  ],
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}
