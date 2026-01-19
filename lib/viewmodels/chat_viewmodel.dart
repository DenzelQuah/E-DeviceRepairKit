import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../models/chat_session.dart';
import '../models/feedback.dart';
import '../models/message.dart';
import '../models/push_service.dart';
import '../models/shop.dart';
import '../services/ai_service.dart';
import '../services/cache_service.dart';
import '../services/chat_service.dart';
import '../services/feedback_service.dart';
import '../services/findshop_service.dart';
import '../services/forum_service.dart';
import '../services/image_analyzer_service.dart';
import '../services/location_service.dart';
import '../services/offline_search_service.dart';

class ChatViewModel extends ChangeNotifier {
  // --- STATE VARIABLES ---
  String _sessionId = DateTime.now().millisecondsSinceEpoch.toString();
  bool _isLoading = false;
  String? _currentProblemQuery;
  String? _attachedImagePath;

  // Settings
  String _mode = 'practical';
  double _temperature = 0.5;
  bool useAi = true;

  // Logic tracking
  bool _waitingForFixConfirmation = false;
  int _failedAttempts = 0;

  // Data Lists
  List<Shop> _shops = [];
  List<ChatSession> _sessions = [];

  // --- SERVICES ---
  final AIService _aiService;
  final LocationService _locationService;
  final ShopFinderService _shopFinderService;
  final ChatService _chatService;
  final FeedbackService _feedbackService;
  final LocalCacheService _cacheService;
  final OfflineSearchService _offlineSearch;
  final ForumService _forumService;
  final PushService pushService;

