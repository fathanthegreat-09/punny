// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:html' as html;
import 'dart:async';
import 'package:flutter/material.dart';
import '../models/upload_media_item.dart';

/// Web-only drag-and-drop zone using native dart:html DragEvent listeners.
///
/// Wraps any child widget and shows a "drop here" overlay when the user
/// drags files over the zone. On drop, reads each file as a data-URL and
/// calls [onFilesDropped] with the resulting [UploadMediaItem] list.
class WebDropZone extends StatefulWidget {
  final Widget child;
  final void Function(List<UploadMediaItem> items)? onFilesDropped;

  const WebDropZone({super.key, required this.child, this.onFilesDropped});

  @override
  State<WebDropZone> createState() => _WebDropZoneState();
}

class _WebDropZoneState extends State<WebDropZone> {
  bool _isDraggingOver = false;

  // Track pending drag enter/leave so nested child elements don't flicker
  int _dragEnterCount = 0;

  // Subscriptions on the flutter host canvas element
  StreamSubscription<html.MouseEvent>? _dragOverSub;
  StreamSubscription<html.MouseEvent>? _dragEnterSub;
  StreamSubscription<html.MouseEvent>? _dragLeaveSub;
  StreamSubscription<html.MouseEvent>? _dropSub;

  @override
  void initState() {
    super.initState();
    _attachListeners();
  }

  void _attachListeners() {
    // Listen on the top-level document so we catch all drag events regardless
    // of where Flutter places its canvas element.
    _dragOverSub = html.document.onDragOver.listen((e) {
      e.preventDefault(); // Allow drop
    });

    _dragEnterSub = html.document.onDragEnter.listen((e) {
      e.preventDefault();
      _dragEnterCount++;
      if (mounted && !_isDraggingOver) {
        setState(() => _isDraggingOver = true);
      }
    });

    _dragLeaveSub = html.document.onDragLeave.listen((e) {
      _dragEnterCount--;
      if (_dragEnterCount <= 0) {
        _dragEnterCount = 0;
        if (mounted && _isDraggingOver) {
          setState(() => _isDraggingOver = false);
        }
      }
    });

    _dropSub = html.document.onDrop.listen((mouseEvent) async {
      mouseEvent.preventDefault();
      _dragEnterCount = 0;
      if (mounted) setState(() => _isDraggingOver = false);

      // In dart:html, mouseEvent.dataTransfer is statically typed as non-nullable DataTransfer,
      // but in JS runtime it can be null/undefined. Accessing via dynamic allows a reachable null-check.
      html.DataTransfer? transfer;
      try {
        final dynamic dt = (mouseEvent as dynamic).dataTransfer;
        if (dt is html.DataTransfer) {
          transfer = dt;
        }
      } catch (_) {
        return;
      }
      if (transfer == null) return;

      final files = transfer.files;
      if (files == null || files.isEmpty) return;

      final List<UploadMediaItem> items = [];

      for (final file in files) {
        final isImage = file.type.startsWith('image/');
        final isVideo = file.type.startsWith('video/');
        if (!isImage && !isVideo) continue;

        final reader = html.FileReader();
        reader.readAsDataUrl(file);

        try {
          await reader.onLoad.first.timeout(const Duration(seconds: 10));
        } catch (_) {
          continue;
        }

        final result = reader.result;
        final dataUrl = result is String ? result : '';
        if (dataUrl.isEmpty) continue;

        items.add(UploadMediaItem(
          id: 'drop-${DateTime.now().microsecondsSinceEpoch}-${items.length}',
          dataUrl: dataUrl,
          name: file.name.isNotEmpty ? file.name : (isVideo ? 'Video' : 'Photo'),
          isVideo: isVideo,
        ));
      }

      if (items.isNotEmpty) {
        widget.onFilesDropped?.call(items);
      }
    });
  }

  @override
  void dispose() {
    _dragOverSub?.cancel();
    _dragEnterSub?.cancel();
    _dragLeaveSub?.cancel();
    _dropSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Underlying content
        widget.child,

        // Drop highlight overlay — only visible while dragging
        if (_isDraggingOver)
          Positioned.fill(
            child: IgnorePointer(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                decoration: BoxDecoration(
                  color: const Color(0xFF6366F1).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: const Color(0xFF6366F1),
                    width: 2.5,
                  ),
                ),
                child: const Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.download_for_offline_rounded,
                        color: Color(0xFF6366F1),
                        size: 52,
                      ),
                      SizedBox(height: 10),
                      Text(
                        'Drop images or videos here',
                        style: TextStyle(
                          color: Color(0xFF4F46E5),
                          fontWeight: FontWeight.w700,
                          fontSize: 20,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'PNG, JPG, WebP, MP4, WebM, MOV',
                        style: TextStyle(
                          color: Color(0xFF818CF8),
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
