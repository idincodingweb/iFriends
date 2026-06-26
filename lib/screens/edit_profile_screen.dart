import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../config/app_config.dart';
import '../models/user_model.dart';
import '../services/drive_service.dart';
import '../services/firestore_service.dart';
import '../theme/app_theme.dart';
import '../widgets/user_avatar.dart';
import 'image_crop_screen.dart';

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
  File? _pickedCover;
  bool _saving = false;
  String? _error;

  Future<void> _pickAvatar() async {
    final x = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 1200,
      imageQuality: 88,
    );
    if (x == null || !mounted) return;
    // Crop avatar 1:1.
    final cropped = await Navigator.of(context).push<File>(
      MaterialPageRoute(
        builder: (_) => ImageCropScreen(
          file: File(x.path),
          title: 'Atur foto profil',
          aspects: const [CropAspect.square],
        ),
      ),
    );
    if (cropped != null) setState(() => _pickedAvatar = cropped);
  }

  Future<void> _pickCover() async {
    final x = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      // Cover bisa apa saja ukuran/rasionya — user atur sendiri di cropper.
    );
    if (x == null || !mounted) return;
    final cropped = await Navigator.of(context).push<File>(
      MaterialPageRoute(
        builder: (_) => ImageCropScreen(
          file: File(x.path),
          title: 'Atur foto sampul',
          aspects: const [CropAspect.cover, CropAspect.square],
        ),
      ),
    );
    if (cropped != null) setState(() => _pickedCover = cropped);
  }

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
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
      String? coverUrl;
      if (_pickedCover != null) {
        coverUrl = await DriveService.instance.uploadImage(
          file: _pickedCover!,
          folder: AppConfig.folderCovers,
        );
      }
      await FirestoreService.instance.updateUser(
        widget.user.uid,
        displayName: _name.text.trim(),
        bio: _bio.text.trim(),
        location: _location.text.trim(),
        avatarUrl: avatarUrl,
        coverUrl: coverUrl,
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
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        child: Column(
          children: [
            _coverPicker(),
            const SizedBox(height: 18),
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

  Widget _coverPicker() {
    return GestureDetector(
      onTap: _pickCover,
      child: AspectRatio(
        aspectRatio: 16 / 9,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (_pickedCover != null)
                Image.file(_pickedCover!, fit: BoxFit.cover)
              else if (widget.user.coverUrl.isNotEmpty)
                CachedNetworkImage(
                  imageUrl: widget.user.coverUrl,
                  fit: BoxFit.cover,
                  placeholder: (_, __) =>
                      Container(color: AppColors.softBg),
                  errorWidget: (_, __, ___) =>
                      Container(color: AppColors.softBg),
                )
              else
                Container(
                  decoration:
                      const BoxDecoration(gradient: AppColors.vibrant),
                ),
              Container(color: Colors.black.withOpacity(.15)),
              const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.photo_camera_back,
                        color: Colors.white, size: 28),
                    SizedBox(height: 6),
                    Text('Ubah foto sampul',
                        style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            ],
          ),
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
