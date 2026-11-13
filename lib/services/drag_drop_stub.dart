// Stub for non-web platforms (desktop, mobile, tests).
// On web this file is replaced by drag_drop_web.dart via conditional export.
import 'package:flutter/widgets.dart';
import '../models/upload_media_item.dart';

/// No-op drop zone for non-web: simply renders [child] unchanged.
class WebDropZone extends StatelessWidget {
  final Widget child;

  /// Not called on non-web — here only to match the web widget's API.
  final void Function(List<UploadMediaItem> items)? onFilesDropped;

  const WebDropZone({super.key, required this.child, this.onFilesDropped});

  @override
  Widget build(BuildContext context) => child;
}
