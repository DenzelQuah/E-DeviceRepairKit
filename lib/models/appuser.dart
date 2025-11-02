
import 'package:firebase_auth/firebase_auth.dart';

/// A custom user model to represent the logged-in user.
class AppUser {
  final String uid;
  final String? email;
  final String? displayName;
  final String? photoUrl;

  AppUser({
    required this.uid,
    this.email,
    this.displayName,
    this.photoUrl,
  });

  /// Factory constructor to create an AppUser from a Firebase User
  factory AppUser.fromFirebaseUser(User user) {
    return AppUser(
      uid: user.uid,
      email: user.email,
      displayName: user.displayName,
      photoUrl: user.photoURL,
    );
  }
}
