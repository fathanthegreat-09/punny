import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/post.dart';
import '../pages/pin_detail_page.dart';
import '../services/api_service.dart';
import '../services/video_player.dart';

class PinCard extends StatefulWidget {
  final Post post;
  final VoidCallback onLikeToggle;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback? onSaveToggle;

  const PinCard({
    super.key,
    required this.post,
    required this.onLikeToggle,
    required this.onEdit,
    required this.onDelete,
    this.onSaveToggle,
  });

  @override
  State<PinCard> createState() => _PinCardState();
}

class _PinCardState extends State<PinCard> {
  bool _isHovered = false;

  Future<void> _openDetail(BuildContext context) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PinDetailPage(
          post: widget.post,
          onLikeToggle: widget.onLikeToggle,
          onEdit: widget.onEdit,
          onDelete: widget.onDelete,
        ),
      ),
    );
    if (mounted) {
      setState(() {});
      widget.onSaveToggle?.call();
    }
  }

  void _handleQuickSave() {
    final nowSaved = ApiService().toggleSavePost(widget.post.id);
    setState(() {});
    widget.onSaveToggle?.call();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        duration: const Duration(seconds: 1),
        backgroundColor: nowSaved ? const Color(0xFF10B981) : const Color(0xFF1E293B),
        content: Text(
          nowSaved ? 'Saved "${widget.post.title}" to collection!' : 'Removed from saved collection',
        ),
      ),
    );
  }

  void _handleToggleFollow() {
    final nowFollowing = ApiService().toggleFollow(widget.post.author);
    setState(() {});
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        duration: const Duration(seconds: 1),
        backgroundColor: nowFollowing ? const Color(0xFF6366F1) : const Color(0xFF1E293B),
        content: Text(
          nowFollowing ? 'Followed @${widget.post.author}' : 'Unfollowed @${widget.post.author}',
        ),
      ),
    );
  }

  void _showDeleteConfirmation(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Delete Pin?',
          style: GoogleFonts.inter(fontWeight: FontWeight.bold),
        ),
        content: Text(
          'Are you sure you want to delete "${widget.post.title}"? This action cannot be undone.',
          style: GoogleFonts.inter(color: const Color(0xFF475569)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text('Cancel', style: GoogleFonts.inter(color: const Color(0xFF64748B))),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () {
              Navigator.of(ctx).pop();
              widget.onDelete();
            },
            child: Text('Delete', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = ApiService().currentUser;
    final isLiked = widget.post.isLikedBy(currentUser);
    final isAuthor = widget.post.author.toLowerCase() == currentUser.toLowerCase();
    final isSaved = ApiService().isPostSaved(widget.post.id);
    final isFollowing = ApiService().isFollowing(widget.post.author);

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: _isHovered
                  ? const Color(0x1A000000)
                  : const Color(0x0A000000),
              blurRadius: _isHovered ? 20 : 12,
              offset: Offset(0, _isHovered ? 8 : 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Pin Image with rounded top corners
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              child: Stack(
                children: [
                  InkWell(
                    onTap: () => _openDetail(context),
                    child: AspectRatio(
                      aspectRatio: 1.0,
                      child: widget.post.isVideoPost
                          ? buildVideoThumbnail(videoUrl: widget.post.videoUrl)
                          : buildSafeImage(
                              widget.post.imageUrl,
                              fit: BoxFit.cover,
                            ),
                    ),
                  ),

                  // Multi-image indicator badge
                  if (widget.post.isMultiImage)
                    Positioned(
                      bottom: 10,
                      right: 10,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.7),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.collections_rounded, size: 12, color: Colors.white),
                            const SizedBox(width: 4),
                            Text(
                              '${widget.post.imageUrls.length}',
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                  // Video badge
                  if (widget.post.isVideoPost && !widget.post.isMultiImage)
                    Positioned(
                      bottom: 10,
                      right: 10,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.75),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.videocam_rounded, size: 13, color: Colors.white),
                            SizedBox(width: 4),
                            Text('Video',
                                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white)),
                          ],
                        ),
                      ),
                    ),

                  // Play overlay for video posts
                  if (widget.post.isVideoPost)
                    Positioned.fill(
                      child: Center(
                        child: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.4),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 32),
                        ),
                      ),
                    ),

                  // Floating Quick Like button on top right
                  Positioned(
                    top: 10,
                    right: 10,
                    child: InkWell(
                      onTap: widget.onLikeToggle,
                      borderRadius: BorderRadius.circular(20),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.9),
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x1F000000),
                              blurRadius: 6,
                              offset: Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              isLiked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                              size: 16,
                              color: isLiked ? Colors.redAccent : const Color(0xFF64748B),
                            ),
                            if (widget.post.likeCount > 0) ...[
                              const SizedBox(width: 4),
                              Text(
                                '${widget.post.likeCount}',
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: isLiked ? Colors.redAccent : const Color(0xFF475569),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),

                  // Quick Save / Bookmark Button on top left
                  Positioned(
                    top: 10,
                    left: 10,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (widget.post.isMarketing)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                            margin: const EdgeInsets.only(right: 6),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF59E0B).withValues(alpha: 0.95),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.campaign_rounded, size: 11, color: Colors.white),
                                const SizedBox(width: 3),
                                Text(
                                  'Ad',
                                  style: GoogleFonts.inter(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        if (isAuthor)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            margin: const EdgeInsets.only(right: 6),
                            decoration: BoxDecoration(
                              color: const Color(0xFF6366F1).withValues(alpha: 0.9),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              'You',
                              style: GoogleFonts.inter(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        InkWell(
                          onTap: _handleQuickSave,
                          borderRadius: BorderRadius.circular(20),
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: isSaved
                                  ? const Color(0xFFE60023)
                                  : Colors.white.withValues(alpha: 0.9),
                              shape: BoxShape.circle,
                              boxShadow: const [
                                BoxShadow(
                                  color: Color(0x1F000000),
                                  blurRadius: 6,
                                  offset: Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Icon(
                              isSaved ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
                              size: 16,
                              color: isSaved ? Colors.white : const Color(0xFF475569),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Pin Info
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Title & Author
                      Expanded(
                        child: InkWell(
                          onTap: () => _openDetail(context),
                          borderRadius: BorderRadius.circular(8),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.post.title,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.inter(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: const Color(0xFF0F172A),
                                  height: 1.25,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '@${widget.post.author}',
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  color: const Color(0xFF94A3B8),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      // Context Menu
                      PopupMenuButton<String>(
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        icon: const Icon(
                          Icons.more_vert,
                          size: 18,
                          color: Color(0xFF64748B),
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        onSelected: (value) {
                          if (value == 'edit') {
                            widget.onEdit();
                          } else if (value == 'delete') {
                            _showDeleteConfirmation(context);
                          } else if (value == 'like') {
                            widget.onLikeToggle();
                          } else if (value == 'save') {
                            _handleQuickSave();
                          } else if (value == 'follow') {
                            _handleToggleFollow();
                          }
                        },
                        itemBuilder: (context) => [
                          PopupMenuItem(
                            value: 'like',
                            child: Row(
                              children: [
                                Icon(
                                  isLiked ? Icons.favorite : Icons.favorite_border,
                                  size: 18,
                                  color: isLiked ? Colors.redAccent : const Color(0xFF64748B),
                                ),
                                const SizedBox(width: 10),
                                Text(isLiked ? 'Unlike Pin' : 'Love Pin'),
                              ],
                            ),
                          ),
                          PopupMenuItem(
                            value: 'save',
                            child: Row(
                              children: [
                                Icon(
                                  isSaved ? Icons.bookmark : Icons.bookmark_border,
                                  size: 18,
                                  color: isSaved ? const Color(0xFFE60023) : const Color(0xFF64748B),
                                ),
                                const SizedBox(width: 10),
                                Text(isSaved ? 'Remove from Saved' : 'Save Pin'),
                              ],
                            ),
                          ),
                          if (!isAuthor)
                            PopupMenuItem(
                              value: 'follow',
                              child: Row(
                                children: [
                                  Icon(
                                    isFollowing ? Icons.person_remove_outlined : Icons.person_add_outlined,
                                    size: 18,
                                    color: isFollowing ? Colors.redAccent : const Color(0xFF6366F1),
                                  ),
                                  const SizedBox(width: 10),
                                  Text(isFollowing ? 'Unfollow @${widget.post.author}' : 'Follow @${widget.post.author}'),
                                ],
                              ),
                            ),
                          if (isAuthor)
                            const PopupMenuItem(
                              value: 'edit',
                              child: Row(
                                children: [
                                  Icon(Icons.edit_outlined, size: 18, color: Color(0xFF6366F1)),
                                  SizedBox(width: 10),
                                  Text('Edit Pin'),
                                ],
                              ),
                            ),
                          if (isAuthor || ApiService().isAdmin)
                            PopupMenuItem(
                              value: 'delete',
                              child: Row(
                                children: [
                                  const Icon(Icons.delete_outline, size: 18, color: Colors.redAccent),
                                  const SizedBox(width: 10),
                                  Text(
                                    (!isAuthor && ApiService().isAdmin) ? 'Delete Pin (Admin)' : 'Delete Pin',
                                    style: const TextStyle(color: Colors.redAccent),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
