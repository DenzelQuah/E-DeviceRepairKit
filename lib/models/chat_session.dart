import 'package:cloud_firestore/cloud_firestore.dart';

class ChatSession {
  final String id;
  final String title;
  final DateTime lastActive;

  ChatSession({
    required this.id,
    required this.title,
    required this.lastActive,
  });

  factory ChatSession.fromSnapshot(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ChatSession(
      id: doc.id,
      title: data['title'] ?? 'New Chat', // You should save a 'title' in Firestore
      lastActive: (data['lastActive'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}