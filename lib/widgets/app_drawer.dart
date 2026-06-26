import 'package:flutter/material.dart';

import '../models/user_model.dart';
import '../screens/activity_screen.dart';
import '../screens/saved_screen.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';
import 'user_avatar.dart';

class AppDrawerMenu extends StatelessWidget {
  final AppUser? user;
  final VoidCallback onProfileTap;
  const AppDrawerMenu({super.key, required this.user, required this.onProfileTap});

  void _open(BuildContext context, Widget page) {
    Navigator.of(context).pop();
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));
  }

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: Colors.white,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
              decoration: const BoxDecoration(gradient: AppColors.vibrant),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  UserAvatar(
                    avatarUrl: user?.avatarUrl ?? '',
                    seed: user?.username ?? '?',
                    size: 64,
                    ring: false,
                    background: Colors.white,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    user?.displayName.isNotEmpty == true
                        ? user!.displayName
                        : 'iFriends User',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    user != null ? '@${user!.username}' : '',
                    style: const TextStyle(color: Colors.white70),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 8),
                children: [
                  _item(context, Icons.person_outline, 'Your Profile',
                      onProfileTap),
                  _item(context, Icons.bookmark_border, 'Saved',
                      () => _open(context, const SavedScreen())),
                  _item(context, Icons.archive_outlined, 'Archive', () {}),
                  _item(context, Icons.history, 'Your Activity',
                      () => _open(context, const ActivityScreen())),
                  _item(context, Icons.insights_outlined, 'Insights', () {}),
                  _item(context, Icons.qr_code_2, 'QR Code', () {}),
                  const Divider(height: 24),
                  _item(context, Icons.settings_outlined, 'Settings', () {}),
                  _item(context, Icons.switch_account_outlined,
                      'Switch Account', () {}),
                  _item(
                    context,
                    Icons.logout,
                    'Log Out',
                    () async {
                      Navigator.of(context).pop();
                      await AuthService.instance.signOut();
                    },
                    danger: true,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _item(BuildContext context, IconData icon, String label, VoidCallback onTap,
      {bool danger = false}) {
    final color = danger ? AppColors.primaryPink : AppColors.textDark;
    return ListTile(
      leading: Icon(icon, color: color),
      title: Text(label,
          style: TextStyle(color: color, fontWeight: FontWeight.w500)),
      onTap: onTap,
    );
  }
}
