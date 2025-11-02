import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:e_repairkit/models/comment_forum.dart';
import 'package:e_repairkit/models/forum_post.dart';
import 'package:e_repairkit/models/repair_suggestion.dart';
import 'package:e_repairkit/services/forum_service.dart';
import 'package:firebase_auth/firebase_auth.dart';

class FirestoreForumService implements ForumService {
  final _firestore = FirebaseFirestore.instance;
  // final _currentUser = FirebaseAuth.instance.currentUser; // <-- 1. REMOVE THIS STALE VARIABLE

  // --- 2. THIS IS THE FIX ---
  // These getters now fetch the *current* user every time they are called.
  String get _currentUserId => FirebaseAuth.instance.currentUser?.uid ?? 'anonymous';
  String get _currentUsername =>
      FirebaseAuth.instance.currentUser?.displayName ?? 'Anonymous User';
  // --- END OF FIX ---

  /// Helper for the new 'solutions' collection
  CollectionReference<RepairSuggestion> _solutionsCollection() {
    return _firestore.collection('solutions').withConverter<RepairSuggestion>(
          fromFirestore: (snapshot, _) =>
              RepairSuggestion.fromJson(snapshot.data()!),
          toFirestore: (suggestion, _) => suggestion.toJson(),
        );
  }

  /// Helper for the 'comments' subcollection on a solution
  CollectionReference<Comment> _commentsCollection(String solutionId) {
    return _solutionsCollection()
        .doc(solutionId)
        .collection('comments')
        .withConverter<Comment>(
          fromFirestore: (snapshot, _) => Comment.fromJson(snapshot.data()!),
          toFirestore: (comment, _) => comment.toJson(),
        );
  }

  @override
  Future<void> publishSolution(RepairSuggestion suggestion) async {
    // This creates/updates the main solution document
    await _solutionsCollection().doc(suggestion.id).set(
          suggestion,
          SetOptions(mergeFields: [
            'id',
            'title',
            'steps',
            'tools',
            'confidence',
            'estimatedTimeMinutes',
            'safetyNotes',
            'query',
            'keywords'
          ]),
        );
  }

  @override
  Stream<List<RepairSuggestion>> getPublishedSolutions() {
    return _solutionsCollection()
        .orderBy('tryCount', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => doc.data()).toList());
  }

  @override
  Stream<List<Comment>> getComments(String solutionId) {
    return _commentsCollection(solutionId)
        .orderBy('timestamp', descending: false)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => doc.data()).toList());
  }

  @override
  Future<void> addComment(
      {required String solutionId, required String text}) async {
    final newCommentRef = _commentsCollection(solutionId).doc();
    final newComment = Comment(
      id: newCommentRef.id,
      postId: solutionId, // Link it to the solution
      userId: _currentUserId, // This will now be your REAL ID
      username: _currentUsername, // This will now be your REAL username
      text: text,
      timestamp: Timestamp.now(),
    );

    final batch = _firestore.batch();
    batch.set(newCommentRef, newComment);
    batch.update(_solutionsCollection().doc(solutionId), {
      'commentCount': FieldValue.increment(1),
    });
    await batch.commit();
  }

  @override
  Future<void> deleteComment(String solutionId, String commentId) async {
    // TODO: Add security rule to check if user is admin or comment owner
    final batch = _firestore.batch();
    batch.delete(_commentsCollection(solutionId).doc(commentId));
    batch.update(_solutionsCollection().doc(solutionId), {
      'commentCount': FieldValue.increment(-1),
    });
    await batch.commit();
  }

  @override
  Future<void> updateSolutionStats(
      {required String solutionId, bool didTry = false, int? newRating}) async {
    final solutionRef = _solutionsCollection().doc(solutionId);

    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(solutionRef);
      if (!snapshot.exists) {
        throw Exception("Solution not found!");
      }

      final data = snapshot.data()!;
      int newTryCount = data.tryCount;
      double newAvgRating = data.avgRating;
      int newRatingCount = data.ratingCount;

      if (didTry) newTryCount++;

      if (newRating != null && newRating > 0) {
        newRatingCount++;
        newAvgRating =
            ((data.avgRating * data.ratingCount) + newRating) / newRatingCount;
      }

      transaction.update(solutionRef, {
        'tryCount': newTryCount,
        'avgRating': newAvgRating,
        'ratingCount': newRatingCount,
      });
    });
  }


  Stream<List<Comment>> getMyComments(String userId) {
    return _firestore
        .collectionGroup('comments')
        .where('userId', isEqualTo: userId)
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => Comment.fromJson(doc.data())).toList());
  }

  @override
  Stream<List<RepairSuggestion>> getSolutionsByIds(List<String> solutionIds) {
    if (solutionIds.isEmpty) {
      return Stream.value([]);
    }
    return _solutionsCollection()
        .where('id', whereIn: solutionIds)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => doc.data()).toList());
  }

  // --- This is the function your CreatePostView is looking for ---
  @override
  Future<void> createPost(
      {required String title,
      required String content,
      RepairSuggestion? suggestion}) async {
    final newPostRef = _firestore.collection('forumPosts').doc(); // New collection

    final newPost = ForumPost(
      id: newPostRef.id,
      userId: _currentUserId, // This will now be your REAL ID
      username: _currentUsername, // This will now be your REAL username
      title: title,
      content: content,
      timestamp: Timestamp.now(),
      likeCount: 0,
      commentCount: 0,
      sharedSolution: suggestion?.toJson(), // Save the solution here
    );

    await newPostRef.set(newPost.toJson());
  }
}

