import 'package:e_repairkit/models/appuser.dart';

abstract class AuthService {
  /// A stream that emits the current user when auth state changes
  /// (emits null if logged out).
  Stream<AppUser?> get onAuthStateChanged;

  /// Gets the currently signed-in user, if any.
  Future<AppUser?> getCurrentUser();

  /// Triggers the Sign-in with Google flow.
  Future<AppUser?> signInWithGoogle();

  /// --- ADD THIS ---
  /// Signs in with email and password.
  Future<AppUser?> signInWithEmailAndPassword({
    required String email,
    required String password,
  });

  /// --- ADD THIS ---
  /// Creates a new user with email, password, and username.
  Future<AppUser?> signUpWithEmailAndPassword({
    required String email,
    required String password,
    required String username,
  });

  /// --- ADD THIS ---
  /// Sends a password reset email.
  Future<void> sendPasswordResetEmail({required String email});

  /// Signs the current user out.
  Future<void> signOut();
}
