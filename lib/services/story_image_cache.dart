import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';

/// Dedicated LRU disk cache for story images.
///
/// Story images are short-lived (24h) and can be numerous, so we keep them in
/// a separate, bounded cache instead of polluting the default image cache.
/// `flutter_cache_manager` evicts the least-recently-used objects once either
/// limit is reached, giving us LRU behaviour out of the box.
class StoryImageCache {
  StoryImageCache._();

  static const String _key = 'ifriends_story_cache';

  /// Keep at most 120 story images for up to 24h each. Whichever cap is hit
  /// first triggers LRU eviction of the oldest-used entries.
  static final CacheManager manager = CacheManager(
    Config(
      _key,
      stalePeriod: const Duration(hours: 24),
      maxNrOfCacheObjects: 120,
    ),
  );

  /// Build an [ImageProvider] for a story image backed by the LRU cache.
  static ImageProvider provider(String url) =>
      CachedNetworkImageProvider(url, cacheManager: manager);
}
