import 'package:cloud_firestore/cloud_firestore.dart';

class Chat {
  final String id;
  final List<String> participants;
  final String lastMessage;
  final DateTime updatedAt;
  final String lastSenderId;

  const Chat({
    required this.id,
    required this.participants,
    required this.lastMessage,
    required this.updatedAt,
    this.lastSenderId = '',
  });

  factory Chat.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final m = doc.data() ?? const {};
    return Chat(
      id: doc.id,
      participants: List<String>.from(m['participants'] ?? const []),
      lastMessage: (m['lastMessage'] ?? '') as String,
      lastSenderId: (m['lastSenderId'] ?? '') as String,
      updatedAt: (m['updatedAt'] is Timestamp)
          ? (m['updatedAt'] as Timestamp).toDate()
          : DateTime.now(),
    );
  }

  static String idFor(String a, String b) {
    final s = [a, b]..sort();
    return '${s[0]}_${s[1]}';
  }
}

class ChatMessage {
  final String id;
  final String senderId;
  final String text;
  final String imageUrl;
  final DateTime createdAt;

  // Shared post payload (optional). When postId is non-empty the bubble
  // renders a tappable post-preview card instead of a plain text/image.
  final String postId;
  final String postImageUrl;
  final String postCaption;
  final String postAuthorName;
  final String postAuthorAvatarUrl;

  const ChatMessage({
    required this.id,
    required this.senderId,
    required this.text,
    required this.imageUrl,
    required this.createdAt,
    this.postId = '',
    this.postImageUrl = '',
    this.postCaption = '',
    this.postAuthorName = '',
    this.postAuthorAvatarUrl = '',
  });

  bool get isSharedPost => postId.isNotEmpty;

  factory ChatMessage.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final m = doc.data() ?? const {};
    return ChatMessage(
      id: doc.id,
      senderId: (m['senderId'] ?? '') as String,
      text: (m['text'] ?? '') as String,
      imageUrl: (m['imageUrl'] ?? '') as String,
      createdAt: (m['createdAt'] is Timestamp)
          ? (m['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
      postId: (m['postId'] ?? '') as String,
      postImageUrl: (m['postImageUrl'] ?? '') as String,
      postCaption: (m['postCaption'] ?? '') as String,
      postAuthorName: (m['postAuthorName'] ?? '') as String,
      postAuthorAvatarUrl: (m['postAuthorAvatarUrl'] ?? '') as String,
    );
  }
}
