import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AuthService extends ChangeNotifier {
  static final AuthService instance = AuthService._init();
  final FirebaseAuth _auth = FirebaseAuth.instance;

  AuthService._init() {
    _auth.authStateChanges().listen((User? user) {
      notifyListeners();
    });
  }

  // Stream of auth changes
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // Get current user
  User? get currentUser => _auth.currentUser;

  // Sign in with email and password
  Future<UserCredential?> signInWithEmailAndPassword(
    String email,
    String password,
  ) async {
    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      return credential;
    } on FirebaseAuthException catch (e) {
      debugPrint('AuthService: Error signing in: ${e.code} - ${e.message}');
      rethrow;
    } catch (e) {
      debugPrint('AuthService: Unexpected error signing in: $e');
      rethrow;
    }
  }

  // Sign in with Google
  Future<UserCredential?> signInWithGoogle() async {
    try {
      // Trigger the authentication flow
      final GoogleSignInAccount? googleUser = await GoogleSignIn().signIn();

      if (googleUser == null) {
        // The user canceled the sign-in
        return null;
      }

      // Obtain the auth details from the request
      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      // Create a new credential
      final OAuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // Sign in to Firebase with the Google User Credential
      final userCredential = await _auth.signInWithCredential(credential);
      final user = userCredential.user;

      if (user != null && user.email != null) {
        try {
          // Check if the user's email exists in the 'allowed_users' collection
          // We use the email (lowercase) as the document ID for O(1) lookup
          final userDoc = await FirebaseFirestore.instance
              .collection('allowed_users')
              .doc(user.email!.toLowerCase())
              .get();

          if (!userDoc.exists) {
            // Not allowed - sign out immediately
            await signOut();
            throw FirebaseAuthException(
              code: 'not-authorized',
              message:
                  'This email is not authorized to access the application.',
            );
          }
        } catch (e) {
          // If it's already our custom exception, rethrow it
          if (e is FirebaseAuthException && e.code == 'not-authorized') {
            rethrow;
          }
          // For other errors (e.g. network, permission), we might want to allow or deny
          // For security, let's deny if we can't verify
          await signOut();
          debugPrint('AuthService: Error verifying allowed user: $e');
          throw FirebaseAuthException(
            code: 'auth-verification-failed',
            message: 'Failed to verify user authorization. Please try again.',
          );
        }
      }

      return userCredential;
    } catch (e) {
      debugPrint('AuthService: Error signing in with Google: $e');
      rethrow;
    }
  }

  // Sign out
  Future<void> signOut() async {
    try {
      await GoogleSignIn().signOut();
      await _auth.signOut();
    } catch (e) {
      debugPrint('AuthService: Error signing out: $e');
      rethrow;
    }
  }
}
