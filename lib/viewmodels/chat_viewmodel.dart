import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:e_repairkit/models/push_service.dart';
import 'package:e_repairkit/services/cache_service.dart';
import 'package:e_repairkit/services/offline_search_service.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/feedback.dart';
import '../models/message.dart';
import '../models/shop.dart';
import '../services/ai_service.dart';
import '../services/chat_service.dart';
import '../services/feedback_service.dart';
import '../services/findshop_service.dart';
import '../services/forum_service.dart';
import '../services/image_analyzer_service.dart';
import '../services/location_service.dart';

class ChatViewModel extends ChangeNotifier {
  final AIService _aiService;
  final LocationService _locationService;
  final ShopFinderService _shopFinderService;
  final ChatService _chatService;
  final FeedbackService _feedbackService;
  final LocalCacheService _cacheService;
  final OfflineSearchService _offlineSearch;
  final ForumService _forumService;
  final PushService pushService;

  String _sessionId = "my_first_session";

  bool _isLoading = false;
  bool get isLoading => _isLoading;
  
  List<Shop> _shops = [];
  List<Shop> get shops => _shops;

  // Track if we're waiting for user confirmation
  bool _waitingForFixConfirmation = false;
  bool get waitingForFixConfirmation => _waitingForFixConfirmation;
  
  // Track the original problem and failed attempts
  
  int _failedAttempts = 0;

  bool useAi = true;
  void setUseAi(bool v) {
    useAi = v;
    notifyListeners();
  }

  late Stream<List<Message>> _messagesStream;
  Stream<List<Message>> get messagesStream => _messagesStream;

  String _mode = 'practical';
  double _temperature = 0.5;
  String? _attachedImagePath;

  String get mode => _mode;
  double get temperature => _temperature;
  String? get attachedImagePath => _attachedImagePath;

  void setMode(String m) {
    _mode = m;
    notifyListeners();
  }

  void setTemperature(double t) {
    _temperature = t;
    notifyListeners();
  }

  void setAttachedImagePath(String? path) {
    _attachedImagePath = path;
    notifyListeners();
  }

  ChatViewModel({
    required AIService aiService,
    required LocationService locationService,
    required ShopFinderService shopFinderService,
    required ChatService chatService,
    required FeedbackService feedbackService,
    required LocalCacheService cacheService,
    required OfflineSearchService offlineSearch,
    required ForumService forumService,
    required this.pushService,
  })  : _aiService = aiService,
        _locationService = locationService,
        _shopFinderService = shopFinderService,
        _chatService = chatService,
        _feedbackService = feedbackService,
        _cacheService = cacheService,
        _offlineSearch = offlineSearch,
        _forumService = forumService {
    _messagesStream = _chatService.getMessages(_sessionId);
  }

  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  String _buildAnalysisSummary(Map<String, dynamic>? analysis) {
    if (analysis == null) return 'No image analysis available.';
    final labels = analysis['labels'];
    final ocr = analysis['ocr'] ?? '';
    final filename = analysis['attachedImageFilename'] ?? '';
    final buf = StringBuffer();
    if (filename.isNotEmpty) buf.writeln('Image: $filename');
    if (labels is List && labels.isNotEmpty) {
      buf.writeln('Detected labels:');
      for (final l in labels) {
        if (l is Map && l.containsKey('label')) {
          final conf = (l['confidence'] is num) ? (l['confidence'] as num).toDouble() : 0.0;
          buf.writeln('- ${l['label']} (${(conf * 100).toStringAsFixed(0)}%)');
        } else {
          buf.writeln('- $l');
        }
      }
    }
    if ((ocr as String).isNotEmpty) {
      buf.writeln('Text: $ocr');
    }
    if (analysis['analysisUnavailable'] == true) {
      buf.writeln('\nNote: on-device analysis unavailable; this is a best-effort hint.');
    }
    return buf.toString();
  }

