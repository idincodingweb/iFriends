import 'package:cloud_firestore/cloud_firestore.dart';

class Post {
  final String id;
  final String authorId;
  final String authorName;
  final String authorUsername;
  final String authorAvatarUrl;
  final String imageUrl;
  final String caption;
  final List<String> likes; // uids
  final int commentsCount;
  final DateTime createdAt;

  const Post({
    required this.id,
    required this.authorId,
    required this.authorName,
    required this.authorUsername,
    required this.authorAvatarUrl,
    required this.imageUrl,
    required this.caption,
    required this.likes,
    required this.commentsCount,
    required this.createdAt,
  });

  int get likesCount => likes.length;

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
      caption: (m['caption'] ?? '') as String,
      likes: List<String>.from(m['likes'] ?? const []),
      commentsCount: (m['commentsCount'] ?? 0) as int,
      createdAt: (m['createdAt'] is Timestamp)
          ? (m['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
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
  final DateTime createdAt;

  const Comment({
    required this.id,
    required this.authorId,
    required this.authorName,
    required this.authorAvatarUrl,
    required this.text,
    this.parentId = '',
    this.replyToName = '',
    required this.createdAt,
  });

  bool get isReply => parentId.isNotEmpty;

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
      createdAt: (m['createdAt'] is Timestamp)
          ? (m['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
    );
  }
}
