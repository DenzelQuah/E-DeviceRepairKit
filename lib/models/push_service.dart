/// Defines the abstract "contract" for any push notification service
/// used in the app. This allows for interchangeable implementations,
/// such as HMS, GMS, or a "stub" service for unsupported platforms.
abstract class PushService {
  /// Initializes the push service and registers the device for a token.
  Future<String?> initialize();

  /// Deletes the device's token from the push service and local storage.
  Future<void> deleteToken();

  /// Queues a 1-to-1 notification for a specific user.
  Future<void> sendNotificationToUser({
    required String userId,
    required String title,
    required String body,
    Map<String, String>? data, // For deep-linking
  });

  // --- 1. ADD THIS FUNCTION ---
  /// Subscribes the current device to a topic (e.g., "Laptop_Repair").
  Future<void> subscribeToTopic(String topic);

  // --- 2. ADD THIS FUNCTION ---
  /// Unsubscribes the current device from a topic.
  Future<void> unsubscribeFromTopic(String topic);

  // --- 3. ADD THIS FUNCTION ---
  /// Queues a broadcast notification for all users subscribed to a topic.
  Future<void> sendNotificationToTopic({
    required String topic,
    required String title,
    required String body,
    Map<String, String>? data,
  });
}