import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../models/post_model.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import '../theme/app_theme.dart';
import '../widgets/live_user_avatar.dart';
import 'share_to_chat_screen.dart';

class PostDetailScreen extends StatefulWidget {
  final String postId;
  final AppUser? currentUser;
  const PostDetailScreen({
    super.key,
    required this.postId,
    required this.currentUser,
  });

  @override
  State<PostDetailScreen> createState() => _PostDetailScreenState();
}

class _PostDetailScreenState extends State<PostDetailScreen> {
  final _ctrl = TextEditingController();
  final _focus = FocusNode();
  bool _sending = false;

  // Reply target. When null the comment is top-level.
  String _replyParentId = '';
  String _replyToName = '';

  @override
  void dispose() {
    _ctrl.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _startReply(Comment c) {
    setState(() {
      // Multi-level: a reply to a reply keeps threading under the same root by
      // pointing parentId at the comment being replied to.
      _replyParentId = c.id;
      _replyToName = c.authorName;
    });
    _focus.requestFocus();
  }

  void _cancelReply() {
    setState(() {
      _replyParentId = '';
      _replyToName = '';
    });
  }

  /// Fallback chain: prefer the explicitly passed `currentUser`, otherwise
  /// resolve it from the auth-service cache. Some entry points (e.g. profile
  /// grid tiles) push us with `currentUser: null` even though the user IS
  /// signed in, which used to silently hide the composer.
  AppUser? _resolveMe() {
    if (widget.currentUser != null) return widget.currentUser;
    final uid = AuthService.instance.currentUser?.uid;
    if (uid == null) return null;
    return FirestoreService.instance.cachedUser(uid);
  }

  Future<void> _send([AppUser? meArg]) async {
    final me = meArg ?? _resolveMe();
    final text = _ctrl.text.trim();
    if (me == null || text.isEmpty) return;
    setState(() => _sending = true);
    try {
      await FirestoreService.instance.addComment(
        postId: widget.postId,
        author: me,
        text: text,
        parentId: _replyParentId,
        replyToName: _replyToName,
      );
      _ctrl.clear();
      _cancelReply();
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgWhite,
      appBar: AppBar(
        title: const Text('Post'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: AppColors.textDark,
        actions: [
          StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
            stream: FirebaseFirestore.instance
                .collection('posts')
                .doc(widget.postId)
                .snapshots(),
            builder: (context, s) {
              if (!s.hasData || !s.data!.exists) return const SizedBox.shrink();
              final p = Post.fromDoc(s.data!);
              return IconButton(
                icon: const Icon(Icons.send_outlined),
                onPressed: () => ShareToChatSheet.show(context, p),
              );
            },
          ),
        ],
      ),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('posts')
            .doc(widget.postId)
            .snapshots(),
        builder: (context, snap) {
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snap.data!.exists) {
            return const Center(child: Text('Post unavailable'));
          }
          final post = Post.fromDoc(snap.data!);
          return Column(
            children: [
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Row(
                      children: [
                        LiveUserAvatar(
                          uid: post.authorId,
                          fallbackAvatarUrl: post.authorAvatarUrl,
                          fallbackSeed: post.authorUsername,
                          size: 40,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: LiveUserName(
                            uid: post.authorId,
                            fallbackDisplayName: post.authorName,
                            fallbackUsername: post.authorUsername,
                            nameStyle: const TextStyle(
                                fontWeight: FontWeight.w600),
                            subStyle: const TextStyle(
                                color: AppColors.textMuted, fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(18),
                      child: post.imageUrl.isNotEmpty
                          ? CachedNetworkImage(
                              imageUrl: post.imageUrl, fit: BoxFit.cover)
                          : Container(
                              height: 240,
                              decoration: const BoxDecoration(
                                  gradient: AppColors.sunset),
                            ),
                    ),
                    const SizedBox(height: 10),
                    if (post.caption.isNotEmpty) Text(post.caption),
                    const SizedBox(height: 16),
                    const Divider(),
                    const Text('Comments',
                        style: TextStyle(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    StreamBuilder<List<Comment>>(
                      stream: FirestoreService.instance
                          .commentsStream(widget.postId),
                      builder: (context, cs) {
                        final list = cs.data ?? const <Comment>[];
                        if (list.isEmpty) {
                          return const Padding(
                            padding: EdgeInsets.symmetric(vertical: 16),
                            child: Text('Be the first to comment.',
                                style:
                                    TextStyle(color: AppColors.textMuted)),
                          );
                        }
                        return _CommentTree(
                          comments: list,
                          onReply: _startReply,
                        );
                      },
                    ),
                  ],
                ),
              ),
              _composerSection(),
            ],
          );
        },
      ),
    );
  }

  /// Live-resolves the current user so the composer is shown whenever ANYONE
  /// is signed in — not just when the parent screen happened to pass a non-null
  /// `currentUser` (the profile grid tile passes `null`, for example).
  Widget _composerSection() {
    final uid = AuthService.instance.currentUser?.uid;
    if (uid == null) return const SizedBox.shrink();
    return StreamBuilder<AppUser?>(
      stream: FirestoreService.instance.userStream(uid),
      initialData: widget.currentUser ??
          FirestoreService.instance.cachedUser(uid),
      builder: (context, snap) {
        final me = snap.data ?? widget.currentUser;
        if (me == null) {
          // Still show the composer so the user sees the reply target;
          // the send button stays disabled until the user doc arrives.
          return _composer(meForSend: null);
        }
        return _composer(meForSend: me);
      },
    );
  }

  Widget _composer({AppUser? meForSend}) {
    return SafeArea(
      top: false,
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          border:
              Border(top: BorderSide(color: AppColors.divider, width: 1)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_replyToName.isNotEmpty)
              Container(
                width: double.infinity,
                color: AppColors.softBg,
                padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Replying to @$_replyToName',
                        style: const TextStyle(
                            color: AppColors.textMuted, fontSize: 12.5),
                      ),
                    ),
                    GestureDetector(
                      onTap: _cancelReply,
                      child: const Icon(Icons.close,
                          size: 18, color: AppColors.textMuted),
                    ),
                  ],
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _ctrl,
                      focusNode: _focus,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) {
                        if (!_sending) _send(meForSend);
                      },
                      decoration: InputDecoration(
                        hintText: _replyToName.isNotEmpty
                            ? 'Add a reply...'
                            : 'Add a comment...',
                        filled: true,
                        fillColor: AppColors.softBg,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 10),
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: (_sending || meForSend == null)
                        ? null
                        : () => _send(meForSend),
                    icon: const Icon(Icons.send,
                        color: AppColors.primaryCoral),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Builds a threaded comment tree from a flat, time-ordered list. Supports
/// arbitrary nesting depth (multi-level replies); indentation is capped so deep
/// chains stay readable, Instagram-style.
class _CommentTree extends StatelessWidget {
  final List<Comment> comments;
  final void Function(Comment) onReply;
  const _CommentTree({required this.comments, required this.onReply});

  @override
  Widget build(BuildContext context) {
    final byParent = <String, List<Comment>>{};
    final ids = comments.map((c) => c.id).toSet();
    for (final c in comments) {
      // Treat replies whose parent was deleted as top-level so nothing is lost.
      final key = (c.parentId.isNotEmpty && ids.contains(c.parentId))
          ? c.parentId
          : '';
      byParent.putIfAbsent(key, () => <Comment>[]).add(c);
    }

    final rows = <Widget>[];
    void walk(String parentId, int depth) {
      final children = byParent[parentId] ?? const <Comment>[];
      for (final c in children) {
        rows.add(_CommentRow(
          comment: c,
          depth: depth,
          onReply: onReply,
        ));
        walk(c.id, depth + 1);
      }
    }

    walk('', 0);
    return Column(children: rows);
  }
}

class _CommentRow extends StatelessWidget {
  final Comment comment;
  final int depth;
  final void Function(Comment) onReply;
  const _CommentRow({
    required this.comment,
    required this.depth,
    required this.onReply,
  });

  @override
  Widget build(BuildContext context) {
    final indent = (depth.clamp(0, 4)) * 28.0;
    final avatarSize = depth == 0 ? 32.0 : 26.0;
    return Padding(
      padding: EdgeInsets.only(left: indent, top: 6, bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LiveUserAvatar(
            uid: comment.authorId,
            fallbackAvatarUrl: comment.authorAvatarUrl,
            fallbackSeed: comment.authorName,
            size: avatarSize,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                LiveUserName(
                  uid: comment.authorId,
                  fallbackDisplayName: comment.authorName,
                  fallbackUsername: comment.authorName,
                  nameStyle: const TextStyle(
                      fontWeight: FontWeight.w600, fontSize: 13),
                  subStyle: const TextStyle(
                      color: AppColors.textMuted, fontSize: 11),
                  verifiedSize: 13,
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: RichText(
                    text: TextSpan(
                      style: const TextStyle(
                          fontSize: 13.5, color: AppColors.textDark),
                      children: [
                        if (comment.replyToName.isNotEmpty)
                          TextSpan(
                            text: '@${comment.replyToName} ',
                            style: const TextStyle(
                                color: AppColors.primaryCoral,
                                fontWeight: FontWeight.w600),
                          ),
                        TextSpan(text: comment.text),
                      ],
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: () => onReply(comment),
                  child: const Padding(
                    padding: EdgeInsets.only(top: 4),
                    child: Text('Reply',
                        style: TextStyle(
                            color: AppColors.textMuted,
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
