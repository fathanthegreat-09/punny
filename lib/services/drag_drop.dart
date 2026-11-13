// Conditional export: on web use dart:html drop events; elsewhere use a no-op stub.
export 'drag_drop_stub.dart'
    if (dart.library.html) 'drag_drop_web.dart' show WebDropZone;
