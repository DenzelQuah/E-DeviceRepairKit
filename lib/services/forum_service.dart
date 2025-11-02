import 'package:e_repairkit/models/comment_forum.dart';
import 'package:e_repairkit/models/repair_suggestion.dart';

abstract class ForumService {
  /// Publishes an AI solution to the global 'solutions' collection.
  Future<void> publishSolution(RepairSuggestion suggestion);

  /// Gets a stream of all published solutions, sorted by most "tried".
  Stream<List<RepairSuggestion>> getPublishedSolutions();

  /// Gets a stream of all comments for a specific solution.
  Stream<List<Comment>> getComments(String solutionId);

  Stream<List<RepairSuggestion>> getSolutionsByIds(List<String> solutionIds);

  /// Adds a comment to a solution.
  Future<void> addComment({
    required String solutionId,
    required String text,
  });

  /// Deletes a comment.
  Future<void> deleteComment(String solutionId, String commentId);

  /// Updates the public stats for a solution (try count, rating).
  Future<void> updateSolutionStats({
    required String solutionId,
    bool didTry,
    int? newRating,
  });

  createPost({required String title, required String content, required RepairSuggestion suggestion}) {}
}
