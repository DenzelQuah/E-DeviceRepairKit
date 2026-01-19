import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:e_repairkit/models/push_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:e_repairkit/models/comment_forum.dart';
import 'package:e_repairkit/models/repair_suggestion.dart';
// import 'package:e_repairkit/models/push_service.dart'; // UNCOMMENT if you have PushService ready

class ForumService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final PushService _pushService; // UNCOMMENT if you use PushService

  // Constructor (Uncomment below if using PushService)
  ForumService({required PushService pushService}) : _pushService = pushService;

  // --- 1. GET ALL PUBLISHED SOLUTIONS ---
Stream<List<RepairSuggestion>> getPublishedSolutions() {
    return _firestore
        .collection('forumPosts')
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map((doc) {
            final data = doc.data();

            return RepairSuggestion(
              id: doc.id,
              query: data['query'] ?? data['title'] ?? 'General Issue',
              title: data['title'] ?? 'Repair Solution',
              deviceType: data['deviceType'] ?? 'Other',
              
              // FIX: Prioritize 'steps' list first. Only use 'content' if 'steps' is missing.
              steps: _parseSteps(data['steps'] ?? data['content']),
              
              tools: data['tools'] is List 
                  ? List<String>.from(data['tools'].map((e) => e.toString()))
                  : [],
              
              safetyNotes: data['safetyNotes'] is List 
                  ? (data['safetyNotes'] as List).join(', ') 
                  : (data['safetyNotes']?.toString() ?? ''),

              confidence: (data['confidence'] as num?)?.toDouble() ?? 0.0,
              estimatedTimeMinutes: (data['estimatedTimeMinutes'] as num?)?.toInt() ?? 0,
              tryCount: (data['tryCount'] ?? data['likeCount'] as num?)?.toInt() ?? 0,
              avgRating: (data['rating'] as num?)?.toDouble() ?? 0.0,
              ratingCount: (data['ratingCount'] as num?)?.toInt() ?? 0,
              commentCount: (data['commentCount'] as num?)?.toInt() ?? 0,
            );
          }).toList();
        });
  }

  // --- 2. PUBLISH SOLUTION ---
Future<void> publishSolution(RepairSuggestion suggestion) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    await _firestore.collection('forumPosts').add({
      'userId': user.uid,
      'username': user.displayName ?? 'Anonymous',
      'query': suggestion.query,
      'title': suggestion.title,
      'deviceType': suggestion.deviceType,
      'steps': suggestion.steps, 
      'content': suggestion.steps.join('\n'), // Sync content with steps
      'tools': suggestion.tools,
      'safetyNotes': suggestion.safetyNotes,
      'estimatedTimeMinutes': suggestion.estimatedTimeMinutes,
      'confidence': suggestion.confidence,
      'tryCount': 0, 'likeCount': 0, 'commentCount': 0, 'rating': 0.0, 'ratingCount': 0,
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  // --- 3. GET SAVED SOLUTIONS (Profile Page) ---
  Stream<List<RepairSuggestion>> getSolutionsByIds(List<String> ids) {
    if (ids.isEmpty) return Stream.value([]);

    // Firestore limit: max 10 items in 'whereIn'
    final chunk = ids.take(10).toList();

    return _firestore
        .collection('forumPosts')
        .where(FieldPath.documentId, whereIn: chunk)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data();
        // Re-use mapping logic manually to ensure consistency
        return RepairSuggestion(
          id: doc.id,
          query: data['query'] ?? data['title'] ?? 'General Issue',
          title: data['title'] ?? 'Repair Solution',
          deviceType: data['deviceType'] ?? 'Other',
          steps: _parseSteps(data['content'] ?? data['steps']),
          tools: data['tools'] is List ? List<String>.from(data['tools'].map((e) => e.toString())) : [],
          safetyNotes: data['safetyNotes'] is List ? (data['safetyNotes'] as List).join(', ') : (data['safetyNotes']?.toString() ?? ''),
          confidence: (data['confidence'] as num?)?.toDouble() ?? 0.0,
          estimatedTimeMinutes: (data['estimatedTimeMinutes'] as num?)?.toInt() ?? 0,
          tryCount: (data['tryCount'] ?? data['likeCount'] as num?)?.toInt() ?? 0,
          avgRating: (data['rating'] as num?)?.toDouble() ?? 0.0,
          ratingCount: (data['ratingCount'] as num?)?.toInt() ?? 0,
          commentCount: (data['commentCount'] as num?)?.toInt() ?? 0,
        );
      }).toList();
    });
  }

  

  // --- 4. COMMENTS & INTERACTIONS ---
  
  Stream<List<Comment>> getComments(String solutionId) {
    return _firestore
        .collection('forumPosts')
        .doc(solutionId)
        .collection('comments')
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        // Fix: Pass ID correctly
        return Comment.fromJson(doc.data(), doc.id); 
      }).toList();
    });
  }

  // Get ALL comments by a specific user (for Profile)
  Stream<List<Comment>> getUserComments(String userId) {
    return _firestore
        .collectionGroup('comments')
        .where('userId', isEqualTo: userId)
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map((doc) {
            return Comment.fromJson(doc.data(), doc.id);
          }).toList();
        });
  }

  Future<void> addComment({required String solutionId, required String text}) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    
    // 1. Add Comment
    await _firestore.collection('forumPosts').doc(solutionId).collection('comments').add({
      'userId': user.uid,
      'username': user.displayName ?? 'User',
      'text': text,
      'timestamp': FieldValue.serverTimestamp(),
    });

    // 2. Update Count
    final postRef = _firestore.collection('forumPosts').doc(solutionId);
    await postRef.update({
      'commentCount': FieldValue.increment(1),
    });

    // 3. Send Push Notification (Logic merged from your other file)
    try {
      final postDoc = await postRef.get();
      if (postDoc.exists) {
        final originalPosterId = postDoc.data()?['userId'];
        if (originalPosterId != null && originalPosterId != user.uid) {
          await _pushService.sendNotificationToUser(
            userId: originalPosterId,
            title: "New Reply on E-RepairKit",
            body: "${user.displayName} replied: $text",
            data: {'postId': solutionId, 'type': 'forum_reply'},
          );
        }
      }
    } catch (e) {
      print("Push Error: $e");
    }
    
  }

  Future<void> createPost({
    required String title,
    required String content,
    required RepairSuggestion suggestion,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    await _firestore.collection('forumPosts').add({
      'userId': user.uid,
      'username': user.displayName ?? 'Anonymous',
      'query': suggestion.query.isNotEmpty ? suggestion.query : title,
      'title': title,
      'deviceType': suggestion.deviceType, 
      'content': content, 
      'steps': _parseSteps(content), 
      'tools': suggestion.tools,
      'safetyNotes': suggestion.safetyNotes,
      'estimatedTimeMinutes': suggestion.estimatedTimeMinutes,
      'confidence': suggestion.confidence,
      'tryCount': 0,
      'likeCount': 0,
      'commentCount': 0,
      'rating': 0.0,
      'ratingCount': 0,
      'timestamp': FieldValue.serverTimestamp(),
      
    });
  }
  
  // --- HELPER ---
  List<String> _parseSteps(dynamic content) {
    if (content == null) return [];
    if (content is List) return List<String>.from(content.map((e) => e.toString()));
    if (content is String) {
      return content.split('\n').where((s) => s.trim().isNotEmpty).toList();
    }
    return [];
  }
}