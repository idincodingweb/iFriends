import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../config/app_config.dart';
import '../models/user_model.dart';
import '../services/drive_service.dart';
import '../services/firestore_service.dart';
import '../theme/app_theme.dart';
import '../widgets/user_avatar.dart';

class EditProfileScreen extends StatefulWidget {
  final AppUser user;
  const EditProfileScreen({super.key, required this.user});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  late final TextEditingController _name =
      TextEditingController(text: widget.user.displayName);
  late final TextEditingController _username =
      TextEditingController(text: widget.user.username);
  late final TextEditingController _bio =
      TextEditingController(text: widget.user.bio);
  late final TextEditingController _location =
      TextEditingController(text: widget.user.location);

  File? _pickedAvatar;
  bool _saving = false;
  String? _error;

  Future<void> _pickAvatar() async {
    final picker = ImagePicker();
    final x = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 800,
      imageQuality: 85,
    );
    if (x != null) setState(() => _pickedAvatar = File(x.path));
  }

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      // Username change first (enforces 14-day cooldown + uniqueness). Throws
      // a user-facing Exception that we surface inline.
      final newUsername =
          _username.text.trim().toLowerCase().replaceAll('@', '');
      if (newUsername != widget.user.username) {
        await FirestoreService.instance.updateUsername(
          uid: widget.user.uid,
          newUsername: newUsername,
        );
      }
      String? avatarUrl;
      if (_pickedAvatar != null) {
        avatarUrl = await DriveService.instance.uploadImage(
          file: _pickedAvatar!,
          folder: AppConfig.folderProfiles,
        );
      }
      await FirestoreService.instance.updateUser(
        widget.user.uid,
        displayName: _name.text.trim(),
        bio: _bio.text.trim(),
        location: _location.text.trim(),
        avatarUrl: avatarUrl,
      );
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      setState(() =>
          _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Profile'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: AppColors.textDark,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            GestureDetector(
              onTap: _pickAvatar,
              child: Stack(
                alignment: Alignment.bottomRight,
                children: [
                  _pickedAvatar != null
                      ? ClipOval(
                          child: Image.file(_pickedAvatar!,
                              width: 110, height: 110, fit: BoxFit.cover))
                      : UserAvatar(
                          avatarUrl: widget.user.avatarUrl,
                          seed: widget.user.username,
                          size: 110,
                          ring: true,
                        ),
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: const BoxDecoration(
                      gradient: AppColors.vibrant,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.camera_alt,
                        color: Colors.white, size: 18),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            _field(_name, 'Display name'),
            const SizedBox(height: 12),
            _field(
              _username,
              'Username',
              enabled: widget.user.canChangeUsername,
              prefix: '@',
            ),
            Padding(
              padding: const EdgeInsets.only(top: 6, left: 4),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  widget.user.canChangeUsername
                      ? 'Username bisa diganti 1x setiap ${AppUser.usernameCooldownDays} hari.'
                      : 'Username baru bisa diganti lagi dalam ${widget.user.daysUntilUsernameChange} hari.',
                  style: const TextStyle(
                      color: AppColors.textMuted, fontSize: 12),
                ),
              ),
            ),
            const SizedBox(height: 12),
            _field(_bio, 'Bio', maxLines: 3),
            const SizedBox(height: 12),
            _field(_location, 'Location'),
            const SizedBox(height: 20),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(_error!,
                    style: const TextStyle(color: Colors.red)),
              ),
            SizedBox(
              width: double.infinity,
              child: GestureDetector(
                onTap: _saving ? null : _save,
                child: Container(
                  height: 52,
                  decoration: BoxDecoration(
                    gradient: AppColors.vibrant,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  alignment: Alignment.center,
                  child: _saving
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2.5),
                        )
                      : const Text('Save changes',
                          style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                              fontSize: 16)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _field(TextEditingController c, String label,
      {int maxLines = 1, bool enabled = true, String? prefix}) {
    return TextField(
      controller: c,
      maxLines: maxLines,
      enabled: enabled,
      decoration: InputDecoration(
        labelText: label,
        prefixText: prefix,
        filled: true,
        fillColor: AppColors.softBg,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}
