/// The abstract "contract" for any push notification service in the app.
abstract class PushService {
  Future<String?> initialize();
  Future<void> deleteToken();
}
