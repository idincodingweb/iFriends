import 'package:cloud_firestore/cloud_firestore.dart';

class AppUser {
  final String uid;
  final String email;
  final String displayName;
  final String username;
  final String bio;
  final String location;
  final String avatarUrl;
  final String role; // 'user' | 'verified'
  final List<String> following;
  final List<String> followers;
  final DateTime createdAt;

  const AppUser({
    required this.uid,
    required this.email,
    required this.displayName,
    required this.username,
    this.bio = '',
    this.location = '',
    this.avatarUrl = '',
    this.role = 'user',
    this.following = const [],
    this.followers = const [],
    required this.createdAt,
  });

  bool get isVerified => role == 'verified';

  factory AppUser.fromMap(String uid, Map<String, dynamic> m) {
    return AppUser(
      uid: uid,
      email: (m['email'] ?? '') as String,
      displayName: (m['displayName'] ?? '') as String,
      username: (m['username'] ?? '') as String,
      bio: (m['bio'] ?? '') as String,
      location: (m['location'] ?? '') as String,
      avatarUrl: (m['avatarUrl'] ?? '') as String,
      role: (m['role'] ?? 'user') as String,
      following: List<String>.from(m['following'] ?? const []),
      followers: List<String>.from(m['followers'] ?? const []),
      createdAt: (m['createdAt'] is Timestamp)
          ? (m['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() => {
        'email': email,
        'displayName': displayName,
        'username': username,
        'bio': bio,
        'location': location,
        'avatarUrl': avatarUrl,
        'role': role,
        'following': following,
        'followers': followers,
        'createdAt': Timestamp.fromDate(createdAt),
      };

  AppUser copyWith({
    String? displayName,
    String? bio,
    String? location,
    String? avatarUrl,
  }) {
    return AppUser(
      uid: uid,
      email: email,
      displayName: displayName ?? this.displayName,
      username: username,
      bio: bio ?? this.bio,
      location: location ?? this.location,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      role: role,
      following: following,
      followers: followers,
      createdAt: createdAt,
    );
  }
}
