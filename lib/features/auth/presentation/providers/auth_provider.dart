import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../../../core/usecases/usecase.dart';
import '../../domain/entities/user_entity.dart';
import '../../domain/usecases/auth_getters.dart';
import '../../domain/usecases/sign_in_with_email.dart';
import '../../domain/usecases/sign_in_with_google.dart';
import '../../domain/usecases/sign_out.dart';

class AuthProvider extends ChangeNotifier {
  final SignInWithEmail _signInWithEmail;
  final SignInWithGoogle _signInWithGoogle;
  final SignOut _signOut;
  final GetAuthStateChanges _getAuthStateChanges;

  UserEntity? _user;
  bool _isLoading = false;
  bool _isResolvingSession = true;
  String? _errorMessage;
  StreamSubscription<UserEntity?>? _authSubscription;

  AuthProvider({
    required SignInWithEmail signInWithEmail,
    required SignInWithGoogle signInWithGoogle,
    required SignOut signOut,
    required GetCurrentUser getCurrentUser,
    required GetAuthStateChanges getAuthStateChanges,
  })  : _signInWithEmail = signInWithEmail,
        _signInWithGoogle = signInWithGoogle,
        _signOut = signOut,
        _getAuthStateChanges = getAuthStateChanges {
    // getCurrentUser kept in constructor for DI stability; session uses stream only.
    _init();
  }

  UserEntity? get user => _user;
  bool get isLoading => _isLoading;
  /// True until the first auth state + role resolution completes.
  bool get isResolvingSession => _isResolvingSession;
  String? get errorMessage => _errorMessage;

  void _init() {
    // Do not trust a synchronous Firebase user without role resolution.
    // Wait for authStateChanges which loads roles / enforces allow-list.
    _authSubscription = _getAuthStateChanges.call().listen((user) {
      _user = user;
      _isResolvingSession = false;
      notifyListeners();
    }, onError: (_) {
      _user = null;
      _isResolvingSession = false;
      notifyListeners();
    });
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }

  Future<bool> login(String email, String password) async {
    _setLoading(true);
    final result = await _signInWithEmail(
      SignInParams(email: email, password: password),
    );

    return result.fold(
      (failure) {
        _errorMessage = failure.message;
        _user = null;
        _setLoading(false);
        return false;
      },
      (user) {
        _user = user;
        _errorMessage = null;
        _isResolvingSession = false;
        _setLoading(false);
        return true;
      },
    );
  }

  Future<bool> loginWithGoogle() async {
    _setLoading(true);
    final result = await _signInWithGoogle(NoParams());

    return result.fold(
      (failure) {
        _errorMessage = failure.message;
        _user = null;
        _setLoading(false);
        return false;
      },
      (user) {
        _user = user;
        _errorMessage = null;
        _isResolvingSession = false;
        _setLoading(false);
        return true;
      },
    );
  }

  Future<void> logout() async {
    _setLoading(true);
    await _signOut(NoParams());
    _user = null;
    _setLoading(false);
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }
}
