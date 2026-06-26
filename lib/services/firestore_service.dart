import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/user_model.dart';
import '../models/post_model.dart';
import '../models/chat_model.dart';
import '../models/story.dart';

class FirestoreService {
  FirestoreService._();
  static final FirestoreService instance = FirestoreService._();

  FirebaseFirestore get _db => FirebaseFirestore.instance;

  // ============================================================
  // USERS
  // ============================================================
  CollectionReference<Map<String, dynamic>> get _users => _db.collection('users');

  Future<bool> isUsernameTaken(String username) async {
    final q = await _users
        .where('username', isEqualTo: username.toLowerCase())
        .limit(1)
        .get();
    return q.docs.isNotEmpty;
  }

  Future<void> createUser(AppUser u) => _users.doc(u.uid).set(u.toMap());

  Future<AppUser?> getUser(String uid) async {
    final d = await _users.doc(uid).get();
    if (!d.exists) return null;
    return AppUser.fromMap(d.id, d.data() ?? const {});
  }

  // ---- shared user-stream cache --------------------------------------------
  // Many widgets (post cards, comments, chat bubbles, story bubbles) subscribe
  // to the same `users/{uid}` doc. We share a single broadcast stream per uid
  // and keep the last value in memory so new subscribers paint instantly with
  // no Firestore read and no avatar flicker.
  final Map<String, Stream<AppUser?>> _userStreams = {};
  final Map<String, AppUser> _userCache = {};

  AppUser? cachedUser(String uid) => _userCache[uid];

  Stream<AppUser?> userStream(String uid) {
    return _userStreams.putIfAbsent(uid, () {
      return _users.doc(uid).snapshots().map((d) {
        if (!d.exists) return null;
        final u = AppUser.fromMap(d.id, d.data() ?? const {});
        _userCache[uid] = u;
        return u;
      }).asBroadcastStream();
    });
  }

  Future<void> updateUser(
    String uid, {
    String? displayName,
    String? bio,
    String? location,
    String? avatarUrl,
  }) {
    final m = <String, dynamic>{};
    if (displayName != null) m['displayName'] = displayName;
    if (bio != null) m['bio'] = bio;
    if (location != null) m['location'] = location;
    if (avatarUrl != null) m['avatarUrl'] = avatarUrl;
    return _users.doc(uid).update(m);
  }

  Future<List<AppUser>> searchUsers(String query) async {
    final q = query.trim().toLowerCase().replaceAll('@', '');
    if (q.isEmpty) return [];
    // Prefix search by username
    final byUser = await _users
        .where('username', isGreaterThanOrEqualTo: q)
        .where('username', isLessThan: '${q}z')
        .limit(20)
        .get();
    final results = <String, AppUser>{};
    for (final d in byUser.docs) {
      results[d.id] = AppUser.fromMap(d.id, d.data());
    }
    // Also try displayName prefix (case-sensitive limitation of Firestore).
    final cap = q.isEmpty ? q : q[0].toUpperCase() + q.substring(1);
    final byName = await _users
        .where('displayName', isGreaterThanOrEqualTo: cap)
        .where('displayName', isLessThan: '${cap}z')
        .limit(20)
        .get();
    for (final d in byName.docs) {
      results[d.id] = AppUser.fromMap(d.id, d.data());
    }
    return results.values.toList();
  }

  Future<void> toggleFollow({
    required String currentUid,
    required String targetUid,
  }) async {
    if (currentUid == targetUid) return;
    final me = _users.doc(currentUid);
    final them = _users.doc(targetUid);
    await _db.runTransaction((tx) async {
      final meSnap = await tx.get(me);
      final following = List<String>.from(meSnap.data()?['following'] ?? const []);
      final isFollowing = following.contains(targetUid);
      if (isFollowing) {
        tx.update(me, {'following': FieldValue.arrayRemove([targetUid])});
        tx.update(them, {'followers': FieldValue.arrayRemove([currentUid])});
      } else {
        tx.update(me, {'following': FieldValue.arrayUnion([targetUid])});
        tx.update(them, {'followers': FieldValue.arrayUnion([currentUid])});
      }
    });
  }

