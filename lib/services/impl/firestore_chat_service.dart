import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:e_repairkit/models/message.dart';
import 'package:e_repairkit/services/chat_service.dart';

class FirestoreChatService implements ChatService {
  final _firestore = FirebaseFirestore.instance;

  CollectionReference<Message> _messagesCollection(String sessionId) {
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
    return _messagesCollection(sessionId)
        .orderBy('timestamp', descending: false)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => doc.data()).toList());
  }

  // --- ADD THIS FUNCTION ---
  @override
  Future<List<Message>> getHistory(String sessionId) async {
    final snapshot = await _messagesCollection(sessionId)
        .orderBy('timestamp', descending: true)
        .limit(20) // Get the last 20 messages for context
        .get();
    
    // We reverse the list so it's in chronological order (oldest to newest)
    return snapshot.docs.map((doc) => doc.data()).toList().reversed.toList();
  }
  // --- END OF ADDITION ---

  @override
  Future<void> saveMessage(Message message, String sessionId) async {
    await _messagesCollection(sessionId).doc(message.id).set(message);
  }

  @override
  Future<void> deleteReplies(String sessionId, String originalMessageId) async {
    final snapshot = await _messagesCollection(sessionId)
        .where('inReplyTo', isEqualTo: originalMessageId)
        .get();
    
    final batch = _firestore.batch();
    for (final doc in snapshot.docs) {
      batch.delete(doc.reference);
    }
    await batch.commit();
  }
}