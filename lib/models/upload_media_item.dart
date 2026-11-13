import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';

/// Represents a single media item being prepared for upload.
/// Can be an image or a video, from file picker, drag-and-drop, URL, or data URI.
class UploadMediaItem {
  final String id;

  /// Source file from [ImagePicker] (image or video).
  final XFile? file;

  /// Raw bytes of an image file (not used for videos due to size).
  final Uint8List? bytes;

  /// A remote or asset URL (images only via URL tab).
  final String? url;

  /// A data URI string (base64 for images, or object URL for videos from drag-drop).
  final String? dataUrl;

  /// Human-readable file name.
  final String name;

  /// True when this item is a video (mp4, webm, etc.).
  final bool isVideo;

  UploadMediaItem({
    required this.id,
    this.file,
    this.bytes,
    this.url,
    this.dataUrl,
    required this.name,
    this.isVideo = false,
  });

  /// True if this item came from a local file (picker or drag-drop), not a remote URL.
  bool get isFile => bytes != null || file != null || dataUrl != null;

  /// True if this item has a data URI (from drag-drop or base64 encode).
  bool get hasDataUrl => dataUrl != null && dataUrl!.isNotEmpty;
}