  // ============================================================
  // POSTS
  // ============================================================
  CollectionReference<Map<String, dynamic>> get _posts => _db.collection('posts');

  Future<String> createPost({
    required AppUser author,
    required String imageUrl,
    required String caption,
  }) async {
    final doc = await _posts.add({
      'authorId': author.uid,
      'authorName': author.displayName,
      'authorUsername': author.username,
      'authorAvatarUrl': author.avatarUrl,
      'imageUrl': imageUrl,
      'caption': caption,
      'likes': <String>[],
      'commentsCount': 0,
      'createdAt': FieldValue.serverTimestamp(),
    });
    return doc.id;
  }

  Stream<List<Post>> feedStream({int limit = 50}) {
    return _posts
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((s) => s.docs.map(Post.fromDoc).toList());
  }

  Stream<List<Post>> userPostsStream(String uid) {
    // NOTE: we intentionally drop the server-side orderBy here. Combining
    // where('authorId') + orderBy('createdAt') requires a composite index in
    // Firestore; when the index is missing the stream errors out silently and
    // the profile shows "No posts yet". Sorting in-memory keeps it index-free.
    return _posts
        .where('authorId', isEqualTo: uid)
        .snapshots()
        .handleError((Object e, StackTrace st) {
          // Surface index / permission errors instead of failing silently.
          // ignore: avoid_print
          print('[firestore] userPostsStream($uid) error: $e');
        })
        .map((s) {
          final list = s.docs.map(Post.fromDoc).toList();
          list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          return list;
        });
  }

  Stream<List<Post>> trendingStream() {
    final cutoff = DateTime.now().subtract(const Duration(days: 7));
    return _posts
        .where('createdAt', isGreaterThan: Timestamp.fromDate(cutoff))
        .snapshots()
        .map((s) {
      final list = s.docs.map(Post.fromDoc).toList();
      list.sort((a, b) => b.score.compareTo(a.score));
      return list;
    });
  }

  Future<void> toggleLike({required String postId, required String uid}) async {
    final ref = _posts.doc(postId);
    await _db.runTransaction((tx) async {
      final snap = await tx.get(ref);
      final likes = List<String>.from(snap.data()?['likes'] ?? const []);
      if (likes.contains(uid)) {
        tx.update(ref, {'likes': FieldValue.arrayRemove([uid])});
      } else {
        tx.update(ref, {'likes': FieldValue.arrayUnion([uid])});
      }
    });
  }

  // ----- comments -----
  CollectionReference<Map<String, dynamic>> _commentsCol(String postId) =>
      _posts.doc(postId).collection('comments');

  Stream<List<Comment>> commentsStream(String postId) {
    return _commentsCol(postId)
        .orderBy('createdAt', descending: false)
        .snapshots()
        .map((s) => s.docs.map(Comment.fromDoc).toList());
  }

  Future<void> addComment({
    required String postId,
    required AppUser author,
    required String text,
    String parentId = '',
    String replyToName = '',
  }) async {
    final batch = _db.batch();
    final c = _commentsCol(postId).doc();
    batch.set(c, {
      'authorId': author.uid,
      'authorName': author.displayName,
      'authorAvatarUrl': author.avatarUrl,
      'text': text,
      'parentId': parentId,
      'replyToName': replyToName,
      'createdAt': FieldValue.serverTimestamp(),
    });
    batch.update(_posts.doc(postId), {
      'commentsCount': FieldValue.increment(1),
    });
    await batch.commit();
  }

  // ============================================================
  // CHATS
  // ============================================================
  CollectionReference<Map<String, dynamic>> get _chats => _db.collection('chats');

  /// Stream of chats the given user participates in, newest first.
  Stream<List<Chat>> myChatsStream(String uid) {
    return _chats
        .where('participants', arrayContains: uid)
        .snapshots()
        .map((s) {
      final list = s.docs.map(Chat.fromDoc).toList();
      list.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      return list;
    });
  }

