import 'package:cloud_firestore/cloud_firestore.dart';

class ForumPost {
  final String id;
  final String userId;
  final String username;
  final String title;
  final String content; // This will be the user's review/thoughts
  final Timestamp timestamp;
  final int likeCount;
  final int commentCount;
  
  // --- ADD THIS ---
  // This map will store the RepairSuggestion JSON
  final Map<String, dynamic>? sharedSolution; 

  ForumPost({
    required this.id,
    required this.userId,
    required this.username,
    required this.title,
    required this.content,
    required this.timestamp,
    this.likeCount = 0,
    this.commentCount = 0,
    this.sharedSolution, // <-- Add to constructor
  });

  factory ForumPost.fromJson(Map<String, dynamic> json) {
    return ForumPost(
      id: json['id'] as String,
      userId: json['userId'] as String,
      username: json['username'] as String,
      title: json['title'] as String,
      content: json['content'] as String,
      timestamp: json['timestamp'] as Timestamp,
      likeCount: json['likeCount'] ?? 0,
      commentCount: json['commentCount'] ?? 0,
      // --- ADD THIS ---
      sharedSolution: json['sharedSolution'] as Map<String, dynamic>?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'username': username,
      'title': title,
      'content': content,
      'timestamp': timestamp,
      'likeCount': likeCount,
      'commentCount': commentCount,
      // --- ADD THIS ---
      'sharedSolution': sharedSolution,
    };
  }
}
