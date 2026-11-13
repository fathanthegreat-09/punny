import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/post.dart';
import '../services/api_service.dart';
import '../widgets/edit_post_dialog.dart';
import '../widgets/pin_card.dart';

class SearchPage extends StatefulWidget {
  const SearchPage({super.key});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final _searchController = TextEditingController();
  List<Post> _searchResults = [];
  bool _isLoading = false;
  Timer? _debounce;

  @override
  void dispose() {
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      _performSearch(query.trim());
    });
  }

  Future<void> _performSearch(String query) async {
    if (query.isEmpty) {
      setState(() {
        _searchResults = [];
        _isLoading = false;
      });
      return;
    }

    setState(() => _isLoading = true);

    try {
      final results = await ApiService().fetchPosts(search: query);
      setState(() {
        _searchResults = results;
        _isLoading = false;
      });
    } catch (_) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _handleLikeToggle(Post post) async {
    final currentUser = ApiService().currentUser;
    final isCurrentlyLiked = post.isLikedBy(currentUser);

    setState(() {
      final index = _searchResults.indexWhere((p) => p.id == post.id);
      if (index != -1) {
        final updatedLikes = List<String>.from(_searchResults[index].likes);
        if (isCurrentlyLiked) {
          updatedLikes.remove(currentUser);
        } else {
          updatedLikes.add(currentUser);
        }
        _searchResults[index] = _searchResults[index].copyWith(
          likes: updatedLikes,
          likeCount: updatedLikes.length,
        );
      }
    });

    try {
      await ApiService().toggleLike(post.id, currentUser);
    } catch (_) {
      _performSearch(_searchController.text.trim());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1000),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Search Bar
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.04),
                          blurRadius: 15,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: TextField(
                      controller: _searchController,
                      onChanged: _onSearchChanged,
                      style: GoogleFonts.inter(color: const Color(0xFF0F172A)),
                      decoration: InputDecoration(
                        hintText: "Search pins by title or keyword...",
                        hintStyle: GoogleFonts.inter(color: const Color(0xFF94A3B8)),
                        prefixIcon: const Icon(Icons.search, color: Color(0xFF64748B)),
                        suffixIcon: _searchController.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear, size: 18),
                                onPressed: () {
                                  _searchController.clear();
                                  _performSearch('');
                                },
                              )
                            : null,
                        filled: true,
                        fillColor: Colors.white,
                        contentPadding: const EdgeInsets.symmetric(vertical: 16.0),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16.0),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Search Results or Trending Tags
                  if (_searchController.text.isNotEmpty) ...[
                    Text(
                      _isLoading ? "Searching..." : "Results (${_searchResults.length})",
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: _isLoading
                          ? const Center(
                              child: CircularProgressIndicator(color: Color(0xFFE60023)),
                            )
                          : _searchResults.isEmpty
                              ? Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const Icon(Icons.search_off, size: 48, color: Color(0xFFCBD5E1)),
                                      const SizedBox(height: 12),
                                      Text(
                                        'No pins found matching "${_searchController.text}"',
                                        style: GoogleFonts.inter(
                                          fontWeight: FontWeight.w600,
                                          color: const Color(0xFF64748B),
                                        ),
                                      ),
                                    ],
                                  ),
                                )
                              : MasonryGridView.count(
                                  crossAxisCount: 2,
                                  mainAxisSpacing: 16,
                                  crossAxisSpacing: 16,
                                  itemCount: _searchResults.length,
                                  itemBuilder: (context, index) {
                                    final post = _searchResults[index];
                                    return PinCard(
                                      post: post,
                                      onLikeToggle: () => _handleLikeToggle(post),
                                      onEdit: () {
                                        showDialog(
                                          context: context,
                                          builder: (_) => EditPostDialog(
                                            post: post,
                                            onUpdated: () => _performSearch(_searchController.text.trim()),
                                          ),
                                        );
                                      },
                                      onDelete: () async {
                                        await ApiService().deletePost(post.id);
                                        _performSearch(_searchController.text.trim());
                                      },
                                    );
                                  },
                                ),
                    ),
                  ] else ...[
                    Text(
                      "Trending Ideas",
                      style: GoogleFonts.inter(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 10.0,
                      runSpacing: 10.0,
                      children: [
                        _buildChip("Tokyo"),
                        _buildChip("Aesthetic"),
                        _buildChip("Workspace"),
                        _buildChip("Sunset"),
                        _buildChip("Matcha"),
                        _buildChip("Minimalist"),
                        _buildChip("Cyberpunk"),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildChip(String label) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () {
          _searchController.text = label;
          _performSearch(label);
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            border: Border.all(color: const Color(0xFFE2E8F0)),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            label,
            style: GoogleFonts.inter(
              color: const Color(0xFF334155),
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
        ),
      ),
    );
  }
}