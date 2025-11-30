import 'package:cloud_firestore/cloud_firestore.dart'; // 1. Import firestore

import 'repair_suggestion.dart';

class Message {
  final String id;
  final String text;
  final bool isFromUser;
  final List<RepairSuggestion>? suggestions;
  final Timestamp timestamp; // 2. Use Timestamp for Firebase
  final String?
  inReplyTo; // message id this message replies to (for AI replies)
  final bool edited;

  Message({
    required this.id,
    required this.text,
    required this.isFromUser,
    this.suggestions,
    required this.timestamp, // 3. Add to constructor
    this.inReplyTo,
    required this.edited,
  });

  // --- ADD THIS FACTORY ---
  factory Message.fromJson(Map<String, dynamic> json) {
    var suggestionsList =
        (json['suggestions'] as List? ?? [])
            .map((s) => RepairSuggestion.fromJson(s as Map<String, dynamic>))
            .toList();

    return Message(
      id: json['id'],
      text: json['text'],
      isFromUser: json['isFromUser'],
      timestamp:
          json['timestamp'] ?? Timestamp.now(),
      suggestions: suggestionsList.isNotEmpty ? suggestionsList : null,
      inReplyTo: json['inReplyTo'] as String?,
      edited: json['edited'] as bool? ?? false,
    );
  }

  // --- ADD THIS METHOD ---
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'text': text,
      'isFromUser': isFromUser,
      'timestamp': timestamp,
      'suggestions': suggestions?.map((s) => s.toJson()).toList(),
      'inReplyTo': inReplyTo,
      'edited': edited,
    };
  }
}
