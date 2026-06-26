import 'package:flutter/material.dart';

import '../services/firestore_service.dart';
import '../theme/app_theme.dart';

/// Edit an existing post's caption. Hashtags are re-parsed on save by the
/// service. Image editing is intentionally not offered (keeps uploads simple).
class EditPostScreen extends StatefulWidget {
  final String postId;
  final String initialCaption;
  const EditPostScreen({
    super.key,
    required this.postId,
    required this.initialCaption,
  });

  @override
  State<EditPostScreen> createState() => _EditPostScreenState();
}

class _EditPostScreenState extends State<EditPostScreen> {
  late final TextEditingController _caption =
      TextEditingController(text: widget.initialCaption);
  bool _saving = false;
  String? _error;

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await FirestoreService.instance.updatePost(
        postId: widget.postId,
        caption: _caption.text.trim(),
      );
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  void dispose() {
    _caption.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgWhite,
      appBar: AppBar(
        title: const Text('Edit Post'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: AppColors.textDark,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _caption,
              maxLines: 5,
              autofocus: true,
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
              Text(_error!, style: const TextStyle(color: Colors.red)),
            ],
            const SizedBox(height: 20),
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
}
