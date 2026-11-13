import 'image_download_stub.dart'
    if (dart.library.html) 'image_download_web.dart';

void saveImageToDevice(String url, String fileName) {
  downloadImageFile(url, fileName);
}

