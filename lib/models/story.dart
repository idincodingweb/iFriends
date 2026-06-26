import 'package:cloud_firestore/cloud_firestore.dart';

class Story {
  final String id;
  final String authorId;
  final String imageUrl;
  final String caption;
  final DateTime createdAt;
  final DateTime expiresAt;
  final List<String> viewers;

  const Story({
    required this.id,
    required this.authorId,
    required this.imageUrl,
    required this.caption,
    required this.createdAt,
    required this.expiresAt,
    required this.viewers,
  });

  bool get isExpired => DateTime.now().isAfter(expiresAt);

  bool isViewedBy(String uid) => viewers.contains(uid);

  factory Story.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final m = doc.data() ?? const {};
    final created = (m['createdAt'] is Timestamp)
        ? (m['createdAt'] as Timestamp).toDate()
        : DateTime.now();
    final expires = (m['expiresAt'] is Timestamp)
        ? (m['expiresAt'] as Timestamp).toDate()
        : created.add(const Duration(hours: 24));
    return Story(
      id: doc.id,
      authorId: (m['authorId'] ?? '') as String,
      imageUrl: (m['imageUrl'] ?? '') as String,
      caption: (m['caption'] ?? '') as String,
      createdAt: created,
      expiresAt: expires,
      viewers: List<String>.from(m['viewers'] ?? const []),
    );
  }
}

/// Stories grouped per author, sorted oldest -> newest within the group.
class StoryGroup {
  final String authorId;
  final List<Story> stories;
  const StoryGroup({required this.authorId, required this.stories});

  bool allViewedBy(String uid) => stories.every((s) => s.isViewedBy(uid));
  DateTime get latestAt => stories
      .map((s) => s.createdAt)
      .reduce((a, b) => a.isAfter(b) ? a : b);
}
