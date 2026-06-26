import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../config/app_config.dart';
import '../models/user_model.dart';
import '../services/drive_service.dart';
import '../services/firestore_service.dart';
import '../theme/app_theme.dart';

class CreatePostScreen extends StatefulWidget {
  final AppUser currentUser;
  const CreatePostScreen({super.key, required this.currentUser});

  @override
  State<CreatePostScreen> createState() => _CreatePostScreenState();
}

class _CreatePostScreenState extends State<CreatePostScreen> {
  final _caption = TextEditingController();
  File? _image;
  bool _posting = false;
  String? _error;

  Future<void> _pick(ImageSource s) async {
    final x = await ImagePicker().pickImage(
      source: s,
      maxWidth: 1600,
      imageQuality: 85,
    );
    if (x != null) setState(() => _image = File(x.path));
  }

  Future<void> _submit() async {
    if (_image == null) return;
    setState(() {
      _posting = true;
      _error = null;
    });
    try {
      final url = await DriveService.instance.uploadImage(
        file: _image!,
        folder: AppConfig.folderPosts,
      );
      await FirestoreService.instance.createPost(
        author: widget.currentUser,
        imageUrl: url,
        caption: _caption.text.trim(),
      );
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _posting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final canPost = _image != null && !_posting;
    return Scaffold(
      backgroundColor: AppColors.bgWhite,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.maybePop(context),
                    child: const Icon(Icons.close, size: 26),
                  ),
                  const Spacer(),
                  ShaderMask(
                    shaderCallback: (b) =>
                        AppColors.vibrant.createShader(b),
                    child: const Text(
                      'New Post',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const Spacer(),
                  Opacity(
                    opacity: canPost ? 1 : .4,
                    child: GestureDetector(
                      onTap: canPost ? _submit : null,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          gradient: AppColors.vibrant,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: _posting
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                    color: Colors.white, strokeWidth: 2),
                              )
                            : const Text('Post',
                                style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600)),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _imageSection(),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          _pickBtn(Icons.photo, 'Gallery',
                              () => _pick(ImageSource.gallery)),
                          const SizedBox(width: 10),
                          _pickBtn(Icons.camera_alt, 'Camera',
                              () => _pick(ImageSource.camera)),
                        ],
                      ),
                      const SizedBox(height: 18),
                      TextField(
                        controller: _caption,
                        maxLines: 4,
                        decoration: InputDecoration(
                          hintText: 'Write a caption...',
                          filled: true,
                          fillColor: AppColors.softBg,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                      if (_error != null) ...[
                        const SizedBox(height: 12),
                        Text(_error!,
                            style: const TextStyle(color: Colors.red)),
                      ],
                      if (_image == null) ...[
                        const SizedBox(height: 12),
                        const Text(
                          'Pilih gambar dulu untuk mengaktifkan tombol Post.',
                          style: TextStyle(
                              color: AppColors.textMuted, fontSize: 12),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _imageSection() {
    return GestureDetector(
      onTap: () => _pick(ImageSource.gallery),
      child: Container(
        height: 280,
        width: double.infinity,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          gradient: _image == null ? AppColors.sunset : null,
          color: _image == null ? null : AppColors.softBg,
        ),
        clipBehavior: Clip.antiAlias,
        child: _image == null
            ? const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.add_photo_alternate,
                        size: 70, color: Colors.white),
                    SizedBox(height: 8),
                    Text('Tap to add a photo',
                        style: TextStyle(color: Colors.white)),
                  ],
                ),
              )
            : Image.file(_image!, fit: BoxFit.cover),
      ),
    );
  }

  Widget _pickBtn(IconData i, String label, VoidCallback onTap) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: AppColors.softBg,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(i, color: AppColors.primaryCoral),
              const SizedBox(width: 8),
              Text(label,
                  style: const TextStyle(fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ),
    );
  }
}
