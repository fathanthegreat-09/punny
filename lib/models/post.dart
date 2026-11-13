import 'dart:convert';
import 'package:flutter/material.dart';

class Post {
  final String id;
  final String title;
  final String imageUrl;
  final List<String> imageUrls;
  final String? videoUrl;   // data-URI or remote URL for a video post
  final String author;
  final List<String> likes;
  final int likeCount;
  final DateTime? createdAt;
  final String? description;
  final String? category;
  final String? link;
  final List<Map<String, String>> comments;

  Post({
    required this.id,
    required this.title,
    required this.imageUrl,
    List<String>? imageUrls,
    this.videoUrl,
    required this.author,
    required this.likes,
    required this.likeCount,
    this.createdAt,
    this.description,
    this.category,
    this.link,
    List<Map<String, String>>? comments,
  })  : imageUrls = (imageUrls != null && imageUrls.isNotEmpty)
            ? imageUrls
            : [imageUrl],
        comments = comments ??
            [
              {
                'user': 'Yuuka',
                'avatar': 'Y',
                'text': 'This looks absolutely stunning! Love the aesthetic vibe.'
              },
              {
                'user': 'Arona',
                'avatar': 'A',
                'text': 'Saved to my favorite moodboard! ✨'
              },
            ];

  bool get isMultiImage => imageUrls.length > 1;
  bool get isVideoPost => videoUrl != null && videoUrl!.isNotEmpty;

  bool isLikedBy(String username) {
    return likes.contains(username);
  }

  factory Post.fromJson(Map<String, dynamic> json) {
    final rawImages = json['imageUrls'];
    List<String> parsedUrls = [];
    if (rawImages is List) {
      parsedUrls = rawImages.map((e) => e.toString()).toList();
    }
    final primaryUrl = json['imageUrl']?.toString() ??
        (parsedUrls.isNotEmpty ? parsedUrls.first : '');

    if (parsedUrls.isEmpty && primaryUrl.isNotEmpty) {
      parsedUrls = [primaryUrl];
    }

    final rawComments = json['comments'];
    List<Map<String, String>> parsedComments = [];
    if (rawComments is List) {
      parsedComments = rawComments
          .map((c) => Map<String, String>.from(c as Map))
          .toList();
    }
    if (parsedComments.isEmpty) {
      parsedComments = [
        {
          'user': 'Yuuka',
          'avatar': 'Y',
          'text': 'This looks absolutely stunning! Love the aesthetic vibe.'
        },
        {
          'user': 'Arona',
          'avatar': 'A',
          'text': 'Saved to my favorite moodboard! ✨'
        },
      ];
    }

    return Post(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      imageUrl: primaryUrl,
      imageUrls: parsedUrls,
      videoUrl: json['videoUrl']?.toString(),
      author: json['author']?.toString() ?? 'Anonymous',
      likes: (json['likes'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      likeCount: json['likeCount'] is int
          ? json['likeCount']
          : int.tryParse(json['likeCount']?.toString() ?? '0') ?? 0,
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'].toString())
          : null,
      description: json['description']?.toString(),
      category: json['category']?.toString(),
      link: json['link']?.toString(),
      comments: parsedComments,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'imageUrl': imageUrl,
      'imageUrls': imageUrls,
      'videoUrl': videoUrl,
      'author': author,
      'likes': likes,
      'likeCount': likeCount,
      'createdAt': createdAt?.toIso8601String(),
      'description': description,
      'category': category,
      'link': link,
      'comments': comments,
    };
  }

  Post copyWith({
    String? id,
    String? title,
    String? imageUrl,
    List<String>? imageUrls,
    String? videoUrl,
    String? author,
    List<String>? likes,
    int? likeCount,
    DateTime? createdAt,
    String? description,
    String? category,
    String? link,
    List<Map<String, String>>? comments,
  }) {
    return Post(
      id: id ?? this.id,
      title: title ?? this.title,
      imageUrl: imageUrl ?? this.imageUrl,
      imageUrls: imageUrls ?? this.imageUrls,
      videoUrl: videoUrl ?? this.videoUrl,
      author: author ?? this.author,
      likes: likes ?? this.likes,
      likeCount: likeCount ?? this.likeCount,
      createdAt: createdAt ?? this.createdAt,
      description: description ?? this.description,
      category: category ?? this.category,
      link: link ?? this.link,
      comments: comments ?? this.comments,
    );
  }
}

/// Reusable helper to safely render any image format (network, base64 data URI, asset)
Widget buildSafeImage(
  String url, {
  BoxFit fit = BoxFit.cover,
  double? width,
  double? height,
  Widget Function(BuildContext, Object, StackTrace?)? errorBuilder,
}) {
  if (url.startsWith('data:image')) {
    try {
      final base64String = url.contains(',') ? url.split(',').last : url;
      final bytes = base64Decode(base64String);
      return Image.memory(
        bytes,
        fit: fit,
        width: width,
        height: height,
        errorBuilder: errorBuilder ??
            (context, error, stackTrace) => Container(
                  width: width,
                  height: height,
                  color: const Color(0xFFE2E8F0),
                  child: const Center(
                    child: Icon(Icons.broken_image_rounded, color: Colors.grey, size: 36),
                  ),
                ),
      );
    } catch (_) {}
  }

  if (url.startsWith('http://') || url.startsWith('https://')) {
    return Image.network(
      url,
      fit: fit,
      width: width,
      height: height,
      loadingBuilder: (context, child, loadingProgress) {
        if (loadingProgress == null) return child;
        return Container(
          width: width,
          height: height,
          color: const Color(0xFFF1F5F9),
          child: const Center(
            child: SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Color(0xFF6366F1),
              ),
            ),
          ),
        );
      },
      errorBuilder: errorBuilder ??
          (context, error, stackTrace) => Container(
                width: width,
                height: height,
                color: const Color(0xFFE2E8F0),
                child: const Center(
                  child: Icon(Icons.broken_image_rounded, color: Colors.grey, size: 36),
                ),
              ),
    );
  }

  return Image.asset(
    url,
    fit: fit,
    width: width,
    height: height,
    errorBuilder: errorBuilder ??
        (context, error, stackTrace) => Container(
              width: width,
              height: height,
              color: const Color(0xFFE2E8F0),
              child: const Center(
                child: Icon(Icons.broken_image_rounded, color: Colors.grey, size: 36),
              ),
            ),
  );
}
