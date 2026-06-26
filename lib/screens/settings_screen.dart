import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../models/user_model.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import '../theme/app_theme.dart';
import '../widgets/user_avatar.dart';
import 'edit_profile_screen.dart';
import 'follow_requests_screen.dart';

/// Instagram-style Settings screen.
///
/// Sections:
///   • Account        — Edit profile, Username, Email, Password
///   • Privacy        — Private account, Blocked users, Follow requests
///   • Notifications  — Local toggles (likes / comments / follows / messages)
///   • App            — Theme, Language (placeholders)
///   • Support        — Help, About
///   • Danger zone    — Log out, Delete account
class SettingsScreen extends StatefulWidget {
  final AppUser user;
  const SettingsScreen({super.key, required this.user});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late AppUser _user = widget.user;
  bool _busyPrivate = false;

  // local-only notification prefs (kept in-memory for this session)
  bool _notifLikes = true;
  bool _notifComments = true;
  bool _notifFollows = true;
  bool _notifMessages = true;

  FirestoreService get _db => FirestoreService.instance;

  @override
  void initState() {
    super.initState();
    // keep user fresh
    _db.userStream(widget.user.uid).listen((u) {
      if (mounted && u != null) setState(() => _user = u);
    });
  }

  // ------------------------------------------------------------ helpers

