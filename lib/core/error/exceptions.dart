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

/// Thrown when a network call does not complete in time, which is how
/// Firebase behaves offline: writes and uploads wait instead of failing.
class NetworkException implements Exception {
  final String message;
  NetworkException([
    this.message =
        'No internet connection. Please check your connection and try again.',
  ]);

  @override
  String toString() => message;
}
