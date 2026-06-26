import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../config/app_config.dart';
import '../models/user_model.dart';
import '../services/drive_service.dart';
import '../services/firestore_service.dart';
import '../theme/app_theme.dart';
import 'image_crop_screen.dart';

class CreatePostScreen extends StatefulWidget {
  final AppUser currentUser;
  const CreatePostScreen({super.key, required this.currentUser});

  @override
  State<CreatePostScreen> createState() => _CreatePostScreenState();
}

class _CreatePostScreenState extends State<CreatePostScreen> {
  final _caption = TextEditingController();
  final List<File> _images = [];
  bool _posting = false;
  String? _error;

  static const int _maxImages = 10;

  Future<File?> _cropForPost(File f) async {
    if (!mounted) return null;
    return Navigator.of(context).push<File>(
      MaterialPageRoute(
        builder: (_) => ImageCropScreen(
          file: f,
          title: 'Crop foto',
          aspects: const [CropAspect.square, CropAspect.portrait],
        ),
      ),
    );
  }

  Future<void> _pickFromGallery() async {
    final xs = await ImagePicker().pickMultiImage(
      maxWidth: 1600,
      imageQuality: 85,
    );
    if (xs.isEmpty) return;
    for (final x in xs) {
      if (_images.length >= _maxImages) break;
      final cropped = await _cropForPost(File(x.path));
      if (cropped == null) continue; // user cancelled this one
      if (!mounted) return;
      setState(() => _images.add(cropped));
    }
  }

  Future<void> _pickFromCamera() async {
    final x = await ImagePicker().pickImage(
      source: ImageSource.camera,
      maxWidth: 1600,
      imageQuality: 85,
    );
    if (x == null) return;
    if (_images.length >= _maxImages) return;
    final cropped = await _cropForPost(File(x.path));
    if (cropped == null) return;
    if (!mounted) return;
    setState(() => _images.add(cropped));
  }

  void _removeAt(int i) => setState(() => _images.removeAt(i));

  Future<void> _replaceCrop(int i) async {
    final cropped = await _cropForPost(_images[i]);
    if (cropped == null || !mounted) return;
    setState(() => _images[i] = cropped);
  }

  Future<void> _submit() async {
    if (_images.isEmpty) return;
    setState(() {
      _posting = true;
      _error = null;
    });
    try {
      final urls = <String>[];
      for (final f in _images) {
        final url = await DriveService.instance.uploadImage(
          file: f,
          folder: AppConfig.folderPosts,
        );
        urls.add(url);
      }
      await FirestoreService.instance.createPost(
        author: widget.currentUser,
        imageUrls: urls,
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
    final canPost = _images.isNotEmpty && !_posting;
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
                    shaderCallback: (b) => AppColors.vibrant.createShader(b),
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
                          _pickBtn(Icons.photo, 'Gallery', _pickFromGallery),
                          const SizedBox(width: 10),
                          _pickBtn(Icons.camera_alt, 'Camera', _pickFromCamera),
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
                      if (_images.isEmpty) ...[
                        const SizedBox(height: 12),
                        const Text(
                          'Pilih foto, lalu atur crop 1:1 atau 3:4 sebelum Post.',
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
    if (_images.isEmpty) {
      return GestureDetector(
        onTap: _pickFromGallery,
        child: Container(
          height: 280,
          width: double.infinity,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            gradient: AppColors.sunset,
          ),
          clipBehavior: Clip.antiAlias,
          child: const Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.add_photo_alternate, size: 70, color: Colors.white),
                SizedBox(height: 8),
                Text('Tap to add photos',
                    style: TextStyle(color: Colors.white)),
              ],
            ),
          ),
        ),
      );
    }
    return SizedBox(
      height: 280,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _images.length + 1,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (_, i) {
          if (i == _images.length) {
            return GestureDetector(
              onTap: _images.length >= _maxImages ? null : _pickFromGallery,
              child: Container(
                width: 110,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  color: AppColors.softBg,
                ),
                child: Icon(Icons.add,
                    size: 40,
                    color: _images.length >= _maxImages
                        ? AppColors.textMuted
                        : AppColors.primaryCoral),
              ),
            );
          }
          return Stack(
            children: [
              GestureDetector(
                onTap: () => _replaceCrop(i),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(18),
                  child: Image.file(_images[i],
                      width: 220, height: 280, fit: BoxFit.cover),
                ),
              ),
              Positioned(
                top: 8,
                right: 8,
                child: GestureDetector(
                  onTap: () => _removeAt(i),
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(.55),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.close,
                        color: Colors.white, size: 18),
                  ),
                ),
              ),
              Positioned(
                bottom: 8,
                right: 8,
                child: GestureDetector(
                  onTap: () => _replaceCrop(i),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(.55),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.crop, color: Colors.white, size: 14),
                        SizedBox(width: 4),
                        Text('Crop',
                            style: TextStyle(
                                color: Colors.white, fontSize: 11)),
                      ],
                    ),
                  ),
                ),
              ),
              Positioned(
                bottom: 8,
                left: 8,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(.55),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text('${i + 1}/${_images.length}',
                      style: const TextStyle(
                          color: Colors.white, fontSize: 11)),
                ),
              ),
            ],
          );
        },
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
            borderRadius: BorderRadius.circular(16),
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
