import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import '../models/post.dart';
import 'storage_service.dart';

class ApiService {
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;

  // Storage keys for persistent state across browser reloads
  static const String _storageKeyCustomPosts = 'punny_custom_posts';
  static const String _storageKeySavedIds = 'punny_saved_ids';
  static const String _storageKeyFollowing = 'punny_following';
  static const String _storageKeyLikedIds = 'punny_liked_ids';
  static const String _storageKeyCurrentUser = 'punny_current_user';

  static final Set<String> _defaultPostIds = {
    'pin-user-1',
    ...List.generate(45, (i) => 'pin-${i + 1}'),
  };

  // Current logged in user (with automatic persistence)
  String _currentUser = 'Fathan';
  String get currentUser => _currentUser;
  set currentUser(String val) {
    _currentUser = val;
    try {
      AppStorage.set(_storageKeyCurrentUser, val);
    } catch (_) {}
    notifyChanges();
  }

  // Global change notifier for reactive UI updates
  final ValueNotifier<int> changeNotifier = ValueNotifier<int>(0);

  void notifyChanges() {
    changeNotifier.value++;
  }

  // Followed authors/users (seeded with popular creators)
  final Set<String> _following = {'Sensei', 'Yuuka'};

  // Saved/Bookmarked post IDs
  final Set<String> _savedPostIds = {'pin-1', 'pin-7'};

  // In-memory master posts list
  late final List<Post> _allPosts;

  ApiService._internal() {
    _initDefaultPosts();
    _loadFromStorage();
  }

