import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import '../models/post.dart';
import '../services/api_service.dart';
import '../services/video_player.dart';

class EditMediaItem {
  final String id;
  String url; // original remote/asset or data URI
  Uint8List? newBytes; // newly replaced file bytes
  String? newFileName;
  bool isVideo;

  EditMediaItem({
    required this.id,
    required this.url,
    this.newBytes,
    this.newFileName,
    this.isVideo = false,
  });
}

class EditPostDialog extends StatefulWidget {
  final Post post;
  final VoidCallback onUpdated;

  const EditPostDialog({
    super.key,
    required this.post,
    required this.onUpdated,
  });

  @override
  State<EditPostDialog> createState() => _EditPostDialogState();
}

class _EditPostDialogState extends State<EditPostDialog> {
  late TextEditingController _titleController;
  late TextEditingController _urlController;
  final ImagePicker _picker = ImagePicker();

  late bool _isVideoPost;
  final List<EditMediaItem> _mediaItems = [];
  int _activeMediaIndex = 0;

  bool _isLoading = false;
  bool _useUrlInput = false;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.post.title);
    _urlController = TextEditingController();

    _isVideoPost = widget.post.isVideoPost;
    if (_isVideoPost) {
      final videos = widget.post.videoUrls.isNotEmpty
          ? widget.post.videoUrls
          : (widget.post.videoUrl != null ? [widget.post.videoUrl!] : <String>[]);
      for (int i = 0; i < videos.length; i++) {
        _mediaItems.add(EditMediaItem(
          id: 'vid-$i-${DateTime.now().microsecondsSinceEpoch}',
          url: videos[i],
          isVideo: true,
        ));
      }
    } else {
      final images = widget.post.imageUrls.isNotEmpty
          ? widget.post.imageUrls
          : (widget.post.imageUrl.isNotEmpty ? [widget.post.imageUrl] : <String>[]);
      for (int i = 0; i < images.length; i++) {
        _mediaItems.add(EditMediaItem(
          id: 'img-$i-${DateTime.now().microsecondsSinceEpoch}',
          url: images[i],
          isVideo: false,
        ));
      }
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _urlController.dispose();
    super.dispose();
  }

  Future<void> _replaceMediaAt(int index) async {
    if (index < 0 || index >= _mediaItems.length) return;
    final item = _mediaItems[index];

    try {
      if (item.isVideo) {
        final XFile? file = await _picker.pickVideo(source: ImageSource.gallery);
        if (file == null) return;
        final length = await file.length();
        if (length > 15 * 1024 * 1024) {
          _showError('Video exceeds 15MB limit');
          return;
        }
        final bytes = await file.readAsBytes();
        final ext = file.name.toLowerCase().endsWith('.webm') ? 'webm' : 'mp4';
        final dataUrl = 'data:video/$ext;base64,${base64Encode(bytes)}';

        setState(() {
          item.url = dataUrl;
          item.newBytes = bytes;
          item.newFileName = file.name;
        });
      } else {
        final XFile? file = await _picker.pickImage(
          source: ImageSource.gallery,
          maxWidth: 1600,
          maxHeight: 1600,
          imageQuality: 85,
        );
        if (file == null) return;
        final bytes = await file.readAsBytes();
        final dataUrl = 'data:image/jpeg;base64,${base64Encode(bytes)}';

        setState(() {
          item.url = dataUrl;
          item.newBytes = bytes;
          item.newFileName = file.name;
        });
      }
    } catch (e) {
      _showError('Error replacing file: $e');
    }
  }

  Future<void> _addNewMedia() async {
    if (_mediaItems.length >= 5) {
      _showError('Maximum 5 ${_isVideoPost ? 'videos' : 'images'} allowed');
      return;
    }

    try {
      if (_isVideoPost) {
        final XFile? file = await _picker.pickVideo(source: ImageSource.gallery);
        if (file == null) return;
        final length = await file.length();
        if (length > 15 * 1024 * 1024) {
          _showError('Video exceeds 15MB limit');
          return;
        }
        final bytes = await file.readAsBytes();
        final ext = file.name.toLowerCase().endsWith('.webm') ? 'webm' : 'mp4';
        final dataUrl = 'data:video/$ext;base64,${base64Encode(bytes)}';

        setState(() {
          _mediaItems.add(EditMediaItem(
            id: 'vid-${DateTime.now().microsecondsSinceEpoch}',
            url: dataUrl,
            newBytes: bytes,
            newFileName: file.name,
            isVideo: true,
          ));
          _activeMediaIndex = _mediaItems.length - 1;
        });
      } else {
        final XFile? file = await _picker.pickImage(
          source: ImageSource.gallery,
          maxWidth: 1600,
          maxHeight: 1600,
          imageQuality: 85,
        );
        if (file == null) return;
        final bytes = await file.readAsBytes();
        final dataUrl = 'data:image/jpeg;base64,${base64Encode(bytes)}';

        setState(() {
          _mediaItems.add(EditMediaItem(
            id: 'img-${DateTime.now().microsecondsSinceEpoch}',
            url: dataUrl,
            newBytes: bytes,
            newFileName: file.name,
            isVideo: false,
          ));
          _activeMediaIndex = _mediaItems.length - 1;
        });
      }
    } catch (e) {
      _showError('Error adding file: $e');
    }
  }

  void _deleteMediaAt(int index) {
    if (_mediaItems.length <= 1) {
      _showError('Post must have at least one ${_isVideoPost ? 'video' : 'image'}');
      return;
    }

    setState(() {
      _mediaItems.removeAt(index);
      if (_activeMediaIndex >= _mediaItems.length) {
        _activeMediaIndex = _mediaItems.length - 1;
      }
    });
  }

  void _replaceWithUrl() {
    final url = _urlController.text.trim();
    if (url.isEmpty) return;

    if (_activeMediaIndex < 0 || _activeMediaIndex >= _mediaItems.length) return;

    setState(() {
      _mediaItems[_activeMediaIndex].url = url;
      _mediaItems[_activeMediaIndex].newBytes = null;
      _mediaItems[_activeMediaIndex].newFileName = null;
      _urlController.clear();
      _useUrlInput = false;
    });
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(backgroundColor: Colors.redAccent, content: Text(msg)),
    );
  }

  Future<void> _saveChanges() async {
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      _showError('Please enter a title for your pin');
      return;
    }

    if (_mediaItems.isEmpty) {
      _showError('Please keep at least one ${_isVideoPost ? 'video' : 'image'}');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final List<String> resolvedUrls = _mediaItems.map((m) => m.url).toList();

      if (_isVideoPost) {
        await ApiService().updatePost(
          id: widget.post.id,
          title: title,
          category: widget.post.category,
          videoUrl: resolvedUrls.first,
          videoUrls: resolvedUrls,
        );
      } else {
        await ApiService().updatePost(
          id: widget.post.id,
          title: title,
          category: widget.post.category,
          imageUrl: resolvedUrls.first,
          imageUrls: resolvedUrls,
        );
      }

      if (mounted) {
        widget.onUpdated();
        Navigator.of(context).pop(true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: Color(0xFF10B981),
            content: Text('Pin updated successfully!'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        _showError('Error updating pin: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final activeItem = (_activeMediaIndex >= 0 && _activeMediaIndex < _mediaItems.length)
        ? _mediaItems[_activeMediaIndex]
        : null;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 620, maxHeight: 780),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(
                        _isVideoPost ? Icons.videocam_rounded : Icons.photo_library_rounded,
                        color: const Color(0xFF6366F1),
                        size: 24,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _isVideoPost ? 'Edit Videos' : 'Edit Images',
                        style: GoogleFonts.inter(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF0F172A),
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Color(0xFF64748B)),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Active Media Preview
                      if (activeItem != null)
                        ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: Container(
                            constraints: const BoxConstraints(minHeight: 220, maxHeight: 340),
                            width: double.infinity,
                            color: const Color(0xFF0F172A),
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                Center(
                                  child: activeItem.isVideo
                                      ? SizedBox.expand(
                                          key: ValueKey<String>('edit-vid-${activeItem.url}'),
                                          child: buildVideoPreview(activeItem.url, showControls: true),
                                        )
                                      : buildSafeImage(activeItem.url, fit: BoxFit.contain),
                                ),
                                // Index badge
                                Positioned(
                                  top: 10,
                                  left: 10,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: Colors.black.withValues(alpha: 0.7),
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                    child: Text(
                                      '${_activeMediaIndex + 1} of ${_mediaItems.length}',
                                      style: GoogleFonts.inter(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                      const SizedBox(height: 14),

                      // Thumbnails strip of current post images/videos
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '${_isVideoPost ? 'Videos' : 'Images'} (${_mediaItems.length}/5):',
                            style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: const Color(0xFF475569)),
                          ),
                          if (_mediaItems.length < 5)
                            TextButton.icon(
                              onPressed: _addNewMedia,
                              icon: const Icon(Icons.add, size: 16),
                              label: Text('Add ${_isVideoPost ? 'Video' : 'Image'}'),
                              style: TextButton.styleFrom(
                                foregroundColor: const Color(0xFF6366F1),
                                visualDensity: VisualDensity.compact,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),

                      SizedBox(
                        height: 76,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: _mediaItems.length,
                          separatorBuilder: (context, index) => const SizedBox(width: 10),
                          itemBuilder: (context, idx) {
                            final item = _mediaItems[idx];
                            final isSel = idx == _activeMediaIndex;

                            return Stack(
                              clipBehavior: Clip.none,
                              children: [
                                GestureDetector(
                                  onTap: () => setState(() => _activeMediaIndex = idx),
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 150),
                                    width: 72,
                                    height: 72,
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: isSel ? const Color(0xFFE60023) : const Color(0xFFE2E8F0),
                                        width: isSel ? 2.5 : 1.0,
                                      ),
                                    ),
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(10),
                                      child: item.isVideo
                                          ? buildVideoThumbnail(videoUrl: item.url)
                                          : buildSafeImage(item.url, fit: BoxFit.cover),
                                    ),
                                  ),
                                ),
                                // Delete badge if more than 1 item
                                if (_mediaItems.length > 1)
                                  Positioned(
                                    top: -4,
                                    right: -4,
                                    child: GestureDetector(
                                      onTap: () => _deleteMediaAt(idx),
                                      child: Container(
                                        padding: const EdgeInsets.all(2),
                                        decoration: const BoxDecoration(color: Colors.redAccent, shape: BoxShape.circle),
                                        child: const Icon(Icons.close, size: 12, color: Colors.white),
                                      ),
                                    ),
                                  ),
                              ],
                            );
                          },
                        ),
                      ),

                      const SizedBox(height: 14),

                      // Replace selected item actions
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () => _replaceMediaAt(_activeMediaIndex),
                              icon: Icon(_isVideoPost ? Icons.video_file_outlined : Icons.image_outlined, size: 18),
                              label: Text('Replace Selected #${_activeMediaIndex + 1}'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: const Color(0xFF6366F1),
                                side: const BorderSide(color: Color(0xFFC7D2FE)),
                                padding: const EdgeInsets.symmetric(vertical: 11),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          OutlinedButton.icon(
                            onPressed: () => setState(() => _useUrlInput = !_useUrlInput),
                            icon: const Icon(Icons.link, size: 18),
                            label: Text(_useUrlInput ? 'Hide URL' : 'Use URL'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFF64748B),
                              side: const BorderSide(color: Color(0xFFE2E8F0)),
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                          ),
                        ],
                      ),

                      if (_useUrlInput) ...[
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _urlController,
                                style: GoogleFonts.inter(fontSize: 13),
                                decoration: InputDecoration(
                                  labelText: 'Replace with URL',
                                  hintText: 'https://...',
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            ElevatedButton(
                              onPressed: _replaceWithUrl,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF6366F1),
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                              child: const Text('Apply'),
                            ),
                          ],
                        ),
                      ],

                      const SizedBox(height: 16),
                      // Title input
                      TextField(
                        controller: _titleController,
                        style: GoogleFonts.inter(fontWeight: FontWeight.w500),
                        decoration: InputDecoration(
                          labelText: 'Pin Title',
                          hintText: 'Add an inspiring title...',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 18),
              // Action buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
                    child: Text('Cancel', style: GoogleFonts.inter(color: const Color(0xFF64748B))),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: _isLoading ? null : _saveChanges,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF6366F1),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 0,
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                          )
                        : Text('Save Changes', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