  Future<void> sendMessage(
    String text, {
    String? imagePath,
    double? temperature,
    double? topP,
    String? mode,
  }) async {
    
    final userMessage = Message(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      text: text,
      isFromUser: true,
      timestamp: Timestamp.now(),
      edited: false,
    );
    await _chatService.saveMessage(userMessage, _sessionId);

    _setLoading(true);

    try {
      // Check if we're in follow-up mode
      if (_waitingForFixConfirmation) {
        await _handleFollowUpResponse(text, userMessage.id);
        return;
      }

      // Store original problem for follow-ups
      
      _failedAttempts = 0;

      final hasAttachedImage = imagePath != null || _attachedImagePath != null;

      // Scope check for non-image queries
      if (!hasAttachedImage) {
        final bool isInScope = await _aiService.isRepairQuestion(text);
        if (!isInScope) {
          final aiMessage = Message(
            id: 'scope_${DateTime.now().millisecondsSinceEpoch}',
            text:
                "Sorry — I can only help with electronic device repairs and finding nearby repair shops. Please ask about device repair or locating a service center.",
            isFromUser: false,
            timestamp: Timestamp.now(),
            edited: false,
          );
          await _chatService.saveMessage(aiMessage, _sessionId);
          return;
        }
      }

      Map<String, dynamic>? analysis;
      if (imagePath != null) {
        try {
          final analyzer = ImageAnalyzerService();
          analysis = await analyzer.analyzeImage(imagePath);
        } catch (e) {
          print('Image analysis failed: $e');
          try {
            final fileName = imagePath.split('/').isNotEmpty ? imagePath.split('/').last : imagePath;
            analysis = {
              'attachedImageFilename': fileName,
              'analysisUnavailable': true,
              'note': 'User attached an image; on-device analysis failed...'
            };
          } catch (_) {}
        }
      }
      
      final connectivityResult = await Connectivity().checkConnectivity();
      final bool isOnline =
          connectivityResult.contains(ConnectivityResult.mobile) ||
          connectivityResult.contains(ConnectivityResult.wifi);
            
      if (!isOnline) {
        final searchResults = await _offlineSearch.searchOffline(text);
        if (searchResults.isNotEmpty) {
          final cachedMessage = Message(
            id: 'offline_${DateTime.now().millisecondsSinceEpoch}',
            text: "📶 (Offline) I found ${searchResults.length} saved solution(s) related to '$text':",
            isFromUser: false, timestamp: Timestamp.now(),
            suggestions: searchResults, inReplyTo: userMessage.id, edited: false,
          );
          await _chatService.saveMessage(cachedMessage, _sessionId);
        } else {
          final offlineMessage = Message(
            id: 'offline_${DateTime.now().millisecondsSinceEpoch}',
            text: "⚠️ You are offline, and I couldn't find any saved solutions for '$text'.",
            isFromUser: false, timestamp: Timestamp.now(),
            inReplyTo: userMessage.id, edited: false,
          );
          await _chatService.saveMessage(offlineMessage, _sessionId);
        }
        return;
      }

      if (!useAi) {
        final summary = _buildAnalysisSummary(analysis);
        final aiMessage = Message(
          id: 'local_${DateTime.now().millisecondsSinceEpoch}',
          text: 'Image analysis result:\n$summary',
          isFromUser: false, timestamp: Timestamp.now(),
          inReplyTo: userMessage.id, edited: false,
        );
        await _chatService.saveMessage(aiMessage, _sessionId);
        return;
      }
      
      final history = await _chatService.getHistory(_sessionId); 

      final aiResponse = await _aiService.diagnose(
        history: history,
        imagePath: imagePath ?? _attachedImagePath,
        imageAnalysis: analysis,
        temperature: temperature ?? _temperature,
        topP: topP,
        mode: mode ?? _mode,
      );

      // Update follow-up state based on AI response
      _waitingForFixConfirmation = aiResponse.followUp;
      notifyListeners();

      // Cache response
      try {
        await _cacheService.cacheResponse(text, aiResponse);
      } catch (_) {}

      // Save and publish suggestions
      if (aiResponse.suggestions.isNotEmpty) {
        final userQuery = text;
        final keywords = userQuery.toLowerCase().split(' ').toSet().toList();
        final currentUserId = FirebaseAuth.instance.currentUser?.uid;

        for (final suggestion in aiResponse.suggestions) {
          final bool isFullSolution = suggestion.steps.length >= 2;

          final suggestionToSave = suggestion.copyWith(
            query: userQuery,
            keywords: keywords,
            id: currentUserId,
          );
          
          try {
            if (isFullSolution) {
              await _offlineSearch.cacheSuggestion(suggestionToSave);
              await _forumService.publishSolution(suggestionToSave);
            }
          } catch (e) {
            print("Failed to save/publish suggestion: $e");
          }
        }
      }

      final aiMessage = Message(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        text: aiResponse.rawText,
        isFromUser: false,
        timestamp: Timestamp.now(),
        suggestions: aiResponse.suggestions,
        inReplyTo: userMessage.id,
        edited: false,
      );
      await _chatService.saveMessage(aiMessage, _sessionId);

    } catch (e) {
      print("Error in sendMessage: $e");
      try {
        final cached = await _cacheService.getCachedResponse(text);
        if (cached != null) {
          final aiMessageCached = Message(
            id: DateTime.now().millisecondsSinceEpoch.toString(),
            text: "${cached.rawText}\n\n(Served from cache)",
            isFromUser: false,
            timestamp: Timestamp.now(),
            inReplyTo: userMessage.id,
            edited: false,
            suggestions: cached.suggestions,
          );
          await _chatService.saveMessage(aiMessageCached, _sessionId);
          return;
        }
      } catch (_) {}
      
      final errorMessage = Message(
        id: 'error_${DateTime.now().millisecondsSinceEpoch}',
        text: "⚠️ Sorry, I couldn't process your request at this time.",
        isFromUser: false,
        timestamp: Timestamp.now(),
        inReplyTo: userMessage.id,
        edited: false,
      );
      await _chatService.saveMessage(errorMessage, _sessionId);

    } finally {
      _setLoading(false);
      setAttachedImagePath(null);
    }
  }