  void _initDefaultPosts() {
    _allPosts = [
      Post(
        id: 'pin-user-1',
        imageUrl: 'assets/images/file11.jpg',
        title: 'Blue Archive Vibes & Aesthetic',
        author: 'Fathan',
        likes: ['Sensei', 'Yuuka', 'Arona'],
        likeCount: 3,
        createdAt: DateTime.now().subtract(const Duration(days: 2)),
      ),
      Post(
        id: 'pin-1',
        imageUrl: 'assets/images/file.jpg',
        title: 'Shirasu Azusa',
        author: 'Sensei',
        likes: ['Fathan'],
        likeCount: 16,
      ),
      Post(
        id: 'pin-2',
        imageUrl: 'assets/images/file2.jpg',
        title: 'Igusa Haruka',
        author: 'Sensei',
        likes: [],
        likeCount: 8,
      ),
      Post(
        id: 'pin-3',
        imageUrl: 'assets/images/file3.jpg',
        title: 'Yutori Natsu',
        author: 'Sensei',
        likes: [],
        likeCount: 12,
      ),
      Post(
        id: 'pin-4',
        imageUrl: 'assets/images/file4.jpg',
        title: 'Kyoukama Kazusa',
        author: 'Sensei',
        likes: [],
        likeCount: 22,
      ),
      Post(
        id: 'pin-5',
        imageUrl: 'assets/images/file5.jpg',
        title: 'Mob-chan~',
        author: 'Sensei',
        likes: [],
        likeCount: 19,
      ),
      Post(
        id: 'pin-6',
        imageUrl: 'assets/images/file6.jpg',
        title: 'Serina and Hanae',
        author: 'Arona',
        likes: [],
        likeCount: 14,
      ),
      Post(
        id: 'pin-7',
        imageUrl: 'assets/images/file7.jpg',
        title: 'Cheerleader kei',
        author: 'Kei',
        likes: ['Fathan'],
        likeCount: 29,
      ),
      Post(
        id: 'pin-8',
        imageUrl: 'assets/images/file8.jpg',
        title: 'cheerleader arona and plana',
        author: 'Arona',
        likes: [],
        likeCount: 35,
      ),
      Post(
        id: 'pin-9',
        imageUrl: 'assets/images/file9.jpg',
        title: 'Tyrant',
        author: 'Yuuka',
        likes: ['Fathan'],
        likeCount: 42,
      ),
      Post(
        id: 'pin-10',
        imageUrl: 'assets/images/file10.jpg',
        title: 'Hanae',
        author: 'Hanae',
        likes: [],
        likeCount: 9,
      ),
      Post(
        id: 'pin-11',
        imageUrl: 'assets/images/file11.jpg',
        title: 'Laffey',
        author: 'Laffey',
        likes: [],
        likeCount: 18,
      ),
      Post(
        id: 'pin-12',
        imageUrl: 'assets/images/file12.jpg',
        title: 'Miyu Maid',
        author: 'Miyu',
        likes: [],
        likeCount: 27,
      ),
      Post(
        id: 'pin-13',
        imageUrl: 'assets/images/file13.jpg',
        title: 'Miyu',
        author: 'Miyu',
        likes: [],
        likeCount: 15,
      ),
      Post(
        id: 'pin-14',
        imageUrl: 'assets/images/file14.jpg',
        title: 'cheerleader kokona',
        author: 'Kokona',
        likes: [],
        likeCount: 11,
      ),
      Post(
        id: 'pin-15',
        imageUrl: 'assets/images/file15.jpg',
        title: 'cheerleader yuuka',
        author: 'Yuuka',
        likes: [],
        likeCount: 38,
      ),
      Post(
        id: 'pin-16',
        imageUrl: 'assets/images/file16.jpg',
        title: 'cheerleader noa',
        author: 'Noa',
        likes: [],
        likeCount: 24,
      ),
      Post(
        id: 'pin-17',
        imageUrl: 'assets/images/file17.jpg',
        title: 'shirao eri',
        author: 'Eri',
        likes: [],
        likeCount: 7,
      ),
      Post(
        id: 'pin-18',
        imageUrl: 'assets/images/file18.jpg',
        title: 'eri eri',
        author: 'Eri',
        likes: [],
        likeCount: 13,
      ),
      Post(
        id: 'pin-19',
        imageUrl: 'assets/images/file19.jpg',
        title: 'hasumi',
        author: 'Hasumi',
        likes: [],
        likeCount: 20,
      ),
      Post(
        id: 'pin-20',
        imageUrl: 'assets/images/file20.jpg',
        title: 'nanagami rin',
        author: 'Rin',
        likes: [],
        likeCount: 17,
      ),
      Post(
        id: 'pin-21',
        imageUrl: 'assets/images/file21.jpg',
        title: 'tyrant stella sora',
        author: 'Sora',
        likes: [],
        likeCount: 14,
      ),
      Post(
        id: 'pin-22',
        imageUrl: 'assets/images/file22.jpg',
        title: 'akane',
        author: 'Akane',
        likes: [],
        likeCount: 16,
      ),
      Post(
        id: 'pin-23',
        imageUrl: 'assets/images/file23.jpg',
        title: 'miyu',
        author: 'Miyu',
        likes: [],
        likeCount: 31,
      ),
      Post(
        id: 'pin-24',
        imageUrl: 'assets/images/file24.jpg',
        title: 'sorasaki hina',
        author: 'Hina',
        likes: [],
        likeCount: 45,
      ),
      Post(
        id: 'pin-25',
        imageUrl: 'assets/images/file25.jpg',
        title: 'aris maid',
        author: 'Aris',
        likes: [],
        likeCount: 33,
      ),
      Post(
        id: 'pin-26',
        imageUrl: 'assets/images/file26.jpg',
        title: 'aris battle suit',
        author: 'Aris',
        likes: [],
        likeCount: 28,
      ),
      Post(
        id: 'pin-27',
        imageUrl: 'assets/images/file27.jpg',
        title: 'kei swimsuit',
        author: 'Kei',
        likes: [],
        likeCount: 39,
      ),
      Post(
        id: 'pin-28',
        imageUrl: 'assets/images/file28.jpg',
        title: 'misuzu',
        author: 'Misuzu',
        likes: [],
        likeCount: 10,
      ),
      Post(
        id: 'pin-29',
        imageUrl: 'assets/images/file29.jpg',
        title: 'tsubasa',
        author: 'Tsubasa',
        likes: [],
        likeCount: 8,
      ),
      Post(
        id: 'pin-30',
        imageUrl: 'assets/images/file30.jpg',
        title: 'eri',
        author: 'Eri',
        likes: [],
        likeCount: 12,
      ),
      Post(
        id: 'pin-31',
        imageUrl: 'assets/images/file31.jpg',
        title: 'eri',
        author: 'Eri',
        likes: [],
        likeCount: 15,
      ),
      Post(
        id: 'pin-32',
        imageUrl: 'assets/images/file32.jpg',
        title: 'aru',
        author: 'Aru',
        likes: [],
        likeCount: 26,
      ),
      Post(
        id: 'pin-33',
        imageUrl: 'assets/images/file33.jpg',
        title: 'rio maid',
        author: 'Rio',
        likes: [],
        likeCount: 52,
      ),
      Post(
        id: 'pin-34',
        imageUrl: 'assets/images/file34.jpg',
        title: 'rio dress',
        author: 'Rio',
        likes: [],
        likeCount: 48,
      ),
      Post(
        id: 'pin-35',
        imageUrl: 'assets/images/file35.jpg',
        title: 'rio dress',
        author: 'Rio',
        likes: [],
        likeCount: 37,
      ),
      Post(
        id: 'pin-36',
        imageUrl: 'assets/images/file36.jpg',
        title: 'shiroko terror casual',
        author: 'Shiroko',
        likes: [],
        likeCount: 54,
      ),
      Post(
        id: 'pin-37',
        imageUrl: 'assets/images/file37.jpg',
        title: 'asuna',
        author: 'Asuna',
        likes: [],
        likeCount: 29,
      ),
      Post(
        id: 'pin-38',
        imageUrl: 'assets/images/file38.jpg',
        title: 'rio',
        author: 'Rio',
        likes: [],
        likeCount: 23,
      ),
      Post(
        id: 'pin-39',
        imageUrl: 'assets/images/file39.jpg',
        title: 'chinatsu',
        author: 'Chinatsu',
        likes: [],
        likeCount: 17,
      ),
      Post(
        id: 'pin-40',
        imageUrl: 'assets/images/file40.jpg',
        title: 'mika',
        author: 'Mika',
        likes: [],
        likeCount: 65,
      ),
      Post(
        id: 'pin-41',
        imageUrl: 'assets/images/file41.jpg',
        title: 'mine idol',
        author: 'Mine',
        likes: [],
        likeCount: 19,
      ),
      Post(
        id: 'pin-42',
        imageUrl: 'assets/images/file42.jpg',
        title: 'rio',
        author: 'Rio',
        likes: [],
        likeCount: 30,
      ),
      Post(
        id: 'pin-43',
        imageUrl: 'assets/images/file43.jpg',
        title: 'rio',
        author: 'Rio',
        likes: [],
        likeCount: 21,
      ),
      Post(
        id: 'pin-44',
        imageUrl: 'assets/images/file44.jpg',
        title: 'aru',
        author: 'Aru',
        likes: [],
        likeCount: 34,
      ),
      Post(
        id: 'pin-45',
        imageUrl: 'assets/images/file45.jpg',
        title: 'chitose',
        author: 'Chitose',
        likes: [],
        likeCount: 18,
      ),
    ];
  }

