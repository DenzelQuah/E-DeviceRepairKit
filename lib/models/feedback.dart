import 'package:cloud_firestore/cloud_firestore.dart';

class FeedbackEntry {
  final String id;
  final String suggestionId;
  final String userId;
  final int rating;
  final bool tried;
  final bool saved;
  final String? notes;
  final Timestamp createdAt;
  final Map<String, dynamic>? metadata;

  FeedbackEntry({
    required this.id,
    required this.suggestionId,
    required this.userId,
    required this.rating,
    required this.tried,
    required this.saved,
    this.notes,
    required this.createdAt,
    this.metadata,
  });

  /// The factory constructor that was missing
  factory FeedbackEntry.fromJson(Map<String, dynamic> json) {
    return FeedbackEntry(
      id: json['id'] as String,
      suggestionId: json['suggestionId'] as String,
      userId: json['userId'] as String,
      rating: (json['rating'] ?? 0) as int,
      tried: (json['tried'] ?? false) as bool,
      saved: (json['saved'] ?? false) as bool,
      notes: json['notes'] as String?,
      createdAt: json['createdAt'] as Timestamp,
      metadata: json['metadata'] as Map<String, dynamic>?,
    );
  }

  /// Converts the object to a Map for Firestore
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'suggestionId': suggestionId,
      'userId': userId,
      'rating': rating,
      'tried': tried,
      'saved': saved,
      'notes': notes,
      'createdAt': createdAt,
      'metadata': metadata,
    };
  }
}
