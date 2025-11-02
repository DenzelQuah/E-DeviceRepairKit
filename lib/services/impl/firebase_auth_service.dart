import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:e_repairkit/models/appuser.dart';
import 'package:e_repairkit/services/auth_service.dart'; // <-- Your abstract class
import 'package:firebase_auth/firebase_auth.dart'; // <-- Firebase Auth package
import 'package:google_sign_in/google_sign_in.dart'; // <-- Google Sign-In package

class FirebaseAuthService implements AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  /// Converts a Firebase User into your custom AppUser
  AppUser? _appUserFromFirebase(User? user) {
    return user == null ? null : AppUser.fromFirebaseUser(user);
  }

  @override
  Stream<AppUser?> get onAuthStateChanged {
    return _auth.authStateChanges().map(_appUserFromFirebase);
  }

  @override
  Future<AppUser?> getCurrentUser() async {
    return _appUserFromFirebase(_auth.currentUser);
  }

  @override
  Future<AppUser?> signInWithGoogle() async {
    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) return null; // User canceled
      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;
      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
      final UserCredential userCredential =
          await _auth.signInWithCredential(credential);
      final User? user = userCredential.user;

      if (user != null) {
        // Create/update user document in Firestore
        final docRef = _firestore.collection('users').doc(user.uid);
        final doc = await docRef.get();
        if (!doc.exists) {
          await docRef.set({
            'username': user.displayName ?? 'Google User',
            'email': user.email,
            'uid': user.uid,
            'createdAt': Timestamp.now(),
            'photoUrl': user.photoURL,
          });
        }
        return _appUserFromFirebase(user);
      }
      return null;
    } catch (e) {
      print('Google Sign-In Error: $e');
      throw Exception('Failed to sign in with Google.');
    }
  }

  @override
  Future<AppUser?> signInWithEmailAndPassword(
      {required String email, required String password}) async {
    try {
      final userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      return _appUserFromFirebase(userCredential.user);
    } on FirebaseAuthException catch (e) {
      throw Exception('Failed to sign in: ${e.message}');
    }
  }

  @override
  Future<AppUser?> signUpWithEmailAndPassword({
    required String email,
    required String password,
    required String username,
  }) async {
    try {
      // 1. Create user in Firebase Auth
      UserCredential userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      User? user = userCredential.user;

      if (user != null) {
        // 2. Update their profile with the username
        await user.updateDisplayName(username);
        await user.reload();
        user = _auth.currentUser; // Get the reloaded user

        // 3. Create the user document in Firestore
        await _firestore.collection('users').doc(user!.uid).set({
          'username': username,
          'email': email,
          'uid': user.uid,
          'createdAt': Timestamp.now(),
          'photoUrl': null, // Email sign up doesn't have a photo URL
        });
        return _appUserFromFirebase(user);
      }
      return null;
    } on FirebaseAuthException catch (e) {
      throw Exception('Failed to sign up: ${e.message}');
    }
  }

  @override
  Future<void> sendPasswordResetEmail({required String email}) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
    } on FirebaseAuthException catch (e) {
      throw Exception('Failed to send reset link: ${e.message}');
    }
  }

  @override
  Future<void> signOut() async {
    await _googleSignIn.signOut();
    await _auth.signOut();
  }
}