  void _mergeBackendPosts(List<Post> backendPosts) {
    for (final post in backendPosts) {
      final idx = _allPosts.indexWhere((p) => p.id == post.id);
      if (idx != -1) {
        _allPosts[idx] = post;
      } else {
        _allPosts.insert(0, post);
      }
    }
    _persistCustomPosts();
    notifyChanges();
  }

  // Base URL calculation based on platform
  String get baseUrl {
    if (kIsWeb) {
      return 'http://localhost:5000';
    } else if (defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:5000';
    } else {
      return 'http://localhost:5000';
    }
  }

  // 1. Fetch all posts with optional filtering
  Future<List<Post>> fetchPosts({String? author, String? search}) async {
    final queryParams = <String, String>{};
    if (author != null && author.isNotEmpty) queryParams['author'] = author;
    if (search != null && search.isNotEmpty) queryParams['search'] = search;

    final uri = Uri.parse('$baseUrl/api/posts').replace(queryParameters: queryParams);

    try {
      final response = await http.get(uri).timeout(const Duration(seconds: 4));
      if (response.statusCode == 200) {
        final decoded = json.decode(response.body);
        if (decoded['success'] == true && decoded['data'] is List) {
          final backendPosts = (decoded['data'] as List)
              .map((item) => Post.fromJson(item as Map<String, dynamic>))
              .toList();
          _mergeBackendPosts(backendPosts);
        }
      }
    } catch (e) {
      debugPrint('Backend fetch info (local store active): $e');
    }

    return getFilteredPosts(author: author, search: search);
  }