  Future<Chat> ensureChat(String a, String b) async {
    final id = Chat.idFor(a, b);
    final ref = _chats.doc(id);
    final snap = await ref.get();
    if (!snap.exists) {
      await ref.set({
        'participants': [a, b],
        'lastMessage': '',
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }
    final fresh = await ref.get();
    return Chat.fromDoc(fresh);
  }

  Stream<List<ChatMessage>> messagesStream(String chatId) {
    return _chats
        .doc(chatId)
        .collection('messages')
        .orderBy('createdAt', descending: false)
        .snapshots()
        .map((s) => s.docs.map(ChatMessage.fromDoc).toList());
  }

  Future<void> sendMessage({
    required String chatId,
    required String senderId,
    String text = '',
    String imageUrl = '',
  }) async {
    final batch = _db.batch();
    final msg = _chats.doc(chatId).collection('messages').doc();
    batch.set(msg, {
      'senderId': senderId,
      'text': text,
      'imageUrl': imageUrl,
      'createdAt': FieldValue.serverTimestamp(),
    });
    batch.update(_chats.doc(chatId), {
      'lastMessage': text.isNotEmpty ? text : '📷 Photo',
      'lastSenderId': senderId,
      'updatedAt': FieldValue.serverTimestamp(),
    });
    await batch.commit();
  }

  /// Share a post into an existing chat. Stores post metadata on the message
  /// document so the chat bubble can render a preview without needing a
  /// follow-up read.
  Future<void> sendSharedPost({
    required String chatId,
    required String senderId,
    required Post post,
  }) async {
    final batch = _db.batch();
    final msg = _chats.doc(chatId).collection('messages').doc();
    batch.set(msg, {
      'senderId': senderId,
      'text': '',
      'imageUrl': '',
      'postId': post.id,
      'postImageUrl': post.imageUrl,
      'postCaption': post.caption,
      'postAuthorName': post.authorName,
      'postAuthorAvatarUrl': post.authorAvatarUrl,
      'createdAt': FieldValue.serverTimestamp(),
    });
    batch.update(_chats.doc(chatId), {
      'lastMessage': '📎 Shared a post',
      'lastSenderId': senderId,
      'updatedAt': FieldValue.serverTimestamp(),
    });
    await batch.commit();
  }

  // ============================================================
  // STORIES
  // ============================================================
  CollectionReference<Map<String, dynamic>> get _stories =>
      _db.collection('stories');

  Future<String> createStory({
    required String authorId,
    required String imageUrl,
    String caption = '',
  }) async {
    final now = DateTime.now();
    final doc = await _stories.add({
      'authorId': authorId,
      'imageUrl': imageUrl,
      'caption': caption,
      'createdAt': FieldValue.serverTimestamp(),
      'expiresAt':
          Timestamp.fromDate(now.add(const Duration(hours: 24))),
      'viewers': <String>[],
    });
    return doc.id;
  }

  /// All non-expired stories, grouped per author. No composite index required.
  Stream<List<StoryGroup>> activeStoriesStream({int limit = 300}) {
    return _stories
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .handleError((Object e, StackTrace st) {
          // ignore: avoid_print
          print('[firestore] activeStoriesStream error: $e');
        })
        .map((s) {
      final now = DateTime.now();
      final active = s.docs
          .map(Story.fromDoc)
          .where((st) => st.expiresAt.isAfter(now) && st.authorId.isNotEmpty)
          .toList();
      final byAuthor = <String, List<Story>>{};
      for (final st in active) {
        byAuthor.putIfAbsent(st.authorId, () => <Story>[]).add(st);
      }
      final groups = byAuthor.entries.map((e) {
        final list = e.value
          ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
        return StoryGroup(authorId: e.key, stories: list);
      }).toList();
      groups.sort((a, b) => b.latestAt.compareTo(a.latestAt));
      return groups;
    });
  }

  Future<void> markStoryViewed(String storyId, String viewerUid) {
    return _stories.doc(storyId).update({
      'viewers': FieldValue.arrayUnion([viewerUid]),
    });
  }
}