  void _snack(String msg, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: error ? Colors.red.shade600 : null,
      ),
    );
  }

  Future<void> _togglePrivate(bool v) async {
    setState(() => _busyPrivate = true);
    try {
      await _db.setAccountPrivate(_user.uid, v);
      _snack(v ? 'Akun kamu sekarang privat' : 'Akun kamu sekarang publik');
    } catch (e) {
      _snack('Gagal mengubah privasi: $e', error: true);
    } finally {
      if (mounted) setState(() => _busyPrivate = false);
    }
  }

  // ------------------------------------------------------------ build

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FB),
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0.5,
        title: const Text('Settings',
            style: TextStyle(fontWeight: FontWeight.w700)),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 12),
        children: [
          _profileHeader(),
          _section('Account'),
          _tile(
            icon: Icons.person_outline,
            title: 'Edit profile',
            subtitle: 'Nama, bio, foto, lokasi',
            onTap: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => EditProfileScreen(user: _user))),
          ),
          _tile(
            icon: Icons.alternate_email,
            title: 'Username',
            subtitle: '@${_user.username}',
            onTap: () => _snack(
                'Ubah username dari halaman Edit Profile (cooldown 14 hari)'),
          ),
          _tile(
            icon: Icons.mail_outline,
            title: 'Email',
            subtitle: _user.email.isEmpty ? '—' : _user.email,
            onTap: _showChangeEmail,
          ),
          _tile(
            icon: Icons.lock_outline,
            title: 'Password',
            subtitle: 'Ubah password akun',
            onTap: _showChangePassword,
          ),
          _tile(
            icon: Icons.password,
            title: 'Lupa password?',
            subtitle: 'Kirim email reset password',
            onTap: _sendPasswordReset,
          ),

          _section('Privacy & Security'),
          _switchTile(
            icon: Icons.lock_person_outlined,
            title: 'Akun privat',
            subtitle:
                'Hanya follower yang disetujui yang bisa melihat post kamu',
            value: _user.isPrivate,
            loading: _busyPrivate,
            onChanged: _togglePrivate,
          ),
          if (_user.isPrivate)
            _tile(
              icon: Icons.how_to_reg_outlined,
              title: 'Permintaan follow',
              subtitle: 'Setujui atau tolak pengikut baru',
              onTap: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) =>
                      FollowRequestsScreen(currentUser: _user))),
            ),
          _tile(
            icon: Icons.block,
            title: 'Pengguna diblokir',
            subtitle: '${_user.blocked.length} akun',
            onTap: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => _BlockedUsersScreen(currentUser: _user))),
          ),

          _section('Notifikasi'),
          _switchTile(
            icon: Icons.favorite_outline,
            title: 'Like',
            value: _notifLikes,
            onChanged: (v) => setState(() => _notifLikes = v),
          ),
          _switchTile(
            icon: Icons.mode_comment_outlined,
            title: 'Komentar',
            value: _notifComments,
            onChanged: (v) => setState(() => _notifComments = v),
          ),
          _switchTile(
            icon: Icons.person_add_alt,
            title: 'Follower baru',
            value: _notifFollows,
            onChanged: (v) => setState(() => _notifFollows = v),
          ),
          _switchTile(
            icon: Icons.chat_bubble_outline,
            title: 'Pesan',
            value: _notifMessages,
            onChanged: (v) => setState(() => _notifMessages = v),
          ),

          _section('Tampilan'),
          _tile(
            icon: Icons.color_lens_outlined,
            title: 'Tema',
            subtitle: 'Light (default)',
            onTap: () => _snack('Tema gelap segera hadir'),
          ),
          _tile(
            icon: Icons.translate,
            title: 'Bahasa',
            subtitle: 'Bahasa Indonesia',
            onTap: () => _snack('Pilihan bahasa segera hadir'),
          ),

          _section('Bantuan'),
          _tile(
            icon: Icons.help_outline,
            title: 'Pusat bantuan',
            onTap: () => _snack('Pusat bantuan segera hadir'),
          ),
          _tile(
            icon: Icons.privacy_tip_outlined,
            title: 'Kebijakan privasi',
            onTap: () => _snack('Dokumen privasi segera hadir'),
          ),
          _tile(
            icon: Icons.info_outline,
            title: 'Tentang iFriends',
            subtitle: 'Versi 1.0.0',
            onTap: () => showAboutDialog(
              context: context,
              applicationName: 'iFriends',
              applicationVersion: '1.0.0',
              applicationLegalese: '© 2026 iFriends',
            ),
          ),

          _section(''),
          _tile(
            icon: Icons.logout,
            title: 'Log out',
            danger: true,
            onTap: _confirmLogout,
          ),
          _tile(
            icon: Icons.delete_forever_outlined,
            title: 'Hapus akun',
            subtitle: 'Tindakan ini tidak bisa dibatalkan',
            danger: true,
            onTap: _confirmDeleteAccount,
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  // ------------------------------------------------------------ widgets

  Widget _profileHeader() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: AppColors.vibrant,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          UserAvatar(
            avatarUrl: _user.avatarUrl,
            seed: _user.username,
            size: 56,
            ring: false,
            background: Colors.white,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _user.displayName.isEmpty ? 'iFriends User' : _user.displayName,
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 16),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text('@${_user.username}',
                    style: const TextStyle(color: Colors.white70, fontSize: 13)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _section(String label) {
    if (label.isEmpty) return const SizedBox(height: 16);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 6),
      child: Text(
        label.toUpperCase(),
        style: TextStyle(
          color: Colors.grey.shade600,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.6,
        ),
      ),
    );
  }

  Widget _tile({
    required IconData icon,
    required String title,
    String? subtitle,
    bool danger = false,
    required VoidCallback onTap,
  }) {
    final color = danger ? Colors.red.shade600 : Colors.black87;
    return Container(
      color: Colors.white,
      child: ListTile(
        leading: Icon(icon, color: color),
        title: Text(title,
            style: TextStyle(color: color, fontWeight: FontWeight.w600)),
        subtitle: subtitle == null
            ? null
            : Text(subtitle, style: const TextStyle(fontSize: 12)),
        trailing: const Icon(Icons.chevron_right, color: Colors.grey),
        onTap: onTap,
      ),
    );
  }

  Widget _switchTile({
    required IconData icon,
    required String title,
    String? subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
    bool loading = false,
  }) {
    return Container(
      color: Colors.white,
      child: SwitchListTile(
        secondary: Icon(icon, color: Colors.black87),
        title: Text(title,
            style: const TextStyle(
                color: Colors.black87, fontWeight: FontWeight.w600)),
        subtitle: subtitle == null
            ? null
            : Text(subtitle, style: const TextStyle(fontSize: 12)),
        value: value,
        onChanged: loading ? null : onChanged,
        activeColor: AppColors.primaryPink,
      ),
    );
  }

  // ------------------------------------------------------------ actions

  Future<void> _showChangePassword() async {
    final cur = TextEditingController();
    final n1 = TextEditingController();
    final n2 = TextEditingController();
    final formKey = GlobalKey<FormState>();
    bool busy = false;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(builder: (ctx, setLocal) {
        return Padding(
          padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 20,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 20),
          child: Form(
            key: formKey,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Text('Ubah Password',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
              const SizedBox(height: 16),
              _pwField(cur, 'Password sekarang'),
              const SizedBox(height: 10),
              _pwField(n1, 'Password baru', minLen: 6),
              const SizedBox(height: 10),
              _pwField(n2, 'Konfirmasi password baru',
                  validator: (v) =>
                      v != n1.text ? 'Konfirmasi tidak cocok' : null),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primaryPink,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  onPressed: busy
                      ? null
                      : () async {
                          if (!formKey.currentState!.validate()) return;
                          setLocal(() => busy = true);
                          try {
                            final user = FirebaseAuth.instance.currentUser!;
                            final cred = EmailAuthProvider.credential(
                                email: user.email!, password: cur.text);
                            await user.reauthenticateWithCredential(cred);
                            await user.updatePassword(n1.text);
                            if (mounted) Navigator.pop(ctx);
                            _snack('Password berhasil diubah');
                          } on FirebaseAuthException catch (e) {
                            setLocal(() => busy = false);
                            _snack(
                                e.message ?? 'Gagal mengubah password',
                                error: true);
                          } catch (e) {
                            setLocal(() => busy = false);
                            _snack('Gagal: $e', error: true);
                          }
                        },
                  child: busy
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : const Text('Simpan'),
                ),
              ),
            ]),
          ),
        );
      }),
    );
  }

  Widget _pwField(TextEditingController c, String label,
      {int minLen = 1, String? Function(String?)? validator}) {
    return TextFormField(
      controller: c,
      obscureText: true,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
      validator: validator ??
          (v) {
            if (v == null || v.isEmpty) return 'Wajib diisi';
            if (v.length < minLen) return 'Minimal $minLen karakter';
            return null;
          },
    );
  }

  Future<void> _showChangeEmail() async {
    final pw = TextEditingController();
    final email = TextEditingController(text: _user.email);
    final formKey = GlobalKey<FormState>();
    bool busy = false;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(builder: (ctx, setLocal) {
        return Padding(
          padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 20,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 20),
          child: Form(
            key: formKey,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Text('Ubah Email',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              const Text(
                'Verifikasi akan dikirim ke email baru.',
                style: TextStyle(fontSize: 12, color: Colors.black54),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: email,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                    labelText: 'Email baru',
                    border: OutlineInputBorder()),
                validator: (v) {
                  if (v == null || !v.contains('@')) return 'Email tidak valid';
                  return null;
                },
              ),
              const SizedBox(height: 10),
              _pwField(pw, 'Password saat ini'),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primaryPink,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  onPressed: busy
                      ? null
                      : () async {
                          if (!formKey.currentState!.validate()) return;
                          setLocal(() => busy = true);
                          try {
                            final user = FirebaseAuth.instance.currentUser!;
                            final cred = EmailAuthProvider.credential(
                                email: user.email!, password: pw.text);
                            await user.reauthenticateWithCredential(cred);
                            await user.verifyBeforeUpdateEmail(email.text.trim());
                            if (mounted) Navigator.pop(ctx);
                            _snack(
                                'Email verifikasi dikirim ke ${email.text.trim()}');
                          } on FirebaseAuthException catch (e) {
                            setLocal(() => busy = false);
                            _snack(e.message ?? 'Gagal', error: true);
                          } catch (e) {
                            setLocal(() => busy = false);
                            _snack('Gagal: $e', error: true);
                          }
                        },
                  child: busy
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : const Text('Kirim verifikasi'),
                ),
              ),
            ]),
          ),
        );
      }),
    );
  }

  Future<void> _sendPasswordReset() async {
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: _user.email);
      _snack('Email reset password telah dikirim');
    } catch (e) {
      _snack('Gagal kirim email: $e', error: true);
    }
  }

  Future<void> _confirmLogout() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Log out?'),
        content: const Text('Kamu akan keluar dari akun ini.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Batal')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Log out'),
          ),
        ],
      ),
    );
    if (ok == true) {
      await AuthService.instance.signOut();
    }
  }

  Future<void> _confirmDeleteAccount() async {
    final pw = TextEditingController();
    final formKey = GlobalKey<FormState>();
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus akun?'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Akun, post, dan komentar kamu akan terhapus permanen. '
                'Masukkan password untuk konfirmasi.',
                style: TextStyle(fontSize: 13),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: pw,
                obscureText: true,
                decoration: const InputDecoration(
                    labelText: 'Password', border: OutlineInputBorder()),
                validator: (v) =>
                    v == null || v.isEmpty ? 'Wajib diisi' : null,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Batal')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              if (formKey.currentState!.validate()) Navigator.pop(ctx, true);
            },
            child: const Text('Hapus'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final user = FirebaseAuth.instance.currentUser!;
      final cred =
          EmailAuthProvider.credential(email: user.email!, password: pw.text);
      await user.reauthenticateWithCredential(cred);
      await user.delete();
      _snack('Akun terhapus');
    } on FirebaseAuthException catch (e) {
      _snack(e.message ?? 'Gagal menghapus akun', error: true);
    } catch (e) {
      _snack('Gagal: $e', error: true);
    }
  }
}

