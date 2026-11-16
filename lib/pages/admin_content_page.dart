import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/post.dart';
import '../services/api_service.dart';
import '../services/video_player.dart';
import '../widgets/edit_post_dialog.dart';
import 'pin_detail_page.dart';

class AdminContentPage extends StatefulWidget {
  const AdminContentPage({super.key});

  @override
  State<AdminContentPage> createState() => _AdminContentPageState();
}

class _AdminContentPageState extends State<AdminContentPage> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _mediaFilter = 'all'; // 'all', 'images', 'videos', 'marketing'
  String _categoryFilter = 'all';
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.trim().toLowerCase();
      });
    });
    ApiService().changeNotifier.addListener(_onServiceChanged);
  }

  @override
  void dispose() {
    _searchController.dispose();
    ApiService().changeNotifier.removeListener(_onServiceChanged);
    super.dispose();
  }

  void _onServiceChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _refreshData() async {
    setState(() => _isLoading = true);
    try {
      await ApiService().fetchPosts();
    } catch (_) {}
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _handleDeletePost(Post post) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFFEE2E2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.delete_forever_rounded, color: Colors.redAccent, size: 22),
            ),
            const SizedBox(width: 12),
            Text(
              'Admin Delete Post',
              style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 18),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Are you sure you want to permanently delete this content as Administrator?',
              style: GoogleFonts.inter(color: const Color(0xFF334155), fontSize: 14),
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Title: "${post.title}"',
                    style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 13),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Author: @${post.author} • Category: ${post.category ?? "General"}',
                    style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B)),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Media Type: ${post.isVideoPost ? "Video" : "Image"} (${post.isVideoPost ? post.videoUrls.length : post.imageUrls.length} files)',
                    style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Text(
              '⚠️ This will permanently remove the record and any associated uploaded media files from the database and backend storage.',
              style: GoogleFonts.inter(color: const Color(0xFFEF4444), fontSize: 12, fontWeight: FontWeight.w500),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel', style: GoogleFonts.inter(color: const Color(0xFF64748B))),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Delete As Admin', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await ApiService().deletePost(post.id);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: const Color(0xFF1E293B),
              content: Text('Admin successfully deleted "${post.title}"'),
              duration: const Duration(seconds: 3),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(backgroundColor: Colors.redAccent, content: Text('Failed to delete: $e')),
          );
        }
      }
    }
  }

  void _handleEditPost(Post post) {
    showDialog(
      context: context,
      builder: (ctx) => EditPostDialog(
        post: post,
        onUpdated: () => setState(() {}),
      ),
    );
  }

  void _openPinDetail(Post post) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PinDetailPage(
          post: post,
          onLikeToggle: () async {
            final currentUser = ApiService().currentUser;
            await ApiService().toggleLike(post.id, currentUser);
            if (mounted) setState(() {});
          },
          onDelete: () {
            if (mounted) setState(() {});
          },
          onEdit: () {
            if (mounted) setState(() {});
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final allPosts = ApiService().getAllPosts();

    // Counts for stats
    final totalPosts = allPosts.length;
    final totalImages = allPosts.where((p) => !p.isVideoPost).length;
    final totalVideos = allPosts.where((p) => p.isVideoPost).length;
    final totalAds = allPosts.where((p) => p.isMarketing).length;

    // Filter posts
    List<Post> filtered = allPosts.where((p) {
      // 1. Media Type Filter
      if (_mediaFilter == 'images' && p.isVideoPost) return false;
      if (_mediaFilter == 'videos' && !p.isVideoPost) return false;
      if (_mediaFilter == 'marketing' && !p.isMarketing) return false;

      // 2. Category Filter
      if (_categoryFilter != 'all') {
        if (p.category == null || p.category!.toLowerCase() != _categoryFilter.toLowerCase()) {
          return false;
        }
      }

      // 3. Search query
      if (_searchQuery.isNotEmpty) {
        final titleMatch = p.title.toLowerCase().contains(_searchQuery);
        final authorMatch = p.author.toLowerCase().contains(_searchQuery);
        final idMatch = p.id.toLowerCase().contains(_searchQuery);
        final descMatch = (p.description ?? '').toLowerCase().contains(_searchQuery);
        if (!titleMatch && !authorMatch && !idMatch && !descMatch) return false;
      }

      return true;
    }).toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F172A),
        foregroundColor: Colors.white,
        elevation: 0,
        titleSpacing: 16,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: const Color(0xFFE60023),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.admin_panel_settings_rounded, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Content Management',
                  style: GoogleFonts.inter(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
                Text(
                  'Logged in as @${ApiService().currentUser} (Administrator)',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    color: const Color(0xFF94A3B8),
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh Content',
            icon: _isLoading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.refresh_rounded, color: Colors.white),
            onPressed: _refreshData,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1200),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 1. Metric Overview Cards
                _buildMetricsSection(
                  total: totalPosts,
                  images: totalImages,
                  videos: totalVideos,
                  ads: totalAds,
                ),
                const SizedBox(height: 20),

                // 2. Search & Filter Bar
                _buildFilterControls(),
                const SizedBox(height: 20),

                // 3. Post Count & Quick Status
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Matching Content (${filtered.length} posts)',
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF0F172A),
                      ),
                    ),
                    if (_searchQuery.isNotEmpty || _mediaFilter != 'all' || _categoryFilter != 'all')
                      TextButton.icon(
                        onPressed: () {
                          setState(() {
                            _searchController.clear();
                            _mediaFilter = 'all';
                            _categoryFilter = 'all';
                          });
                        },
                        icon: const Icon(Icons.clear_all_rounded, size: 16),
                        label: const Text('Reset Filters'),
                        style: TextButton.styleFrom(foregroundColor: const Color(0xFFE60023)),
                      ),
                  ],
                ),
                const SizedBox(height: 12),

                // 4. Content List
                if (filtered.isEmpty)
                  _buildEmptyState()
                else
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: filtered.length,
                    separatorBuilder: (context, index) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final post = filtered[index];
                      return _buildPostManagementCard(post);
                    },
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ─── Metrics Section ───────────────────────────────────────────────────────

  Widget _buildMetricsSection({
    required int total,
    required int images,
    required int videos,
    required int ads,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 650;
        final cardWidth = isCompact ? (constraints.maxWidth - 12) / 2 : (constraints.maxWidth - 36) / 4;

        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _buildStatCard(
              width: cardWidth,
              title: 'Total Posts',
              value: '$total',
              subtitle: 'All platform pins',
              icon: Icons.dashboard_rounded,
              color: const Color(0xFF2563EB),
              bg: const Color(0xFFEFF6FF),
              isSelected: _mediaFilter == 'all',
              onTap: () => setState(() => _mediaFilter = 'all'),
            ),
            _buildStatCard(
              width: cardWidth,
              title: 'Images',
              value: '$images',
              subtitle: 'Photos & illustrations',
              icon: Icons.image_rounded,
              color: const Color(0xFF059669),
              bg: const Color(0xFFECFDF5),
              isSelected: _mediaFilter == 'images',
              onTap: () => setState(() => _mediaFilter = 'images'),
            ),
            _buildStatCard(
              width: cardWidth,
              title: 'Videos',
              value: '$videos',
              subtitle: 'Motion & clips',
              icon: Icons.videocam_rounded,
              color: const Color(0xFF7C3AED),
              bg: const Color(0xFFF5F3FF),
              isSelected: _mediaFilter == 'videos',
              onTap: () => setState(() => _mediaFilter = 'videos'),
            ),
            _buildStatCard(
              width: cardWidth,
              title: 'Ads & Marketing',
              value: '$ads',
              subtitle: 'Sponsored showcase',
              icon: Icons.campaign_rounded,
              color: const Color(0xFFD97706),
              bg: const Color(0xFFFFFBEB),
              isSelected: _mediaFilter == 'marketing',
              onTap: () => setState(() => _mediaFilter = 'marketing'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildStatCard({
    required double width,
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color color,
    required Color bg,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: width,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? color : const Color(0xFFE2E8F0),
            width: isSelected ? 2.0 : 1.0,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF64748B)),
                  ),
                  Text(
                    value,
                    style: GoogleFonts.inter(fontSize: 22, fontWeight: FontWeight.w800, color: const Color(0xFF0F172A)),
                  ),
                  Text(
                    subtitle,
                    style: GoogleFonts.inter(fontSize: 10, color: const Color(0xFF94A3B8)),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Filter & Search Controls ──────────────────────────────────────────────

  Widget _buildFilterControls() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Search Field
          TextField(
            controller: _searchController,
            style: GoogleFonts.inter(fontSize: 14),
            decoration: InputDecoration(
              hintText: 'Search by pin title, creator handle, ID or keyword...',
              hintStyle: GoogleFonts.inter(color: const Color(0xFF94A3B8), fontSize: 13),
              prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFF64748B)),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.close_rounded, size: 18),
                      onPressed: () => _searchController.clear(),
                    )
                  : null,
              filled: true,
              fillColor: const Color(0xFFF8FAFC),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFE60023), width: 1.5),
              ),
            ),
          ),
          const SizedBox(height: 14),

          // Media Type Pills
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                'Media Filter:',
                style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: const Color(0xFF64748B)),
              ),
              _buildTypeChip('All Media', 'all', Icons.grid_view_rounded),
              _buildTypeChip('📷 Images Only', 'images', Icons.image_rounded),
              _buildTypeChip('🎥 Videos Only', 'videos', Icons.videocam_rounded),
              _buildTypeChip('📢 Ads & Marketing', 'marketing', Icons.campaign_rounded),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTypeChip(String label, String value, IconData icon) {
    final isSelected = _mediaFilter == value;
    return InkWell(
      onTap: () => setState(() => _mediaFilter = value),
      borderRadius: BorderRadius.circular(14),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? const Color(0xFF0F172A) : const Color(0xFFE2E8F0),
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            color: isSelected ? Colors.white : const Color(0xFF475569),
          ),
        ),
      ),
    );
  }

  // ─── Post Management Card ──────────────────────────────────────────────────

  Widget _buildPostManagementCard(Post post) {
    final isVideo = post.isVideoPost;
    final isAd = post.isMarketing;
    final mediaCount = isVideo ? post.videoUrls.length : post.imageUrls.length;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isAd ? const Color(0xFFFDE68A) : const Color(0xFFE2E8F0),
          width: isAd ? 1.5 : 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      padding: const EdgeInsets.all(14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // 1. Thumbnail Preview with Badges
          InkWell(
            onTap: () => _openPinDetail(post),
            borderRadius: BorderRadius.circular(12),
            child: SizedBox(
              width: 80,
              height: 80,
              child: Stack(
                children: [
                  Positioned.fill(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        color: const Color(0xFF0F172A),
                        child: isVideo
                            ? buildVideoThumbnail(videoUrl: post.videoUrl)
                            : buildSafeImage(post.imageUrl, fit: BoxFit.cover),
                      ),
                    ),
                  ),
                  if (isVideo)
                    Positioned(
                      bottom: 4,
                      right: 4,
                      child: Container(
                        padding: const EdgeInsets.all(3),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.75),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Icon(Icons.videocam_rounded, size: 12, color: Colors.white),
                      ),
                    ),
                  if (mediaCount > 1)
                    Positioned(
                      top: 4,
                      left: 4,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.75),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '${mediaCount}x',
                          style: const TextStyle(fontSize: 9, color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 16),

          // 2. Post Information
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    // Title
                    Expanded(
                      child: Text(
                        post.title,
                        style: GoogleFonts.inter(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF0F172A),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Badges
                    if (isAd)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEF3C7),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFFDE68A)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.campaign_rounded, size: 12, color: Color(0xFFD97706)),
                            const SizedBox(width: 4),
                            Text(
                              'Ad / Marketing',
                              style: GoogleFonts.inter(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                color: const Color(0xFFB45309),
                              ),
                            ),
                          ],
                        ),
                      ),
                    if (isVideo) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF5F3FF),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFDDD6FE)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.videocam_rounded, size: 12, color: Color(0xFF7C3AED)),
                            const SizedBox(width: 4),
                            Text(
                              'Video',
                              style: GoogleFonts.inter(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFF6D28D9),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 6),

                // Creator & Category Metadata
                Wrap(
                  spacing: 12,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircleAvatar(
                          radius: 9,
                          backgroundColor: const Color(0xFF6366F1),
                          child: Text(
                            post.author.isNotEmpty ? post.author[0].toUpperCase() : 'U',
                            style: const TextStyle(fontSize: 8, color: Colors.white, fontWeight: FontWeight.bold),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '@${post.author}',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF475569),
                          ),
                        ),
                      ],
                    ),
                    Text(
                      '• ID: ${post.id}',
                      style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF94A3B8)),
                    ),
                    if (post.category != null && post.category!.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          post.category!,
                          style: GoogleFonts.inter(fontSize: 10, color: const Color(0xFF475569), fontWeight: FontWeight.w500),
                        ),
                      ),
                    Text(
                      '• ❤️ ${post.likeCount} loves',
                      style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF94A3B8)),
                    ),
                    Text(
                      '• 💬 ${post.comments.length} comments',
                      style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF94A3B8)),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 14),

          // 3. Admin Action Buttons
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                tooltip: 'Inspect Pin',
                icon: const Icon(Icons.open_in_new_rounded, size: 20, color: Color(0xFF64748B)),
                onPressed: () => _openPinDetail(post),
              ),
              IconButton(
                tooltip: 'Edit Pin',
                icon: const Icon(Icons.edit_outlined, size: 20, color: Color(0xFF6366F1)),
                onPressed: () => _handleEditPost(post),
              ),
              IconButton(
                tooltip: 'Delete Post as Administrator',
                icon: const Icon(Icons.delete_outline_rounded, size: 20, color: Color(0xFFDC2626)),
                onPressed: () => _handleDeletePost(post),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ─── Empty State ───────────────────────────────────────────────────────────

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Center(
        child: Column(
          children: [
            const Icon(Icons.filter_none_rounded, size: 48, color: Color(0xFFCBD5E1)),
            const SizedBox(height: 14),
            Text(
              'No posts match the active filters',
              style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold, color: const Color(0xFF334155)),
            ),
            const SizedBox(height: 6),
            Text(
              'Try clearing search keywords or switching media categories.',
              style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF94A3B8)),
            ),
          ],
        ),
      ),
    );
  }
}
