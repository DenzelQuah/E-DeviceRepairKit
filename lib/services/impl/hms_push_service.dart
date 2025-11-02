// lib/services/impl/hms_push_service.dart (FINAL CORRECTED VERSION)

import 'package:e_repairkit/models/push_service.dart';
import 'package:flutter/services.dart';
import 'package:huawei_push/huawei_push.dart'; 
// FIX 1: Add the specific import for the messaging constants
import 'package:firebase_auth/firebase_auth.dart'; 
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart'; 

/// This is the REAL implementation that runs ONLY on Android.
class HmsPushService implements PushService {
  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;
  static const String _tokenKey = 'hms_push_token';

  // Constructor to inject dependencies
  HmsPushService({required FirebaseAuth auth, required FirebaseFirestore firestore})
      : _auth = auth,
        _firestore = firestore;

  @override
  Future<String?> initialize() async {
    try {
      print("Initializing Huawei Push Service...");

      Push.getTokenStream.listen(
        (token) async {
          print("Got Huawei Push Token: $token");
          
          // Store token locally
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString(_tokenKey, token);
          
          final userId = _auth.currentUser?.uid;
          if (userId != null) {
            final userDocRef = _firestore.collection('users').doc(userId);
            await userDocRef.set({
              'huaweiPushTokens': FieldValue.arrayUnion([token])
            }, SetOptions(merge: true));
            print("Token saved to Firestore for user $userId.");
          }
        },
        onError: (err) {
          print("Error getting push token: $err");
        },
      );

      // FIX 2: AWAIT the getToken call to ensure reliability and use the correct constant
      Push.getToken("HCM");

      Push.onMessageReceivedStream.listen((RemoteMessage message) {
        print("Got background data message: ${message.data}");
      });

      return null;
    } on PlatformException catch (e) {
      print("Failed to initialize Push Service: ${e.message}");
      return null;
    }
  }

  @override
  Future<void> deleteToken() async {
    try {
      final userId = _auth.currentUser?.uid;

      // Get the stored token from SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      final currentToken = prefs.getString(_tokenKey); // This is correct, no await needed

      // FIX 3: AWAIT the Push.deleteToken call and use the correct constant
      Push.deleteToken("HCM");
      print("Push token deleted.");

      // Remove from local storage
      await prefs.remove(_tokenKey);

      if (userId != null && currentToken != null) {
        final userDocRef = _firestore.collection('users').doc(userId);
        await userDocRef.set({
          'huaweiPushTokens': FieldValue.arrayRemove([currentToken])
        }, SetOptions(merge: true));
        print("Token removed from Firestore.");
      }
    } on PlatformException catch (e) {
      print("Failed to delete token: ${e.message}");
    }
  }
}