import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../../../../core/error/exceptions.dart';
import '../../../../core/rbac/permission.dart';
import '../../../../core/rbac/rbac_manager.dart';
import '../models/user_model.dart';

abstract class AuthRemoteDataSource {
  Stream<UserModel?> get authStateChanges;
  UserModel? get currentUser;
  Future<UserModel> signInWithEmailAndPassword(String email, String password);
  Future<UserModel> signInWithGoogle();
  Future<void> signOut();
}

class AuthRemoteDataSourceImpl implements AuthRemoteDataSource {
  final FirebaseAuth auth;
  final GoogleSignIn googleSignIn;
  final FirebaseFirestore firestore;

  /// Initial Super Admin — bootstrapped into `users` on first successful Auth login
  /// if no profile document exists yet.
  static const String _bootstrapSuperAdminEmail =
      'muhammed.saleh@xlooptours.com';

  /// Cache role info so [currentUser] is not empty on cold start.
  UserModel? _cachedUser;

  AuthRemoteDataSourceImpl({
    required this.auth,
    required this.googleSignIn,
    required this.firestore,
  });

  Future<List<String>> _permissionsForRole(String roleId) async {
    final id = RbacManager.normalizeRoleId(roleId);
    if (id == RbacManager.roleSuperAdmin) {
      return AppPermission.values.map((p) => p.toPermissionString()).toList();
    }
    if (id == RbacManager.roleAdmin) {
      return AppPermission.values
          .where((p) => p != AppPermission.manageRoles)
          .map((p) => p.toPermissionString())
          .toList();
    }
    try {
      final roleDoc = await firestore.collection('roles').doc(id).get();
      if (!roleDoc.exists) return const [];
      final raw = roleDoc.data()?['permissions'] as List<dynamic>? ?? [];
      return raw.map((e) => e.toString()).toList();
    } catch (_) {
      return const [];
    }
  }

  /// Maps a `users` doc (or equivalent map) to a normalized roleId.
  /// Prefer [roleId]; fall back to legacy [isAdmin] boolean on the same doc.
  String _roleIdFromUserData(Map<String, dynamic> data) {
    final rawRole = data['roleId'] as String?;
    if (rawRole != null && rawRole.trim().isNotEmpty) {
      return RbacManager.normalizeRoleId(rawRole);
    }
    // Legacy field on users / allowed_users docs
    if (data['isAdmin'] == true) {
      return RbacManager.roleAdmin;
    }
    return 'office_staff';
  }

  /// Resolves authorized role for a Firebase user.
  /// Throws [AuthenticationException] if not in allow-list or inactive.
  Future<String?> _roleNameFor(String roleId) async {
    try {
      final doc = await firestore.collection('roles').doc(roleId).get();
      if (doc.exists) {
        return doc.data()?['name'] as String?;
      }
    } catch (_) {}
    return null;
  }

  Future<String?> _employeePhotoUrl(String? employeeId) async {
    if (employeeId == null || employeeId.trim().isEmpty) return null;
    try {
      final doc =
          await firestore.collection('employees').doc(employeeId.trim()).get();
      if (!doc.exists) return null;
      final url = doc.data()?['imageUrl'] as String?;
      if (url == null || url.trim().isEmpty) return null;
      return url.trim();
    } catch (_) {
      return null;
    }
  }

  Future<
      ({
        String roleId,
        List<String> permissions,
        String? displayName,
        String? roleName,
        String? employeeId,
        String? employeeName,
        String? photoUrl,
      })> _resolveAuthorizedUser(User user) async {
    final email = user.email?.toLowerCase().trim();
    if (email == null || email.isEmpty) {
      throw AuthenticationException(
        'Your account has no email address and cannot sign in.',
      );
    }

    try {
      // 1. Canonical: users/{uid}
      var userDoc = await firestore.collection('users').doc(user.uid).get();

      // 2. Legacy email-as-document-id
      if (!userDoc.exists) {
        userDoc = await firestore.collection('users').doc(email).get();
      }

      // 3. Query by email field (single-doc model)
      if (!userDoc.exists) {
        final query = await firestore
            .collection('users')
            .where('email', isEqualTo: email)
            .limit(1)
            .get();
        if (query.docs.isNotEmpty) {
          userDoc = query.docs.first;
        }
      }

      if (userDoc.exists) {
        final data = userDoc.data() ?? {};
        final isActive = data['isActive'] ?? true;
        if (!isActive) {
          throw AuthenticationException(
            'Your account has been deactivated. Contact an administrator.',
          );
        }
        final roleId = _roleIdFromUserData(data);
        final permissions = await _permissionsForRole(roleId);
        final roleName = await _roleNameFor(roleId);
        final employeeId = data['employeeId'] as String?;
        final photoUrl = await _employeePhotoUrl(employeeId);
        return (
          roleId: roleId,
          permissions: permissions,
          displayName: data['displayName'] as String?,
          roleName: roleName ?? data['roleName'] as String?,
          employeeId: employeeId,
          employeeName: data['employeeName'] as String?,
          photoUrl: photoUrl,
        );
      }

      // 4. Legacy allowed_users collection
      final allowedDoc = await firestore
          .collection('allowed_users')
          .doc(email)
          .get();
      if (allowedDoc.exists) {
        final data = allowedDoc.data() ?? {};
        final isActive = data['active'] ?? true;
        if (!isActive) {
          throw AuthenticationException(
            'Your account is not active. Contact an administrator.',
          );
        }
        // Legacy: isAdmin true → admin; also honor roleId if present
        final roleId = _roleIdFromUserData(data);
        final permissions = await _permissionsForRole(roleId);
        final roleName = await _roleNameFor(roleId);
        return (
          roleId: roleId,
          permissions: permissions,
          displayName: data['displayName'] as String?,
          roleName: roleName,
          employeeId: null,
          employeeName: null,
          photoUrl: null,
        );
      }
    } on AuthenticationException {
      rethrow;
    } catch (e) {
      throw AuthenticationException(
        'Unable to verify account access. Please try again.',
      );
    }

    // One-time bootstrap for the designated Super Admin account
    if (email == _bootstrapSuperAdminEmail) {
      await firestore.collection('users').doc(user.uid).set({
        'uid': user.uid,
        'email': email,
        'displayName': user.displayName ?? 'Super Admin',
        'roleId': RbacManager.roleSuperAdmin,
        'isAdmin': true,
        'isActive': true,
        'createdAt': FieldValue.serverTimestamp(),
        'createdBy': 'system_bootstrap',
      }, SetOptions(merge: true));
      await firestore.collection('allowed_users').doc(email).set({
        'active': true,
        'isAdmin': true,
      }, SetOptions(merge: true));
      final permissions = await _permissionsForRole(RbacManager.roleSuperAdmin);
      return (
        roleId: RbacManager.roleSuperAdmin,
        permissions: permissions,
        displayName: 'Super Admin',
        roleName: 'Super Admin',
        employeeId: null,
        employeeName: null,
        photoUrl: null,
      );
    }

    throw AuthenticationException(
      'You are not authorized to access this application. Contact an administrator.',
    );
  }

