/// Where to go after login: the `from` location the user was redirected
/// away from, if it is an in-app path, otherwise the dashboard.
String safeReturnLocation(String? from) {
  if (from == null ||
      !from.startsWith('/') ||
      from.startsWith('//') ||
      from.startsWith('/login') ||
      from == '/') {
    return '/home';
  }
  return from;
}