  // NEW METHOD: Handle follow-up responses
  Future<void> _handleFollowUpResponse(String text, String userMessageId) async {
    final lowerText = text.toLowerCase();
    
    // Check if user confirmed fix worked
    if (lowerText.contains('yes') || 
        lowerText.contains('fixed') || 
        lowerText.contains('worked') ||
        lowerText.contains('solved')) {
      
      // SUCCESS - Show congratulations
      final successMessage = Message(
        id: 'success_${DateTime.now().millisecondsSinceEpoch}',
        text: "Have bug at this part, Will fix right away. Please Type I want you provide me troubleshoot",
        isFromUser: false,
        timestamp: Timestamp.now(),
        inReplyTo: userMessageId,
        edited: false,
      );
      await _chatService.saveMessage(successMessage, _sessionId);
      
      // Reset follow-up state
      _waitingForFixConfirmation = false;
      _failedAttempts = 0;
      notifyListeners();
      
    } else if (lowerText.contains('no') || 
               lowerText.contains('not') || 
               lowerText.contains('didn\'t') ||
               lowerText.contains('still')) {
      
      // FAILED - Try another solution
      _failedAttempts++;
      
      if (_failedAttempts >= 3) {
        // After 3 failed attempts, recommend repair shop
        final shopMessage = Message(
          id: 'shop_${DateTime.now().millisecondsSinceEpoch}',
          text: "I understand this issue is persistent. At this point, I recommend visiting a professional repair shop for hands-on diagnosis. Would you like me to find nearby repair shops for you?",
          isFromUser: false,
          timestamp: Timestamp.now(),
          inReplyTo: userMessageId,
          edited: false,
        );
        await _chatService.saveMessage(shopMessage, _sessionId);
        
        _waitingForFixConfirmation = false;
        _failedAttempts = 0;
        notifyListeners();
        
      } else {
        // Provide another solution
        // Create a retry message to add to chat history so AI knows previous solution failed
final retryMessage = Message(
  id: 'retry_${DateTime.now().millisecondsSinceEpoch}',
  text: "The previous solution didn't work. Please try a different approach.",
  isFromUser: true,
  timestamp: Timestamp.now(),
  edited: false,
);
await _chatService.saveMessage(retryMessage, _sessionId);

final history = await _chatService.getHistory(_sessionId);
        
        final aiResponse = await _aiService.diagnose(
          history: history,
          temperature: _temperature,
          mode: _mode,
        );
        
        _waitingForFixConfirmation = aiResponse.followUp;
        notifyListeners();
        
        final aiMessage = Message(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          text: aiResponse.rawText,
          isFromUser: false,
          timestamp: Timestamp.now(),
          suggestions: aiResponse.suggestions,
          inReplyTo: userMessageId,
          edited: false,
        );
        await _chatService.saveMessage(aiMessage, _sessionId);
      }
    } else {
      // Unclear response - ask for clarification
      final clarifyMessage = Message(
        id: 'clarify_${DateTime.now().millisecondsSinceEpoch}',
        text: "I'm not sure I understood. Did the solution fix your problem? Please reply with 'yes' if it worked, or 'no' if it didn't.",
        isFromUser: false,
        timestamp: Timestamp.now(),
        inReplyTo: userMessageId,
        edited: false,
      );
      await _chatService.saveMessage(clarifyMessage, _sessionId);
    }
  }

  Future<void> saveFeedback({
    required String suggestionId,
    required String userId,
    required int rating,
    required bool tried,
    required bool saved,
    String? notes,
    Map<String, dynamic>? metadata,
  }) async {
    final entry = FeedbackEntry(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      suggestionId: suggestionId,
      userId: userId,
      rating: rating,
      tried: tried,
      saved: saved,
      notes: notes,
      createdAt: Timestamp.now(),
      metadata: metadata,
    );
    await _feedbackService.saveFeedback(entry);

    try {
      await _forumService.updateSolutionStats(
        solutionId: suggestionId,
        didTry: tried,
        newRating: rating > 0 ? rating : null,
      );
    } catch (e) {
      print("Failed to update forum stats: $e");
    }
  }

