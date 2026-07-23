import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../../../../core/error/exceptions.dart';
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

  AuthRemoteDataSourceImpl({
    required this.auth,
    required this.googleSignIn,
    required this.firestore,
  });

  Future<UserModel> _userFromFirebase(User user) async {
    if (user.email == null) {
      return UserModel.fromFirebaseUser(user);
    }
    try {
      final userDoc = await firestore
          .collection('allowed_users')
          .doc(user.email!.toLowerCase())
          .get();
      if (!userDoc.exists) {
        return UserModel.fromFirebaseUser(user);
      }
      final data = userDoc.data();
      final model = UserModel.fromFirebaseUserAndWhitelist(user, data);
      if (!model.isActive) {
        throw AuthenticationException(
          'This account has been deactivated. Contact an administrator.',
        );
      }
      return model;
    } on AuthenticationException {
      rethrow;
    } catch (_) {
      return UserModel.fromFirebaseUser(user);
    }
  }

  @override
  Stream<UserModel?> get authStateChanges {
    return auth.authStateChanges().asyncMap((user) async {
      if (user != null) {
        try {
          return await _userFromFirebase(user);
        } on AuthenticationException {
          await signOut();
          return null;
        }
      }
      return null;
    });
  }

  @override
  UserModel? get currentUser {
    final user = auth.currentUser;
    if (user != null) {
      // Sync path has no role yet; authStateChanges fills it in.
      return UserModel.fromFirebaseUser(user);
    }
    return null;
  }

  @override
  Future<UserModel> signInWithEmailAndPassword(
    String email,
    String password,
  ) async {
    try {
      final credential = await auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      if (credential.user != null) {
        return await _userFromFirebase(credential.user!);
      }
      throw AuthenticationException('Login failed');
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

      if (user != null && user.email != null) {
        try {
          final userDoc = await firestore
              .collection('allowed_users')
              .doc(user.email!.toLowerCase())
              .get();

          if (!userDoc.exists) {
            await signOut();
            throw AuthenticationException(
              'This email is not authorized to access the application.',
            );
          }

          final data = userDoc.data();
          final isActive = data?['isActive'] as bool? ?? true;
          if (!isActive) {
            await signOut();
            throw AuthenticationException(
              'This account has been deactivated. Contact an administrator.',
            );
          }

          return UserModel.fromFirebaseUserAndWhitelist(user, data);
        } catch (e) {
          if (e is AuthenticationException) rethrow;
          await signOut();
          throw AuthenticationException(
            'Failed to verify user authorization. Please try again.',
          );
        }
      }

      if (user != null) {
        return UserModel.fromFirebaseUser(user);
      }
      throw AuthenticationException('Login failed');
    } on FirebaseAuthException catch (e) {
      throw AuthenticationException(e.message ?? 'Google Sign-in failed');
    } catch (e) {
      if (e is AuthenticationException) rethrow;
      throw ServerException('Unexpected error during Google Sign-in');
    }
  }

  @override
  Future<void> signOut() async {
    try {
      await googleSignIn.signOut();
      await auth.signOut();
    } catch (e) {
      throw ServerException('Failed to sign out');
    }
  }
}
