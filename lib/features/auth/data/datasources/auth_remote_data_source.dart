import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
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

  @override
  Stream<UserModel?> get authStateChanges {
    return auth.authStateChanges().map((user) {
      if (user != null) {
        return UserModel.fromFirebaseUser(user);
      }
      return null;
    });
  }

  @override
  UserModel? get currentUser {
    final user = auth.currentUser;
    if (user != null) {
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
        return UserModel.fromFirebaseUser(credential.user!);
      }
      throw AuthenticationException('Login failed');
    } on FirebaseAuthException catch (e) {
      throw AuthenticationException(e.message ?? 'Authentication error');
    } catch (e) {
      throw ServerException('Unexpected error');
    }
  }

  @override
  Future<UserModel> signInWithGoogle() async {
    try {
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
      final user = userCredential.user;

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
