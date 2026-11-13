import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/post.dart';
import '../services/api_service.dart';
import '../services/image_download.dart';
import '../services/video_player.dart';
import '../widgets/edit_post_dialog.dart';

class PinDetailPage extends StatefulWidget {
  final Post post;
  final VoidCallback onLikeToggle;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const PinDetailPage({
    super.key,
    required this.post,
    required this.onLikeToggle,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  State<PinDetailPage> createState() => _PinDetailPageState();
}

class _PinDetailPageState extends State<PinDetailPage> {
  late Post _currentPost;
  final TextEditingController _commentController = TextEditingController();
  int _currentImageIndex = 0;

  @override
  void initState() {
    super.initState();
    _currentPost = widget.post;
    _currentImageIndex = 0;
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  void _prevImage(int length) {
    if (_currentImageIndex > 0) {
      setState(() => _currentImageIndex--);
    }
  }

  void _nextImage(int length) {
    if (_currentImageIndex < length - 1) {
      setState(() => _currentImageIndex++);
    }
  }

  void _handleLike() {
    widget.onLikeToggle();
    final currentUser = ApiService().currentUser;
    final isLiked = _currentPost.isLikedBy(currentUser);

    setState(() {
      final updatedLikes = List<String>.from(_currentPost.likes);
      if (isLiked) {
        updatedLikes.remove(currentUser);
      } else {
        updatedLikes.add(currentUser);
      }
      _currentPost = _currentPost.copyWith(
        likes: updatedLikes,
        likeCount: updatedLikes.length,
      );
    });
  }

  void _handleToggleSave() {
    final nowSaved = ApiService().toggleSavePost(_currentPost.id);
    setState(() {});
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        duration: const Duration(seconds: 2),
        backgroundColor: nowSaved ? const Color(0xFF10B981) : const Color(0xFF1E293B),
        content: Text(
          nowSaved ? 'Pin saved to your collection!' : 'Removed from saved collection',
        ),
      ),
    );
  }

  void _handleToggleFollow() {
    final nowFollowing = ApiService().toggleFollow(_currentPost.author);
    setState(() {});
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        duration: const Duration(seconds: 2),
        backgroundColor: nowFollowing ? const Color(0xFF6366F1) : const Color(0xFF1E293B),
        content: Text(
          nowFollowing
              ? 'Now following @${_currentPost.author}'
              : 'Unfollowed @${_currentPost.author}',
        ),
      ),
    );
  }

  void _handleDownloadImage(String imageUrl) {
    final fileName = 'punny_${_currentPost.id}_${_currentImageIndex + 1}.jpg';
    saveImageToDevice(imageUrl, fileName);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        duration: Duration(seconds: 2),
        backgroundColor: Color(0xFF10B981),
        content: Text('Downloading image to your device...'),
      ),
    );
  }

  void _handleAddComment() {
    final text = _commentController.text.trim();
    if (text.isEmpty) return;

    final newComment = {
      'user': ApiService().currentUser,
      'avatar': ApiService().currentUser.isNotEmpty ? ApiService().currentUser[0].toUpperCase() : 'U',
      'text': text,
    };

    ApiService().addCommentToPost(_currentPost.id, newComment);

    setState(() {
      final updatedComments = List<Map<String, String>>.from(_currentPost.comments)..add(newComment);
      _currentPost = _currentPost.copyWith(comments: updatedComments);
      _commentController.clear();
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        duration: Duration(seconds: 2),
        backgroundColor: Color(0xFF10B981),
        content: Text('Comment posted!'),
      ),
    );
  }

  void _confirmDelete() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Delete Pin?', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
        content: Text(
          'Are you sure you want to delete "${_currentPost.title}"? This cannot be undone.',
          style: GoogleFonts.inter(color: const Color(0xFF475569)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: GoogleFonts.inter(color: const Color(0xFF64748B))),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.pop(context); // Close detail page
              widget.onDelete();
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  Widget _buildImageSection(List<String> images) {
    final isVideo = _currentPost.isVideoPost;
    final videoSrc = _currentPost.videoUrl ?? '';
    final activeUrl = (images.isNotEmpty && _currentImageIndex < images.length)
        ? images[_currentImageIndex]
        : _currentPost.imageUrl;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Main Frame
        ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: Container(
            color: const Color(0xFF0F172A),
            constraints: const BoxConstraints(minHeight: 380, maxHeight: 580),
            child: Stack(
              alignment: Alignment.center,
              children: [
                // VIDEO player
                if (isVideo && videoSrc.isNotEmpty)
                  SizedBox.expand(child: buildVideoPreview(videoSrc, showControls: true))
                else
                  // IMAGE carousel (swipeable)
                  GestureDetector(
                    onHorizontalDragEnd: (details) {
                      if (details.primaryVelocity != null) {
                        if (details.primaryVelocity! < -200) {
                          _nextImage(images.length);
                        } else if (details.primaryVelocity! > 200) {
                          _prevImage(images.length);
                        }
                      }
                    },
                    child: Center(
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 200),
                        child: Container(
                          key: ValueKey<String>('$activeUrl-$_currentImageIndex'),
                          constraints: const BoxConstraints(maxHeight: 580),
                          child: buildSafeImage(activeUrl, fit: BoxFit.contain),
                        ),
                      ),
                    ),
                  ),

                // Video badge
                if (isVideo)
                  Positioned(
                    top: 14,
                    left: 14,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.65), borderRadius: BorderRadius.circular(16)),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.videocam_rounded, size: 14, color: Colors.white),
                          SizedBox(width: 4),
                          Text('Video', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                  ),

                // Multi-Image Index Badge (non-video)
                if (!isVideo && images.length > 1)
                  Positioned(
                    top: 14,
                    left: 14,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.65), borderRadius: BorderRadius.circular(16)),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.collections_rounded, size: 14, color: Colors.white),
                          const SizedBox(width: 4),
                          Text('${_currentImageIndex + 1} / ${images.length}',
                              style: GoogleFonts.inter(
                                  color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                  ),

                // Download button (images only)
                if (!isVideo)
                  Positioned(
                    top: 14,
                    right: 14,
                    child: CircleAvatar(
                      backgroundColor: Colors.black.withValues(alpha: 0.65),
                      child: IconButton(
                        tooltip: 'Save / Download Image',
                        icon: const Icon(Icons.download_rounded, color: Colors.white, size: 18),
                        onPressed: () => _handleDownloadImage(activeUrl),
                      ),
                    ),
                  ),

                // Previous Arrow (images only)
                if (!isVideo && images.length > 1 && _currentImageIndex > 0)
                  Positioned(
                    left: 12,
                    child: CircleAvatar(
                      backgroundColor: Colors.black.withValues(alpha: 0.6),
                      child: IconButton(
                        icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 16),
                        onPressed: () => _prevImage(images.length),
                      ),
                    ),
                  ),

                // Next Arrow (images only)
                if (!isVideo && images.length > 1 && _currentImageIndex < images.length - 1)
                  Positioned(
                    right: 12,
                    child: CircleAvatar(
                      backgroundColor: Colors.black.withValues(alpha: 0.6),
                      child: IconButton(
                        icon: const Icon(Icons.arrow_forward_ios, color: Colors.white, size: 16),
                        onPressed: () => _nextImage(images.length),
                      ),
                    ),
                  ),

                // Indicator Dots (images only)
                if (!isVideo && images.length > 1)
                  Positioned(
                    bottom: 12,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: List.generate(images.length, (i) {
                        final isSel = _currentImageIndex == i;
                        return AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          margin: const EdgeInsets.symmetric(horizontal: 3),
                          width: isSel ? 18 : 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: isSel ? Colors.white : Colors.white.withValues(alpha: 0.4),
                            borderRadius: BorderRadius.circular(3),
                          ),
                        );
                      }),
                    ),
                  ),
              ],
            ),
          ),
        ),

        // Thumbnails Strip (image carousel only)
        if (!isVideo && images.length > 1) ...[
          const SizedBox(height: 12),
          SizedBox(
            height: 60,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: images.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, idx) {
                final isSel = idx == _currentImageIndex;
                return GestureDetector(
                  onTap: () => setState(() => _currentImageIndex = idx),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: isSel ? const Color(0xFFE60023) : Colors.transparent, width: 2.5),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(9),
                      child: buildSafeImage(images[idx], fit: BoxFit.cover),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = ApiService().currentUser;
    final isLiked = _currentPost.isLikedBy(currentUser);
    final isAuthor = _currentPost.author.toLowerCase() == currentUser.toLowerCase();
    final images = _currentPost.imageUrls.isNotEmpty ? _currentPost.imageUrls : [_currentPost.imageUrl];

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: Container(
          margin: const EdgeInsets.only(left: 12),
          child: CircleAvatar(
            backgroundColor: Colors.white,
            child: IconButton(
              icon: const Icon(Icons.arrow_back, color: Color(0xFF0F172A)),
              onPressed: () => Navigator.pop(context),
            ),
          ),
        ),
        actions: [
          CircleAvatar(
            backgroundColor: Colors.white,
            child: IconButton(
              tooltip: 'Share',
              icon: const Icon(Icons.share_outlined, color: Color(0xFF0F172A)),
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Pin link copied to clipboard!')),
                );
              },
            ),
          ),
          const SizedBox(width: 8),
          if (isAuthor) ...[
            CircleAvatar(
              backgroundColor: Colors.white,
              child: IconButton(
                tooltip: 'Edit Pin',
                icon: const Icon(Icons.edit_outlined, color: Color(0xFF6366F1)),
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (ctx) => EditPostDialog(
                      post: _currentPost,
                      onUpdated: () {
                        widget.onEdit();
                        Navigator.pop(context); // Return to feed with updated data
                      },
                    ),
                  );
                },
              ),
            ),
            const SizedBox(width: 8),
            CircleAvatar(
              backgroundColor: Colors.white,
              child: IconButton(
                tooltip: 'Delete Pin',
                icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                onPressed: _confirmDelete,
              ),
            ),
          ],
          const SizedBox(width: 16),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1050),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(32),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 28,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final isWide = constraints.maxWidth >= 750;

                    if (isWide) {
                      // Desktop / Tablet Pinterest Split Layout (NO IntrinsicHeight to prevent viewport assertion crashes)
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Left Column: Big Image
                          Expanded(
                            flex: 5,
                            child: Padding(
                              padding: const EdgeInsets.all(20.0),
                              child: _buildImageSection(images),
                            ),
                          ),
                          // Divider
                          Container(width: 1, color: const Color(0xFFF1F5F9)),
                          // Right Column: Details & Comments
                          Expanded(
                            flex: 5,
                            child: _buildDetailsColumn(isLiked, isAuthor),
                          ),
                        ],
                      );
                    } else {
                      // Mobile Stack Layout
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: _buildImageSection(images),
                          ),
                          _buildDetailsColumn(isLiked, isAuthor),
                        ],
                      );
                    }
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDetailsColumn(bool isLiked, bool isAuthor) {
    final isSaved = ApiService().isPostSaved(_currentPost.id);
    final isFollowing = ApiService().isFollowing(_currentPost.author);
    final comments = _currentPost.comments;

    return Padding(
      padding: const EdgeInsets.all(28.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Action Header: Like button + Save Button
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Like/Love Interactive Button
              InkWell(
                onTap: _handleLike,
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: isLiked ? const Color(0xFFFEE2E2) : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        isLiked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                        color: isLiked ? Colors.redAccent : const Color(0xFF475569),
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        isLiked ? 'Loved (${_currentPost.likeCount})' : 'Love (${_currentPost.likeCount})',
                        style: GoogleFonts.inter(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                          color: isLiked ? Colors.redAccent : const Color(0xFF334155),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Pinterest Signature Save Button
              ElevatedButton.icon(
                onPressed: _handleToggleSave,
                icon: Icon(
                  isSaved ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
                  size: 18,
                ),
                label: Text(isSaved ? 'Saved' : 'Save'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: isSaved ? const Color(0xFF1E293B) : const Color(0xFFE60023),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Category Badge if present
          if (_currentPost.category != null && _currentPost.category!.isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFEEF2FF),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                _currentPost.category!,
                style: GoogleFonts.inter(
                  color: const Color(0xFF4F46E5),
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
              ),
            ),
            const SizedBox(height: 8),
          ],

          // Title
          Text(
            _currentPost.title,
            style: GoogleFonts.inter(
              fontSize: 26,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF0F172A),
              height: 1.25,
            ),
          ),

          // Description if present
          if (_currentPost.description != null && _currentPost.description!.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              _currentPost.description!,
              style: GoogleFonts.inter(
                fontSize: 14,
                color: const Color(0xFF64748B),
                height: 1.5,
              ),
            ),
          ],

          // Link if present
          if (_currentPost.link != null && _currentPost.link!.isNotEmpty) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                const Icon(Icons.link_rounded, size: 16, color: Color(0xFF6366F1)),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    _currentPost.link!,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: const Color(0xFF6366F1),
                      decoration: TextDecoration.underline,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 20),

          // Author Info Card
          Container(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFF1F5F9)),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: const Color(0xFF6366F1),
                  child: Text(
                    _currentPost.author.isNotEmpty ? _currentPost.author[0].toUpperCase() : 'A',
                    style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _currentPost.author,
                        style: GoogleFonts.inter(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                          color: const Color(0xFF0F172A),
                        ),
                      ),
                      Text(
                        '@${_currentPost.author.toLowerCase()}',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: const Color(0xFF94A3B8),
                        ),
                      ),
                    ],
                  ),
                ),
                if (!isAuthor)
                  ElevatedButton.icon(
                    onPressed: _handleToggleFollow,
                    icon: Icon(
                      isFollowing ? Icons.check_rounded : Icons.person_add_rounded,
                      size: 16,
                    ),
                    label: Text(
                      isFollowing ? 'Following' : 'Follow',
                      style: GoogleFonts.inter(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isFollowing ? const Color(0xFFEEF2FF) : const Color(0xFF0F172A),
                      foregroundColor: isFollowing ? const Color(0xFF4F46E5) : Colors.white,
                      elevation: 0,
                      side: isFollowing ? const BorderSide(color: Color(0xFFC7D2FE)) : BorderSide.none,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Comments Section Header
          Text(
            'Comments (${comments.length})',
            style: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF1E293B),
            ),
          ),
          const SizedBox(height: 12),

          // Comments List
          Column(
            children: comments.map((c) {
              final avatar = (c['avatar'] != null && c['avatar']!.isNotEmpty)
                  ? c['avatar']!
                  : (c['user'] != null && c['user']!.isNotEmpty ? c['user']![0].toUpperCase() : 'U');
              return Padding(
                padding: const EdgeInsets.only(bottom: 12.0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CircleAvatar(
                      radius: 14,
                      backgroundColor: const Color(0xFFEEF2FF),
                      child: Text(
                        avatar,
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF6366F1)),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: RichText(
                        text: TextSpan(
                          style: GoogleFonts.inter(color: const Color(0xFF334155), fontSize: 13),
                          children: [
                            TextSpan(
                              text: '${c['user'] ?? 'User'}  ',
                              style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                            ),
                            TextSpan(text: c['text'] ?? ''),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),

          // Add comment field
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _commentController,
                  onSubmitted: (_) => _handleAddComment(),
                  decoration: InputDecoration(
                    hintText: 'Add a comment...',
                    hintStyle: GoogleFonts.inter(color: const Color(0xFF94A3B8), fontSize: 13),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    filled: true,
                    fillColor: const Color(0xFFF8FAFC),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(20),
                      borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.send_rounded, color: Color(0xFFE60023)),
                onPressed: _handleAddComment,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
