import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../models/chat_model.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import '../theme/app_theme.dart';
import '../widgets/user_avatar.dart';
import '../widgets/live_user_avatar.dart';
import 'post_detail_screen.dart';

class ChatScreen extends StatefulWidget {
  final String chatId;
  final AppUser otherUser;
  const ChatScreen({super.key, required this.chatId, required this.otherUser});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _ctrl = TextEditingController();
  bool _sending = false;

  Future<void> _send() async {
    final myUid = AuthService.instance.currentUser?.uid;
    final text = _ctrl.text.trim();
    if (myUid == null || text.isEmpty) return;
    setState(() => _sending = true);
    try {
      await FirestoreService.instance.sendMessage(
        chatId: widget.chatId,
        senderId: myUid,
        text: text,
      );
      _ctrl.clear();
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final myUid = AuthService.instance.currentUser?.uid;
    return Scaffold(
      backgroundColor: AppColors.bgWhite,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: AppColors.textDark,
        title: Row(
          children: [
            LiveUserAvatar(
              uid: widget.otherUser.uid,
              fallbackAvatarUrl: widget.otherUser.avatarUrl,
              fallbackSeed: widget.otherUser.username,
              size: 36,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: LiveUserName(
                uid: widget.otherUser.uid,
                fallbackDisplayName: widget.otherUser.displayName,
                fallbackUsername: widget.otherUser.username,
                nameStyle: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w600),
                subStyle: const TextStyle(
                    color: AppColors.textMuted, fontSize: 12),
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<List<ChatMessage>>(
              stream: FirestoreService.instance.messagesStream(widget.chatId),
              builder: (context, snap) {
                final msgs = snap.data ?? const [];
                if (msgs.isEmpty) {
                  return const Center(
                    child: Text('Say hi 👋',
                        style: TextStyle(color: AppColors.textMuted)),
                  );
                }
                return ListView.builder(
                  reverse: false,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 12),
                  itemCount: msgs.length,
                  itemBuilder: (_, i) {
                    final m = msgs[i];
                    final mine = m.senderId == myUid;
                    if (m.isSharedPost) {
                      return Align(
                        alignment:
                            mine ? Alignment.centerRight : Alignment.centerLeft,
                        child: _SharedPostBubble(message: m, mine: mine),
                      );
                    }
                    return Align(
                      alignment:
                          mine ? Alignment.centerRight : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.symmetric(vertical: 3),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 10),
                        constraints: BoxConstraints(
                          maxWidth:
                              MediaQuery.of(context).size.width * .72,
                        ),
                        decoration: BoxDecoration(
                          gradient: mine ? AppColors.vibrant : null,
                          color: mine ? null : AppColors.softBg,
                          borderRadius: BorderRadius.only(
                            topLeft: const Radius.circular(16),
                            topRight: const Radius.circular(16),
                            bottomLeft: Radius.circular(mine ? 16 : 4),
                            bottomRight: Radius.circular(mine ? 4 : 16),
                          ),
                        ),
                        child: m.imageUrl.isNotEmpty
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: CachedNetworkImage(
                                    imageUrl: m.imageUrl, width: 200),
                              )
                            : Text(
                                m.text,
                                style: TextStyle(
                                  color: mine
                                      ? Colors.white
                                      : AppColors.textDark,
                                ),
                              ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          SafeArea(
            top: false,
            child: Container(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(
                    top: BorderSide(color: AppColors.divider, width: 1)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _ctrl,
                      decoration: InputDecoration(
                        hintText: 'Type a message...',
                        filled: true,
                        fillColor: AppColors.softBg,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(20),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 10),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: _sending ? null : _send,
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: const BoxDecoration(
                        gradient: AppColors.vibrant,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.send,
                          color: Colors.white, size: 20),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SharedPostBubble extends StatelessWidget {
  final ChatMessage message;
  final bool mine;
  const _SharedPostBubble({required this.message, required this.mine});

  void _openPost(BuildContext context) {
    // Lightweight inline import to avoid cycles at the top.
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _PostDetailRouter(postId: message.postId),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final maxW = MediaQuery.of(context).size.width * .72;
    return GestureDetector(
      onTap: () => _openPost(context),
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 3),
        constraints: BoxConstraints(maxWidth: maxW),
        decoration: BoxDecoration(
          color: AppColors.softBg,
          border: Border.all(color: AppColors.divider),
          borderRadius: BorderRadius.circular(14),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 6),
              child: Row(
                children: [
                  UserAvatar(
                    avatarUrl: message.postAuthorAvatarUrl,
                    seed: message.postAuthorName,
                    size: 22,
                  ),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      message.postAuthorName.isEmpty
                          ? 'iFriends'
                          : message.postAuthorName,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 12.5, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
            if (message.postImageUrl.isNotEmpty)
              AspectRatio(
                aspectRatio: 1,
                child: CachedNetworkImage(
                  imageUrl: message.postImageUrl,
                  fit: BoxFit.cover,
                ),
              ),
            if (message.postCaption.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
                child: Text(
                  message.postCaption,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12.5),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Wraps PostDetailScreen with the current user, avoiding a top-level import
/// cycle between chat_screen and post_detail_screen.
class _PostDetailRouter extends StatelessWidget {
  final String postId;
  const _PostDetailRouter({required this.postId});
  @override
  Widget build(BuildContext context) {
    final myUid = AuthService.instance.currentUser?.uid;
    return StreamBuilder<AppUser?>(
      stream: myUid == null
          ? const Stream.empty()
          : FirestoreService.instance.userStream(myUid),
      initialData:
          myUid == null ? null : FirestoreService.instance.cachedUser(myUid),
      builder: (context, snap) {
        return PostDetailScreen(postId: postId, currentUser: snap.data);
      },
    );
  }
}