  // --- CONSTRUCTOR ---
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
  }) : _aiService = aiService,
       _locationService = locationService,
       _shopFinderService = shopFinderService,
       _chatService = chatService,
       _feedbackService = feedbackService,
       _cacheService = cacheService,
       _offlineSearch = offlineSearch,
       _forumService = forumService;

  // --- GETTERS ---
  String get sessionId => _sessionId;
  bool get isLoading => _isLoading;
  String? get attachedImagePath => _attachedImagePath;
  String get mode => _mode;
  double get temperature => _temperature;
  List<Shop> get shops => _shops;
  List<ChatSession> get sessions => _sessions;
  bool get waitingForFixConfirmation => _waitingForFixConfirmation;

  // Stream for Chat View
  Stream<List<Message>> get messagesStream =>
      _chatService.getMessages(_sessionId);

  // --- SETTERS ---
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

  void setUseAi(bool v) {
    useAi = v;
    notifyListeners();
  }

  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  // --- SESSION MANAGEMENT ---

  void startNewChatSession() {
    resetSession();
  }

  void resetSession() {
    _sessionId = DateTime.now().millisecondsSinceEpoch.toString();
    _currentProblemQuery = null;
    _failedAttempts = 0;
    _waitingForFixConfirmation = false;
    setAttachedImagePath(null);
    _shops = [];
    notifyListeners();
  }

  void loadSession(ChatSession session) {
    _sessionId = session.id;
    _currentProblemQuery = session.title;
    _attachedImagePath = null;
    notifyListeners();
  }

  Future<void> fetchChatSessions() async {
    final userId = FirebaseAuth.instance.currentUser?.uid;

    // 1. If not logged in, we can't fetch history, so stop.
    if (userId == null) return;

    try {
      // 2. Simply fetch the sessions (No 'isFirstMessage' check needed here)
      final snapshot =
          await FirebaseFirestore.instance
              .collection('users')
              .doc(userId)
              .collection('sessions')
              .orderBy('lastActive', descending: true)
              .get();

      _sessions =
          snapshot.docs.map((doc) => ChatSession.fromSnapshot(doc)).toList();

      notifyListeners();
    } catch (e) {
      print("Error fetching sessions: $e");
    }
  }

  // --- MAIN LOGIC: SEND MESSAGE ---

  Future<void> sendMessage(
    String text, {
    String? imagePath,
    double? temperature,
    double? topP,
    String? mode,
  }) async {
    // --- 1. ADD THIS AUTO-LOGIN BLOCK ---
    // If we don't have a user, sign in anonymously so we can save data.
    User? user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      try {
        final cred = await FirebaseAuth.instance.signInAnonymously();
        user = cred.user;
      } catch (e) {
        print("Auto-login failed: $e");
      }
    }
    final userId = user?.uid;
    // ------------------------------------

    // 2. SESSION TITLE LOGIC
    try {
      final history = await _chatService.getHistory(_sessionId);
      final isFirstMessage = history.isEmpty;

      // Now 'userId' is guaranteed to exist if login succeeded
      if (userId != null && isFirstMessage) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(userId)
            .collection('sessions')
            .doc(_sessionId)
            .set({
              'title': text,
              'lastActive': FieldValue.serverTimestamp(),
              'id': _sessionId,
            }, SetOptions(merge: true));
      }
    } catch (e) {
      print("Error checking history: $e");
    }

    // 3. Save the User Message
    final userMessage = Message(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      text: text,
      isFromUser: true,
      timestamp: Timestamp.now(),
      edited: false,
    );
    await _chatService.saveMessage(userMessage, _sessionId);

    _currentProblemQuery ??= text;
    _setLoading(true);

    try {
      // 4. Check Follow-Up Mode (Yes/No)
      if (_waitingForFixConfirmation) {
        await _handleFollowUpResponse(text, userMessage.id);
        return;
      }

      // 5. Check Offline Status
      final connectivityResult = await Connectivity().checkConnectivity();
      final bool isOnline =
          connectivityResult.contains(ConnectivityResult.mobile) ||
          connectivityResult.contains(ConnectivityResult.wifi);

      if (!isOnline) {
        final searchResults = await _offlineSearch.searchOffline(text);
        final offlineMsgText =
            searchResults.isNotEmpty
                ? "📶 (Offline) I found ${searchResults.length} saved solution(s) related to '$text':"
                : "⚠️ You are offline, and I couldn't find any saved solutions for '$text'.";

        final offlineMessage = Message(
          id: 'offline_${DateTime.now().millisecondsSinceEpoch}',
          text: offlineMsgText,
          isFromUser: false,
          timestamp: Timestamp.now(),
          suggestions: searchResults.isNotEmpty ? searchResults : null,
          inReplyTo: userMessage.id,
          edited: false,
        );
        await _chatService.saveMessage(offlineMessage, _sessionId);
        return;
      }

      // 6. Scope Check (If not image)
      final hasAttachedImage = imagePath != null || _attachedImagePath != null;
      if (!hasAttachedImage) {
        final bool isInScope = await _aiService.isRepairQuestion(text);
        if (!isInScope) {
          final aiMessage = Message(
            id: 'scope_${DateTime.now().millisecondsSinceEpoch}',
            text:
                "Sorry — I can only help with electronic device repairs and finding nearby repair shops.",
            isFromUser: false,
            timestamp: Timestamp.now(),
            edited: false,
          );
          await _chatService.saveMessage(aiMessage, _sessionId);
          return;
        }
      }

      // 7. Image Analysis
      Map<String, dynamic>? analysis;
      if (imagePath != null) {
        try {
          final analyzer = ImageAnalyzerService();
          analysis = await analyzer.analyzeImage(imagePath);
        } catch (e) {
          analysis = {
            'attachedImageFilename': 'image.jpg',
            'analysisUnavailable': true,
          };
        }
      }

      // 8. Local Mode Check (No AI)
      if (!useAi) {
        final summary = _buildAnalysisSummary(analysis);
        final aiMessage = Message(
          id: 'local_${DateTime.now().millisecondsSinceEpoch}',
          text: 'Image analysis result:\n$summary',
          isFromUser: false,
          timestamp: Timestamp.now(),
          inReplyTo: userMessage.id,
          edited: false,
        );
        await _chatService.saveMessage(aiMessage, _sessionId);
        return;
      }

      // 9. AI Diagnosis Call
      final historyForAi = await _chatService.getHistory(_sessionId);
      final aiResponse = await _aiService.diagnose(
        history: historyForAi,
        imagePath: imagePath ?? _attachedImagePath,
        imageAnalysis: analysis,
        temperature: temperature ?? _temperature,
        topP: topP,
        mode: mode ?? _mode,
      );

      // 10. Auto-Find Shops
      bool aiRecommendsShop =
          aiResponse.suggestions.isEmpty &&
          (aiResponse.rawText.toLowerCase().contains('shop') ||
              aiResponse.rawText.toLowerCase().contains('service center') ||
              aiResponse.rawText.toLowerCase().contains('professional'));

      if (aiRecommendsShop) {
        findRepairShops();
      }

      // 11. Update State
      _waitingForFixConfirmation =
          aiResponse.followUp && aiResponse.suggestions.isNotEmpty;
      notifyListeners();

      // 12. Cache & Publish Suggestions
      try {
        await _cacheService.cacheResponse(text, aiResponse);
        if (aiResponse.suggestions.isNotEmpty) {
          final userQuery = _currentProblemQuery ?? text;
          final keywords = userQuery.toLowerCase().split(' ').toSet().toList();

          for (final suggestion in aiResponse.suggestions) {
            if (suggestion.steps.length >= 2) {
              final suggestionToSave = suggestion.copyWith(
                query: userQuery,
                keywords: keywords,
                userId: userId,
              );
              await _offlineSearch.cacheSuggestion(suggestionToSave);
              await _forumService.publishSolution(suggestionToSave);
            }
          }
        }
      } catch (_) {}

      // 13. Save AI Message
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
      // ALWAYS stop loading
      _setLoading(false);
      setAttachedImagePath(null);
    }
  }

  // --- FOLLOW UP LOGIC ---

  Future<void> _handleFollowUpResponse(
    String text,
    String userMessageId,
  ) async {
    final lowerText = text.toLowerCase().trim();

    bool isConfirmedSuccess =
        lowerText == 'yes' ||
        lowerText.startsWith('yes ') ||
        lowerText.contains('fixed') ||
        lowerText.contains('worked');

    bool isConfirmedFailure =
        lowerText == 'no' ||
        lowerText.startsWith('no ') ||
        lowerText.contains('didn\'t') ||
        lowerText.contains('not worked');

    if (isConfirmedSuccess) {
      final successMessage = Message(
        id: 'success_${DateTime.now().millisecondsSinceEpoch}',
        text: "Great! I'm glad I could help fix your device.",
        isFromUser: false,
        timestamp: Timestamp.now(),
        inReplyTo: userMessageId,
        edited: false,
      );
      await _chatService.saveMessage(successMessage, _sessionId);
      _waitingForFixConfirmation = false;
      _failedAttempts = 0;
      notifyListeners();
    } else if (isConfirmedFailure) {
      _failedAttempts++;
      if (_failedAttempts >= 3) {
        final shopMessage = Message(
          id: 'shop_${DateTime.now().millisecondsSinceEpoch}',
          text:
              "I recommend visiting a professional repair shop for hands-on diagnosis. Shall I find one nearby?",
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
        final retryMessage = Message(
          id: 'retry_${DateTime.now().millisecondsSinceEpoch}',
          text:
              "The previous solution didn't work. Let me try a different approach...",
          isFromUser: false, // This serves as a system status msg
          timestamp: Timestamp.now(),
          edited: false,
        );
        await _chatService.saveMessage(retryMessage, _sessionId);

        // Retry AI
        final history = await _chatService.getHistory(_sessionId);
        final aiResponse = await _aiService.diagnose(
          history: history,
          temperature: _temperature,
          mode: _mode,
        );

        _waitingForFixConfirmation =
            aiResponse.followUp && aiResponse.suggestions.isNotEmpty;
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
      // FALLBACK: User said something else (e.g., "Yesterday"), treat as normal query
      _waitingForFixConfirmation = false;
      await sendMessage(text);
    }
  }

  // --- HELPERS ---

  Future<void> findRepairShops() async {
    _setLoading(true);
    _shops = [];
    notifyListeners();
    try {
      final location = await _locationService.getCurrentLocation();
      if (location == null) throw Exception("Location not available.");
      _shops = await _shopFinderService.findNearby(location);
    } catch (e) {
      print("Shop search failed: $e");
    } finally {
      _setLoading(false);
    }
  }

  String _buildAnalysisSummary(Map<String, dynamic>? analysis) {
    if (analysis == null) return 'No image analysis available.';
    return "Analysis complete."; // Simplified for brevity
  }

  Future<void> editMessage({
    required String messageId,
    required String newText,
    String? imagePath,
  }) async {
    // 1. Save Edited User Message
    final editedMessage = Message(
      id: messageId,
      text: newText,
      isFromUser: true,
      timestamp: Timestamp.now(),
      edited: true,
    );
    await _chatService.saveMessage(editedMessage, _sessionId);
    await _chatService.deleteReplies(_sessionId, messageId);

    // 2. Re-Trigger AI Response
    // We treat this almost like a new message but in reply to the edit
    _setLoading(true);
    try {
      final history = await _chatService.getHistory(_sessionId);

      // Filter history to up to this message
      // (Simplified: just send full history, AI usually handles context well)

      final aiResponse = await _aiService.diagnose(
        history: history,
        imagePath: imagePath,
        temperature: _temperature,
        mode: _mode,
      );

      final aiMessage = Message(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        text: aiResponse.rawText,
        timestamp: Timestamp.now(),
        suggestions: aiResponse.suggestions,
        inReplyTo: messageId,
        edited: false,
        isFromUser: false,
      );
      await _chatService.saveMessage(aiMessage, _sessionId);
    } catch (e) {
      // Error handling
    } finally {
      _setLoading(false);
    }
  }

  Future<void> saveFeedback({
    required String suggestionId,
    required String userId,
    required int rating,
    required bool tried,
    required bool saved,
    String? notes,
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
    );
    await _feedbackService.saveFeedback(entry);
  }
}
