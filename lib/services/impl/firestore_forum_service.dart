import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:e_repairkit/models/comment_forum.dart';
import 'package:e_repairkit/models/forum_post.dart';
import 'package:e_repairkit/models/repair_suggestion.dart';
import 'package:e_repairkit/services/forum_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:e_repairkit/models/push_service.dart'; // 1. Import PushService

class FirestoreForumService implements ForumService {
  final _firestore = FirebaseFirestore.instance;
  final PushService _pushService; // 2. Injected PushService

  // Getters for current user info
  String get _currentUserId => FirebaseAuth.instance.currentUser?.uid ?? 'anonymous';
  String get _currentUsername =>
      FirebaseAuth.instance.currentUser?.displayName ?? 'Anonymous User';

  // 3. Constructor with Dependency Injection
  FirestoreForumService({required PushService pushService})
      : _pushService = pushService;

  /// Helper for the 'solutions' collection
  CollectionReference<RepairSuggestion> _solutionsCollection() {
    return _firestore.collection('solutions').withConverter<RepairSuggestion>(
          fromFirestore: (snapshot, _) =>
              RepairSuggestion.fromJson(snapshot.data()!),
          toFirestore: (suggestion, _) => suggestion.toJson(),
        );
  }

  /// Helper for the 'comments' subcollection
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
    await _solutionsCollection().doc(suggestion.id).set(
          suggestion,
          SetOptions(merge: true),
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
      postId: solutionId,
      userId: _currentUserId,
      username: _currentUsername,
      text: text,
      timestamp: Timestamp.now(),
    );

    final solutionRef = _solutionsCollection().doc(solutionId);

    final batch = _firestore.batch();
    batch.set(newCommentRef, newComment);
    batch.update(solutionRef, {
      'commentCount': FieldValue.increment(1),
    });
    await batch.commit();

    // --- 4. SEND PUSH NOTIFICATION ---
    try {
      final solutionDoc = await solutionRef.get();
      if (!solutionDoc.exists) return;

      // *** THIS IS THE CRITICAL FIX ***
      // We get the userId of the person who posted the solution
      final originalPosterId = solutionDoc.data()?.id; 

      // Only send if the commenter is NOT the original poster
      if (originalPosterId != null && originalPosterId != _currentUserId) {
        await _pushService.sendNotificationToUser(
          userId: originalPosterId,
          title: "New Reply on E-RepairKit",
          body: "$_currentUsername replied: $text",
          data: {'postId': solutionId, 'type': 'forum_reply'},
        );
        print("Push notification sent to $originalPosterId");
      }
    } catch (e) {
      print("Failed to send push notification: $e");
    }
  }

  @override
  Future<void> deleteComment(String solutionId, String commentId) async {
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

    // --- 5. SEND "VERIFIED FIX" NOTIFICATION ---
    if (newRating != null && newRating >= 4) {
      try {
        final solutionDoc = await solutionRef.get();
        if (!solutionDoc.exists) return;

        // *** THIS IS THE CRITICAL FIX ***
        final originalPosterId = solutionDoc.data()?.id;

        if (originalPosterId != null && originalPosterId != _currentUserId) {
          await _pushService.sendNotificationToUser(
            userId: originalPosterId,
            title: "Your Solution was Verified!",
            body: "A user found your solution for '${solutionDoc.data()?.title}' helpful.",
            data: {'postId': solutionId, 'type': 'solution_verified'},
          );
          print("Verified fix notification sent to $originalPosterId");
        }
      } catch (e) {
        print("Failed to send verification notification: $e");
      }
    }
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

  @override
  Future<void> createPost(
      {required String title,
      required String content,
      RepairSuggestion? suggestion}) async {
    final newPostRef = _firestore.collection('forumPosts').doc();

    final newPost = ForumPost(
      id: newPostRef.id,
      userId: _currentUserId,
      username: _currentUsername,
      title: title,
      content: content,
      timestamp: Timestamp.now(),
      likeCount: 0,
      commentCount: 0,
      sharedSolution: suggestion?.toJson(),
    );

    await newPostRef.set(newPost.toJson());
  }
}