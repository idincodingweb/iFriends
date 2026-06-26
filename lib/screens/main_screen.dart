import 'package:flutter/material.dart';

import '../models/user_model.dart';
import '../services/firestore_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_drawer.dart';
import 'create_post_screen.dart';
import 'friends_screen.dart';
import 'home_feed_screen.dart';
import 'profile_screen.dart';
import 'trending_screen.dart';

class MainScreen extends StatefulWidget {
  final String uid;
  const MainScreen({super.key, required this.uid});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _index = 0;
  final _scaffoldKey = GlobalKey<ScaffoldState>();

  void _openCreate(AppUser? me) {
    if (me == null) return;
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => CreatePostScreen(currentUser: me)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AppUser?>(
      stream: FirestoreService.instance.userStream(widget.uid),
      builder: (context, snap) {
        final me = snap.data;
        final pages = <Widget>[
          HomeFeedScreen(
            currentUser: me,
            onMenu: () => _scaffoldKey.currentState?.openDrawer(),
          ),
          FriendsScreen(currentUser: me),
          const SizedBox.shrink(),
          TrendingScreen(currentUser: me),
          ProfileScreen(uid: widget.uid, isMe: true),
        ];

        return Scaffold(
          key: _scaffoldKey,
          drawer: AppDrawerMenu(
            user: me,
            onProfileTap: () {
              Navigator.of(context).pop();
              setState(() => _index = 4);
            },
          ),
          body: IndexedStack(index: _index, children: pages),
          bottomNavigationBar: _BottomBar(
            index: _index,
            onTap: (i) {
              if (i == 2) {
                _openCreate(me);
              } else {
                setState(() => _index = i);
              }
            },
          ),
        );
      },
    );
  }
}

class _BottomBar extends StatelessWidget {
  final int index;
  final ValueChanged<int> onTap;
  const _BottomBar({required this.index, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final items = [
      Icons.home_rounded,
      Icons.people_alt_rounded,
      Icons.add,
      Icons.local_fire_department_rounded,
      Icons.person_rounded,
    ];
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(.05),
            blurRadius: 20,
            offset: const Offset(0, -4),
          )
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: SafeArea(
        top: false,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: List.generate(items.length, (i) {
            final selected = i == index;
            if (i == 2) {
              return GestureDetector(
                onTap: () => onTap(i),
                child: Container(
                  width: 52,
                  height: 52,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: AppColors.vibrant,
                  ),
                  child: const Icon(Icons.add, color: Colors.white, size: 28),
                ),
              );
            }
            return IconButton(
              onPressed: () => onTap(i),
              icon: ShaderMask(
                shaderCallback: (b) => (selected
                        ? AppColors.vibrant
                        : const LinearGradient(
                            colors: [Color(0xFF9A9A9A), Color(0xFF9A9A9A)]))
                    .createShader(b),
                child: Icon(items[i], size: 28, color: Colors.white),
              ),
            );
          }),
        ),
      ),
    );
  }
}
