import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../models/story.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import '../theme/app_theme.dart';
import '../widgets/live_user_avatar.dart';

class StoryViewerScreen extends StatefulWidget {
  final List<Story> stories;
  final int initialIndex;
  const StoryViewerScreen({
    super.key,
    required this.stories,
    this.initialIndex = -1, // -1 = auto: first unviewed
  });

  @override
  State<StoryViewerScreen> createState() => _StoryViewerScreenState();
}

class _StoryViewerScreenState extends State<StoryViewerScreen>
    with SingleTickerProviderStateMixin {
  static const Duration _segment = Duration(seconds: 5);
  late int _index;
  late AnimationController _progress;
  bool _paused = false;
  bool _didPrecache = false;

  final _replyCtrl = TextEditingController();
  final _replyFocus = FocusNode();
  bool _sendingReply = false;

  static const List<String> _quickEmojis = ['❤️', '😂', '😮', '😢', '👏', '🔥'];

  @override
  void initState() {
    super.initState();
    final uid = AuthService.instance.currentUser?.uid ?? '';
    int initial = widget.initialIndex;
    if (initial < 0) {
      initial = widget.stories.indexWhere((s) => !s.isViewedBy(uid));
      if (initial < 0) initial = 0;
    }
    _index = initial.clamp(0, widget.stories.length - 1);
    _progress = AnimationController(vsync: this, duration: _segment)
      ..addStatusListener((status) {
        if (status == AnimationStatus.completed) _next();
      });
    _start();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_didPrecache) return;
    _didPrecache = true;
    _precacheNeighbors();
  }

  void _precacheNeighbors() {
    for (final i in [_index, _index + 1]) {
      if (i >= 0 && i < widget.stories.length) {
        final url = widget.stories[i].imageUrl;
        if (url.isNotEmpty) {
          precacheImage(CachedNetworkImageProvider(url), context).catchError((_) {});
        }
      }
    }
  }

  void _start() {
    _markViewed(widget.stories[_index]);
    _progress
      ..reset()
      ..forward();
    _precacheNeighbors();
  }

  void _markViewed(Story s) {
    final uid = AuthService.instance.currentUser?.uid;
    if (uid == null || uid.isEmpty) return;
    if (s.viewers.contains(uid)) return;
    FirestoreService.instance.markStoryViewed(s.id, uid).catchError((_) {});
  }

  void _next() {
    if (_index < widget.stories.length - 1) {
      setState(() => _index++);
      _start();
    } else {
      Navigator.of(context).maybePop();
    }
  }

  void _prev() {
    if (_progress.value < 0.15 && _index > 0) {
      setState(() => _index--);
      _start();
    } else {
      _progress
        ..reset()
        ..forward();
    }
  }

  void _pause() {
    if (_paused) return;
    _paused = true;
    _progress.stop();
    setState(() {});
  }

  void _resume() {
    if (!_paused) return;
    _paused = false;
    _progress.forward();
    setState(() {});
  }

  @override
  void dispose() {
    _progress.dispose();
    _replyCtrl.dispose();
    _replyFocus.dispose();
    super.dispose();
  }

  Future<void> _sendReply({String? emoji}) async {
    final myUid = AuthService.instance.currentUser?.uid;
    final story = widget.stories[_index];
    if (myUid == null || myUid.isEmpty || myUid == story.authorId) return;
    final raw = (emoji ?? _replyCtrl.text).trim();
    if (raw.isEmpty || _sendingReply) return;
    setState(() => _sendingReply = true);
    try {
      final chat =
          await FirestoreService.instance.ensureChat(myUid, story.authorId);
      await FirestoreService.instance.sendMessage(
        chatId: chat.id,
        senderId: myUid,
        text: emoji != null ? emoji : 'Replied to your story: $raw',
      );
      _replyCtrl.clear();
      _replyFocus.unfocus();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Reply sent'),
            duration: Duration(seconds: 1),
          ),
        );
      }
      _resume();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to send: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _sendingReply = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final story = widget.stories[_index];
    final w = MediaQuery.of(context).size.width;
    final myUid = AuthService.instance.currentUser?.uid ?? '';
    final canReply = myUid.isNotEmpty && myUid != story.authorId;
    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapUp: (d) {
          if (d.globalPosition.dx < w / 2) {
            _prev();
          } else {
            _next();
          }
        },
        onLongPressStart: (_) => _pause(),
        onLongPressEnd: (_) => _resume(),
        onVerticalDragEnd: (d) {
          if ((d.primaryVelocity ?? 0) > 200) {
            Navigator.of(context).maybePop();
          }
        },
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Smooth fade between segments.
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              child: Container(
                key: ValueKey(story.id),
                color: Colors.black,
                child: story.imageUrl.isNotEmpty
                    ? CachedNetworkImage(
                        imageUrl: story.imageUrl,
                        fit: BoxFit.contain,
                        fadeInDuration:
                            const Duration(milliseconds: 180),
                        placeholder: (_, __) => const Center(
                          child: CircularProgressIndicator(
                              color: Colors.white),
                        ),
                        errorWidget: (_, __, ___) => const Center(
                          child: Icon(Icons.broken_image,
                              color: Colors.white, size: 64),
                        ),
                      )
                    : Container(
                        decoration: const BoxDecoration(
                            gradient: AppColors.sunset),
                      ),
              ),
            ),
            // Hide chrome while paused for a cleaner look.
            AnimatedOpacity(
              duration: const Duration(milliseconds: 180),
              opacity: _paused ? 0 : 1,
              child: SafeArea(
                child: Column(
                  children: [
                    _progressBar(),
                    const SizedBox(height: 8),
                    _topBar(story),
                    const Spacer(),
                    if (story.caption.isNotEmpty)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                        color: Colors.black.withOpacity(.35),
                        child: Text(
                          story.caption,
                          style: const TextStyle(
                              color: Colors.white, fontSize: 14),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            if (canReply)
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: _replyBar(),
              ),
          ],
        ),
      ),
    );
  }

  Widget _replyBar() {
    return Container(
      padding: EdgeInsets.fromLTRB(
        12,
        10,
        12,
        MediaQuery.of(context).viewInsets.bottom + 12,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.transparent, Colors.black.withOpacity(.6)],
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              for (final e in _quickEmojis)
                GestureDetector(
                  onTap: _sendingReply ? null : () => _sendReply(emoji: e),
                  child: Text(e, style: const TextStyle(fontSize: 26)),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _replyCtrl,
                  focusNode: _replyFocus,
                  style: const TextStyle(color: Colors.white),
                  textInputAction: TextInputAction.send,
                  onTap: _pause,
                  onSubmitted: (_) => _sendReply(),
                  decoration: InputDecoration(
                    hintText: 'Send a reply...',
                    hintStyle:
                        TextStyle(color: Colors.white.withOpacity(.7)),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 18, vertical: 12),
                    filled: true,
                    fillColor: Colors.white.withOpacity(.18),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(30),
                      borderSide:
                          BorderSide(color: Colors.white.withOpacity(.5)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(30),
                      borderSide: const BorderSide(color: Colors.white),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: _sendingReply ? null : () => _sendReply(),
                child: Container(
                  width: 46,
                  height: 46,
                  decoration: const BoxDecoration(
                    gradient: AppColors.vibrant,
                    shape: BoxShape.circle,
                  ),
                  child: _sendingReply
                      ? const Padding(
                          padding: EdgeInsets.all(13),
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2),
                        )
                      : const Icon(Icons.send, color: Colors.white, size: 20),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _progressBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: Row(
        children: List.generate(widget.stories.length, (i) {
          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: AnimatedBuilder(
                animation: _progress,
                builder: (_, __) {
                  double v;
                  if (i < _index) {
                    v = 1;
                  } else if (i == _index) {
                    v = _progress.value;
                  } else {
                    v = 0;
                  }
                  return ClipRRect(
                    borderRadius: BorderRadius.circular(2),
                    child: LinearProgressIndicator(
                      value: v,
                      minHeight: 3,
                      backgroundColor: Colors.white.withOpacity(.3),
                      valueColor: const AlwaysStoppedAnimation<Color>(
                          Colors.white),
                    ),
                  );
                },
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _topBar(Story story) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          LiveUserAvatar(
            uid: story.authorId,
            fallbackSeed: story.authorId,
            size: 36,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: StreamBuilder<AppUser?>(
              stream: story.authorId.isEmpty
                  ? const Stream<AppUser?>.empty()
                  : FirestoreService.instance.userStream(story.authorId),
              initialData: story.authorId.isEmpty
                  ? null
                  : FirestoreService.instance.cachedUser(story.authorId),
              builder: (context, snap) {
                final u = snap.data;
                final name = u?.displayName ?? '';
                final verified = u?.isVerified ?? false;
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: Text(
                        name,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600),
                      ),
                    ),
                    if (verified) ...[
                      const SizedBox(width: 4),
                      const Icon(Icons.verified,
                          size: 16, color: Colors.white),
                    ],
                  ],
                );
              },
            ),
          ),
          IconButton(
            onPressed: () => Navigator.of(context).maybePop(),
            icon: const Icon(Icons.close, color: Colors.white),
          ),
        ],
      ),
    );
  }
}
