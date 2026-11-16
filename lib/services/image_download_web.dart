// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:html' as html;

void downloadImageFile(String url, String fileName) {
  try {
    final anchor = html.AnchorElement(href: url)
      ..target = '_blank'
      ..download = fileName;
    html.document.body?.children.add(anchor);
    anchor.click();
    anchor.remove();
  } catch (_) {}
}