  Future<void> findRepairShops() async {
    _setLoading(true);
    _shops = [];
    notifyListeners();
    try {
      final location = await _locationService.getCurrentLocation();
      if (location == null) {
        throw Exception("Location not available.");
      }
      final nearbyShops = await _shopFinderService.findNearby(location);
      _shops = nearbyShops;
    } catch (e) {
      // Handle error
    } finally {
      _setLoading(false);
    }
  }

  Future<void> editMessage({
    required String messageId,
    required String newText,
    String? imagePath,
    double? temperature,
    double? topP,
    String? mode,
  }) async {
    
    final editedMessage = Message(
      id: messageId,
      text: newText,
      isFromUser: true,
      timestamp: Timestamp.now(),
      edited: true,
    );
    await _chatService.saveMessage(editedMessage, _sessionId);

    await _chatService.deleteReplies(_sessionId, messageId);

    _setLoading(true);
    
    try {
      final hasAttachedImage = imagePath != null;
      final bool isInScope = await _aiService.isRepairQuestion(newText);

      if (!isInScope && !hasAttachedImage) {
         final aiMessage = Message(
            id: 'scope_edit_${DateTime.now().millisecondsSinceEpoch}',
            text:
                "Sorry — I can only help with electronic device repairs and finding nearby repair shops. Please ask about device repair or locating a service center.",
            isFromUser: false,
            timestamp: Timestamp.now(),
            edited: false,
            inReplyTo: messageId,
          );
          await _chatService.saveMessage(aiMessage, _sessionId);
          return;
      }
      
      Map<String, dynamic>? analysis;
      if (imagePath != null) {
        try {
          final analyzer = ImageAnalyzerService();
          analysis = await analyzer.analyzeImage(imagePath);
        } catch (e) {
          // ignore
        }
      }

      final history = await _chatService.getHistory(_sessionId);
      final editIndex = history.indexWhere((m) => m.id == messageId);
      final historyUpToEdit = (editIndex != -1) ? history.sublist(0, editIndex + 1) : [editedMessage];

      final aiResponse = await _aiService.diagnose(
        history: historyUpToEdit,
        imagePath: imagePath,
        imageAnalysis: analysis,
        temperature: temperature,
        topP: topP,
        mode: mode,
      );

      // Update follow-up state
      _waitingForFixConfirmation = aiResponse.followUp;
      notifyListeners();

      try {
        await _cacheService.cacheResponse(newText, aiResponse);
        if (aiResponse.suggestions.isNotEmpty) {
          final userQuery = newText;
          final keywords = userQuery.toLowerCase().split(' ').toSet().toList();
          final currentUserId = FirebaseAuth.instance.currentUser?.uid;

          for (final suggestion in aiResponse.suggestions) {
            final bool isFullSolution = suggestion.steps.length >= 2;
            
            final suggestionToSave = suggestion.copyWith(
              query: userQuery,
              keywords: keywords,
              id: currentUserId,
            );
            
            if (isFullSolution) {
              await _offlineSearch.cacheSuggestion(suggestionToSave);
              await _forumService.publishSolution(suggestionToSave);
            }
          }
        }
      } catch (_) {}

      final aiMessage = Message(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        text: aiResponse.rawText,
        timestamp: Timestamp.now(),
        suggestions: aiResponse.suggestions,
        inReplyTo: messageId,
        edited: false, 
        isFromUser: false
      );
      await _chatService.saveMessage(aiMessage, _sessionId);

    } catch (e) {
      final errorMessage = Message(
        id: 'error_edit_${DateTime.now().millisecondsSinceEpoch}',
        text: "Sorry, I couldn't process your edited message.",
        isFromUser: false,
        timestamp: Timestamp.now(),
        inReplyTo: messageId,
        edited: false,
      );
      await _chatService.saveMessage(errorMessage, _sessionId);
    } finally {
      _setLoading(false);
      setAttachedImagePath(null);
    }
  }
 
  void startNewChatSession() {
    _sessionId = DateTime.now().millisecondsSinceEpoch.toString();
    _messagesStream = _chatService.getMessages(_sessionId);
    _shops = [];
    _isLoading = false;
    _attachedImagePath = null;
    _waitingForFixConfirmation = false;
    _failedAttempts = 0;
    notifyListeners();
  }
}