import '../models/message.dart';

abstract class ChatService {
  // Get a real-time stream of messages
  Stream<List<Message>> getMessages(String sessionId);

  // Save a new message
  Future<void> saveMessage(Message message, String sessionId);
}