// ============================================================================
// Blocked users sub-screen
// ============================================================================
class _BlockedUsersScreen extends StatefulWidget {
  final AppUser currentUser;
  const _BlockedUsersScreen({required this.currentUser});

  @override
  State<_BlockedUsersScreen> createState() => _BlockedUsersScreenState();
}

class _BlockedUsersScreenState extends State<_BlockedUsersScreen> {
  late List<String> _ids = List.of(widget.currentUser.blocked);
  final Map<String, AppUser?> _cache = {};

  @override
  void initState() {
    super.initState();
    for (final id in _ids) {
      FirestoreService.instance.getUser(id).then((u) {
        if (mounted) setState(() => _cache[id] = u);
      });
    }
  }

  Future<void> _unblock(String uid) async {
    try {
      await FirestoreService.instance
          .unblockUser(currentUid: widget.currentUser.uid, targetUid: uid);
      if (mounted) setState(() => _ids.remove(uid));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Gagal: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pengguna diblokir'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0.5,
      ),
      body: _ids.isEmpty
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Belum ada pengguna yang kamu blokir.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.black54),
                ),
              ),
            )
          : ListView.separated(
              itemCount: _ids.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (_, i) {
                final id = _ids[i];
                final u = _cache[id];
                return ListTile(
                  leading: UserAvatar(
                    avatarUrl: u?.avatarUrl ?? '',
                    seed: u?.username ?? id,
                    size: 40,
                  ),
                  title: Text(u?.displayName ?? '…'),
                  subtitle: Text('@${u?.username ?? id}'),
                  trailing: OutlinedButton(
                    onPressed: () => _unblock(id),
                    child: const Text('Unblock'),
                  ),
                );
              },
            ),
    );
  }
}
