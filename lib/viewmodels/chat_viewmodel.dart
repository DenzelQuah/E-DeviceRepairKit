import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:e_repairkit/models/push_service.dart';
import 'package:e_repairkit/services/cache_service.dart';
import 'package:e_repairkit/services/offline_search_service.dart';
import 'package:flutter/material.dart';

import '../models/feedback.dart';
import '../models/message.dart';
import '../models/shop.dart';
import '../services/ai_service.dart';
import '../services/chat_service.dart';
import '../services/feedback_service.dart';
import '../services/findshop_service.dart';
import '../services/forum_service.dart'; // <-- 1. IMPORT FORUM SERVICE
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
  final ForumService _forumService; // <-- 2. ADD FORUM SERVICE
  final PushService pushService;

  final String _sessionId = "my_first_session";
  
  // --- STATUS ---
  bool _isLoading = false;
  bool get isLoading => _isLoading;
  List<Shop> _shops = [];
  List<Shop> get shops => _shops;

  bool useAi = true;
  void setUseAi(bool v) {
    useAi = v;
    notifyListeners();
  }

  // --- MESSAGES STREAM ---
  late Stream<List<Message>> _messagesStream;
  Stream<List<Message>> get messagesStream => _messagesStream;

  String _mode = 'practical';
  double _temperature = 0.2;
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

  // --- 3. UPDATE CONSTRUCTOR ---
  ChatViewModel({
    required AIService aiService,
    required LocationService locationService,
    required ShopFinderService shopFinderService,
    required ChatService chatService,
    required FeedbackService feedbackService,
    required LocalCacheService cacheService,
    required OfflineSearchService offlineSearch,
    required ForumService forumService, // <-- Add to constructor
    required this.pushService,
  })  : _aiService = aiService,
        _locationService = locationService,
        _shopFinderService = shopFinderService,
        _chatService = chatService,
        _feedbackService = feedbackService,
        _cacheService = cacheService,
        _offlineSearch = offlineSearch,
        _forumService = forumService { // <-- Initialize
    _messagesStream = _chatService.getMessages(_sessionId);
  }

  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  bool _isInScope(String text) {
    // ... (your existing code)
    final lower = text.toLowerCase();
    final keywords = [
      'repair', 'fix', 'screen', 'battery', 'charging', 'charge', 'power',
      'boot', 'camera', 'speaker', 'microphone', 'water', 'liquid', 'display',
      'touch', 'port', 'overheat', 'shop', 'service center', 'store', 'near',
      'device', 'phone', 'tablet', 'laptop', 'computer', 'motherboard', 'crack',
      'broken', 'charger', 'button', 'volume', 'mouse',
    ];
    for (final k in keywords) {
      if (lower.contains(k)) return true;
    }
    return false;
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
      // --- THIS IS THE FIX ---
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
    // ... (your existing code for scope check, analysis, user message)
    final hasAttachedImage = imagePath != null || _attachedImagePath != null;
    if (!_isInScope(text) && !hasAttachedImage) {
      final userMessage = Message(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        text: text, isFromUser: true, timestamp: Timestamp.now(), edited: false,
      );
      await _chatService.saveMessage(userMessage, _sessionId);
      final aiMessage = Message(
        id: 'scope_${DateTime.now().millisecondsSinceEpoch}',
        text: "Sorry — I can only help with electronic device repairs and finding nearby repair shops. Please ask about device repair or locating a service center.",
        isFromUser: false, timestamp: Timestamp.now(), edited: false,
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
    final userMessage = Message(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      text: text,
      isFromUser: true,
      timestamp: Timestamp.now(),
      edited: false,
    );
    await _chatService.saveMessage(userMessage, _sessionId);
    _setLoading(true);

    // ... (your existing connectivity check & offline logic)
    final connectivityResult = await Connectivity().checkConnectivity();
    final bool isOnline =
        connectivityResult.contains(ConnectivityResult.mobile) ||
        connectivityResult.contains(ConnectivityResult.wifi);
    if (!isOnline) {
      try {
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
      } catch (e) {
        final errorMessage = Message(
          id: 'offline_err_${DateTime.now().millisecondsSinceEpoch}',
          text: "⚠️ You are offline, and an error occurred while searching saved solutions.",
          isFromUser: false, timestamp: Timestamp.now(),
          inReplyTo: userMessage.id, edited: false,
        );
        await _chatService.saveMessage(errorMessage, _sessionId);
      } finally {
        _setLoading(false);
        setAttachedImagePath(null);
        return; 
      }
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
      setAttachedImagePath(null);
      _setLoading(false);
      return;
    }

    // --- 4. UPDATE AI CALL ---
    try {
      final aiResponse = await _aiService.diagnose(
        message: userMessage,
        imagePath: imagePath ?? _attachedImagePath,
        imageAnalysis: analysis,
        temperature: temperature ?? _temperature,
        topP: topP,
        mode: mode ?? _mode,
      );

      // (Cache the 1-to-1 response)
      try {
        await _cacheService.cacheResponse(text, aiResponse);
      } catch (_) {}

      if (aiResponse.suggestions.isNotEmpty) {
        // Create keywords
        final userQuery = text;
        final keywords = userQuery.toLowerCase().split(' ').toSet().toList();

        for (final suggestion in aiResponse.suggestions) {
          final suggestionToSave = suggestion.copyWith(
            query: userQuery,
            keywords: keywords,
          );
          
          // --- 5. SAVE TO BOTH DATABASES ---
          try {
            // Save to local offline DB
            await _offlineSearch.cacheSuggestion(suggestionToSave);
            // PUBLISH to global forum DB
            await _forumService.publishSolution(suggestionToSave);
          } catch (e) {
            print("Failed to save/publish suggestion: $e");
          }
        }
        print(
            "Successfully cached and published ${aiResponse.suggestions.length} suggestions.");
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
      // (Your existing error/cache fallback logic...)
      try {
        final cached = await _cacheService.getCachedResponse(text);
        if (cached != null) {
          final aiMessageCached = Message(
            id: DateTime.now().millisecondsSinceEpoch.toString(),
            text: "${cached.rawText}\n\n(Served from cache)", // Added cache note
            isFromUser: false,
            timestamp: Timestamp.now(),
            inReplyTo: userMessage.id,
            edited: false,
            suggestions: cached.suggestions, // Also load cached suggestions
          );
          await _chatService.saveMessage(aiMessageCached, _sessionId);
          _setLoading(false);
          setAttachedImagePath(null);
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

  // --- 6. UPDATE SAVEFEEDBACK ---
  Future<void> saveFeedback({
    required String suggestionId,
    required String userId,
    required int rating,
    required bool tried,
    required bool saved,
    String? notes,
    Map<String, dynamic>? metadata,
  }) async {
    // Save to your private feedback collection
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

    // --- 7. UPDATE THE PUBLIC FORUM STATS ---
    try {
      await _forumService.updateSolutionStats(
        solutionId: suggestionId,
        didTry: tried,
        newRating: rating > 0 ? rating : null,
      );
    } catch (e) {
      print("Failed to update forum stats: $e");
      // Don't throw, failing this isn't critical
    }
  }

  /// Find repair shops
  Future<void> findRepairShops() async {
    // ... (your existing code)
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

  /// Edit an existing user message
  Future<void> editMessage({
    required String messageId,
    required String newText,
    String? imagePath,
    double? temperature,
    double? topP,
    String? mode,
  }) async {
    // ... (your existing code)
    final editedMessage = Message(
      id: messageId,
      text: newText,
      isFromUser: true,
      timestamp: Timestamp.now(), // Update timestamp to reflect edit time
      edited: true,
    );

    await _chatService.saveMessage(editedMessage, _sessionId);
    await _chatService.deleteReplies(_sessionId, messageId);

    Map<String, dynamic>? analysis;
    if (imagePath != null) {
      try {
        final analyzer = ImageAnalyzerService();
        analysis = await analyzer.analyzeImage(imagePath);
      } catch (e) {
        // ignore
      }
    }

    try {
      final aiResponse = await _aiService.diagnose(
        message: editedMessage,
        imagePath: imagePath,
        imageAnalysis: analysis,
        temperature: temperature,
        topP: topP,
        mode: mode,
      );

      // --- 8. UPDATE THIS BLOCK TOO ---
      try {
        await _cacheService.cacheResponse(newText, aiResponse);
        if (aiResponse.suggestions.isNotEmpty) {
          final userQuery = newText;
          final keywords = userQuery.toLowerCase().split(' ').toSet().toList();

          for (final suggestion in aiResponse.suggestions) {
            final suggestionToSave = suggestion.copyWith(
              query: userQuery,
              keywords: keywords,
            );
            // Save to both places
            await _offlineSearch.cacheSuggestion(suggestionToSave);
            await _forumService.publishSolution(suggestionToSave);
          }
        }
      } catch (_) {}
      // --- End caching ---

      final aiMessage = Message(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        text: aiResponse.rawText,
        isFromUser: false,
        timestamp: Timestamp.now(),
        suggestions: aiResponse.suggestions,
        inReplyTo: messageId,
        edited: false,
      );
      await _chatService.saveMessage(aiMessage, _sessionId);

    } catch (e) {
      // Handle error on edit
      final errorMessage = Message(
        id: 'error_edit_${DateTime.now().millisecondsSinceEpoch}',
        text: "Sorry, I couldn't process your edited message.",
        isFromUser: false,
        timestamp: Timestamp.now(),
        inReplyTo: messageId,
        edited: false,
      );
      await _chatService.saveMessage(errorMessage, _sessionId);
    }
  }
}