  Future<UserModel> _buildAuthorizedUserModel(User user) async {
    final resolved = await _resolveAuthorizedUser(user);
    final model = UserModel.fromFirebaseUser(
      user,
      roleId: resolved.roleId,
      roleName: resolved.roleName,
      permissions: resolved.permissions,
      displayName: resolved.displayName,
      employeeId: resolved.employeeId,
      employeeName: resolved.employeeName,
      photoUrl: resolved.photoUrl,
    );
    _cachedUser = model;
    return model;
  }

  Future<void> _rejectAndSignOut(User? user) async {
    _cachedUser = null;
    try {
      await auth.signOut();
      await googleSignIn.signOut();
    } catch (_) {}
  }

  @override
  Stream<UserModel?> get authStateChanges {
    return auth.authStateChanges().asyncMap((user) async {
      if (user == null) {
        _cachedUser = null;
        return null;
      }
      try {
        return await _buildAuthorizedUserModel(user);
      } on AuthenticationException {
        await _rejectAndSignOut(user);
        return null;
      } catch (_) {
        await _rejectAndSignOut(user);
        return null;
      }
    });
  }

  @override
  UserModel? get currentUser {
    if (_cachedUser != null && _cachedUser!.id == auth.currentUser?.uid) {
      return _cachedUser;
    }
    final user = auth.currentUser;
    if (user == null) return null;
    // Synchronous snapshot without role; authStateChanges will enrich shortly.
    // Prefer not to claim isAdmin until resolved — return null only if no cache
    // would break redirects; keep minimal model with default non-admin role.
    return UserModel.fromFirebaseUser(user);
  }

  @override
  Future<UserModel> signInWithEmailAndPassword(
    String email,
    String password,
  ) async {
    try {
      final credential = await auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      if (credential.user == null) {
        throw AuthenticationException('Login failed');
      }
      try {
        return await _buildAuthorizedUserModel(credential.user!);
      } on AuthenticationException {
        await _rejectAndSignOut(credential.user);
        rethrow;
      }
    } on FirebaseAuthException catch (e) {
      throw AuthenticationException(e.message ?? 'Authentication error');
    } on AuthenticationException {
      rethrow;
    } catch (e) {
      throw ServerException('Unexpected error');
    }
  }

  @override
  Future<UserModel> signInWithGoogle() async {
    try {
      User? user;

      if (kIsWeb) {
        final googleProvider = GoogleAuthProvider();
        final userCredential = await auth.signInWithPopup(googleProvider);
        user = userCredential.user;
      } else {
        final googleUser = await googleSignIn.signIn();
        if (googleUser == null) {
          throw AuthenticationException('Google sign-in canceled');
        }

        final googleAuth = await googleUser.authentication;
        final credential = GoogleAuthProvider.credential(
          accessToken: googleAuth.accessToken,
          idToken: googleAuth.idToken,
        );

        final userCredential = await auth.signInWithCredential(credential);
        user = userCredential.user;
      }

      if (user == null || user.email == null) {
        throw AuthenticationException('Login failed');
      }

      try {
        return await _buildAuthorizedUserModel(user);
      } on AuthenticationException {
        await _rejectAndSignOut(user);
        rethrow;
      }
    } on FirebaseAuthException catch (e) {
      throw AuthenticationException(e.message ?? 'Google Sign-in failed');
    } on AuthenticationException {
      rethrow;
    } catch (e) {
      throw ServerException('Unexpected error during Google Sign-in');
    }
  }

  @override
  Future<void> signOut() async {
    try {
      _cachedUser = null;
      await googleSignIn.signOut();
      await auth.signOut();
    } catch (e) {
      throw ServerException('Failed to sign out');
    }
  }
}
