import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Swipeable image carousel for posts. Renders a single image directly and a
/// [PageView] with page dots + an "x/n" counter when there are multiple.
class PostImageCarousel extends StatefulWidget {
  final List<String> images;
  final double height;
  final double borderRadius;
  final EdgeInsetsGeometry margin;
  final VoidCallback? onTap;
  final BoxFit fit;

  const PostImageCarousel({
    super.key,
    required this.images,
    this.height = 240,
    this.borderRadius = 18,
    this.margin = EdgeInsets.zero,
    this.onTap,
    this.fit = BoxFit.cover,
  });

  @override
  State<PostImageCarousel> createState() => _PostImageCarouselState();
}

class _PostImageCarouselState extends State<PostImageCarousel> {
  final _controller = PageController();
  int _page = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Widget _image(String url) {
    if (url.isEmpty) {
      return Container(
        decoration: const BoxDecoration(gradient: AppColors.sunset),
        alignment: Alignment.center,
        child: const Icon(Icons.image, color: Colors.white, size: 64),
      );
    }
    return CachedNetworkImage(
      imageUrl: url,
      fit: widget.fit,
      width: double.infinity,
      placeholder: (_, __) => Container(
        color: AppColors.softBg,
        alignment: Alignment.center,
        child: const CircularProgressIndicator(strokeWidth: 2),
      ),
      errorWidget: (_, __, ___) => Container(
        decoration: const BoxDecoration(gradient: AppColors.sunset),
        alignment: Alignment.center,
        child: const Icon(Icons.broken_image, color: Colors.white, size: 48),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final imgs = widget.images.isEmpty ? const [''] : widget.images;
    final multi = imgs.length > 1;
    return GestureDetector(
      onTap: widget.onTap,
      child: Container(
        height: widget.height,
        margin: widget.margin,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(widget.borderRadius),
          color: AppColors.softBg,
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
            if (multi)
              PageView.builder(
                controller: _controller,
                itemCount: imgs.length,
                onPageChanged: (i) => setState(() => _page = i),
                itemBuilder: (_, i) => _image(imgs[i]),
              )
            else
              _image(imgs.first),
            if (multi)
              Positioned(
                top: 10,
                right: 10,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(.55),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${_page + 1}/${imgs.length}',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            if (multi)
              Positioned(
                bottom: 10,
                left: 0,
                right: 0,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(imgs.length, (i) {
                    final active = i == _page;
                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      width: active ? 8 : 6,
                      height: active ? 8 : 6,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: active
                            ? Colors.white
                            : Colors.white.withOpacity(.5),
                      ),
                    );
                  }),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
