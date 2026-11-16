import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import '../models/post.dart';
import '../models/upload_media_item.dart';
import '../services/api_service.dart';
import '../services/drag_drop.dart';
import '../services/video_player.dart';

class AddPage extends StatefulWidget {
  final VoidCallback? onPostCreated;

  const AddPage({super.key, this.onPostCreated});

  @override
  State<AddPage> createState() => _AddPageState();
}

class _AddPageState extends State<AddPage> {
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _linkController = TextEditingController();
  final _urlInputController = TextEditingController();
  final _picker = ImagePicker();

  final List<UploadMediaItem> _selectedMedia = [];
  int _activePreviewIndex = 0;
  BoxFit _previewFit = BoxFit.contain;
  bool _useUrlTab = false;
  bool _isLoading = false;
  bool _publishAsCarousel = true;
  String _selectedCategory = 'Aesthetic';

  static const List<String> _categories = [
    'Aesthetic',
    'Anime',
    'Art & Design',
    'Photography',
    'Wallpapers',
    'Gaming',
    'Quotes',
    'Illustration',
    'Video',
    'Ads & Marketing',
  ];

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _linkController.dispose();
    _urlInputController.dispose();
    super.dispose();
  }

  // ─── Pickers ─────────────────────────────────────────────────────────────

  Future<void> _pickImages() async {
    try {
      final List<XFile> pickedList = await _picker.pickMultiImage(
        maxWidth: 1600,
        maxHeight: 1600,
        imageQuality: 82,
      );

      if (pickedList.isNotEmpty) {
        final List<UploadMediaItem> newItems = [];
        for (final file in pickedList) {
          final bytes = await file.readAsBytes();
          newItems.add(UploadMediaItem(
            id: 'img-${DateTime.now().microsecondsSinceEpoch}-${newItems.length}',
            file: file,
            bytes: bytes,
            name: file.name.isNotEmpty ? file.name : 'Photo ${_selectedMedia.length + 1}',
          ));
        }
        setState(() {
          _selectedMedia.addAll(newItems);
          _activePreviewIndex = _selectedMedia.length - 1;
          _useUrlTab = false;
        });
      } else {
        // Fallback: single pick
        final XFile? single = await _picker.pickImage(
          source: ImageSource.gallery,
          maxWidth: 1600,
          maxHeight: 1600,
          imageQuality: 82,
        );
        if (single != null) {
          final bytes = await single.readAsBytes();
          setState(() {
            _selectedMedia.add(UploadMediaItem(
              id: 'img-${DateTime.now().microsecondsSinceEpoch}',
              file: single,
              bytes: bytes,
              name: single.name.isNotEmpty ? single.name : 'Photo ${_selectedMedia.length + 1}',
            ));
            _activePreviewIndex = _selectedMedia.length - 1;
            _useUrlTab = false;
          });
        }
      }
    } catch (e) {
      _showError('Failed to pick images: $e');
    }
  }

  Future<void> _pickVideo() async {
    try {
      final currentVideoCount = _selectedMedia.where((m) => m.isVideo).length;
      if (currentVideoCount >= 5) {
        _showError('Maximum 5 videos allowed per post');
        return;
      }

      final XFile? videoFile = await _picker.pickVideo(source: ImageSource.gallery);
      if (videoFile == null) return;

      final length = await videoFile.length();
      // Calculate current total video bytes
      int currentVideoBytes = 0;
      for (final m in _selectedMedia) {
        if (m.isVideo && m.bytes != null) {
          currentVideoBytes += m.bytes!.length;
        }
      }

      const maxLimitBytes = 15 * 1024 * 1024; // 15MB limit
      if (currentVideoBytes + length > maxLimitBytes) {
        final currentMb = (currentVideoBytes / (1024 * 1024)).toStringAsFixed(1);
        final fileMb = (length / (1024 * 1024)).toStringAsFixed(1);
        _showError('Video exceeds 15MB limit ($fileMb MB, current total: $currentMb MB / 15 MB)');
        return;
      }

      // Read video bytes and convert to data URI for local preview
      final bytes = await videoFile.readAsBytes();
      final ext = videoFile.name.toLowerCase().endsWith('.webm') ? 'webm' : 'mp4';
      final dataUrl = 'data:video/$ext;base64,${base64Encode(bytes)}';

      setState(() {
        _selectedMedia.add(UploadMediaItem(
          id: 'vid-${DateTime.now().microsecondsSinceEpoch}',
          file: videoFile,
          bytes: bytes,
          dataUrl: dataUrl,
          name: videoFile.name.isNotEmpty ? videoFile.name : 'Video ${_selectedMedia.length + 1}',
          isVideo: true,
        ));
        _activePreviewIndex = _selectedMedia.length - 1;
        _useUrlTab = false;
      });
    } catch (e) {
      _showError('Failed to pick video: $e');
    }
  }

  void _onFilesDropped(List<UploadMediaItem> droppedItems) {
    setState(() {
      _selectedMedia.addAll(droppedItems);
      _activePreviewIndex = _selectedMedia.length - 1;
      _useUrlTab = false;
    });
  }

  void _addUrlMedia() {
    final url = _urlInputController.text.trim();
    if (url.isEmpty) {
      _showError('Please enter an image URL');
      return;
    }

    final isVideo = url.contains('.mp4') ||
        url.contains('.webm') ||
        url.contains('.mov') ||
        url.contains('video/');

    setState(() {
      _selectedMedia.add(UploadMediaItem(
        id: 'url-${DateTime.now().microsecondsSinceEpoch}',
        url: url,
        name: isVideo ? 'Video URL ${_selectedMedia.length + 1}' : 'Web Image ${_selectedMedia.length + 1}',
        isVideo: isVideo,
      ));
      _activePreviewIndex = _selectedMedia.length - 1;
      _urlInputController.clear();
    });
  }

  void _removeMediaAt(int index) {
    if (index < 0 || index >= _selectedMedia.length) return;
    setState(() {
      _selectedMedia.removeAt(index);
      if (_selectedMedia.isEmpty) {
        _activePreviewIndex = 0;
      } else if (_activePreviewIndex >= _selectedMedia.length) {
        _activePreviewIndex = _selectedMedia.length - 1;
      }
    });
  }

  void _clearAllMedia() {
    setState(() {
      _selectedMedia.clear();
      _activePreviewIndex = 0;
      _urlInputController.clear();
    });
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(backgroundColor: Colors.redAccent, content: Text(msg)),
    );
  }

  // ─── Publish ──────────────────────────────────────────────────────────────

  Future<void> _publishPost() async {
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(backgroundColor: Colors.orange, content: Text('Please enter a title for your Pin')),
      );
      return;
    }
    if (_selectedMedia.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(backgroundColor: Colors.orange, content: Text('Please add at least one image or video')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final List<String> allImageUrls = [];
      final List<String> allVideoUrls = [];

      for (final item in _selectedMedia) {
        if (item.isVideo) {
          if (item.hasDataUrl) {
            allVideoUrls.add(item.dataUrl!);
          } else if (item.bytes != null) {
            final ext = item.name.toLowerCase().endsWith('.webm') ? 'webm' : 'mp4';
            allVideoUrls.add('data:video/$ext;base64,${base64Encode(item.bytes!)}');
          } else if (item.url != null && item.url!.isNotEmpty) {
            allVideoUrls.add(item.url!);
          }
        } else {
          // Image
          if (item.hasDataUrl) {
            allImageUrls.add(item.dataUrl!);
          } else if (item.bytes != null) {
            allImageUrls.add('data:image/jpeg;base64,${base64Encode(item.bytes!)}');
          } else if (item.url != null && item.url!.isNotEmpty) {
            allImageUrls.add(item.url!);
          }
        }
      }

      final description = _descriptionController.text.trim();
      final link = _linkController.text.trim();
      final hasVideo = allVideoUrls.isNotEmpty;

      if (!hasVideo && allImageUrls.length > 1 && !_publishAsCarousel) {
        await ApiService().createMultiplePosts(
          title: title,
          author: ApiService().currentUser,
          allImageUrls: allImageUrls,
          description: description.isNotEmpty ? description : null,
          category: _selectedCategory,
          link: link.isNotEmpty ? link : null,
          asIndividualPins: true,
        );
      } else {
        await ApiService().createPost(
          title: title,
          author: ApiService().currentUser,
          imageUrls: allImageUrls.isNotEmpty ? allImageUrls : null,
          imageUrl: allImageUrls.isNotEmpty ? allImageUrls.first : null,
          videoUrl: allVideoUrls.isNotEmpty ? allVideoUrls.first : null,
          videoUrls: allVideoUrls.isNotEmpty ? allVideoUrls : null,
          description: description.isNotEmpty ? description : null,
          category: _selectedCategory,
          link: link.isNotEmpty ? link : null,
        );
      }

      if (mounted) {
        _titleController.clear();
        _descriptionController.clear();
        _linkController.clear();
        _clearAllMedia();
        setState(() => _isLoading = false);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFF10B981),
            behavior: SnackBarBehavior.floating,
            content: Row(children: [
              const Icon(Icons.check_circle_outline, color: Colors.white),
              const SizedBox(width: 10),
              Text(hasVideo ? 'Video pin published to Punny!' : 'Pin published successfully to Punny!'),
            ]),
          ),
        );
        widget.onPostCreated?.call();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(backgroundColor: Colors.redAccent, content: Text('Failed to publish: $e')),
        );
      }
    }
  }

  // ─── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildHeader(),
                  const SizedBox(height: 20),
                  _buildMediaUploadCard(),
                  const SizedBox(height: 20),
                  if (_selectedMedia.length > 1 && !_selectedMedia.any((m) => m.isVideo))
                    _buildMultiPinOptions(),
                  _buildPinDetailsCard(),
                  const SizedBox(height: 20),
                  _buildPublishButton(),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ─── Header ───────────────────────────────────────────────────────────────

  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Create Pin',
              style: GoogleFonts.inter(
                fontSize: 26,
                fontWeight: FontWeight.w800,
                color: const Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Upload images, videos, or drag & drop files',
              style: GoogleFonts.inter(color: const Color(0xFF64748B), fontSize: 14),
            ),
          ],
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: const Color(0xFFEEF2FF),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(children: [
            const CircleAvatar(
              radius: 10,
              backgroundColor: Color(0xFF6366F1),
              child: Icon(Icons.person, size: 12, color: Colors.white),
            ),
            const SizedBox(width: 6),
            Text(
              '@${ApiService().currentUser}',
              style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF6366F1)),
            ),
          ]),
        ),
      ],
    );
  }

  // ─── Upload Card ──────────────────────────────────────────────────────────

  Widget _buildMediaUploadCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 18, offset: const Offset(0, 4))],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Tab Row: Upload Files / URL
          _buildTabRow(),
          const SizedBox(height: 16),

          // URL Input
          if (_useUrlTab) ...[
            _buildUrlInputRow(),
            const SizedBox(height: 16),
          ],

          // Drop Zone wrapping the preview / empty state
          WebDropZone(
            onFilesDropped: _onFilesDropped,
            child: _selectedMedia.isNotEmpty
                ? Column(children: [
                    _buildMainPreview(),
                    const SizedBox(height: 14),
                    _buildThumbnailsStrip(),
                  ])
                : _buildEmptyDropzone(),
          ),
        ],
      ),
    );
  }

  Widget _buildTabRow() {
    return Row(
      children: [
        // Upload Files
        Expanded(
          child: InkWell(
            onTap: () => setState(() => _useUrlTab = false),
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                color: !_useUrlTab ? const Color(0xFFEEF2FF) : Colors.transparent,
                borderRadius: BorderRadius.circular(12),
              ),
              alignment: Alignment.center,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.photo_library_outlined, size: 18,
                      color: !_useUrlTab ? const Color(0xFF6366F1) : const Color(0xFF64748B)),
                  const SizedBox(width: 8),
                  Text('Upload Files',
                      style: GoogleFonts.inter(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                        color: !_useUrlTab ? const Color(0xFF6366F1) : const Color(0xFF64748B),
                      )),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        // URL Link
        Expanded(
          child: InkWell(
            onTap: () => setState(() => _useUrlTab = true),
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                color: _useUrlTab ? const Color(0xFFEEF2FF) : Colors.transparent,
                borderRadius: BorderRadius.circular(12),
              ),
              alignment: Alignment.center,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.link_rounded, size: 18,
                      color: _useUrlTab ? const Color(0xFF6366F1) : const Color(0xFF64748B)),
                  const SizedBox(width: 8),
                  Text('Image / Video URL',
                      style: GoogleFonts.inter(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                        color: _useUrlTab ? const Color(0xFF6366F1) : const Color(0xFF64748B),
                      )),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildUrlInputRow() {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: _urlInputController,
            style: GoogleFonts.inter(fontSize: 13),
            decoration: InputDecoration(
              hintText: 'Paste image or video URL (https://...)',
              prefixIcon: const Icon(Icons.link, color: Color(0xFF6366F1), size: 18),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              filled: true,
              fillColor: const Color(0xFFF8FAFC),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
              ),
            ),
            onSubmitted: (_) => _addUrlMedia(),
          ),
        ),
        const SizedBox(width: 8),
        ElevatedButton.icon(
          onPressed: _addUrlMedia,
          icon: const Icon(Icons.add, size: 16),
          label: const Text('Add URL'),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF6366F1),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
      ],
    );
  }

  // ─── Empty Dropzone ───────────────────────────────────────────────────────

  Widget _buildEmptyDropzone() {
    return Container(
      height: 260,
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFCBD5E1), style: BorderStyle.solid, width: 1.5),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Icon cluster
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: const BoxDecoration(color: Color(0xFFEEF2FF), shape: BoxShape.circle),
                  child: const Icon(Icons.add_photo_alternate_outlined, size: 32, color: Color(0xFF6366F1)),
                ),
                const SizedBox(width: 10),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: const BoxDecoration(color: Color(0xFFFEF2F2), shape: BoxShape.circle),
                  child: const Icon(Icons.videocam_rounded, size: 32, color: Color(0xFFE60023)),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              'Drag & drop files here, or click to browse',
              style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700, color: const Color(0xFF1E293B)),
            ),
            const SizedBox(height: 6),
            Text(
              'Images (PNG, JPG, WebP) or Videos (MP4, WebM, MOV)',
              style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF64748B)),
            ),
            const SizedBox(height: 16),
            // Action buttons
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 10,
              children: [
                OutlinedButton.icon(
                  onPressed: _pickImages,
                  icon: const Icon(Icons.photo_library_outlined, size: 16),
                  label: const Text('Browse Images'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF6366F1),
                    side: const BorderSide(color: Color(0xFFC7D2FE)),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: _pickVideo,
                  icon: const Icon(Icons.video_library_outlined, size: 16),
                  label: const Text('Browse Video'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFE60023),
                    side: const BorderSide(color: Color(0xFFFCA5A5)),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ─── Main Preview ─────────────────────────────────────────────────────────

  Widget _buildMainPreview() {
    final currentItem = _selectedMedia[_activePreviewIndex];

    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: Container(
        color: const Color(0xFF0F172A),
        constraints: const BoxConstraints(minHeight: 280, maxHeight: 520),
        width: double.infinity,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Media content
            Center(
              child: currentItem.isVideo
                  ? _buildVideoPreviewWidget(currentItem)
                  : _buildImagePreviewWidget(currentItem),
            ),

            // Top-left counter pill
            Positioned(
              top: 12,
              left: 12,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.7), borderRadius: BorderRadius.circular(20)),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      currentItem.isVideo ? Icons.videocam_rounded : Icons.photo_outlined,
                      size: 14,
                      color: Colors.white,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '${_activePreviewIndex + 1} of ${_selectedMedia.length}',
                      style: GoogleFonts.inter(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              ),
            ),

            // Top-right controls
            Positioned(
              top: 12,
              right: 12,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (!currentItem.isVideo)
                    Tooltip(
                      message: _previewFit == BoxFit.contain ? 'Whole Picture (Active)' : 'Fill Frame',
                      child: InkWell(
                        onTap: () => setState(() {
                          _previewFit = _previewFit == BoxFit.contain ? BoxFit.cover : BoxFit.contain;
                        }),
                        borderRadius: BorderRadius.circular(20),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.7), borderRadius: BorderRadius.circular(20)),
                          child: Row(children: [
                            Icon(
                              _previewFit == BoxFit.contain ? Icons.fit_screen_rounded : Icons.crop_free_rounded,
                              size: 14,
                              color: Colors.white,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              _previewFit == BoxFit.contain ? 'Whole' : 'Fill',
                              style: GoogleFonts.inter(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
                            ),
                          ]),
                        ),
                      ),
                    ),
                  const SizedBox(width: 6),

                  // Delete current
                  Tooltip(
                    message: 'Remove',
                    child: CircleAvatar(
                      radius: 16,
                      backgroundColor: Colors.black.withValues(alpha: 0.7),
                      child: IconButton(
                        padding: EdgeInsets.zero,
                        icon: const Icon(Icons.close_rounded, color: Colors.white, size: 18),
                        onPressed: () => _removeMediaAt(_activePreviewIndex),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Prev / Next arrows
            if (_selectedMedia.length > 1) ...[
              if (_activePreviewIndex > 0)
                Positioned(
                  left: 10,
                  child: CircleAvatar(
                    radius: 18,
                    backgroundColor: Colors.black.withValues(alpha: 0.6),
                    child: IconButton(
                      padding: EdgeInsets.zero,
                      icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 16),
                      onPressed: () => setState(() => _activePreviewIndex--),
                    ),
                  ),
                ),
              if (_activePreviewIndex < _selectedMedia.length - 1)
                Positioned(
                  right: 10,
                  child: CircleAvatar(
                    radius: 18,
                    backgroundColor: Colors.black.withValues(alpha: 0.6),
                    child: IconButton(
                      padding: EdgeInsets.zero,
                      icon: const Icon(Icons.arrow_forward_ios, color: Colors.white, size: 16),
                      onPressed: () => setState(() => _activePreviewIndex++),
                    ),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildVideoPreviewWidget(UploadMediaItem item) {
    final src = item.dataUrl ?? item.url ?? '';
    if (src.isEmpty) {
      return const Center(child: Icon(Icons.videocam_off_rounded, color: Colors.white54, size: 64));
    }
    return buildVideoPreview(src, showControls: true);
  }

  Widget _buildImagePreviewWidget(UploadMediaItem item) {
    if (item.bytes != null) {
      return Image.memory(item.bytes!, fit: _previewFit);
    }
    if (item.hasDataUrl) {
      try {
        final base64Str = item.dataUrl!.contains(',') ? item.dataUrl!.split(',').last : item.dataUrl!;
        return Image.memory(base64Decode(base64Str), fit: _previewFit);
      } catch (_) {}
    }
    if (item.url != null) {
      return buildSafeImage(item.url!, fit: _previewFit);
    }
    return const Center(child: Icon(Icons.broken_image_rounded, color: Colors.white54, size: 64));
  }

  // ─── Thumbnail Strip ──────────────────────────────────────────────────────

  Widget _buildThumbnailsStrip() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '${_selectedMedia.length} ${_selectedMedia.length == 1 ? 'file' : 'files'} added',
              style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: const Color(0xFF475569)),
            ),
            TextButton(
              onPressed: _clearAllMedia,
              style: TextButton.styleFrom(foregroundColor: Colors.redAccent),
              child: const Text('Clear All'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 84,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: _selectedMedia.length + 2, // +2: Add Image, Add Video
            separatorBuilder: (context, index) => const SizedBox(width: 10),
            itemBuilder: (context, index) {
              // Add More Image button
              if (index == _selectedMedia.length) {
                return _addMoreButton(
                  icon: Icons.add_photo_alternate_outlined,
                  label: 'Image',
                  color: const Color(0xFF6366F1),
                  bg: const Color(0xFFEEF2FF),
                  border: const Color(0xFFC7D2FE),
                  onTap: _pickImages,
                );
              }
              // Add Video button
              if (index == _selectedMedia.length + 1) {
                return _addMoreButton(
                  icon: Icons.video_library_outlined,
                  label: 'Video',
                  color: const Color(0xFFE60023),
                  bg: const Color(0xFFFEF2F2),
                  border: const Color(0xFFFCA5A5),
                  onTap: _pickVideo,
                );
              }

              final item = _selectedMedia[index];
              final isCurrent = _activePreviewIndex == index;

              return Stack(
                clipBehavior: Clip.none,
                children: [
                  InkWell(
                    onTap: () => setState(() => _activePreviewIndex = index),
                    borderRadius: BorderRadius.circular(14),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      width: 76,
                      height: 76,
                      decoration: BoxDecoration(
                        color: const Color(0xFF0F172A),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: isCurrent ? const Color(0xFFE60023) : const Color(0xFFE2E8F0),
                          width: isCurrent ? 2.5 : 1.0,
                        ),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: item.isVideo
                            ? buildVideoThumbnail()
                            : _buildThumbnailImage(item),
                      ),
                    ),
                  ),
                  // Video badge
                  if (item.isVideo)
                    const Positioned(
                      bottom: 4,
                      left: 4,
                      child: Icon(Icons.videocam_rounded, size: 16, color: Colors.white),
                    ),
                  // Delete badge
                  Positioned(
                    top: -4,
                    right: -4,
                    child: GestureDetector(
                      onTap: () => _removeMediaAt(index),
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
      ],
    );
  }

  Widget _buildThumbnailImage(UploadMediaItem item) {
    if (item.bytes != null) return Image.memory(item.bytes!, fit: BoxFit.cover);
    if (item.hasDataUrl) {
      try {
        final base64Str = item.dataUrl!.contains(',') ? item.dataUrl!.split(',').last : item.dataUrl!;
        return Image.memory(base64Decode(base64Str), fit: BoxFit.cover);
      } catch (_) {}
    }
    if (item.url != null) return buildSafeImage(item.url!, fit: BoxFit.cover);
    return const Icon(Icons.broken_image_rounded, color: Colors.white54);
  }

  Widget _addMoreButton({
    required IconData icon,
    required String label,
    required Color color,
    required Color bg,
    required Color border,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        width: 76,
        height: 76,
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: border, width: 1.5),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 4),
            Text('+ $label', style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.bold, color: color)),
          ],
        ),
      ),
    );
  }

  // ─── Multi-Pin Options ────────────────────────────────────────────────────

  Widget _buildMultiPinOptions() {
    return Column(
      children: [
        Container(
          decoration: BoxDecoration(
              color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: const Color(0xFFE2E8F0))),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                const Icon(Icons.collections_rounded, color: Color(0xFFE60023), size: 20),
                const SizedBox(width: 8),
                Text('Multi-Photo Pin Settings (${_selectedMedia.length} images)',
                    style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700, color: const Color(0xFF0F172A))),
              ]),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(child: _pinOptionTile('1 Carousel Pin', 'Users can swipe through all photos', _publishAsCarousel,
                    () => setState(() => _publishAsCarousel = true))),
                const SizedBox(width: 10),
                Expanded(
                    child: _pinOptionTile('${_selectedMedia.length} Individual Pins', 'Publishes separate individual pins',
                        !_publishAsCarousel, () => setState(() => _publishAsCarousel = false))),
              ]),
            ],
          ),
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _pinOptionTile(String title, String sub, bool selected, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFFEF2F2) : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: selected ? const Color(0xFFE60023) : const Color(0xFFE2E8F0), width: 1.5),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title,
              style: GoogleFonts.inter(
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                  color: selected ? const Color(0xFF991B1B) : const Color(0xFF334155))),
          const SizedBox(height: 2),
          Text(sub, style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF64748B))),
        ]),
      ),
    );
  }

  // ─── Pin Details Card ─────────────────────────────────────────────────────

  Widget _buildPinDetailsCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 18, offset: const Offset(0, 4))],
      ),
      padding: const EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _fieldLabel('Pin Title *'),
          const SizedBox(height: 8),
          _buildTextField(_titleController, 'Add a title (e.g., Aesthetic Vibes)'),
          const SizedBox(height: 18),

          _fieldLabel('Category'),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _categories.map((cat) {
              final isSelected = _selectedCategory == cat;
              return GestureDetector(
                onTap: () => setState(() => _selectedCategory = cat),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                  decoration: BoxDecoration(
                    color: isSelected ? const Color(0xFFE60023) : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isSelected ? const Color(0xFFE60023) : const Color(0xFFE2E8F0),
                    ),
                  ),
                  child: Text(cat,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: isSelected ? Colors.white : const Color(0xFF475569),
                      )),
                ),
              );
            }).toList(),
          ),
          if (_selectedCategory == 'Ads & Marketing') ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFFFBEB),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFFDE68A)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.campaign_rounded, color: Color(0xFFD97706), size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Marketing Pin: This post will be highlighted in the compact Sponsored showcase (Pinterest/Pixiv style) on the home feed.',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: const Color(0xFF92400E),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 18),

          _fieldLabel('Description (optional)'),
          const SizedBox(height: 8),
          TextField(
            controller: _descriptionController,
            maxLines: 3,
            style: GoogleFonts.inter(color: const Color(0xFF0F172A), fontSize: 14),
            decoration: _fieldDecoration('Add a description...'),
          ),
          const SizedBox(height: 18),

          _fieldLabel('Destination Link (optional)'),
          const SizedBox(height: 8),
          _buildTextField(_linkController, 'https://...'),
        ],
      ),
    );
  }

  Widget _fieldLabel(String text) {
    return Text(text,
        style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: const Color(0xFF334155)));
  }

  Widget _buildTextField(TextEditingController controller, String hint) {
    return TextField(
      controller: controller,
      style: GoogleFonts.inter(color: const Color(0xFF0F172A), fontSize: 15, fontWeight: FontWeight.w600),
      decoration: _fieldDecoration(hint),
    );
  }

  InputDecoration _fieldDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: GoogleFonts.inter(color: const Color(0xFF94A3B8)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      filled: true,
      fillColor: const Color(0xFFF8FAFC),
      border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
      enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
      focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFF6366F1), width: 1.5)),
    );
  }

  // ─── Publish Button ───────────────────────────────────────────────────────

  Widget _buildPublishButton() {
    final hasVideo = _selectedMedia.any((m) => m.isVideo);
    final count = _selectedMedia.length;

    String label;
    if (_isLoading) {
      label = 'Publishing...';
    } else if (hasVideo) {
      label = 'Publish Video Pin';
    } else if (count > 1) {
      label = _publishAsCarousel
          ? 'Publish Carousel Pin ($count images)'
          : 'Publish $count Individual Pins';
    } else {
      label = 'Publish Pin';
    }

    return ElevatedButton.icon(
      onPressed: _isLoading ? null : _publishPost,
      icon: _isLoading
          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
          : Icon(hasVideo ? Icons.videocam_rounded : Icons.publish_rounded, size: 20),
      label: Text(label, style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700)),
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFFE60023),
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 18),
        elevation: 2,
        shadowColor: const Color(0xFFE60023).withValues(alpha: 0.4),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }
}
