import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../../../core/usecases/usecase.dart';
import '../../domain/entities/user_entity.dart';
import '../../domain/repositories/auth_repository.dart';
import '../../domain/usecases/auth_getters.dart';
import '../../domain/usecases/sign_in_with_email.dart';
import '../../domain/usecases/sign_in_with_google.dart';
import '../../domain/usecases/sign_out.dart';

class AuthProvider extends ChangeNotifier {
  final SignInWithEmail _signInWithEmail;
  final SignInWithGoogle _signInWithGoogle;
  final SignOut _signOut;
  final GetAuthStateChanges _getAuthStateChanges;
  final AuthRepository _authRepository;

  UserEntity? _user;
  bool _isLoading = false;
  bool _isResolvingSession = true;
  String? _errorMessage;
  StreamSubscription<UserEntity?>? _authSubscription;
  Timer? _presenceTimer;

  AuthProvider({
    required SignInWithEmail signInWithEmail,
    required SignInWithGoogle signInWithGoogle,
    required SignOut signOut,
    required GetCurrentUser getCurrentUser,
    required GetAuthStateChanges getAuthStateChanges,
    required AuthRepository authRepository,
  })  : _signInWithEmail = signInWithEmail,
        _signInWithGoogle = signInWithGoogle,
        _signOut = signOut,
        _getAuthStateChanges = getAuthStateChanges,
        _authRepository = authRepository {
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
      if (user != null) {
        _startPresenceHeartbeat();
      } else {
        _stopPresenceHeartbeat();
      }
      notifyListeners();
    }, onError: (_) {
      _user = null;
      _isResolvingSession = false;
      _stopPresenceHeartbeat();
      notifyListeners();
    });
  }

  void _startPresenceHeartbeat() {
    _presenceTimer?.cancel();
    // Immediate touch, then every 2 minutes while logged in
    unawaited(_authRepository.touchLastActive());
    _presenceTimer = Timer.periodic(const Duration(minutes: 2), (_) {
      unawaited(_authRepository.touchLastActive());
    });
  }

  void _stopPresenceHeartbeat() {
    _presenceTimer?.cancel();
    _presenceTimer = null;
  }

  @override
  void dispose() {
    _stopPresenceHeartbeat();
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
        _startPresenceHeartbeat();
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
        _startPresenceHeartbeat();
        _setLoading(false);
        return true;
      },
    );
  }

  Future<void> logout() async {
    _setLoading(true);
    _stopPresenceHeartbeat();
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
