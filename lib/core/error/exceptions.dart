class ServerException implements Exception {
  final String message;
  ServerException([this.message = 'Server Exception']);
}

class AuthenticationException implements Exception {
  final String message;
  AuthenticationException([this.message = 'Authentication Exception']);
}

class CacheException implements Exception {
  final String message;
  CacheException([this.message = 'Cache Exception']);
}
