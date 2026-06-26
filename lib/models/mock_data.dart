import 'package:flutter/material.dart';

class StoryItem {
  final String name;
  final IconData icon;
  final Color color;
  const StoryItem(this.name, this.icon, this.color);
}

class FeedPost {
  final String username;
  final String handle;
  final String avatarSeed;
  final String imageSeed;
  final String caption;
  final int likes;
  final int comments;
  final String time;
  final IconData categoryIcon;
  final Color categoryColor;
  const FeedPost({
    required this.username,
    required this.handle,
    required this.avatarSeed,
    required this.imageSeed,
    required this.caption,
    required this.likes,
    required this.comments,
    required this.time,
    required this.categoryIcon,
    required this.categoryColor,
  });
}

class Friend {
  final String name;
  final String seed;
  const Friend(this.name, this.seed);
}

class MockData {
  static const List<StoryItem> stories = [
    StoryItem('Shop', Icons.storefront, Color(0xFFFFB347)),
    StoryItem('Plants', Icons.local_florist, Color(0xFF10B981)),
    StoryItem('Coffee', Icons.local_cafe, Color(0xFFB5651D)),
    StoryItem('Lina', Icons.person, Color(0xFFFF2D75)),
    StoryItem('Travel', Icons.flight_takeoff, Color(0xFF3B82F6)),
    StoryItem('Food', Icons.restaurant, Color(0xFFF97316)),
  ];

  static const List<FeedPost> posts = [
    FeedPost(
      username: 'Aulia Putri',
      handle: '@aulia.flora',
      avatarSeed: 'aulia',
      imageSeed: 'florist',
      caption: 'New blooms just arrived at the shop 🌸 swing by today!',
      likes: 1284,
      comments: 92,
      time: '2h',
      categoryIcon: Icons.shopping_bag,
      categoryColor: Color(0xFFFF2D75),
    ),
    FeedPost(
      username: 'Reza Saputra',
      handle: '@rezacoffee',
      avatarSeed: 'reza',
      imageSeed: 'drink',
      caption: 'Iced citrus brew — summer in a cup ☀️🍊',
      likes: 842,
      comments: 41,
      time: '4h',
      categoryIcon: Icons.local_cafe,
      categoryColor: Color(0xFFFF8A3D),
    ),
    FeedPost(
      username: 'Maya Anggrek',
      handle: '@mayagram',
      avatarSeed: 'maya',
      imageSeed: 'plants',
      caption: 'Plant therapy 🌿 my little jungle is thriving.',
      likes: 2103,
      comments: 156,
      time: '6h',
      categoryIcon: Icons.eco,
      categoryColor: Color(0xFF10B981),
    ),
    FeedPost(
      username: 'Dimas Pratama',
      handle: '@dimas.eats',
      avatarSeed: 'dimas',
      imageSeed: 'food',
      caption: 'Comfort food kind of evening 🍜',
      likes: 567,
      comments: 28,
      time: '9h',
      categoryIcon: Icons.restaurant,
      categoryColor: Color(0xFFF97316),
    ),
  ];

  static const List<Friend> closeFriends = [
    Friend('Andi', 'andi'),
    Friend('Sari', 'sari'),
    Friend('Budi', 'budi'),
    Friend('Tika', 'tika'),
    Friend('Joko', 'joko'),
    Friend('Rina', 'rina'),
  ];

  static const List<String> gallerySeeds = [
    'neon', 'beauty', 'meal', 'plant',
    'beach', 'cafe', 'flower', 'street',
    'sunset', 'dog', 'art', 'book',
  ];

  static const profileStats = {
    'posts': '248',
    'followers': '12.4k',
    'following': '389',
  };
}
