// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use
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

/// Small video thumbnail with a play icon overlay or actual video frame
Widget buildVideoThumbnail({String? videoUrl}) {
  if (videoUrl != null && videoUrl.isNotEmpty) {
    final viewId = 'punny-video-thumb-${_videoViewIdCounter++}';
    // ignore: undefined_prefixed_name
    ui_web.platformViewRegistry.registerViewFactory(viewId, (int _) {
      final video = html.VideoElement()
        ..src = videoUrl
        ..controls = false
        ..autoplay = false
        ..muted = true
        ..style.width = '100%'
        ..style.height = '100%'
        ..style.objectFit = 'cover'
        ..style.pointerEvents = 'none';
      return video;
    });

    return Stack(
      fit: StackFit.expand,
      children: [
        HtmlElementView(viewType: viewId),
        Container(color: Colors.black.withValues(alpha: 0.15)),
      ],
    );
  }

  return Container(
    color: const Color(0xFF0F172A),
    child: const Center(
      child: Icon(Icons.videocam_rounded, color: Colors.white70, size: 40),
    ),
  );
}

