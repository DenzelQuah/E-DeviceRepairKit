import 'package:e_repairkit/models/push_service.dart';
import 'package:flutter/services.dart';
import 'package:huawei_push/huawei_push.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// This is the REAL implementation that runs ONLY on Android.
class HmsPushService implements PushService {
  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;
  static const String _tokenKey = 'hms_push_token';

  // Constructor is correct (no circular dependency)
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
      final prefs = await SharedPreferences.getInstance();
      final currentToken = prefs.getString(_tokenKey);

      Push.deleteToken("HCM");
      print("Push token deleted.");

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

  @override
  Future<void> sendNotificationToUser({
    required String userId,
    required String title,
    required String body,
    Map<String, String>? data,
  }) async {
    try {
      await _firestore.collection('notifications').add({
        'userId': userId,
        'title': title,
        'body': body,
        'data': data,
        'createdAt': FieldValue.serverTimestamp(),
      });
      print("Notification job queued for user $userId.");
    } catch (e) {
      print("Failed to queue notification job: $e");
    }
  }

  // --- 1. ADD SUBSCRIBE IMPLEMENTATION ---
  @override
  Future<void> subscribeToTopic(String topic) async {
    try {
      // Replaces invalid characters for a topic name
      final safeTopic = topic.replaceAll(RegExp(r'[^a-zA-Z0-9-_.~%]+'), '_');
      await Push.subscribe(safeTopic);
      print("Subscribed to topic: $safeTopic");
    } on PlatformException catch (e) {
      print("Failed to subscribe to topic $topic: ${e.message}");
    }
  }

  // --- 2. ADD UNSUBSCRIBE IMPLEMENTATION ---
  @override
  Future<void> unsubscribeFromTopic(String topic) async {
    try {
      final safeTopic = topic.replaceAll(RegExp(r'[^a-zA-Z0-9-_.~%]+'), '_');
      await Push.unsubscribe(safeTopic);
      print("Unsubscribed from topic: $safeTopic");
    } on PlatformException catch (e) {
      print("Failed to unsubscribe from topic $topic: ${e.message}");
    }
  }

  // --- 3. ADD TOPIC NOTIFICATION IMPLEMENTATION ---
  @override
  Future<void> sendNotificationToTopic({
    required String topic,
    required String title,
    required String body,
    Map<String, String>? data,
  }) async {
    try {
      // This is the "job" that a Cloud Function would listen for.
      await _firestore.collection('notifications').add({
        'topic': topic, // The topic you want to send to
        'title': title,
        'body': body,
        'data': data,
        'createdAt': FieldValue.serverTimestamp(),
      });
      print("Notification job queued for topic $topic.");
    } catch (e) {
      print("Failed to queue topic notification job: $e");
    }
  }
}