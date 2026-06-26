import 'package:flutter/material.dart';

import '../models/chat_model.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import '../theme/app_theme.dart';
import '../widgets/user_avatar.dart';
import 'chat_screen.dart';

class ChatsInboxScreen extends StatelessWidget {
  const ChatsInboxScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final myUid = AuthService.instance.currentUser?.uid;
    return Scaffold(
      backgroundColor: AppColors.bgWhite,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: AppColors.textDark,
        title: ShaderMask(
          shaderCallback: (b) => AppColors.vibrant.createShader(b),
          child: const Text(
            'Messages',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
      body: myUid == null
          ? const Center(child: Text('Sign in to see messages.'))
          : StreamBuilder<List<Chat>>(
              stream: FirestoreService.instance.myChatsStream(myUid),
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final chats = (snap.data ?? const <Chat>[])
                    .where((c) => c.participants.length == 2)
                    .toList();
                if (chats.isEmpty) {
                  return const _Empty();
                }
                return ListView.separated(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: chats.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 2),
                  itemBuilder: (_, i) {
                    final chat = chats[i];
                    final otherUid = chat.participants
                        .firstWhere((u) => u != myUid, orElse: () => '');
                    if (otherUid.isEmpty) return const SizedBox.shrink();
                    return _ChatTile(chat: chat, otherUid: otherUid);
                  },
                );
              },
            ),
    );
  }
}

class _ChatTile extends StatefulWidget {
  final Chat chat;
  final String otherUid;
  const _ChatTile({required this.chat, required this.otherUid});

  @override
  State<_ChatTile> createState() => _ChatTileState();
}

class _ChatTileState extends State<_ChatTile> {
  AppUser? _fallback;

  @override
  void initState() {
    super.initState();
    _fallback = FirestoreService.instance.cachedUser(widget.otherUid);
    if (_fallback == null) {
      // Eagerly fetch so the tile never gets stuck on the "iFriends User"
      // placeholder when the stream is slow or the doc hasn't yet hit the
      // local Firestore cache.
      FirestoreService.instance.getUser(widget.otherUid).then((u) {
        if (mounted && u != null && _fallback == null) {
          setState(() => _fallback = u);
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AppUser?>(
      stream: FirestoreService.instance.userStream(widget.otherUid),
      initialData: _fallback,
      builder: (context, snap) {
        final u = snap.data ?? _fallback;
        final name = (u?.displayName.isNotEmpty ?? false)
            ? u!.displayName
            : (u?.username.isNotEmpty ?? false)
                ? u!.username
                : 'Loading…';
        final username = u?.username ?? '';
        final preview = widget.chat.lastMessage.isEmpty
            ? 'Say hi 👋'
            : widget.chat.lastMessage;
        return ListTile(
          leading: UserAvatar(
            avatarUrl: u?.avatarUrl ?? '',
            seed: username.isEmpty ? name : username,
            size: 48,
          ),
          title: Row(
            children: [
              Flexible(
                child: Text(name,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w600)),
              ),
              if (u?.isVerified ?? false) ...[
                const SizedBox(width: 4),
                const Icon(Icons.verified,
                    color: AppColors.primaryCoral, size: 16),
              ],
            ],
          ),
          subtitle: Text(
            preview,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: AppColors.textMuted),
          ),
          trailing: Text(
            _ago(widget.chat.updatedAt),
            style: const TextStyle(
                color: AppColors.textMuted, fontSize: 11),
          ),
          onTap: () async {
            // Open chat with whatever we have. If we still don't have a user
            // doc, fetch synchronously before pushing so ChatScreen has data.
            var user = u;
            user ??= await FirestoreService.instance.getUser(widget.otherUid);
            if (!mounted) return;
            if (user == null) return;
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) =>
                    ChatScreen(chatId: widget.chat.id, otherUser: user!),
              ),
            );
          },
        );
      },
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

class _Empty extends StatelessWidget {
  const _Empty();
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
              child: const Icon(Icons.mark_chat_unread_outlined,
                  color: Colors.white, size: 44),
            ),
            const SizedBox(height: 18),
            const Text('No messages yet',
                style:
                    TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            const Text(
              'Visit a profile and tap the paper-plane button to start chatting.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textMuted),
            ),
          ],
        ),
      ),
    );
  }
}
