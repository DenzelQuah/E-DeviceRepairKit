import '../models/message.dart';

abstract class ChatService {
  // Get a real-time stream of messages
  Stream<List<Message>> getMessages(String sessionId);
  
  // Get chat history
  Future<List<Message>> getHistory(String sessionId);
  
  // Save a new message
  Future<void> saveMessage(Message message, String sessionId);

  // Delete reply messages (AI responses) that are in reply to a particular user message
  Future<void> deleteReplies(String sessionId, String inReplyToId);

  
}
