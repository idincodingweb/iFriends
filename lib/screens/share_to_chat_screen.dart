import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../models/post_model.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import '../theme/app_theme.dart';
import '../widgets/user_avatar.dart';

/// Instagram-style share-to-DM bottom sheet.
/// - Drag handle at the top
/// - Search bar
/// - Grid of recipients (followers + following)
/// - Per-row "Send" / "Sent" button
class ShareToChatSheet extends StatefulWidget {
  final Post post;
  const ShareToChatSheet({super.key, required this.post});

  static Future<void> show(BuildContext context, Post post) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ShareToChatSheet(post: post),
    );
  }

  @override
  State<ShareToChatSheet> createState() => _ShareToChatSheetState();
}

class _ShareToChatSheetState extends State<ShareToChatSheet> {
  final _searchCtrl = TextEditingController();
  String _query = '';
  // uid -> sending/sent state
  final Map<String, _SendState> _state = {};

  Future<void> _ensureUser(String uid) async {
    if (FirestoreService.instance.cachedUser(uid) != null) return;
    await FirestoreService.instance.getUser(uid);
  }

  Future<void> _send(AppUser me, AppUser other) async {
    if (_state[other.uid] != _SendState.idle &&
        _state[other.uid] != null) {
      return;
    }
    setState(() => _state[other.uid] = _SendState.sending);
    try {
      final chat = await FirestoreService.instance.ensureChat(me.uid, other.uid);
      await FirestoreService.instance.sendSharedPost(
        chatId: chat.id,
        senderId: me.uid,
        post: widget.post,
      );
      if (!mounted) return;
      setState(() => _state[other.uid] = _SendState.sent);
    } catch (_) {
      if (!mounted) return;
      setState(() => _state[other.uid] = _SendState.idle);
    }
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final myUid = AuthService.instance.currentUser?.uid ?? '';
    final h = MediaQuery.of(context).size.height;
    return DraggableScrollableSheet(
      initialChildSize: 0.78,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (_, scrollCtrl) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 10),
              Container(
                width: 40, height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFD9D9D9),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 14),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: TextField(
                  controller: _searchCtrl,
                  onChanged: (v) => setState(() => _query = v.trim().toLowerCase()),
                  decoration: InputDecoration(
                    hintText: 'Cari',
                    prefixIcon: const Icon(Icons.search, color: AppColors.textMuted),
                    filled: true,
                    fillColor: const Color(0xFFF1F1F2),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(vertical: 0),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: myUid.isEmpty
                    ? const Center(child: Text('Sign in to share.'))
                    : StreamBuilder<AppUser?>(
                        stream: FirestoreService.instance.userStream(myUid),
                        initialData: FirestoreService.instance.cachedUser(myUid),
                        builder: (context, msnap) {
                          final me = msnap.data;
                          if (me == null) {
                            return const Center(child: CircularProgressIndicator());
                          }
                          final recipients = <String>{
                            ...me.following,
                            ...me.followers,
                          }.where((u) => u != me.uid).toList();
                          if (recipients.isEmpty) {
                            return const Center(
                              child: Padding(
                                padding: EdgeInsets.all(32),
                                child: Text(
                                  'Follow seseorang untuk mulai berbagi.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(color: AppColors.textMuted),
                                ),
                              ),
                            );
                          }
                          return _RecipientGrid(
                            scrollController: scrollCtrl,
                            recipientUids: recipients,
                            query: _query,
                            me: me,
                            stateMap: _state,
                            ensureUser: _ensureUser,
                            onSend: _send,
                          );
                        },
                      ),
              ),
              const _ActionsRow(),
              SizedBox(height: MediaQuery.of(context).padding.bottom),
            ],
          ),
        );
      },
    );
  }
}

enum _SendState { idle, sending, sent }

