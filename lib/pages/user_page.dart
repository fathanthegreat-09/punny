import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/post.dart';
import '../services/api_service.dart';
import '../widgets/edit_post_dialog.dart';
import '../widgets/pin_card.dart';

class UserPage extends StatefulWidget {
  final VoidCallback? onDataChanged;

  const UserPage({super.key, this.onDataChanged});

  @override
  State<UserPage> createState() => _UserPageState();
}

class _UserPageState extends State<UserPage> {
  int _selectedTabIndex = 0; // 0: Created, 1: Saved, 2: Liked, 3: Following
  List<Post> _myPosts = [];
  List<Post> _savedPosts = [];
  List<Post> _likedPosts = [];
  List<String> _followingUsers = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUserData();
    ApiService().changeNotifier.addListener(_onServiceDataChanged);
  }

  @override
  void dispose() {
    ApiService().changeNotifier.removeListener(_onServiceDataChanged);
    super.dispose();
  }

  void _onServiceDataChanged() {
    if (mounted) {
      _loadUserData(skipApi: true);
    }
  }

  Future<void> _loadUserData({bool skipApi = false}) async {
    if (!skipApi) {
      setState(() => _isLoading = true);
      try {
        await ApiService().fetchPosts(author: ApiService().currentUser);
      } catch (_) {}
    }

    if (!mounted) return;

    final myPosts = ApiService().getUserPosts(ApiService().currentUser);
    final savedPosts = ApiService().getSavedPosts();
    final likedPosts = ApiService().getLikedPosts();
    final following = ApiService().getFollowingList();

    setState(() {
      _myPosts = myPosts;
      _savedPosts = savedPosts;
      _likedPosts = likedPosts;
      _followingUsers = following;
      _isLoading = false;
    });
  }

  Future<void> _handleLikeToggle(Post post) async {
    final currentUser = ApiService().currentUser;
    await ApiService().toggleLike(post.id, currentUser);
    widget.onDataChanged?.call();
    _loadUserData(skipApi: true);
  }

  void _handleEditPost(Post post) {
    showDialog(
      context: context,
      builder: (ctx) => EditPostDialog(
        post: post,
        onUpdated: () {
          _loadUserData();
          widget.onDataChanged?.call();
        },
      ),
    );
  }

  Future<void> _handleDeletePost(Post post) async {
    try {
      await ApiService().deletePost(post.id);
      widget.onDataChanged?.call();
      _loadUserData(skipApi: true);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFF1E293B),
            content: Text('Deleted "${post.title}"'),
          ),
        );
      }
    } catch (e) {
      _loadUserData(skipApi: true);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.redAccent,
            content: Text('Failed to delete: $e'),
          ),
        );
      }
    }
  }

  void _handleUnfollow(String author) {
    ApiService().toggleFollow(author);
    _loadUserData(skipApi: true);
    widget.onDataChanged?.call();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        duration: const Duration(seconds: 2),
        backgroundColor: const Color(0xFF1E293B),
        content: Text('Unfollowed @$author'),
        action: SnackBarAction(
          label: 'Undo',
          textColor: const Color(0xFF818CF8),
          onPressed: () {
            ApiService().toggleFollow(author);
            _loadUserData(skipApi: true);
            widget.onDataChanged?.call();
          },
        ),
      ),
    );
  }

  void _showAuthorPinsModal(String author) {
    final authorPins = ApiService().getUserPosts(author);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.75,
          maxChildSize: 0.95,
          minChildSize: 0.4,
          builder: (context, scrollController) {
            return Container(
              decoration: const BoxDecoration(
                color: Color(0xFFF8FAFC),
                borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
              ),
              child: Column(
                children: [
                  // Handle
                  Center(
                    child: Container(
                      margin: const EdgeInsets.only(top: 12, bottom: 8),
                      width: 44,
                      height: 5,
                      decoration: BoxDecoration(
                        color: const Color(0xFFCBD5E1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  // Modal Header
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 20,
                          backgroundColor: const Color(0xFF6366F1),
                          child: Text(
                            author.isNotEmpty ? author[0].toUpperCase() : 'U',
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                author,
                                style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.bold),
                              ),
                              Text(
                                '@${author.toLowerCase()} • ${authorPins.length} pins',
                                style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B)),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  // Author Pins Grid
                  Expanded(
                    child: authorPins.isEmpty
                        ? Center(
                            child: Text(
                              'No pins posted by @$author yet',
                              style: GoogleFonts.inter(color: const Color(0xFF94A3B8)),
                            ),
                          )
                        : Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: LayoutBuilder(
                              builder: (context, constraints) {
                                int crossAxisCount = constraints.maxWidth >= 700 ? 3 : 2;
                                return MasonryGridView.count(
                                  controller: scrollController,
                                  crossAxisCount: crossAxisCount,
                                  mainAxisSpacing: 14,
                                  crossAxisSpacing: 14,
                                  itemCount: authorPins.length,
                                  itemBuilder: (context, index) {
                                    final post = authorPins[index];
                                    return PinCard(
                                      post: post,
                                      onLikeToggle: () => _handleLikeToggle(post),
                                      onEdit: () => _handleEditPost(post),
                                      onDelete: () => _handleDeletePost(post),
                                      onSaveToggle: () => _loadUserData(skipApi: true),
                                    );
                                  },
                                );
                              },
                            ),
                          ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final totalLikes = _myPosts.fold<int>(0, (sum, post) => sum + post.likeCount);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1000),
            child: RefreshIndicator(
              color: const Color(0xFFE60023),
              onRefresh: () => _loadUserData(),
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 20.0),
                child: Column(
                  children: [
                    // Profile Avatar & Badges
                    Stack(
                      alignment: Alignment.bottomRight,
                      children: [
                        CircleAvatar(
                          radius: 46,
                          backgroundColor: const Color(0xFFEEF2FF),
                          child: Text(
                            ApiService().currentUser.isNotEmpty
                                ? ApiService().currentUser[0].toUpperCase()
                                : 'U',
                            style: GoogleFonts.inter(
                              fontSize: 38,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF6366F1),
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(
                            color: Color(0xFF10B981),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.check, size: 14, color: Colors.white),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      ApiService().currentUser,
                      style: GoogleFonts.inter(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF0F172A),
                      ),
                    ),
                    Text(
                      "@${ApiService().currentUser.toLowerCase()}_dev",
                      style: GoogleFonts.inter(
                        color: const Color(0xFF94A3B8),
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Stats Bar
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.03),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _buildStatCard(
                            "${_myPosts.length}",
                            "My Pins",
                            onTap: () => setState(() => _selectedTabIndex = 0),
                            isActive: _selectedTabIndex == 0,
                          ),
                          Container(width: 1, height: 32, color: const Color(0xFFF1F5F9)),
                          _buildStatCard(
                            "$totalLikes",
                            "Loves Received",
                          ),
                          Container(width: 1, height: 32, color: const Color(0xFFF1F5F9)),
                          _buildStatCard(
                            "${_followingUsers.length}",
                            "Following",
                            onTap: () => setState(() => _selectedTabIndex = 3),
                            isActive: _selectedTabIndex == 3,
                          ),
                          Container(width: 1, height: 32, color: const Color(0xFFF1F5F9)),
                          _buildStatCard("1.2k", "Followers"),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Custom Profile Navigation Tabs
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE2E8F0).withValues(alpha: 0.6),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        children: [
                          _buildNavTab(0, Icons.push_pin_rounded, "Pins", _myPosts.length),
                          _buildNavTab(1, Icons.bookmark_rounded, "Saved", _savedPosts.length),
                          _buildNavTab(2, Icons.favorite_rounded, "Liked", _likedPosts.length),
                          _buildNavTab(3, Icons.people_alt_rounded, "Following", _followingUsers.length),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Tab Content
                    _buildActiveTabContent(),

                    const SizedBox(height: 36),

                    // Logout Button
                    OutlinedButton.icon(
                      onPressed: () {
                        Navigator.pushReplacementNamed(context, '/login');
                      },
                      icon: const Icon(Icons.logout_rounded, color: Colors.redAccent, size: 18),
                      label: Text(
                        'Log Out',
                        style: GoogleFonts.inter(
                          color: Colors.redAccent,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(48),
                        side: const BorderSide(color: Color(0xFFFECDD3)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavTab(int index, IconData icon, String title, int count) {
    final isSelected = _selectedTabIndex == index;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _selectedTabIndex = index),
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.06),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    icon,
                    size: 16,
                    color: isSelected ? const Color(0xFFE60023) : const Color(0xFF64748B),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    title,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                      color: isSelected ? const Color(0xFF0F172A) : const Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                "$count",
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: isSelected ? const Color(0xFFE60023) : const Color(0xFF94A3B8),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActiveTabContent() {
    if (_isLoading) {
      return const Padding(
        padding: EdgeInsets.all(40.0),
        child: Center(child: CircularProgressIndicator(color: Color(0xFFE60023))),
      );
    }

    switch (_selectedTabIndex) {
      case 0:
        return _buildCreatedPinsTab();
      case 1:
        return _buildSavedPinsTab();
      case 2:
        return _buildLikedPinsTab();
      case 3:
        return _buildFollowingTab();
      default:
        return _buildCreatedPinsTab();
    }
  }

  Widget _buildCreatedPinsTab() {
    if (_myPosts.isEmpty) {
      return _buildEmptyState(
        icon: Icons.push_pin_outlined,
        title: "No Pins Created Yet",
        description: "Express your creativity and share pins with the Punny community!",
        buttonLabel: "Create First Pin",
        onButtonPressed: () {
          // Switch to create pin tab
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Tap the '+' button in the bottom navigation to create a pin!")),
          );
        },
      );
    }

    return _buildPinsGrid(_myPosts);
  }

  Widget _buildSavedPinsTab() {
    if (_savedPosts.isEmpty) {
      return _buildEmptyState(
        icon: Icons.bookmark_border_rounded,
        title: "No Saved Pins Yet",
        description: "Save pins you love from the home feed or detail page to collect them here.",
        buttonLabel: null,
      );
    }

    return _buildPinsGrid(_savedPosts);
  }

  Widget _buildLikedPinsTab() {
    if (_likedPosts.isEmpty) {
      return _buildEmptyState(
        icon: Icons.favorite_border_rounded,
        title: "No Liked Pins Yet",
        description: "Tap the heart on any pin you love, and they will show up here.",
        buttonLabel: null,
      );
    }

    return _buildPinsGrid(_likedPosts);
  }

  Widget _buildFollowingTab() {
    if (_followingUsers.isEmpty) {
      return _buildEmptyState(
        icon: Icons.people_outline_rounded,
        title: "Not Following Anyone Yet",
        description: "Follow creators on their pin detail pages or pin cards to see them here!",
        buttonLabel: null,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 12.0),
          child: Text(
            "Following ${_followingUsers.length} creators",
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF64748B),
            ),
          ),
        ),
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _followingUsers.length,
          separatorBuilder: (context, index) => const SizedBox(height: 10),
          itemBuilder: (context, index) {
            final author = _followingUsers[index];
            final authorPostCount = ApiService().getPostCountByAuthor(author);

            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFF1F5F9)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.02),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  // Author Avatar
                  InkWell(
                    onTap: () => _showAuthorPinsModal(author),
                    child: CircleAvatar(
                      radius: 22,
                      backgroundColor: const Color(0xFF6366F1),
                      child: Text(
                        author.isNotEmpty ? author[0].toUpperCase() : 'U',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),

                  // Author Info
                  Expanded(
                    child: InkWell(
                      onTap: () => _showAuthorPinsModal(author),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            author,
                            style: GoogleFonts.inter(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF0F172A),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            "@${author.toLowerCase()} • $authorPostCount ${authorPostCount == 1 ? 'pin' : 'pins'}",
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              color: const Color(0xFF94A3B8),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // View Pins Action
                  TextButton.icon(
                    onPressed: () => _showAuthorPinsModal(author),
                    icon: const Icon(Icons.grid_view_rounded, size: 14),
                    label: const Text('Pins'),
                    style: TextButton.styleFrom(
                      foregroundColor: const Color(0xFF6366F1),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      textStyle: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                  ),

                  const SizedBox(width: 4),

                  // Unfollow Button
                  OutlinedButton(
                    onPressed: () => _handleUnfollow(author),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Color(0xFFE2E8F0)),
                      foregroundColor: const Color(0xFF64748B),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    ),
                    child: Text(
                      'Unfollow',
                      style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildPinsGrid(List<Post> posts) {
    return LayoutBuilder(
      builder: (context, constraints) {
        int crossAxisCount = constraints.maxWidth >= 700 ? 3 : 2;
        return MasonryGridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: crossAxisCount,
          mainAxisSpacing: 16,
          crossAxisSpacing: 16,
          itemCount: posts.length,
          itemBuilder: (context, index) {
            final post = posts[index];
            return PinCard(
              post: post,
              onLikeToggle: () => _handleLikeToggle(post),
              onEdit: () => _handleEditPost(post),
              onDelete: () => _handleDeletePost(post),
              onSaveToggle: () => _loadUserData(skipApi: true),
            );
          },
        );
      },
    );
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String description,
    String? buttonLabel,
    VoidCallback? onButtonPressed,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(36),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFF1F5F9)),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: Color(0xFFF8FAFC),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 40, color: const Color(0xFFCBD5E1)),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF334155),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            description,
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              color: const Color(0xFF94A3B8),
              fontSize: 13,
            ),
          ),
          if (buttonLabel != null && onButtonPressed != null) ...[
            const SizedBox(height: 18),
            ElevatedButton(
              onPressed: onButtonPressed,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFE60023),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              ),
              child: Text(
                buttonLabel,
                style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 13),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStatCard(String value, String label, {VoidCallback? onTap, bool isActive = false}) {
    final content = Column(
      children: [
        Text(
          value,
          style: GoogleFonts.inter(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: isActive ? const Color(0xFFE60023) : const Color(0xFF0F172A),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: GoogleFonts.inter(
            color: isActive ? const Color(0xFFE60023) : const Color(0xFF64748B),
            fontSize: 12,
            fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ],
    );

    if (onTap != null) {
      return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: content,
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: content,
    );
  }
}
