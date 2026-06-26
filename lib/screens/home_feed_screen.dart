import 'package:flutter/material.dart';

import '../models/post_model.dart';
import '../models/story.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import '../theme/app_theme.dart';
import '../widgets/feed_post_card.dart';
import '../widgets/live_user_avatar.dart';
import 'chats_inbox_screen.dart';
import 'friends_screen.dart';
import 'story_create_screen.dart';
import 'story_viewer_screen.dart';
import 'trending_screen.dart';

enum _FeedTab { all, trending, popular, saved }

class HomeFeedScreen extends StatefulWidget {
  final AppUser? currentUser;
  final VoidCallback onMenu;
  const HomeFeedScreen({
    super.key,
    required this.currentUser,
    required this.onMenu,
  });

  @override
  State<HomeFeedScreen> createState() => _HomeFeedScreenState();
}

class _HomeFeedScreenState extends State<HomeFeedScreen> {
  _FeedTab _tab = _FeedTab.all;

  Stream<List<Post>> _stream() {
    switch (_tab) {
      case _FeedTab.trending:
      case _FeedTab.popular:
        return FirestoreService.instance.trendingStream();
      case _FeedTab.all:
      case _FeedTab.saved:
        return FirestoreService.instance.feedStream();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F4F2),
      body: StreamBuilder<List<Post>>(
        stream: _stream(),
        builder: (context, snap) {
          final posts = snap.data ?? const <Post>[];
          return CustomScrollView(
            slivers: [
              SliverToBoxAdapter(child: _header(context)),
              SliverToBoxAdapter(child: _storiesRow()),
              SliverToBoxAdapter(child: _tabsRow()),
              if (snap.connectionState == ConnectionState.waiting)
                const SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (posts.isEmpty)
                const SliverFillRemaining(
                  hasScrollBody: false,
                  child: _EmptyFeed(),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.only(top: 4, bottom: 28),
                  sliver: SliverList.builder(
                    itemCount: posts.length,
                    itemBuilder: (_, i) => FeedPostCard(
                      post: posts[i],
                      currentUser: widget.currentUser,
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  // ----- header -----
  Widget _header(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: AppColors.vibrant,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(36)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 56, 20, 18),
      child: Row(
        children: [
          GestureDetector(
            onTap: widget.onMenu,
            child: const Icon(Icons.menu_rounded,
                color: Colors.white, size: 30),
          ),
          const SizedBox(width: 14),
          const Text(
            'iFriends',
            style: TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w700,
              letterSpacing: -.5,
            ),
          ),
          const Spacer(),
          GestureDetector(
            onTap: () => _openSearch(context),
            child: const Icon(Icons.search_rounded,
                color: Colors.white, size: 26),
          ),
          const SizedBox(width: 18),
          GestureDetector(
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const ChatsInboxScreen()),
            ),
            child: const Icon(Icons.notifications_none_rounded,
                color: Colors.white, size: 26),
          ),
        ],
      ),
    );
  }

  void _openSearch(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => FriendsScreen(currentUser: widget.currentUser),
      ),
    );
  }

  // ----- stories row -----
  Widget _storiesRow() {
    return StreamBuilder<List<StoryGroup>>(
      stream: FirestoreService.instance.activeStoriesStream(),
      builder: (context, snap) {
        final groups = snap.data ?? const <StoryGroup>[];
        final myUid = AuthService.instance.currentUser?.uid ?? '';
        final following = widget.currentUser?.following ?? const <String>[];

        // Pull out my own group so it always pins to the left.
        StoryGroup? mine;
        final others = <StoryGroup>[];
        for (final g in groups) {
          if (myUid.isNotEmpty && g.authorId == myUid) {
            mine = g;
          } else {
            // Instagram-style: only show stories from accounts I follow.
            if (following.contains(g.authorId)) {
              others.add(g);
            }
          }
        }
        // Unwatched first, then watched. Recency within each bucket.
        final unwatched = <StoryGroup>[];
        final watched = <StoryGroup>[];
        for (final g in others) {
          if (myUid.isNotEmpty && g.allViewedBy(myUid)) {
            watched.add(g);
          } else {
            unwatched.add(g);
          }
        }
        final ordered = [...unwatched, ...watched];

        return Transform.translate(
          offset: const Offset(0, -36),
          child: SizedBox(
            height: 96,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                _myStoryBubble(mine, myUid),
                for (final g in ordered) _storyBubble(g, myUid: myUid),
              ],
            ),
          ),
        );
      },
    );
  }

  void _openCreator() {
    final me = widget.currentUser;
    if (me == null) return;
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => StoryCreateScreen(currentUser: me)),
    );
  }

  /// Left-most bubble. Acts as creator. If I already have an active story
  /// it doubles as my own story entry with a small `+` badge.
  Widget _myStoryBubble(StoryGroup? mine, String myUid) {
    final hasStory = mine != null && mine.stories.isNotEmpty;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: GestureDetector(
        onTap: () {
          if (hasStory) {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => StoryViewerScreen(stories: mine.stories),
              ),
            );
          } else {
            _openCreator();
          }
        },
        onLongPress: hasStory ? _openCreator : null,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            if (hasStory)
              _StoryRing(
                viewed: mine.allViewedBy(myUid),
                child: LiveUserAvatar(
                  uid: myUid,
                  fallbackSeed: myUid,
                  size: 60,
                ),
              )
            else
              Container(
                width: 76,
                height: 76,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white,
                  border: Border.all(
                      color: const Color(0xFFFFD2C8), width: 3),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(.06),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Container(
                  margin: const EdgeInsets.all(8),
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: AppColors.vibrant,
                  ),
                  child:
                      const Icon(Icons.add, color: Colors.white, size: 28),
                ),
              ),
            if (hasStory)
              Positioned(
                right: -2,
                bottom: -2,
                child: Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: AppColors.vibrant,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                  child:
                      const Icon(Icons.add, color: Colors.white, size: 14),
                ),
              ),
            if (hasStory)
              Positioned(
                left: -1,
                bottom: -1,
                child: LiveVerifiedBadge(
                    uid: myUid, size: 18, withBackground: true),
              ),
          ],
        ),
      ),
    );
  }

  Widget _storyBubble(StoryGroup g, {required String myUid}) {
    final viewed = myUid.isNotEmpty && g.allViewedBy(myUid);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: GestureDetector(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => StoryViewerScreen(stories: g.stories),
          ),
        ),
        child: _StoryRing(
          viewed: viewed,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              LiveUserAvatar(
                uid: g.authorId,
                fallbackSeed: g.authorId,
                size: 60,
              ),
              Positioned(
                right: -1,
                bottom: -1,
                child: LiveVerifiedBadge(
                    uid: g.authorId, size: 18, withBackground: true),
              ),
            ],
          ),
        ),
      ),
    );
  }

    // ----- filter tabs -----
  Widget _tabsRow() {
    return Transform.translate(
      offset: const Offset(0, -28),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(.05),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          children: [
            _tabBtn(_FeedTab.all, Icons.view_list_rounded),
            _tabBtn(_FeedTab.trending, Icons.local_fire_department_rounded),
            _tabBtn(_FeedTab.popular, Icons.bar_chart_rounded),
            _tabBtn(_FeedTab.saved, Icons.bookmark_border_rounded),
          ],
        ),
      ),
    );
  }

  Widget _tabBtn(_FeedTab tab, IconData icon) {
    final selected = _tab == tab;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          if (tab == _FeedTab.popular) {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => TrendingScreen(currentUser: widget.currentUser),
              ),
            );
            return;
          }
          setState(() => _tab = tab);
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          height: 44,
          decoration: BoxDecoration(
            gradient: selected ? AppColors.vibrant : null,
            borderRadius: BorderRadius.circular(14),
          ),
          alignment: Alignment.center,
          child: Icon(
            icon,
            size: 22,
            color: selected ? Colors.white : const Color(0xFF9A9A9A),
          ),
        ),
      ),
    );
  }
}

