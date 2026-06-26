import 'package:cloud_firestore/cloud_firestore.dart';

class AppUser {
  final String uid;
  final String email;
  final String displayName;
  final String username;
  final String bio;
  final String location;
  final String avatarUrl;
  final String coverUrl;
  final String role; // 'user' | 'verified'
  final List<String> following;
  final List<String> followers;
  final List<String> saved; // postIds the user bookmarked
  final String fcmToken; // for push (filled when firebase_messaging is wired)
  final DateTime createdAt;
  final DateTime? usernameUpdatedAt; // last time the @username was changed

  const AppUser({
    required this.uid,
    required this.email,
    required this.displayName,
    required this.username,
    this.bio = '',
    this.location = '',
    this.avatarUrl = '',
    this.coverUrl = '',
    this.role = 'user',
    this.following = const [],
    this.followers = const [],
    this.saved = const [],
    this.fcmToken = '',
    required this.createdAt,
    this.usernameUpdatedAt,
  });

  bool get isVerified => role == 'verified';

  /// How many days the user must wait before changing the username again.
  /// One change per [cooldownDays]. Returns 0 when a change is allowed now.
  static const int usernameCooldownDays = 14;

  DateTime? get nextUsernameChangeAt => usernameUpdatedAt
      ?.add(const Duration(days: usernameCooldownDays));

  bool get canChangeUsername {
    final next = nextUsernameChangeAt;
    if (next == null) return true;
    return DateTime.now().isAfter(next);
  }

  int get daysUntilUsernameChange {
    final next = nextUsernameChangeAt;
    if (next == null) return 0;
    final diff = next.difference(DateTime.now());
    if (diff.isNegative) return 0;
    return diff.inHours ~/ 24 + 1;
  }

  factory AppUser.fromMap(String uid, Map<String, dynamic> m) {
    return AppUser(
      uid: uid,
      email: (m['email'] ?? '') as String,
      displayName: (m['displayName'] ?? '') as String,
      username: (m['username'] ?? '') as String,
      bio: (m['bio'] ?? '') as String,
      location: (m['location'] ?? '') as String,
      avatarUrl: (m['avatarUrl'] ?? '') as String,
      coverUrl: (m['coverUrl'] ?? '') as String,
      role: (m['role'] ?? 'user') as String,
      following: List<String>.from(m['following'] ?? const []),
      followers: List<String>.from(m['followers'] ?? const []),
      saved: List<String>.from(m['saved'] ?? const []),
      fcmToken: (m['fcmToken'] ?? '') as String,
      createdAt: (m['createdAt'] is Timestamp)
          ? (m['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
      usernameUpdatedAt: (m['usernameUpdatedAt'] is Timestamp)
          ? (m['usernameUpdatedAt'] as Timestamp).toDate()
          : null,
    );
  }

  Map<String, dynamic> toMap() => {
        'email': email,
        'displayName': displayName,
        'username': username,
        'bio': bio,
        'location': location,
        'avatarUrl': avatarUrl,
        'coverUrl': coverUrl,
        'role': role,
        'following': following,
        'followers': followers,
        'saved': saved,
        'fcmToken': fcmToken,
        'createdAt': Timestamp.fromDate(createdAt),
        if (usernameUpdatedAt != null)
          'usernameUpdatedAt': Timestamp.fromDate(usernameUpdatedAt!),
      };

  AppUser copyWith({
    String? displayName,
    String? bio,
    String? location,
    String? avatarUrl,
    String? coverUrl,
  }) {
    return AppUser(
      uid: uid,
      email: email,
      displayName: displayName ?? this.displayName,
      username: username,
      bio: bio ?? this.bio,
      location: location ?? this.location,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      coverUrl: coverUrl ?? this.coverUrl,
      role: role,
      following: following,
      followers: followers,
      saved: saved,
      fcmToken: fcmToken,
      createdAt: createdAt,
      usernameUpdatedAt: usernameUpdatedAt,
    );
  }
}
