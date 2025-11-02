import 'package:cloud_firestore/cloud_firestore.dart';

class Comment {
  final String id;
  final String postId;
  final String userId;
  final String username;
  final String text;
  final Timestamp timestamp;

  Comment({
    required this.id,
    required this.postId,
    required this.userId,
    required this.username,
    required this.text,
    required this.timestamp,
  });

  // From Firestore to our model
  factory Comment.fromJson(Map<String, dynamic> json) {
    return Comment(
      id: json['id'] as String,
      postId: json['postId'] as String,
      userId: json['userId'] as String,
      username: json['username'] as String,
      text: json['text'] as String,
      timestamp: json['timestamp'] as Timestamp,
    );
  }

  // From our model to Firestore
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'postId': postId,
      'userId': userId,
      'username': username,
      'text': text,
      'timestamp': timestamp,
    };
  }
}
