import 'package:flutter/material.dart';

import '../models/user_model.dart';
import '../services/firestore_service.dart';
import '../widgets/live_user_avatar.dart';
import 'profile_screen.dart';

/// Lists incoming follow requests for a private account. Allows accept/reject.
class FollowRequestsScreen extends StatelessWidget {
  final AppUser currentUser;
  const FollowRequestsScreen({super.key, required this.currentUser});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Follow requests')),
      body: StreamBuilder<List<String>>(
        stream:
            FirestoreService.instance.incomingFollowRequests(currentUser.uid),
        builder: (context, snap) {
          final ids = snap.data ?? const <String>[];
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (ids.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Belum ada permintaan follow.',
                  style: TextStyle(color: Colors.grey),
                ),
              ),
            );
          }
          return ListView.separated(
            itemCount: ids.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (_, i) {
              final uid = ids[i];
              return ListTile(
                leading: GestureDetector(
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) =>
                          ProfileScreen(uid: uid, isMe: false),
                    ),
                  ),
                  child: LiveUserAvatar(uid: uid, fallbackSeed: uid, size: 40),
                ),
                title: LiveUserName(
                  uid: uid,
                  fallbackDisplayName: uid,
                  fallbackUsername: '',
                  nameStyle: const TextStyle(fontWeight: FontWeight.w600),
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.check_circle,
                          color: Colors.green),
                      onPressed: () => FirestoreService.instance
                          .acceptFollowRequest(
                            currentUid: currentUser.uid,
                            requesterUid: uid,
                          ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.cancel, color: Colors.red),
                      onPressed: () => FirestoreService.instance
                          .rejectFollowRequest(
                            currentUid: currentUser.uid,
                            requesterUid: uid,
                          ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
