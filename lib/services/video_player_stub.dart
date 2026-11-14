// Stub for non-web — shows a placeholder icon
import 'package:flutter/material.dart';

Widget buildVideoPreview(String dataUrl, {bool showControls = true}) {
  return Container(
    color: const Color(0xFF0F172A),
    child: const Center(
      child: Icon(Icons.videocam_rounded, color: Colors.white54, size: 64),
    ),
  );
}

Widget buildVideoThumbnail({String? videoUrl}) {
  return Container(
    color: const Color(0xFF1E293B),
    child: const Center(
      child: Icon(Icons.play_circle_fill_rounded, color: Color(0xFFE60023), size: 28),
    ),
  );
}

