import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../config/app_config.dart';
import '../models/user_model.dart';
import '../services/drive_service.dart';
import '../services/firestore_service.dart';
import '../theme/app_theme.dart';

class StoryCreateScreen extends StatefulWidget {
  final AppUser currentUser;
  const StoryCreateScreen({super.key, required this.currentUser});

  @override
  State<StoryCreateScreen> createState() => _StoryCreateScreenState();
}

class _StoryCreateScreenState extends State<StoryCreateScreen> {
  final _caption = TextEditingController();
  File? _image;
  bool _posting = false;
  String _stage = '';
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _image == null) _pick(ImageSource.gallery);
    });
  }

  Future<void> _pick(ImageSource s) async {
    try {
      final x = await ImagePicker().pickImage(
        source: s,
        maxWidth: 1600,
        imageQuality: 85,
      );
      if (x != null && mounted) setState(() => _image = File(x.path));
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
  }

  Future<void> _submit() async {
    if (_image == null || _posting) return;
    setState(() {
      _posting = true;
      _error = null;
      _stage = 'Uploading image…';
    });
    try {
      final url = await DriveService.instance.uploadImage(
        file: _image!,
        folder: AppConfig.folderStories,
      );
      if (!mounted) return;
      setState(() => _stage = 'Publishing story…');
      await FirestoreService.instance.createStory(
        authorId: widget.currentUser.uid,
        imageUrl: url,
        caption: _caption.text.trim(),
      );
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _stage = '';
        });
      }
    } finally {
      if (mounted) setState(() => _posting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final canPost = _image != null && !_posting;
    return WillPopScope(
      onWillPop: () async => !_posting,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          children: [
            SafeArea(
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                    child: Row(
                      children: [
                        IconButton(
                          onPressed: _posting
                              ? null
                              : () => Navigator.maybePop(context),
                          icon: const Icon(Icons.close, color: Colors.white),
                        ),
                        const Spacer(),
                        const Text(
                          'New Story',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
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
                              child: const Text(
                                'Post Story',
                                style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Center(
                      child: _image == null
                          ? _picker()
                          : Padding(
                              padding: const EdgeInsets.all(12),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(22),
                                child: Image.file(_image!, fit: BoxFit.cover),
                              ),
                            ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: _pickBtn(Icons.photo, 'Gallery',
                                  () => _pick(ImageSource.gallery)),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _pickBtn(Icons.camera_alt, 'Camera',
                                  () => _pick(ImageSource.camera)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        TextField(
                          controller: _caption,
                          maxLength: 100,
                          enabled: !_posting,
                          style: const TextStyle(color: Colors.white),
                          cursorColor: AppColors.primaryCoral,
                          decoration: InputDecoration(
                            counterStyle:
                                const TextStyle(color: Colors.white54),
                            hintText: 'Add a caption (optional)',
                            hintStyle: const TextStyle(color: Colors.white54),
                            filled: true,
                            fillColor: Colors.white.withOpacity(.08),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide.none,
                            ),
                          ),
                        ),
                        if (_error != null) ...[
                          const SizedBox(height: 8),
                          Text(_error!,
                              style:
                                  const TextStyle(color: Colors.redAccent)),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
            if (_posting) _uploadingOverlay(),
          ],
        ),
      ),
    );
  }

  Widget _uploadingOverlay() {
    return Positioned.fill(
      child: AbsorbPointer(
        child: Container(
          color: Colors.black.withOpacity(.65),
          alignment: Alignment.center,
          child: Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 28, vertical: 26),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(.08),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white24),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 56,
                  height: 56,
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: AppColors.vibrant,
                  ),
                  child: const CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 3,
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  _stage.isEmpty ? 'Posting story…' : _stage,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _picker() {
    return GestureDetector(
      onTap: () => _pick(ImageSource.gallery),
      child: Container(
        margin: const EdgeInsets.all(24),
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          gradient: AppColors.sunset,
          borderRadius: BorderRadius.circular(22),
        ),
        child: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.add_photo_alternate,
                size: 70, color: Colors.white),
            SizedBox(height: 8),
            Text('Tap to pick a photo for your story',
                style: TextStyle(color: Colors.white)),
          ],
        ),
      ),
    );
  }

  Widget _pickBtn(IconData i, String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: _posting ? null : onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(.08),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(i, color: Colors.white),
            const SizedBox(width: 8),
            Text(label,
                style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}
