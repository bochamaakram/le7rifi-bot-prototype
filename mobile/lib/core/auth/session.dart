import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SessionStore {
  final FlutterSecureStorage storage;
  const SessionStore([this.storage = const FlutterSecureStorage()]);
  Future<String?> read() => storage.read(key: 'access_token');
  Future<void> save(String token) =>
      storage.write(key: 'access_token', value: token);
  Future<void> clear() => storage.delete(key: 'access_token');
}
