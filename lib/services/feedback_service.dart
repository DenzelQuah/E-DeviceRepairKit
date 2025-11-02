import 'package:e_repairkit/models/feedback.dart';

abstract class FeedbackService {
  Future<void> saveFeedback(FeedbackEntry entry);

  Stream<List<FeedbackEntry>> getMySavedFeedback(String userId);
  
  // --- ADD THIS METHOD ---
  /// Fetches all feedback for a single solution (for the detail page)
  Future<List<FeedbackEntry>> fetchForSuggestion(String suggestionId);
}
