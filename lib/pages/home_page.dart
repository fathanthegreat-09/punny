import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:salomon_bottom_bar/salomon_bottom_bar.dart';

import '../models/post.dart';
import '../services/api_service.dart';
import '../widgets/edit_post_dialog.dart';
import '../widgets/pin_card.dart';
import 'add_page.dart';
import 'notification_page.dart';
import 'search_page.dart';
import 'user_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _currentIndex = 0;
  List<Post> _displayedPosts = [];
  bool _isLoading = false;
  bool _isRefreshing = false;

  // Filter & Sort States
  String _activeFilter = 'all'; // 'all', 'popular', 'following', 'liked', 'saved'
  String? _selectedAuthor; // null means all authors
  String _sortBy = 'default'; // 'default', 'likes_desc', 'title_az'

  @override
  void initState() {
    super.initState();
    _loadPosts();
    ApiService().changeNotifier.addListener(_onServiceChanged);
  }

  @override
  void dispose() {
    ApiService().changeNotifier.removeListener(_onServiceChanged);
    super.dispose();
  }

  void _onServiceChanged() {
    if (mounted) {
      _applyFilters();
    }
  }

  Future<void> _loadPosts({bool isManualRefresh = false}) async {
    if (isManualRefresh) {
      setState(() => _isRefreshing = true);
    } else {
      setState(() => _isLoading = true);
    }

    try {
      await ApiService().fetchPosts();
    } catch (_) {}

    if (!mounted) return;

    _applyFilters();

    setState(() {
      _isLoading = false;
      _isRefreshing = false;
    });

    if (isManualRefresh && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          duration: const Duration(seconds: 2),
          backgroundColor: const Color(0xFF1E293B),
          content: Text('Feed refreshed (${_displayedPosts.length} pins loaded)'),
        ),
      );
    }
  }

  void _applyFilters() {
    final all = ApiService().getAllPosts();
    List<Post> result = List<Post>.from(all);
    final currentUser = ApiService().currentUser;

    // 1. Primary Filter
    switch (_activeFilter) {
      case 'popular':
        result.sort((a, b) => b.likeCount.compareTo(a.likeCount));
        break;
      case 'following':
        final following = ApiService().getFollowingList().map((u) => u.toLowerCase()).toSet();
        result = result.where((p) => following.contains(p.author.toLowerCase())).toList();
        break;
      case 'liked':
        result = result.where((p) => p.isLikedBy(currentUser)).toList();
        break;
      case 'saved':
        final savedIds = ApiService().savedPostIds;
        result = result.where((p) => savedIds.contains(p.id)).toList();
        break;
      case 'all':
      default:
        break;
    }

    // 2. Author Filter
    if (_selectedAuthor != null && _selectedAuthor!.isNotEmpty) {
      result = result.where((p) => p.author.toLowerCase() == _selectedAuthor!.toLowerCase()).toList();
    }

    // 3. Sorting (if not already sorted by popular)
    if (_activeFilter != 'popular') {
      if (_sortBy == 'likes_desc') {
        result.sort((a, b) => b.likeCount.compareTo(a.likeCount));
      } else if (_sortBy == 'title_az') {
        result.sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
      }
    }

    setState(() {
      _displayedPosts = result;
    });
  }

  void _resetFilters() {
    setState(() {
      _activeFilter = 'all';
      _selectedAuthor = null;
      _sortBy = 'default';
    });
    _applyFilters();
  }

  bool get _hasActiveFilter {
    return _activeFilter != 'all' || _selectedAuthor != null || _sortBy != 'default';
  }

  String get _filterDescription {
    final parts = <String>[];
    if (_activeFilter == 'popular') parts.add('Most Popular');
    if (_activeFilter == 'following') parts.add('Following');
    if (_activeFilter == 'liked') parts.add('Liked by You');
    if (_activeFilter == 'saved') parts.add('Saved Pins');
    if (_selectedAuthor != null) parts.add('@$_selectedAuthor');
    if (_sortBy == 'title_az') parts.add('A-Z');
    if (_sortBy == 'likes_desc' && _activeFilter != 'popular') parts.add('Top Loves');
    return parts.isEmpty ? 'All Pins' : parts.join(' • ');
  }

  Future<void> _handleLikeToggle(Post post) async {
    final currentUser = ApiService().currentUser;
    await ApiService().toggleLike(post.id, currentUser);
    _applyFilters();
  }

  void _handleEditPost(Post post) {
    showDialog(
      context: context,
      builder: (ctx) => EditPostDialog(
        post: post,
        onUpdated: () {
          _loadPosts();
        },
      ),
    );
  }

  Future<void> _handleDeletePost(Post post) async {
    try {
      await ApiService().deletePost(post.id);
      _applyFilters();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFF1E293B),
            content: Text('Deleted "${post.title}"'),
          ),
        );
      }
    } catch (e) {
      _loadPosts();
    }
  }

  void _showFilterModal() {
    String tempFilter = _activeFilter;
    String? tempAuthor = _selectedAuthor;
    String tempSort = _sortBy;
    final allAuthors = ApiService().getUniqueAuthors();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
              ),
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
              child: SafeArea(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Handle Bar
                    Center(
                      child: Container(
                        width: 44,
                        height: 5,
                        decoration: BoxDecoration(
                          color: const Color(0xFFCBD5E1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Header Row
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.tune_rounded, color: Color(0xFFE60023), size: 24),
                            const SizedBox(width: 8),
                            Text(
                              'Filter & Sort Pins',
                              style: GoogleFonts.inter(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFF0F172A),
                              ),
                            ),
                          ],
                        ),
                        TextButton(
                          onPressed: () {
                            setModalState(() {
                              tempFilter = 'all';
                              tempAuthor = null;
                              tempSort = 'default';
                            });
                          },
                          child: Text(
                            'Reset All',
                            style: GoogleFonts.inter(
                              color: const Color(0xFFE60023),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Category Filters
                    Text(
                      'CATEGORY / FEED',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF64748B),
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _buildFilterChoiceChip(
                          label: 'All Pins',
                          icon: Icons.grid_view_rounded,
                          isSelected: tempFilter == 'all',
                          onSelected: () => setModalState(() => tempFilter = 'all'),
                        ),
                        _buildFilterChoiceChip(
                          label: 'Popular 🔥',
                          icon: Icons.local_fire_department_rounded,
                          isSelected: tempFilter == 'popular',
                          onSelected: () => setModalState(() => tempFilter = 'popular'),
                        ),
                        _buildFilterChoiceChip(
                          label: 'Following ✨',
                          icon: Icons.people_alt_rounded,
                          isSelected: tempFilter == 'following',
                          onSelected: () => setModalState(() => tempFilter = 'following'),
                        ),
                        _buildFilterChoiceChip(
                          label: 'Liked by You ❤️',
                          icon: Icons.favorite_rounded,
                          isSelected: tempFilter == 'liked',
                          onSelected: () => setModalState(() => tempFilter = 'liked'),
                        ),
                        _buildFilterChoiceChip(
                          label: 'Saved 🔖',
                          icon: Icons.bookmark_rounded,
                          isSelected: tempFilter == 'saved',
                          onSelected: () => setModalState(() => tempFilter = 'saved'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 22),

                    // Filter by Author
                    Text(
                      'FILTER BY CREATOR / AUTHOR',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF64748B),
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      height: 40,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        children: [
                          ChoiceChip(
                            label: const Text('All Creators'),
                            selected: tempAuthor == null,
                            onSelected: (val) {
                              setModalState(() => tempAuthor = null);
                            },
                            selectedColor: const Color(0xFF0F172A),
                            labelStyle: GoogleFonts.inter(
                              color: tempAuthor == null ? Colors.white : const Color(0xFF334155),
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(width: 8),
                          ...allAuthors.map((author) {
                            final isSel = tempAuthor?.toLowerCase() == author.toLowerCase();
                            return Padding(
                              padding: const EdgeInsets.only(right: 8.0),
                              child: ChoiceChip(
                                label: Text('@$author'),
                                selected: isSel,
                                onSelected: (val) {
                                  setModalState(() => tempAuthor = val ? author : null);
                                },
                                selectedColor: const Color(0xFFE60023),
                                labelStyle: GoogleFonts.inter(
                                  color: isSel ? Colors.white : const Color(0xFF334155),
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                ),
                              ),
                            );
                          }),
                        ],
                      ),
                    ),
                    const SizedBox(height: 22),

                    // Sort Order
                    Text(
                      'SORT ORDER',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF64748B),
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      children: [
                        _buildFilterChoiceChip(
                          label: 'Default (Recent)',
                          icon: Icons.schedule_rounded,
                          isSelected: tempSort == 'default',
                          onSelected: () => setModalState(() => tempSort = 'default'),
                        ),
                        _buildFilterChoiceChip(
                          label: 'Most Liked',
                          icon: Icons.thumb_up_alt_rounded,
                          isSelected: tempSort == 'likes_desc',
                          onSelected: () => setModalState(() => tempSort = 'likes_desc'),
                        ),
                        _buildFilterChoiceChip(
                          label: 'Title (A-Z)',
                          icon: Icons.sort_by_alpha_rounded,
                          isSelected: tempSort == 'title_az',
                          onSelected: () => setModalState(() => tempSort = 'title_az'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 28),

                    // Apply Button
                    ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        setState(() {
                          _activeFilter = tempFilter;
                          _selectedAuthor = tempAuthor;
                          _sortBy = tempSort;
                        });
                        _applyFilters();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFE60023),
                        foregroundColor: Colors.white,
                        minimumSize: const Size.fromHeight(52),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        elevation: 0,
                      ),
                      child: Text(
                        'Apply Filters',
                        style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildFilterChoiceChip({
    required String label,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onSelected,
  }) {
    return InkWell(
      onTap: onSelected,
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFE60023) : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? const Color(0xFFE60023) : const Color(0xFFE2E8F0),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16,
              color: isSelected ? Colors.white : const Color(0xFF64748B),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                color: isSelected ? Colors.white : const Color(0xFF334155),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickFilterChips() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 12),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _buildQuickChip(
              label: 'All Pins',
              isSelected: _activeFilter == 'all' && _selectedAuthor == null,
              onTap: _resetFilters,
            ),
            const SizedBox(width: 8),
            _buildQuickChip(
              label: 'Popular 🔥',
              isSelected: _activeFilter == 'popular',
              onTap: () {
                setState(() => _activeFilter = _activeFilter == 'popular' ? 'all' : 'popular');
                _applyFilters();
              },
            ),
            const SizedBox(width: 8),
            _buildQuickChip(
              label: 'Following ✨',
              isSelected: _activeFilter == 'following',
              onTap: () {
                setState(() => _activeFilter = _activeFilter == 'following' ? 'all' : 'following');
                _applyFilters();
              },
            ),
            const SizedBox(width: 8),
            _buildQuickChip(
              label: 'Liked ❤️',
              isSelected: _activeFilter == 'liked',
              onTap: () {
                setState(() => _activeFilter = _activeFilter == 'liked' ? 'all' : 'liked');
                _applyFilters();
              },
            ),
            const SizedBox(width: 8),
            _buildQuickChip(
              label: 'Saved 🔖',
              isSelected: _activeFilter == 'saved',
              onTap: () {
                setState(() => _activeFilter = _activeFilter == 'saved' ? 'all' : 'saved');
                _applyFilters();
              },
            ),
            if (_selectedAuthor != null) ...[
              const SizedBox(width: 8),
              _buildQuickChip(
                label: '@$_selectedAuthor ✕',
                isSelected: true,
                onTap: () {
                  setState(() => _selectedAuthor = null);
                  _applyFilters();
                },
              ),
            ],
            const SizedBox(width: 8),
            InkWell(
              onTap: _showFilterModal,
              borderRadius: BorderRadius.circular(18),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.tune_rounded, size: 14, color: Color(0xFF475569)),
                    const SizedBox(width: 4),
                    Text(
                      'More Filters',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF475569),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickChip({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isSelected ? const Color(0xFF0F172A) : const Color(0xFFE2E8F0),
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
            color: isSelected ? Colors.white : const Color(0xFF475569),
          ),
        ),
      ),
    );
  }

  Widget _buildHomeBody() {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: Color(0xFFE60023)),
            SizedBox(height: 16),
            Text('Loading Punny feed...'),
          ],
        ),
      );
    }

    return Container(
      color: const Color(0xFFF8FAFC),
      child: Column(
        children: [
          // Quick Filter Chips Bar
          _buildQuickFilterChips(),

          // Active Filter Description Bar (if custom filtered)
          if (_hasActiveFilter)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              color: const Color(0xFFFEF2F2),
              child: Row(
                children: [
                  const Icon(Icons.filter_alt_rounded, size: 16, color: Color(0xFFE60023)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Showing: $_filterDescription (${_displayedPosts.length} pins)',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF991B1B),
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  InkWell(
                    onTap: _resetFilters,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      child: Text(
                        'Clear',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFFE60023),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

          // Main Pins Grid or Empty View
          Expanded(
            child: RefreshIndicator(
              color: const Color(0xFFE60023),
              onRefresh: () => _loadPosts(isManualRefresh: true),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  int crossAxisCount = 2;
                  if (constraints.maxWidth >= 1400) {
                    crossAxisCount = 5;
                  } else if (constraints.maxWidth >= 1000) {
                    crossAxisCount = 4;
                  } else if (constraints.maxWidth >= 650) {
                    crossAxisCount = 3;
                  }

                  if (_displayedPosts.isEmpty) {
                    return Center(
                      child: SingleChildScrollView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        child: Padding(
                          padding: const EdgeInsets.all(32.0),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(20),
                                decoration: const BoxDecoration(
                                  color: Colors.white,
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  _activeFilter == 'following'
                                      ? Icons.people_outline_rounded
                                      : _activeFilter == 'saved'
                                          ? Icons.bookmark_border_rounded
                                          : _activeFilter == 'liked'
                                              ? Icons.favorite_border_rounded
                                              : Icons.photo_library_outlined,
                                  size: 56,
                                  color: const Color(0xFF94A3B8),
                                ),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                _activeFilter == 'following'
                                    ? 'No Pins from Followed Creators'
                                    : _activeFilter == 'saved'
                                        ? 'No Saved Pins Yet'
                                        : _activeFilter == 'liked'
                                            ? 'No Liked Pins Yet'
                                            : 'No Pins Match Filters',
                                style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                _activeFilter == 'following'
                                    ? 'Follow creators by visiting pin details to see their posts here!'
                                    : _activeFilter == 'saved'
                                        ? 'Tap the bookmark icon on any pin to save it to your collection.'
                                        : _activeFilter == 'liked'
                                            ? 'Tap the heart icon on any pin you love to collect them.'
                                            : 'Try choosing another filter option or reset filters.',
                                textAlign: TextAlign.center,
                                style: GoogleFonts.inter(color: const Color(0xFF64748B), fontSize: 13),
                              ),
                              const SizedBox(height: 20),
                              ElevatedButton.icon(
                                onPressed: _resetFilters,
                                icon: const Icon(Icons.refresh_rounded, size: 18),
                                label: const Text('View All Pins'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFFE60023),
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }

                  return Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 1400),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
                        child: MasonryGridView.count(
                          crossAxisCount: crossAxisCount,
                          mainAxisSpacing: 18,
                          crossAxisSpacing: 18,
                          itemCount: _displayedPosts.length,
                          itemBuilder: (context, index) {
                            final post = _displayedPosts[index];
                            return PinCard(
                              post: post,
                              onLikeToggle: () => _handleLikeToggle(post),
                              onEdit: () => _handleEditPost(post),
                              onDelete: () => _handleDeletePost(post),
                              onSaveToggle: _applyFilters,
                            );
                          },
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> get _pages => [
        _buildHomeBody(),
        const SearchPage(),
        AddPage(
          onPostCreated: () {
            _loadPosts();
            setState(() => _currentIndex = 0);
          },
        ),
        const NotificationPage(),
        UserPage(
          onDataChanged: _loadPosts,
        ),
      ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 24,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: const BoxDecoration(
                color: Color(0xFFE60023),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.push_pin_rounded, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 12),
            Text(
              "Punny",
              style: GoogleFonts.poppins(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                color: const Color(0xFF0F172A),
              ),
            ),
          ],
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        actions: [
          // Refresh Feed Button
          IconButton(
            tooltip: 'Refresh Feed',
            icon: _isRefreshing
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Color(0xFFE60023),
                    ),
                  )
                : const Icon(Icons.refresh_rounded, color: Color(0xFF0F172A)),
            onPressed: () => _loadPosts(isManualRefresh: true),
          ),
          // Filter Posts Button
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: Stack(
              alignment: Alignment.center,
              children: [
                IconButton(
                  tooltip: 'Filter & Sort Pins',
                  icon: Icon(
                    Icons.tune_rounded,
                    color: _hasActiveFilter ? const Color(0xFFE60023) : const Color(0xFF0F172A),
                  ),
                  onPressed: _showFilterModal,
                ),
                if (_hasActiveFilter)
                  Positioned(
                    top: 10,
                    right: 10,
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: Color(0xFFE60023),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
      body: _pages[_currentIndex],
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 20,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: Center(
          heightFactor: 1.0,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 800),
            child: SalomonBottomBar(
              currentIndex: _currentIndex,
              onTap: (index) {
                setState(() {
                  _currentIndex = index;
                });
                if (index == 0) {
                  _applyFilters();
                }
              },
              items: [
                SalomonBottomBarItem(
                  icon: const Icon(Icons.home_rounded),
                  title: const Text("Home"),
                  selectedColor: const Color(0xFFE60023),
                ),
                SalomonBottomBarItem(
                  icon: const Icon(Icons.search_rounded),
                  title: const Text("Search"),
                  selectedColor: const Color(0xFFEC4899),
                ),
                SalomonBottomBarItem(
                  icon: const Icon(Icons.add_circle_outline_rounded),
                  title: const Text("Create"),
                  selectedColor: const Color(0xFFE60023),
                ),
                SalomonBottomBarItem(
                  icon: const Icon(Icons.notifications_rounded),
                  title: const Text("Notifications"),
                  selectedColor: const Color(0xFF14B8A6),
                ),
                SalomonBottomBarItem(
                  icon: const Icon(Icons.person_rounded),
                  title: const Text("Profile"),
                  selectedColor: const Color(0xFF3B82F6),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
