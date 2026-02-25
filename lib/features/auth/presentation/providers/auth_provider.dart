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
  final GetCurrentUser _getCurrentUser;
  final GetAuthStateChanges _getAuthStateChanges;

  UserEntity? _user;
  bool _isLoading = false;
  String? _errorMessage;
  StreamSubscription<UserEntity?>? _authSubscription;

  AuthProvider({
    required SignInWithEmail signInWithEmail,
    required SignInWithGoogle signInWithGoogle,
    required SignOut signOut,
    required GetCurrentUser getCurrentUser,
    required GetAuthStateChanges getAuthStateChanges,
  }) : _signInWithEmail = signInWithEmail,
       _signInWithGoogle = signInWithGoogle,
       _signOut = signOut,
       _getCurrentUser = getCurrentUser,
       _getAuthStateChanges = getAuthStateChanges {
    _init();
  }

  UserEntity? get user => _user;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  void _init() {
    _user = _getCurrentUser.call();
    _authSubscription = _getAuthStateChanges.call().listen((user) {
      _user = user;
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
        _setLoading(false);
        return false;
      },
      (user) {
        _user = user;
        _errorMessage = null;
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
        _setLoading(false);
        return false;
      },
      (user) {
        _user = user;
        _errorMessage = null;
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
