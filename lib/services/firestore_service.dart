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

  final Map<String, AppUser> _userCache = {};

  AppUser? cachedUser(String uid) => _userCache[uid];

  /// Per-uid live stream. We deliberately return a fresh `snapshots()` stream
  /// on each call instead of caching a broadcast stream — Firestore already
  /// deduplicates listeners for the same document, and a cached broadcast
  /// stream stops emitting once all its listeners disconnect (which broke the
  /// profile follow button after navigating back, and the drawer profile
  /// header after logout + re-login).
  Stream<AppUser?> userStream(String uid) {
    return _users.doc(uid).snapshots().map((d) {
      if (!d.exists) return null;
      final u = AppUser.fromMap(d.id, d.data() ?? const {});
      _userCache[uid] = u;
      return u;
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

  Future<AppUser?> getUserByUsername(String username) async {
    final uname = username.trim().toLowerCase().replaceAll('@', '');
    if (uname.isEmpty) return null;
    final q = await _users
        .where('username', isEqualTo: uname)
        .limit(1)
        .get();
    if (q.docs.isEmpty) return null;
    final d = q.docs.first;
    final u = AppUser.fromMap(d.id, d.data());
    _userCache[u.uid] = u;
    return u;
  }

  /// Change the @username. Enforces format, uniqueness and a 14-day cooldown
  /// (one change per [AppUser.usernameCooldownDays]). Throws [Exception] with a
  /// user-facing message on any rule violation.
  Future<void> updateUsername({
    required String uid,
    required String newUsername,
  }) async {
    final uname = newUsername.trim().toLowerCase().replaceAll('@', '');
    if (uname.length < 3) {
      throw Exception('Username minimal 3 karakter.');
    }
    if (!RegExp(r'^[a-z0-9_\.]+$').hasMatch(uname)) {
      throw Exception(
          'Username hanya boleh huruf, angka, titik, dan underscore.');
    }
    final doc = await _users.doc(uid).get();
    final data = doc.data() ?? const <String, dynamic>{};
    final current = (data['username'] ?? '') as String;
    if (uname == current) return; // no-op
    final lastTs = data['usernameUpdatedAt'];
    if (lastTs is Timestamp) {
      final next =
          lastTs.toDate().add(const Duration(days: AppUser.usernameCooldownDays));
      if (DateTime.now().isBefore(next)) {
        final days = next.difference(DateTime.now()).inHours ~/ 24 + 1;
        throw Exception(
            'Username hanya bisa diganti 1x per ${AppUser.usernameCooldownDays} hari. Coba lagi dalam $days hari.');
      }
    }
    if (await isUsernameTaken(uname)) {
      throw Exception('Username "$uname" sudah dipakai.');
    }
    await _users.doc(uid).update({
      'username': uname,
      'usernameUpdatedAt': FieldValue.serverTimestamp(),
    });
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
    // Notify the followed user (only on new follow).
    final meDoc = await me.get();
    final nowFollowing =
        List<String>.from(meDoc.data()?['following'] ?? const [])
            .contains(targetUid);
    if (nowFollowing) {
      await _pushNotification(
        toUid: targetUid,
        fromUid: currentUid,
        type: 'follow',
      );
    }
  }

  // ============================================================
  // POSTS
  // ============================================================
  CollectionReference<Map<String, dynamic>> get _posts => _db.collection('posts');

  Future<String> createPost({
    required AppUser author,
    String imageUrl = '',
    List<String> imageUrls = const [],
    required String caption,
  }) async {
    final urls = imageUrls.isNotEmpty
        ? imageUrls
        : (imageUrl.isNotEmpty ? <String>[imageUrl] : <String>[]);
    final cover = urls.isNotEmpty ? urls.first : imageUrl;
    final doc = await _posts.add({
      'authorId': author.uid,
      'authorName': author.displayName,
      'authorUsername': author.username,
      'authorAvatarUrl': author.avatarUrl,
      'imageUrl': cover,
      'imageUrls': urls,
      'caption': caption,
      'hashtags': _extractHashtags(caption),
      'likes': <String>[],
      'commentsCount': 0,
      'createdAt': FieldValue.serverTimestamp(),
    });
    // Notify users @mentioned in the caption.
    await _notifyMentionsInText(
      text: caption,
      fromUid: author.uid,
      exclude: const <String>{},
      postId: doc.id,
      postImageUrl: cover,
    );
    return doc.id;
  }

  /// Update an existing post's caption (re-parses hashtags). Image editing is
  /// intentionally out of scope to keep uploads simple.
  Future<void> updatePost({
    required String postId,
    required String caption,
  }) async {
    await _posts.doc(postId).update({
      'caption': caption,
      'hashtags': _extractHashtags(caption),
      'editedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Delete a post and all of its comments. Best-effort; large comment threads
  /// beyond a single batch are not expected for this app's scale.
  Future<void> deletePost(String postId) async {
    final comments = await _commentsCol(postId).limit(450).get();
    final batch = _db.batch();
    for (final d in comments.docs) {
      batch.delete(d.reference);
    }
    batch.delete(_posts.doc(postId));
    await batch.commit();
  }

  /// Posts tagged with [tag] (case-insensitive), newest first. Index-free:
  /// arrayContains + in-memory sort avoids a composite index.
  Stream<List<Post>> hashtagPostsStream(String tag) {
    final t = tag.trim().toLowerCase().replaceAll('#', '');
    if (t.isEmpty) return Stream.value(const <Post>[]);
    return _posts
        .where('hashtags', arrayContains: t)
        .snapshots()
        .map((s) {
      final list = s.docs.map(Post.fromDoc).toList();
      list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return list;
    });
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
    bool justLiked = false;
    String authorId = '';
    String postImageUrl = '';
    await _db.runTransaction((tx) async {
      final snap = await tx.get(ref);
      final data = snap.data() ?? const <String, dynamic>{};
      authorId = (data['authorId'] ?? '') as String;
      postImageUrl = (data['imageUrl'] ?? '') as String;
      final likes = List<String>.from(data['likes'] ?? const []);
      if (likes.contains(uid)) {
        tx.update(ref, {'likes': FieldValue.arrayRemove([uid])});
        justLiked = false;
      } else {
        tx.update(ref, {'likes': FieldValue.arrayUnion([uid])});
        justLiked = true;
      }
    });
    if (justLiked && authorId.isNotEmpty && authorId != uid) {
      await _pushNotification(
        toUid: authorId,
        fromUid: uid,
        type: 'like',
        postId: postId,
        postImageUrl: postImageUrl,
      );
    }
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
      'likes': <String>[],
      'createdAt': FieldValue.serverTimestamp(),
    });
    batch.update(_posts.doc(postId), {
      'commentsCount': FieldValue.increment(1),
    });
    await batch.commit();

    // Resolve the post to know whom to notify and what image to show.
    final postSnap = await _posts.doc(postId).get();
    final postData = postSnap.data() ?? const <String, dynamic>{};
    final postAuthorId = (postData['authorId'] ?? '') as String;
    final postImageUrl = (postData['imageUrl'] ?? '') as String;

    // Reply -> notify the parent comment author (avoid double-notify post owner).
    String? parentAuthorId;
    if (parentId.isNotEmpty) {
      final pSnap = await _commentsCol(postId).doc(parentId).get();
      parentAuthorId = (pSnap.data()?['authorId'] ?? '') as String?;
      if (parentAuthorId != null &&
          parentAuthorId!.isNotEmpty &&
          parentAuthorId != author.uid) {
        await _pushNotification(
          toUid: parentAuthorId!,
          fromUid: author.uid,
          type: 'reply',
          postId: postId,
          commentId: c.id,
          postImageUrl: postImageUrl,
          text: text,
        );
      }
    }

    // Notify the post author if different from the commenter AND the parent.
    if (postAuthorId.isNotEmpty &&
        postAuthorId != author.uid &&
        postAuthorId != parentAuthorId) {
      await _pushNotification(
        toUid: postAuthorId,
        fromUid: author.uid,
        type: parentId.isEmpty ? 'comment' : 'reply',
        postId: postId,
        commentId: c.id,
        postImageUrl: postImageUrl,
        text: text,
      );
    }

    // Mentions: @username inside the comment text.
    final mentioned = _extractMentions(text);
    for (final uname in mentioned) {
      final q = await _users
          .where('username', isEqualTo: uname.toLowerCase())
          .limit(1)
          .get();
      if (q.docs.isEmpty) continue;
      final muid = q.docs.first.id;
      if (muid == author.uid || muid == postAuthorId || muid == parentAuthorId) {
        continue;
      }
      await _pushNotification(
        toUid: muid,
        fromUid: author.uid,
        type: 'mention',
        postId: postId,
        commentId: c.id,
        postImageUrl: postImageUrl,
        text: text,
      );
    }
  }

  Set<String> _extractMentions(String text) {
    final re = RegExp(r'@([a-zA-Z0-9_\.]{2,30})');
    return re.allMatches(text).map((m) => m.group(1)!).toSet();
  }

  /// Parse `#topik` tokens from text -> lowercased, de-duplicated list.
  List<String> _extractHashtags(String text) {
    final re = RegExp(r'#([a-zA-Z0-9_]{1,50})');
    final set = <String>{};
    for (final m in re.allMatches(text)) {
      set.add(m.group(1)!.toLowerCase());
    }
    return set.toList();
  }

  /// Send a 'mention' notification to every valid @username in [text],
  /// skipping the author and any uids in [exclude].
  Future<void> _notifyMentionsInText({
    required String text,
    required String fromUid,
    required Set<String> exclude,
    String postId = '',
    String commentId = '',
    String postImageUrl = '',
  }) async {
    final mentioned = _extractMentions(text);
    for (final uname in mentioned) {
      final q = await _users
          .where('username', isEqualTo: uname.toLowerCase())
          .limit(1)
          .get();
      if (q.docs.isEmpty) continue;
      final muid = q.docs.first.id;
      if (muid == fromUid || exclude.contains(muid)) continue;
      await _pushNotification(
        toUid: muid,
        fromUid: fromUid,
        type: 'mention',
        postId: postId,
        commentId: commentId,
        postImageUrl: postImageUrl,
        text: text,
      );
    }
  }

  Future<void> updateComment({
    required String postId,
    required String commentId,
    required String text,
  }) async {
    await _commentsCol(postId).doc(commentId).update({
      'text': text,
      'editedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> deleteComment({
    required String postId,
    required String commentId,
  }) async {
    final batch = _db.batch();
    batch.delete(_commentsCol(postId).doc(commentId));
    batch.update(_posts.doc(postId), {
      'commentsCount': FieldValue.increment(-1),
    });
    await batch.commit();
  }

  // ----- comment likes -----
  Future<void> toggleCommentLike({
    required String postId,
    required String commentId,
    required String uid,
  }) async {
    final ref = _commentsCol(postId).doc(commentId);
    bool justLiked = false;
    String authorId = '';
    String postImageUrl = '';
    await _db.runTransaction((tx) async {
      final snap = await tx.get(ref);
      final data = snap.data() ?? const <String, dynamic>{};
      authorId = (data['authorId'] ?? '') as String;
      final likes = List<String>.from(data['likes'] ?? const []);
      if (likes.contains(uid)) {
        tx.update(ref, {'likes': FieldValue.arrayRemove([uid])});
        justLiked = false;
      } else {
        tx.update(ref, {'likes': FieldValue.arrayUnion([uid])});
        justLiked = true;
      }
    });
    if (justLiked && authorId.isNotEmpty && authorId != uid) {
      final postSnap = await _posts.doc(postId).get();
      postImageUrl =
          (postSnap.data()?['imageUrl'] ?? '') as String;
      await _pushNotification(
        toUid: authorId,
        fromUid: uid,
        type: 'like',
        postId: postId,
        commentId: commentId,
        postImageUrl: postImageUrl,
        text: 'liked your comment',
      );
    }
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


  // ============================================================
  // SAVED POSTS (bookmark)
  // ============================================================
  Future<void> toggleSavePost({
    required String uid,
    required String postId,
  }) async {
    final ref = _users.doc(uid);
    await _db.runTransaction((tx) async {
      final snap = await tx.get(ref);
      final saved = List<String>.from(snap.data()?['saved'] ?? const []);
      if (saved.contains(postId)) {
        tx.update(ref, {'saved': FieldValue.arrayRemove([postId])});
      } else {
        tx.update(ref, {'saved': FieldValue.arrayUnion([postId])});
      }
    });
  }

  /// Stream the user's saved posts, newest-save first (in array order, reversed).
  /// Firestore `whereIn` caps at 30 ids — we chunk to support more.
  Stream<List<Post>> savedPostsStream(String uid) {
    return userStream(uid).asyncMap((u) async {
      final ids = (u?.saved ?? const <String>[]).reversed.toList();
      if (ids.isEmpty) return <Post>[];
      final out = <Post>[];
      for (var i = 0; i < ids.length; i += 10) {
        final chunk = ids.sublist(i, (i + 10 > ids.length) ? ids.length : i + 10);
        final qs = await _posts
            .where(FieldPath.documentId, whereIn: chunk)
            .get();
        out.addAll(qs.docs.map(Post.fromDoc));
      }
      // Preserve the saved-order (newest first).
      final byId = {for (final p in out) p.id: p};
      return [for (final id in ids) if (byId[id] != null) byId[id]!];
    });
  }

  // ============================================================
  // FCM TOKEN (push)
  // ============================================================
  /// Persist the FCM device token on the user doc. Safe to call repeatedly.
  /// Owner: wire firebase_messaging in main.dart once google-services.json is in
  /// place, then call `saveFcmToken(uid, await FirebaseMessaging.instance.getToken())`.
  Future<void> saveFcmToken(String uid, String? token) async {
    if (token == null || token.isEmpty) return;
    await _users.doc(uid).update({'fcmToken': token});
  }

  // ============================================================
  // NOTIFICATIONS (in-app)
  // ============================================================
  CollectionReference<Map<String, dynamic>> _notifCol(String uid) =>
      _users.doc(uid).collection('notifications');

  Future<void> _pushNotification({
    required String toUid,
    required String fromUid,
    required String type, // like | comment | reply | follow | mention
    String postId = '',
    String commentId = '',
    String postImageUrl = '',
    String text = '',
  }) async {
    if (toUid.isEmpty || toUid == fromUid) return;
    // Hydrate sender display fields so the Activity row paints without an
    // extra read (we still have LiveUserAvatar/Name for live updates).
    final fromUser = _userCache[fromUid] ?? await getUser(fromUid);
    await _notifCol(toUid).add({
      'type': type,
      'fromUid': fromUid,
      'fromName': fromUser?.displayName ?? '',
      'fromAvatarUrl': fromUser?.avatarUrl ?? '',
      'postId': postId,
      'commentId': commentId,
      'postImageUrl': postImageUrl,
      'text': text,
      'read': false,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Stream<List<AppNotification>> notificationsStream(String uid, {int limit = 80}) {
    if (uid.isEmpty) return const Stream.empty();
    return _notifCol(uid)
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((s) => s.docs.map(AppNotification.fromDoc).toList());
  }

  /// Live unread count. Used by the menu icon badge.
  Stream<int> unreadNotificationsCount(String uid) {
    if (uid.isEmpty) return Stream.value(0);
    return _notifCol(uid)
        .where('read', isEqualTo: false)
        .snapshots()
        .map((s) => s.docs.length);
  }

  Future<void> markAllNotificationsRead(String uid) async {
    final q = await _notifCol(uid)
        .where('read', isEqualTo: false)
        .limit(300)
        .get();
    if (q.docs.isEmpty) return;
    final batch = _db.batch();
    for (final d in q.docs) {
      batch.update(d.reference, {'read': true});
    }
    await batch.commit();
  }
}

// ============================================================
// AppNotification model (kept here so screens can import it from this file).
// ============================================================
class AppNotification {
  final String id;
  final String type; // like | comment | reply | follow | mention
  final String fromUid;
  final String fromName;
  final String fromAvatarUrl;
  final String postId;
  final String commentId;
  final String postImageUrl;
  final String text;
  final bool read;
  final DateTime createdAt;

  const AppNotification({
    required this.id,
    required this.type,
    required this.fromUid,
    required this.fromName,
    required this.fromAvatarUrl,
    required this.postId,
    required this.commentId,
    required this.postImageUrl,
    required this.text,
    required this.read,
    required this.createdAt,
  });

  factory AppNotification.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final m = doc.data() ?? const <String, dynamic>{};
    return AppNotification(
      id: doc.id,
      type: (m['type'] ?? '') as String,
      fromUid: (m['fromUid'] ?? '') as String,
      fromName: (m['fromName'] ?? '') as String,
      fromAvatarUrl: (m['fromAvatarUrl'] ?? '') as String,
      postId: (m['postId'] ?? '') as String,
      commentId: (m['commentId'] ?? '') as String,
      postImageUrl: (m['postImageUrl'] ?? '') as String,
      text: (m['text'] ?? '') as String,
      read: (m['read'] ?? false) as bool,
      createdAt: (m['createdAt'] is Timestamp)
          ? (m['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
    );
  }
}