class _EmptyFeed extends StatelessWidget {
  const _EmptyFeed();
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 92,
              height: 92,
              decoration: BoxDecoration(
                gradient: AppColors.warm,
                borderRadius: BorderRadius.circular(28),
              ),
              child: const Icon(Icons.photo_camera,
                  color: Colors.white, size: 44),
            ),
            const SizedBox(height: 18),
            const Text('Belum ada postingan',
                style:
                    TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            const Text(
              'Tekan tombol + untuk berbagi momen pertamamu.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textMuted),
            ),
          ],
        ),
      ),
    );
  }
}

/// Story bubble ring — animated rotating gradient when unwatched, flat
/// grey when watched. Centralises the visual so creator + viewer bubbles
/// stay consistent.
class _StoryRing extends StatefulWidget {
  final bool viewed;
  final Widget child;
  const _StoryRing({required this.viewed, required this.child});

  @override
  State<_StoryRing> createState() => _StoryRingState();
}

class _StoryRingState extends State<_StoryRing>
    with SingleTickerProviderStateMixin {
  late final AnimationController _spin;

  @override
  void initState() {
    super.initState();
    _spin = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    );
    _maybeAnimate();
  }

  @override
  void didUpdateWidget(covariant _StoryRing oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.viewed != widget.viewed) _maybeAnimate();
  }

  void _maybeAnimate() {
    if (widget.viewed) {
      _spin.stop();
    } else {
      _spin.repeat();
    }
  }

  @override
  void dispose() {
    _spin.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _spin,
      builder: (_, child) {
        return Container(
          width: 76,
          height: 76,
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: widget.viewed ? const Color(0xFFD9D9D9) : null,
            gradient: widget.viewed
                ? null
                : SweepGradient(
                    transform:
                        GradientRotation(_spin.value * 6.2831853),
                    colors: const [
                      Color(0xFFFF5E8A),
                      Color(0xFFFF7A59),
                      Color(0xFFFFB347),
                      Color(0xFFFF5E8A),
                    ],
                  ),
          ),
          child: child,
        );
      },
      child: Container(
        padding: const EdgeInsets.all(2.5),
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white,
        ),
        child: widget.child,
      ),
    );
  }
}