  List<Post> getFilteredPosts({String? author, String? search}) {
    List<Post> results = List<Post>.from(_allPosts);

    if (author != null && author.isNotEmpty) {
      results = results.where((p) => p.author.toLowerCase() == author.toLowerCase()).toList();
    }

    if (search != null && search.isNotEmpty) {
      final query = search.toLowerCase();
      results = results.where((p) {
        return p.title.toLowerCase().contains(query) ||
            p.author.toLowerCase().contains(query);
      }).toList();
    }

    return results;
  }

  // 2. Fetch single post by ID
  Future<Post> fetchPostById(String id) async {
    try {
      final uri = Uri.parse('$baseUrl/api/posts/$id');
      final response = await http.get(uri).timeout(const Duration(seconds: 4));

      if (response.statusCode == 200) {
        final decoded = json.decode(response.body);
        final post = Post.fromJson(decoded['data']);
        updatePostInCache(post);
        return post;
      }
    } catch (_) {}

    final found = _allPosts.firstWhere(
      (p) => p.id == id,
      orElse: () => throw Exception('Post not found'),
    );
    return found;
  }

  // 3. Create a new post (Supports File Upload, Multiple Files, Image URLs, Video)
  Future<Post> createPost({
    required String title,
    required String author,
    XFile? imageFile,
    String? imageUrl,
    List<XFile>? imageFiles,
    List<String>? imageUrls,
    String? videoUrl,
    String? description,
    String? category,
    String? link,
  }) async {
    Post? createdPost;

    // Build the collection of image URLs (supporting base64 data URIs for offline local storage)
    final List<String> allResolvedUrls = [];

    if (imageFiles != null && imageFiles.isNotEmpty) {
      for (final f in imageFiles) {
        try {
          final bytes = await f.readAsBytes();
          allResolvedUrls.add('data:image/jpeg;base64,${base64Encode(bytes)}');
        } catch (_) {}
      }
    }

    if (imageUrls != null && imageUrls.isNotEmpty) {
      allResolvedUrls.addAll(imageUrls.where((u) => u.trim().isNotEmpty));
    }

    if (imageFile != null && allResolvedUrls.isEmpty) {
      try {
        final bytes = await imageFile.readAsBytes();
        allResolvedUrls.add('data:image/jpeg;base64,${base64Encode(bytes)}');
      } catch (_) {}
    }

    if (imageUrl != null && imageUrl.trim().isNotEmpty && allResolvedUrls.isEmpty) {
      allResolvedUrls.add(imageUrl.trim());
    }

    // For video posts, don't use asset image placeholder as primaryUrl if videoUrl exists
    final isVideoPost = videoUrl != null && videoUrl.isNotEmpty;
    final primaryUrl = allResolvedUrls.isNotEmpty
        ? allResolvedUrls.first
        : (isVideoPost ? '' : 'assets/images/file.jpg');

    try {
      final uri = Uri.parse('$baseUrl/api/posts');

      // Send to backend via JSON payload (handles multiple images, base64, videoUrl, etc.)
      final payload = {
        'title': title,
        'author': author,
        'imageUrl': primaryUrl,
        'imageUrls': allResolvedUrls,
        'videoUrl': videoUrl,
        'description': description,
        'category': category,
        'link': link,
      };

      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: json.encode(payload),
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 201 || response.statusCode == 200) {
        final decoded = json.decode(response.body);
        if (decoded['data'] != null) {
          createdPost = Post.fromJson(decoded['data']);
        }
      }
    } catch (e) {
      debugPrint('Backend createPost info: $e');
    }

    if (createdPost == null) {
      final newId = 'pin-${DateTime.now().millisecondsSinceEpoch}';
      createdPost = Post(
        id: newId,
        title: title,
        imageUrl: primaryUrl,
        imageUrls: allResolvedUrls.isNotEmpty ? allResolvedUrls : [primaryUrl],
        videoUrl: videoUrl,
        author: author,
        likes: [],
        likeCount: 0,
        createdAt: DateTime.now(),
        description: description,
        category: category,
        link: link,
      );
    } else if (allResolvedUrls.length > 1) {
      createdPost = createdPost.copyWith(imageUrls: allResolvedUrls);
    } else if (isVideoPost) {
      createdPost = createdPost.copyWith(videoUrl: videoUrl);
    }

