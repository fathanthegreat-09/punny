// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'dart:ui_web' as ui_web;
import 'package:flutter/material.dart';

int _videoViewIdCounter = 0;

/// Builds an inline HTML <video> player using HtmlElementView for Flutter Web.
Widget buildVideoPreview(String dataUrl, {bool showControls = true}) {
  final viewId = 'punny-video-${_videoViewIdCounter++}';

  // ignore: undefined_prefixed_name
  ui_web.platformViewRegistry.registerViewFactory(viewId, (int _) {
    final video = html.VideoElement()
      ..src = dataUrl
      ..controls = showControls
      ..autoplay = false
      ..style.width = '100%'
      ..style.height = '100%'
      ..style.objectFit = 'contain'
      ..style.background = '#0f172a'
      ..style.borderRadius = '20px';
    return video;
  });

  return HtmlElementView(viewType: viewId);
}

/// Small video thumbnail with a play icon overlay
Widget buildVideoThumbnail() {
  return Container(
    color: const Color(0xFF1E293B),
    child: const Center(
      child: Icon(Icons.play_circle_fill_rounded, color: Color(0xFFE60023), size: 28),
    ),
  );
}

