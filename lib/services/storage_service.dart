import 'storage_service_stub.dart'
    if (dart.library.html) 'storage_service_web.dart';

class AppStorage {
  static String? get(String key) => StorageService.getItem(key);
  static void set(String key, String value) => StorageService.setItem(key, value);
  static void remove(String key) => StorageService.removeItem(key);
}