    addPostToCache(createdPost);
    return createdPost;
  }

  Future<List<Post>> createMultiplePosts({
    required String title,
    required String author,
    required List<String> allImageUrls,
    String? description,
    String? category,
    String? link,
    bool asIndividualPins = false,
  }) async {
    if (asIndividualPins && allImageUrls.length > 1) {
      final List<Post> posts = [];
      for (int i = 0; i < allImageUrls.length; i++) {
        final subTitle = '$title (Photo ${i + 1}/${allImageUrls.length})';
        final p = await createPost(
          title: subTitle,
          author: author,
          imageUrl: allImageUrls[i],
          imageUrls: [allImageUrls[i]],
          description: description,
          category: category,
          link: link,
        );
        posts.add(p);
      }
      return posts;
    } else {
      final p = await createPost(
        title: title,
        author: author,
        imageUrl: allImageUrls.isNotEmpty ? allImageUrls.first : 'assets/images/file.jpg',
        imageUrls: allImageUrls,
        description: description,
        category: category,
        link: link,
      );
      return [p];
    }
  }

  // 4. Update post (CRUD: Edit)
  Future<Post> updatePost({
    required String id,
    required String title,
    String? author,
    XFile? imageFile,
    String? imageUrl,
  }) async {
    Post? updatedPost;

    try {
      final uri = Uri.parse('$baseUrl/api/posts/$id');

      if (imageFile != null) {
        final request = http.MultipartRequest('PUT', uri);
        request.fields['title'] = title;
        if (author != null) request.fields['author'] = author;

        final fileBytes = await imageFile.readAsBytes();
        final multipartFile = http.MultipartFile.fromBytes(
          'image',
          fileBytes,
          filename: imageFile.name.isNotEmpty ? imageFile.name : 'upload.jpg',
        );
        request.files.add(multipartFile);

        final streamedResponse = await request.send().timeout(const Duration(seconds: 8));
        final response = await http.Response.fromStream(streamedResponse);

        if (response.statusCode == 200) {
          final decoded = json.decode(response.body);
          updatedPost = Post.fromJson(decoded['data']);
        }
      } else {
        final body = <String, dynamic>{'title': title};
        if (author != null) body['author'] = author;
        if (imageUrl != null && imageUrl.isNotEmpty) body['imageUrl'] = imageUrl;

        final response = await http.put(
          uri,
          headers: {'Content-Type': 'application/json'},
          body: json.encode(body),
        ).timeout(const Duration(seconds: 6));

        if (response.statusCode == 200) {
          final decoded = json.decode(response.body);
          updatedPost = Post.fromJson(decoded['data']);
        }
      }
    } catch (e) {
      debugPrint('Backend updatePost info: $e');
    }

    if (updatedPost == null) {
      final idx = _allPosts.indexWhere((p) => p.id == id);
      if (idx != -1) {
        final existing = _allPosts[idx];
        updatedPost = existing.copyWith(
          title: title,
          author: author ?? existing.author,
          imageUrl: (imageUrl != null && imageUrl.isNotEmpty) ? imageUrl : existing.imageUrl,
        );
      } else {
        throw Exception('Post not found');
      }
    }

    updatePostInCache(updatedPost);
    return updatedPost;
  }

  // 5. Delete post (CRUD: Delete)
  Future<bool> deletePost(String id) async {
    try {
      final uri = Uri.parse('$baseUrl/api/posts/$id');
      await http.delete(uri).timeout(const Duration(seconds: 4));
    } catch (e) {
      debugPrint('Backend deletePost info: $e');
    }

    deletePostFromCache(id);
    return true;
  }

  // 6. Toggle Like
  Future<Map<String, dynamic>> toggleLike(String id, String username) async {
    toggleLocalLike(id, username);

    try {
      final uri = Uri.parse('$baseUrl/api/posts/$id/like');
      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'user': username}),
      ).timeout(const Duration(seconds: 4));

      if (response.statusCode == 200) {
        final decoded = json.decode(response.body);
        return {
          'isLiked': decoded['data']['isLiked'] as bool,
          'likeCount': decoded['data']['likeCount'] as int,
        };
      }
    } catch (e) {
      debugPrint('Backend toggleLike info: $e');
    }

    final post = _allPosts.firstWhere((p) => p.id == id);
    return {
      'isLiked': post.isLikedBy(username),
      'likeCount': post.likeCount,
    };
  }

  // --- PERSISTENCE & LOCAL STORAGE ---

  void _loadFromStorage() {
    try {
      // 1. Restore Current User
      final savedUser = AppStorage.get(_storageKeyCurrentUser);
      if (savedUser != null && savedUser.trim().isNotEmpty) {
        _currentUser = savedUser.trim();
      }

      // 2. Restore Saved Post IDs
      final rawSaved = AppStorage.get(_storageKeySavedIds);
      if (rawSaved != null && rawSaved.isNotEmpty) {
        final List<dynamic> decoded = json.decode(rawSaved);
        _savedPostIds.clear();
        _savedPostIds.addAll(decoded.map((e) => e.toString()));
      }

      // 3. Restore Following List
      final rawFollowing = AppStorage.get(_storageKeyFollowing);
      if (rawFollowing != null && rawFollowing.isNotEmpty) {
        final List<dynamic> decoded = json.decode(rawFollowing);
        _following.clear();
        _following.addAll(decoded.map((e) => e.toString()));
      }

      // 4. Restore Custom & Multi-image Posts
      final rawPosts = AppStorage.get(_storageKeyCustomPosts);
      if (rawPosts != null && rawPosts.isNotEmpty) {
        final List<dynamic> decoded = json.decode(rawPosts);
        for (final item in decoded) {
          try {
            final p = Post.fromJson(Map<String, dynamic>.from(item as Map));
            // Don't overwrite if backend has valid imageUrl while local storage has empty
            final existingIdx = _allPosts.indexWhere((existing) => existing.id == p.id);
            if (existingIdx != -1) {
              if (p.imageUrl.isNotEmpty || _allPosts[existingIdx].imageUrl.isEmpty) {
                _allPosts[existingIdx] = p;
              }
            } else {
              _allPosts.insert(0, p);
            }
          } catch (e) {
            debugPrint('Error restoring stored post: $e');
          }
        }
      }

      // 5. Restore Liked Posts
      final rawLiked = AppStorage.get(_storageKeyLikedIds);
      if (rawLiked != null && rawLiked.isNotEmpty) {
        final List<dynamic> decoded = json.decode(rawLiked);
        final likedSet = decoded.map((e) => e.toString()).toSet();
        for (int i = 0; i < _allPosts.length; i++) {
          final p = _allPosts[i];
          final isLiked = p.likes.contains(_currentUser);
          final shouldBeLiked = likedSet.contains(p.id);
          if (shouldBeLiked && !isLiked) {
            final updatedLikes = List<String>.from(p.likes)..add(_currentUser);
            _allPosts[i] = p.copyWith(
              likes: updatedLikes,
              likeCount: updatedLikes.length,
            );
          } else if (!shouldBeLiked && isLiked) {
            final updatedLikes = List<String>.from(p.likes)..remove(_currentUser);
            _allPosts[i] = p.copyWith(
              likes: updatedLikes,
              likeCount: updatedLikes.length,
            );
          }
        }
      }
    } catch (e) {
      debugPrint('Error loading Punny storage: $e');
    }
  }

  void _persistCustomPosts() {
    try {
      final postsToSave = _allPosts.where((p) {
        final isDefault = _defaultPostIds.contains(p.id);
        if (!isDefault) return true;
        // Also persist if a default post was edited or got new comments
        if (p.comments.length != 2) return true;
        return false;
      }).map((p) {
        final jsonMap = p.toJson();
        // If videoUrl is a huge data URI, don't save the full base64 in localStorage to avoid 5MB quota crash
        final vid = jsonMap['videoUrl']?.toString();
        if (vid != null && vid.startsWith('data:') && vid.length > 50000) {
          jsonMap['videoUrl'] = '';
        }
        return jsonMap;
      }).toList();

      AppStorage.set(_storageKeyCustomPosts, json.encode(postsToSave));
    } catch (e) {
      debugPrint('Error persisting custom posts: $e');
    }
  }

  void _persistSavedIds() {
    try {
      AppStorage.set(_storageKeySavedIds, json.encode(_savedPostIds.toList()));
    } catch (e) {
      debugPrint('Error persisting saved IDs: $e');
    }
  }

  void _persistFollowing() {
    try {
      AppStorage.set(_storageKeyFollowing, json.encode(_following.toList()));
    } catch (e) {
      debugPrint('Error persisting following: $e');
    }
  }

  void _persistLikes() {
    try {
      final likedIds = _allPosts
          .where((p) => p.isLikedBy(_currentUser))
          .map((p) => p.id)
          .toList();
      AppStorage.set(_storageKeyLikedIds, json.encode(likedIds));
    } catch (e) {
      debugPrint('Error persisting likes: $e');
    }
  }

  // --- LOCAL REPOSITORY & STATE MANAGEMENT ---

  List<Post> getAllPosts() {
    return List<Post>.unmodifiable(_allPosts);
  }

  void addPostToCache(Post post) {
    _allPosts.removeWhere((p) => p.id == post.id);
    _allPosts.insert(0, post);
    _persistCustomPosts();
    notifyChanges();
  }

  void updatePostInCache(Post post) {
    final idx = _allPosts.indexWhere((p) => p.id == post.id);
    if (idx != -1) {
      _allPosts[idx] = post;
      _persistCustomPosts();
      notifyChanges();
    }
  }

  void deletePostFromCache(String id) {
    _allPosts.removeWhere((p) => p.id == id);
    _savedPostIds.remove(id);
    _persistCustomPosts();
    _persistSavedIds();
    _persistLikes();
    notifyChanges();
  }

  void addCommentToPost(String postId, Map<String, String> comment) {
    final idx = _allPosts.indexWhere((p) => p.id == postId);
    if (idx != -1) {
      final existing = _allPosts[idx];
      final updatedComments = List<Map<String, String>>.from(existing.comments)..add(comment);
      _allPosts[idx] = existing.copyWith(comments: updatedComments);
      _persistCustomPosts();
      notifyChanges();
    }
  }

  void toggleLocalLike(String postId, String username) {
    final idx = _allPosts.indexWhere((p) => p.id == postId);
    if (idx != -1) {
      final post = _allPosts[idx];
      final isLiked = post.isLikedBy(username);
      final updatedLikes = List<String>.from(post.likes);

      if (isLiked) {
        updatedLikes.remove(username);
      } else {
        updatedLikes.add(username);
      }

      _allPosts[idx] = post.copyWith(
        likes: updatedLikes,
        likeCount: updatedLikes.length,
      );
      _persistLikes();
      notifyChanges();
    }
  }

  // Follow management
  bool isFollowing(String username) {
    return _following.any((u) => u.toLowerCase() == username.toLowerCase());
  }

  bool toggleFollow(String username) {
    final existing = _following.firstWhere(
      (u) => u.toLowerCase() == username.toLowerCase(),
      orElse: () => '',
    );
    bool nowFollowing;
    if (existing.isNotEmpty) {
      _following.remove(existing);
      nowFollowing = false;
    } else {
      _following.add(username);
      nowFollowing = true;
    }
    _persistFollowing();
    notifyChanges();
    return nowFollowing;
  }

  List<String> getFollowingList() => _following.toList();
  int get followingCount => _following.length;

  // Saved / Bookmarked posts management
  Set<String> get savedPostIds => Set<String>.unmodifiable(_savedPostIds);

  bool isPostSaved(String postId) {
    return _savedPostIds.contains(postId);
  }

  bool toggleSavePost(String postId) {
    bool nowSaved;
    if (_savedPostIds.contains(postId)) {
      _savedPostIds.remove(postId);
      nowSaved = false;
    } else {
      _savedPostIds.add(postId);
      nowSaved = true;
    }
    _persistSavedIds();
    notifyChanges();
    return nowSaved;
  }

  List<Post> getSavedPosts() {
    return _allPosts.where((p) => _savedPostIds.contains(p.id)).toList();
  }

  List<Post> getLikedPosts() {
    return _allPosts.where((p) => p.isLikedBy(currentUser)).toList();
  }

  List<Post> getUserPosts(String author) {
    return _allPosts.where((p) => p.author.toLowerCase() == author.toLowerCase()).toList();
  }

  List<Post> getFollowingPosts() {
    final followingLower = _following.map((f) => f.toLowerCase()).toSet();
    return _allPosts.where((p) => followingLower.contains(p.author.toLowerCase())).toList();
  }

  List<String> getUniqueAuthors() {
    final authors = _allPosts
        .map((p) => p.author)
        .where((a) => a.isNotEmpty && a.toLowerCase() != currentUser.toLowerCase())
        .toSet()
        .toList();
    authors.sort();
    return authors;
  }

  int getPostCountByAuthor(String author) {
    return _allPosts.where((p) => p.author.toLowerCase() == author.toLowerCase()).length;
  }
}
