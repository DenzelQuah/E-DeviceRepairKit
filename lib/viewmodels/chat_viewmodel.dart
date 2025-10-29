import 'package:flutter/material.dart';
import '../models/message.dart';
import '../models/shop.dart';
import '../services/ai_service.dart';
import '../services/location_service.dart';
import '../services/findshop_service.dart';

class ChatViewModel extends ChangeNotifier {
  // Depend on abstractions (interfaces)
  final AIService _aiService;
  final LocationService _locationService;
  final ShopFinderService _shopFinderService;

  ChatViewModel({
    required AIService aiService,
    required LocationService locationService,
    required ShopFinderService shopFinderService,
  })  : _aiService = aiService,
        _locationService = locationService,
        _shopFinderService = shopFinderService;

  // --- State ---
  final List<Message> _messages = [];
  List<Message> get messages => _messages;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  List<Shop> _shops = [];
  List<Shop> get shops => _shops;
  
  // --- Private Helper ---
  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  // --- Public Methods ---
  Future<void> sendMessage(String text) async {
    final userMessage = Message(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      text: text,
      isFromUser: true,
    );
    _messages.add(userMessage);
    _setLoading(true);

    try {
      final aiResponse = await _aiService.diagnose(message: userMessage);
      _messages.add(Message(
        id: DateTime.now().toString(),
        text: aiResponse.rawText,
        isFromUser: false,
        suggestions: aiResponse.suggestions,
      ));
    } catch (e) {
      _messages.add(Message(
        id: 'error',
        text: "Sorry, I ran into an error. Please try again.",
        isFromUser: false,
      ));
    } finally {
      _setLoading(false);
    }
  }

  Future<void> findRepairShops() async {
    _setLoading(true);
    _shops = []; // Clear old shops

    try {
      final location = await _locationService.getCurrentLocation();
      if (location == null) {
        throw Exception("Location not available.");
      }

      final nearbyShops = await _shopFinderService.findNearby(location);
      _shops = nearbyShops;

      _messages.add(Message(
        id: DateTime.now().toString(),
        text: "Okay, I found ${nearbyShops.length} shops near you.",
        isFromUser: false,
      ));

    } catch (e) {
      _messages.add(Message(
        id: 'error',
        text: "I couldn't get your location to find shops.",
        isFromUser: false,
      ));
    } finally {
      _setLoading(false);
    }
  }
}