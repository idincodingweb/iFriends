import 'package:cloud_firestore/cloud_firestore.dart';

class Post {
  final String id;
  final String authorId;
  final String authorName;
  final String authorUsername;
  final String authorAvatarUrl;
  final String imageUrl; // legacy single image (kept for back-compat)
  final List<String> imageUrls; // carousel (multi-image) support
  final String caption;
  final List<String> hashtags; // lowercased tags parsed from caption
  final List<String> likes; // uids
  final int commentsCount;
  final DateTime createdAt;
  final DateTime? editedAt;
  final bool archived;

  const Post({
    required this.id,
    required this.authorId,
    required this.authorName,
    required this.authorUsername,
    required this.authorAvatarUrl,
    required this.imageUrl,
    this.imageUrls = const [],
    required this.caption,
    this.hashtags = const [],
    required this.likes,
    required this.commentsCount,
    required this.createdAt,
    this.editedAt,
    this.archived = false,
  });

  int get likesCount => likes.length;

  bool get isEdited => editedAt != null;

  /// Unified image list. Falls back to the single legacy [imageUrl] so old
  /// posts created before carousel support still render.
  List<String> get images {
    if (imageUrls.isNotEmpty) return imageUrls;
    if (imageUrl.isNotEmpty) return [imageUrl];
    return const [];
  }

  /// Simple popularity score for Trending.
  int get score => likes.length + commentsCount * 2;

  factory Post.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final m = doc.data() ?? const {};
    return Post(
      id: doc.id,
      authorId: (m['authorId'] ?? '') as String,
      authorName: (m['authorName'] ?? '') as String,
      authorUsername: (m['authorUsername'] ?? '') as String,
      authorAvatarUrl: (m['authorAvatarUrl'] ?? '') as String,
      imageUrl: (m['imageUrl'] ?? '') as String,
      imageUrls: List<String>.from(m['imageUrls'] ?? const []),
      caption: (m['caption'] ?? '') as String,
      hashtags: List<String>.from(m['hashtags'] ?? const []),
      likes: List<String>.from(m['likes'] ?? const []),
      commentsCount: (m['commentsCount'] ?? 0) as int,
      createdAt: (m['createdAt'] is Timestamp)
          ? (m['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
      editedAt: (m['editedAt'] is Timestamp)
          ? (m['editedAt'] as Timestamp).toDate()
          : null,
      archived: (m['archived'] ?? false) as bool,
    );
  }
}

class Comment {
  final String id;
  final String authorId;
  final String authorName;
  final String authorAvatarUrl;
  final String text;
  final String parentId; // '' = top-level, otherwise id of the parent comment
  final String replyToName; // @username this reply targets (for display)
  final List<String> likes; // uids that liked this comment
  final DateTime createdAt;
  final DateTime? editedAt;

  const Comment({
    required this.id,
    required this.authorId,
    required this.authorName,
    required this.authorAvatarUrl,
    required this.text,
    this.parentId = '',
    this.replyToName = '',
    this.likes = const [],
    required this.createdAt,
    this.editedAt,
  });

  bool get isReply => parentId.isNotEmpty;
  bool get isEdited => editedAt != null;
  int get likesCount => likes.length;

  factory Comment.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final m = doc.data() ?? const {};
    return Comment(
      id: doc.id,
      authorId: (m['authorId'] ?? '') as String,
      authorName: (m['authorName'] ?? '') as String,
      authorAvatarUrl: (m['authorAvatarUrl'] ?? '') as String,
      text: (m['text'] ?? '') as String,
      parentId: (m['parentId'] ?? '') as String,
      replyToName: (m['replyToName'] ?? '') as String,
      likes: List<String>.from(m['likes'] ?? const []),
      createdAt: (m['createdAt'] is Timestamp)
          ? (m['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
      editedAt: (m['editedAt'] is Timestamp)
          ? (m['editedAt'] as Timestamp).toDate()
          : null,
    );
  }
}
