import 'dart:convert';

import 'package:e_repairkit/models/repair_suggestion.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/ai_response.dart'; // Ensure this path is correct

class LocalCacheService {
  // A prefix to make cache keys unique
  static const _cacheKeyPrefix = 'ai_cache_';

  // Helper to get the SharedPreferences instance
  Future<SharedPreferences> _prefs() async =>
      await SharedPreferences.getInstance();

  // Creates a unique key for each question (e.g., "ai_cache_my phone screen cracked")
  String _keyFor(String question) =>
      '$_cacheKeyPrefix${question.toLowerCase().trim()}';

  // Saves an AIResponse to local storage
  Future<void> cacheResponse(String question, AIResponse response) async {
    final prefs = await _prefs();
    // Convert the AIResponse object into a Map
    final map = {
      'rawText': response.rawText,
      // Convert each suggestion into its JSON map representation
      'suggestions': response.suggestions.map((s) => s.toJson()).toList(),
    };
    // Encode the map into a JSON string and save it using the question key
    await prefs.setString(_keyFor(question), jsonEncode(map));
  }

  // Retrieves a cached AIResponse from local storage
  Future<AIResponse?> getCachedResponse(String question) async {
    final prefs = await _prefs();
    // Get the saved JSON string using the question key
    final s = prefs.getString(_keyFor(question));
    if (s == null) {
      return null; // Return null if nothing is cached for this question
    }

    try {
      // Decode the JSON string back into a Map
      final m = jsonDecode(s) as Map<String, dynamic>;
      // Parse the 'suggestions' list from the map, converting each map back into a RepairSuggestion object
      final suggestions =
          (m['suggestions'] as List<dynamic>?)
              ?.map((e) => RepairSuggestion.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [];
      // Create and return the AIResponse object from the parsed map
      return AIResponse(
        rawText: m['rawText'] as String? ?? '',
        suggestions: suggestions,
      );
    } catch (_) {
      // If parsing fails (e.g., bad data), return null
      return null;
    }
  }
}
