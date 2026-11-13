import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import '../models/post.dart';
import '../services/api_service.dart';

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

  XFile? _selectedImageFile;
  Uint8List? _selectedImageBytes;
  bool _isLoading = false;
  bool _useUrlInput = false;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.post.title);
    _urlController = TextEditingController(
      text: widget.post.imageUrl.startsWith('http') ? widget.post.imageUrl : '',
    );
  }

  @override
  void dispose() {
    _titleController.dispose();
    _urlController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    try {
      final XFile? file = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1600,
        maxHeight: 1600,
        imageQuality: 85,
      );
      if (file != null) {
        final bytes = await file.readAsBytes();
        setState(() {
          _selectedImageFile = file;
          _selectedImageBytes = bytes;
          _useUrlInput = false;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error picking image: $e')),
        );
      }
    }
  }

  Future<void> _saveChanges() async {
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a title for your pin')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      String? imageUrl;
      if (_useUrlInput && _urlController.text.trim().isNotEmpty) {
        imageUrl = _urlController.text.trim();
      }

      await ApiService().updatePost(
        id: widget.post.id,
        title: title,
        imageFile: _selectedImageFile,
        imageUrl: imageUrl,
      );

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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.redAccent,
            content: Text('Error updating pin: $e'),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 550, maxHeight: 700),
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
                  Text(
                    'Edit Pin',
                    style: GoogleFonts.inter(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF0F172A),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Color(0xFF64748B)),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Preview Image
                      ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: Container(
                          constraints: const BoxConstraints(minHeight: 180, maxHeight: 320),
                          width: double.infinity,
                          color: const Color(0xFF0F172A),
                          child: Center(
                            child: _selectedImageBytes != null
                                ? Image.memory(_selectedImageBytes!, fit: BoxFit.contain)
                                : (_useUrlInput && _urlController.text.trim().isNotEmpty)
                                    ? buildSafeImage(_urlController.text.trim(), fit: BoxFit.contain)
                                    : buildSafeImage(widget.post.imageUrl, fit: BoxFit.contain),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Replace image options
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: _pickImage,
                              icon: const Icon(Icons.image_outlined, size: 18),
                              label: const Text('Change Image File'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: const Color(0xFF6366F1),
                                side: const BorderSide(color: Color(0xFFE2E8F0)),
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () {
                                setState(() {
                                  _useUrlInput = !_useUrlInput;
                                });
                              },
                              icon: const Icon(Icons.link, size: 18),
                              label: Text(_useUrlInput ? 'Hide URL' : 'Use URL'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: const Color(0xFF64748B),
                                side: const BorderSide(color: Color(0xFFE2E8F0)),
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),

                      if (_useUrlInput) ...[
                        const SizedBox(height: 12),
                        TextField(
                          controller: _urlController,
                          decoration: InputDecoration(
                            labelText: 'Image Web URL',
                            hintText: 'https://images.unsplash.com/...',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          onChanged: (_) => setState(() {}),
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
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 20),
              // Action buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
                    child: Text(
                      'Cancel',
                      style: GoogleFonts.inter(color: const Color(0xFF64748B)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: _isLoading ? null : _saveChanges,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF6366F1),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                          )
                        : Text(
                            'Save Changes',
                            style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                          ),
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
