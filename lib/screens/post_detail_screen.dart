import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../models/post_model.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import '../theme/app_theme.dart';
import '../widgets/linked_text.dart';
import '../widgets/live_user_avatar.dart';
import '../widgets/post_image_carousel.dart';
import 'edit_post_screen.dart';
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

  Future<void> _confirmDeletePost() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete post?'),
        content: const Text('This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await FirestoreService.instance.deletePost(widget.postId);
    if (mounted) Navigator.of(context).maybePop();
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
              final myUid = AuthService.instance.currentUser?.uid;
              final isOwner = myUid != null && myUid == p.authorId;
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.send_outlined),
                    onPressed: () => ShareToChatSheet.show(context, p),
                  ),
                  if (isOwner)
                    PopupMenuButton<String>(
                      icon: const Icon(Icons.more_vert),
                      onSelected: (v) async {
                        if (v == 'edit') {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => EditPostScreen(
                                postId: p.id,
                                initialCaption: p.caption,
                              ),
                            ),
                          );
                        } else if (v == 'delete') {
                          await _confirmDeletePost();
                        }
                      },
                      itemBuilder: (_) => const [
                        PopupMenuItem(value: 'edit', child: Text('Edit caption')),
                        PopupMenuItem(value: 'delete', child: Text('Delete post')),
                      ],
                    ),
                ],
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
                    PostImageCarousel(
                      images: post.images,
                      height: 300,
                    ),
                    const SizedBox(height: 10),
                    if (post.caption.isNotEmpty) LinkedText(post.caption),
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
                          postId: widget.postId,
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
  final String postId;
  final List<Comment> comments;
  final void Function(Comment) onReply;
  const _CommentTree({
    required this.postId,
    required this.comments,
    required this.onReply,
  });

  @override
  Widget build(BuildContext context) {
    final byParent = <String, List<Comment>>{};
    final ids = comments.map((c) => c.id).toSet();
    for (final c in comments) {
      // If parent comment was deleted/missing, treat as top-level.
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
          postId: postId,
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
  final String postId;
  final Comment comment;
  final int depth;
  final void Function(Comment) onReply;
  const _CommentRow({
    required this.postId,
    required this.comment,
    required this.depth,
    required this.onReply,
  });

  Widget _action(String label, VoidCallback onTap, {Color? color}) {
    return GestureDetector(
      onTap: onTap,
      child: Text(label,
          style: TextStyle(
              color: color ?? AppColors.textMuted,
              fontSize: 11.5,
              fontWeight: FontWeight.w600)),
    );
  }

  Future<void> _editComment(BuildContext context) async {
    final ctrl = TextEditingController(text: comment.text);
    final text = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit comment'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          maxLines: null,
          decoration: const InputDecoration(hintText: 'Edit your comment...'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (text == null || text.isEmpty || text == comment.text) return;
    await FirestoreService.instance.updateComment(
      postId: postId,
      commentId: comment.id,
      text: text,
    );
  }

  Future<void> _deleteComment(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete comment?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await FirestoreService.instance.deleteComment(
      postId: postId,
      commentId: comment.id,
    );
  }

  @override
  Widget build(BuildContext context) {
    final indent = (depth.clamp(0, 4)) * 28.0;
    final avatarSize = depth == 0 ? 32.0 : 26.0;
    final myUid = AuthService.instance.currentUser?.uid ?? '';
    final liked = comment.likes.contains(myUid);
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
                  child: LinkedText(
                    comment.text,
                    style: const TextStyle(
                        fontSize: 13.5, color: AppColors.textDark),
                    prefix: comment.replyToName.isNotEmpty
                        ? [
                            TextSpan(
                              text: '@${comment.replyToName} ',
                              style: const TextStyle(
                                  color: AppColors.primaryCoral,
                                  fontWeight: FontWeight.w600),
                            ),
                          ]
                        : const [],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Row(
                    children: [
                      _action('Reply', () => onReply(comment)),
                      if (comment.isEdited) ...[
                        const SizedBox(width: 10),
                        const Text('edited',
                            style: TextStyle(
                                color: AppColors.textMuted, fontSize: 11)),
                      ],
                      if (comment.authorId == myUid) ...[
                        const SizedBox(width: 14),
                        _action('Edit', () => _editComment(context)),
                        const SizedBox(width: 14),
                        _action('Delete', () => _deleteComment(context),
                            color: Colors.red),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Heart toggle for the comment.
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              GestureDetector(
                onTap: myUid.isEmpty
                    ? null
                    : () => FirestoreService.instance.toggleCommentLike(
                          postId: postId,
                          commentId: comment.id,
                          uid: myUid,
                        ),
                behavior: HitTestBehavior.opaque,
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: Icon(
                    liked ? Icons.favorite : Icons.favorite_border,
                    size: 16,
                    color: liked ? AppColors.primaryPink : AppColors.textMuted,
                  ),
                ),
              ),
              if (comment.likes.isNotEmpty)
                Text(
                  '${comment.likes.length}',
                  style: const TextStyle(
                      fontSize: 10.5, color: AppColors.textMuted),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
