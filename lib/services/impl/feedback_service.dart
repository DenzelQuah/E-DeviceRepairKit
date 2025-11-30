import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:e_repairkit/models/feedback.dart';
import 'package:e_repairkit/services/feedback_service.dart';

class FirestoreFeedbackService implements FeedbackService {
  final _firestore = FirebaseFirestore.instance;

  /// Helper to get the feedback collection with a converter
  CollectionReference<FeedbackEntry> _feedbackCollection() {
    return _firestore
        .collection('feedback')
        .withConverter<FeedbackEntry>(
          fromFirestore: (snapshot, _) =>
              FeedbackEntry.fromJson(snapshot.data()!),
          toFirestore: (entry, _) => entry.toJson(),
        );
  }

  @override
  Future<void> saveFeedback(FeedbackEntry entry) async {
    // Use the suggestionId and a userId to create a unique ID
    // This ensures a user can only rate/try/save a suggestion *once*.
    final docId = '${entry.suggestionId}_${entry.userId}';
    
    // Use SetOptions(merge: true) to create or update the document
    // without overwriting fields.
    await _feedbackCollection().doc(docId).set(entry, SetOptions(merge: true));
  }

  @override
  Stream<List<FeedbackEntry>> getMySavedFeedback(String userId) {
    return _feedbackCollection()
        .where('userId', isEqualTo: userId)
        .where('saved', isEqualTo: true) // From your SuggestionCard
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => doc.data()).toList());
  }
  
  // --- THIS IS THE COMPLETED FUNCTION ---
  @override
  Future<List<FeedbackEntry>> fetchForSuggestion(String suggestionId) async {
    try {
      final snapshot = await _feedbackCollection()
          .where('suggestionId', isEqualTo: suggestionId)
          .orderBy('createdAt', descending: true)
          .get();
          
      return snapshot.docs.map((doc) => doc.data()).toList();
    } catch (e) {
      print("Error fetching feedback for suggestion $suggestionId: $e");
      return []; // Return an empty list on error
    }
  }
}