class _RecipientGrid extends StatefulWidget {
  final ScrollController scrollController;
  final List<String> recipientUids;
  final String query;
  final AppUser me;
  final Map<String, _SendState> stateMap;
  final Future<void> Function(String) ensureUser;
  final Future<void> Function(AppUser, AppUser) onSend;
  const _RecipientGrid({
    required this.scrollController,
    required this.recipientUids,
    required this.query,
    required this.me,
    required this.stateMap,
    required this.ensureUser,
    required this.onSend,
  });

  @override
  State<_RecipientGrid> createState() => _RecipientGridState();
}

class _RecipientGridState extends State<_RecipientGrid> {
  final Map<String, AppUser?> _users = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    for (final uid in widget.recipientUids) {
      final cached = FirestoreService.instance.cachedUser(uid);
      if (cached != null) {
        _users[uid] = cached;
        continue;
      }
      final u = await FirestoreService.instance.getUser(uid);
      if (!mounted) return;
      _users[uid] = u;
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final all = _users.values.whereType<AppUser>().toList();
    final filtered = widget.query.isEmpty
        ? all
        : all.where((u) {
            final q = widget.query;
            return u.username.toLowerCase().contains(q) ||
                u.displayName.toLowerCase().contains(q);
          }).toList();
    filtered.sort((a, b) => a.displayName
        .toLowerCase()
        .compareTo(b.displayName.toLowerCase()));

    if (_loading && filtered.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (filtered.isEmpty) {
      return const Center(
        child: Text('Tidak ditemukan',
            style: TextStyle(color: AppColors.textMuted)),
      );
    }

    return GridView.builder(
      controller: widget.scrollController,
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 16,
        crossAxisSpacing: 8,
        childAspectRatio: 0.78,
      ),
      itemCount: filtered.length,
      itemBuilder: (_, i) {
        final u = filtered[i];
        final st = widget.stateMap[u.uid] ?? _SendState.idle;
        return _RecipientTile(
          user: u,
          state: st,
          onTap: () => widget.onSend(widget.me, u),
        );
      },
    );
  }
}

class _RecipientTile extends StatelessWidget {
  final AppUser user;
  final _SendState state;
  final VoidCallback onTap;
  const _RecipientTile({
    required this.user,
    required this.state,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    String label;
    Color? bg;
    Color fg;
    switch (state) {
      case _SendState.sending:
        label = '...';
        bg = const Color(0xFFEFEFEF);
        fg = AppColors.textDark;
        break;
      case _SendState.sent:
        label = 'Sent';
        bg = const Color(0xFFEFEFEF);
        fg = AppColors.textMuted;
        break;
      case _SendState.idle:
        label = 'Send';
        bg = null;
        fg = Colors.white;
        break;
    }
    return Column(
      children: [
        UserAvatar(
          avatarUrl: user.avatarUrl,
          seed: user.username.isEmpty ? user.displayName : user.username,
          size: 64,
        ),
        const SizedBox(height: 6),
        Text(
          user.displayName.isEmpty ? user.username : user.displayName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w500),
        ),
        const Spacer(),
        GestureDetector(
          onTap: state == _SendState.idle ? onTap : null,
          child: Container(
            width: 88,
            height: 30,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              gradient: state == _SendState.idle ? AppColors.vibrant : null,
              color: bg,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              label,
              style: TextStyle(
                color: fg,
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _ActionsRow extends StatelessWidget {
  const _ActionsRow();

  @override
  Widget build(BuildContext context) {
    final items = [
      _ActionItem(Icons.add_circle_outline, 'Tambahkan\nke cerita'),
      _ActionItem(Icons.link, 'Salin\ntautan'),
      _ActionItem(Icons.download_outlined, 'Unduh'),
      _ActionItem(Icons.share_outlined, 'Lainnya'),
    ];
    return Container(
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: AppColors.divider, width: 1)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: items,
      ),
    );
  }
}

class _ActionItem extends StatelessWidget {
  final IconData icon;
  final String label;
  const _ActionItem(this.icon, this.label);
  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 52,
          height: 52,
          decoration: const BoxDecoration(
            color: Color(0xFFF1F1F2),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: AppColors.textDark, size: 24),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 11, height: 1.2),
        ),
      ],
    );
  }
}
