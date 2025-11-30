import 'package:e_repairkit/models/push_service.dart';

/// A stub implementation of [PushService] that does nothing.
/// This is used on platforms where push notifications are not supported,
/// such as web or desktop, to prevent the app from crashing.
class StubPushService implements PushService {
  @override
  Future<String?> initialize() async {
    print("StubPushService: initialize() called (non-Android platform).");
    return null;
  }

  @override
  Future<void> deleteToken() async {
    print("StubPushService: deleteToken() called (non-Android platform).");
  }

  @override
  Future<void> sendNotificationToUser({
    required String userId,
    required String title,
    required String body,
    Map<String, String>? data,
  }) async {
    print("StubPushService: sendNotificationToUser() called for $userId.");
  }

  // --- 1. ADD DUMMY SUBSCRIBE ---
  @override
  Future<void> subscribeToTopic(String topic) async {
    print("StubPushService: Subscribed to topic $topic.");
  }

  // --- 2. ADD DUMMY UNSUBSCRIBE ---
  @override
  Future<void> unsubscribeFromTopic(String topic) async {
    print("StubPushService: Unsubscribed from topic $topic.");
  }

  // --- 3. ADD DUMMY TOPIC NOTIFICATION ---
  @override
  Future<void> sendNotificationToTopic({
    required String topic,
    required String title,
    required String body,
    Map<String, String>? data,
  }) async {
    print("StubPushService: sendNotificationToTopic() called for $topic.");
  }
}