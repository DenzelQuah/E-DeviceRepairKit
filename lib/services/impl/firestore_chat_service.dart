import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:e_repairkit/models/message.dart';
import 'package:e_repairkit/services/chat_service.dart';

class FirestoreChatService implements ChatService {
  final _firestore = FirebaseFirestore.instance;

  // Helper to get the messages sub-collection
  CollectionReference<Message> _getMessagesCollection(String sessionId) {
    return _firestore
        .collection('chatSessions')
        .doc(sessionId)
        .collection('messages')
        .withConverter<Message>(
          fromFirestore: (snapshot, _) => Message.fromJson(snapshot.data()!),
          toFirestore: (message, _) => message.toJson(),
        );
  }

  @override
  Stream<List<Message>> getMessages(String sessionId) {
    return _getMessagesCollection(sessionId)
        .orderBy('timestamp', descending: false) // Show oldest first
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) => doc.data()).toList();
    });
  }

  @override
  Future<void> saveMessage(Message message, String sessionId) async {
    await _getMessagesCollection(sessionId).doc(message.id).set(message);
  }
}