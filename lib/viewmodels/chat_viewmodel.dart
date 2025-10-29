import 'package:flutter/material.dart';
import '../models/message.dart';
import '../models/shop.dart';
import '../services/ai_service.dart';
import '../services/location_service.dart';
import '../services/findshop_service.dart';
import '../services/chat_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ChatViewModel extends ChangeNotifier {
  // 2. Add the ChatService
  final AIService _aiService;
  final LocationService _locationService;
  final ShopFinderService _shopFinderService;
  final ChatService _chatService;

  final String _sessionId = "my_first_session";

  // --- STATUS ---
  bool _isLoading = false;
  bool get isLoading => _isLoading;
  List<Shop> _shops = [];
  List<Shop> get shops => _shops;

  // --- MESSAGES STREAM ---
  // The UI will listen to this stream from the database
  late Stream<List<Message>> _messagesStream;
  Stream<List<Message>> get messagesStream => _messagesStream;

  // --- CONSTRUCTOR ---
  // 3. Require ChatService in the constructor
  ChatViewModel({
    required AIService aiService,
    required LocationService locationService,
    required ShopFinderService shopFinderService,
    required ChatService chatService,
  })  : _aiService = aiService,
        _locationService = locationService,
        _shopFinderService = shopFinderService,
        _chatService = chatService {
    // 4. Initialize the stream when the ViewModel is created
    _messagesStream = _chatService.getMessages(_sessionId);
  }


  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  // --- PUBLIC METHODS ---
  Future<void> sendMessage(String text) async {
    final userMessage = Message(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      text: text,
      isFromUser: true,
      timestamp: Timestamp.now(), // 5. Use Firebase Timestamp
    );
    
    // 6. Save the user's message to Firebase
    await _chatService.saveMessage(userMessage, _sessionId);
    _setLoading(true);

    try {
      // 7. Get AI diagnosis
      final aiResponse = await _aiService.diagnose(message: userMessage);

      final aiMessage = Message(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        text: aiResponse.rawText,
        isFromUser: false,
        timestamp: Timestamp.now(), // 5. Use Firebase Timestamp
        suggestions: aiResponse.suggestions,
      );

      // 8. Save the AI's message to Firebase
      await _chatService.saveMessage(aiMessage, _sessionId);
    } catch (e) {
      final errorMessage = Message(
        id: 'error_${DateTime.now().millisecondsSinceEpoch}',
        text: "Sorry, chatviewmodel ran into an error. Please try again.",
        isFromUser: false,
        timestamp: Timestamp.now(), // 5. Use Firebase Timestamp
      );
      // 9. Save the error message to Firebase
      await _chatService.saveMessage(errorMessage, _sessionId);
    } finally {
      _setLoading(false);
    }
  }

  Future<void> findRepairShops() async {
    // This logic remains the same
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
}