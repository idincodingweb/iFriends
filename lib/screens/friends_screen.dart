import 'dart:async';
import 'package:flutter/material.dart';

import '../models/user_model.dart';
import '../services/firestore_service.dart';
import '../theme/app_theme.dart';
import '../widgets/user_avatar.dart';
import 'profile_screen.dart';

class FriendsScreen extends StatefulWidget {
  final AppUser? currentUser;
  const FriendsScreen({super.key, required this.currentUser});

  @override
  State<FriendsScreen> createState() => _FriendsScreenState();
}

class _FriendsScreenState extends State<FriendsScreen> {
  final _ctrl = TextEditingController();
  Timer? _debounce;
  List<AppUser> _results = [];
  bool _loading = false;

  void _onChanged(String q) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () => _search(q));
  }

  Future<void> _search(String q) async {
    if (q.trim().isEmpty) {
      setState(() => _results = []);
      return;
    }
    setState(() => _loading = true);
    try {
      final r = await FirestoreService.instance.searchUsers(q);
      setState(() => _results =
          r.where((u) => u.uid != widget.currentUser?.uid).toList());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final me = widget.currentUser;
    return Scaffold(
      backgroundColor: AppColors.bgWhite,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Row(
                children: [
                  ShaderMask(
                    shaderCallback: (b) => AppColors.vibrant.createShader(b),
                    child: const Text(
                      'Find Friends',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: TextField(
                controller: _ctrl,
                onChanged: _onChanged,
                decoration: InputDecoration(
                  hintText: 'Search by name or @username',
                  prefixIcon: const Icon(Icons.search),
                  filled: true,
                  fillColor: AppColors.softBg,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _results.isEmpty
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(32),
                            child: Text(
                              _ctrl.text.isEmpty
                                  ? 'Type to discover people on iFriends ✨'
                                  : 'No users found.',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                  color: AppColors.textMuted),
                            ),
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 4),
                          itemCount: _results.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 4),
                          itemBuilder: (_, i) {
                            final u = _results[i];
                            final following =
                                me?.following.contains(u.uid) ?? false;
                            return ListTile(
                              onTap: () => Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => ProfileScreen(
                                    uid: u.uid,
                                    isMe: false,
                                  ),
                                ),
                              ),
                              leading: UserAvatar(
                                  avatarUrl: u.avatarUrl,
                                  seed: u.username,
                                  size: 46),
                              title: Row(
                                children: [
                                  Flexible(
                                    child: Text(u.displayName,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                            fontWeight: FontWeight.w600)),
                                  ),
                                  if (u.isVerified) ...[
                                    const SizedBox(width: 4),
                                    const Icon(Icons.verified,
                                        color: AppColors.primaryCoral,
                                        size: 16),
                                  ],
                                ],
                              ),
                              subtitle: Text('@${u.username}',
                                  style: const TextStyle(
                                      color: AppColors.textMuted)),
                              trailing: me == null
                                  ? null
                                  : GestureDetector(
                                      onTap: () => FirestoreService.instance
                                          .toggleFollow(
                                        currentUid: me.uid,
                                        targetUid: u.uid,
                                      ),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 14, vertical: 8),
                                        decoration: BoxDecoration(
                                          gradient: following
                                              ? null
                                              : AppColors.vibrant,
                                          color: following
                                              ? AppColors.softBg
                                              : null,
                                          borderRadius:
                                              BorderRadius.circular(12),
                                        ),
                                        child: Text(
                                          following ? 'Following' : 'Follow',
                                          style: TextStyle(
                                            color: following
                                                ? AppColors.textDark
                                                : Colors.white,
                                            fontWeight: FontWeight.w600,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ),
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
