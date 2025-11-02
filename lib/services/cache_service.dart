import 'dart:convert';

import 'package:e_repairkit/models/repair_suggestion.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/ai_response.dart';

class LocalCacheService {
  static const _cacheKeyPrefix = 'ai_cache_';

  Future<SharedPreferences> _prefs() async =>
      await SharedPreferences.getInstance();

  String _keyFor(String question) =>
      '$_cacheKeyPrefix${question.toLowerCase().trim()}';

  Future<void> cacheResponse(String question, AIResponse response) async {
    final prefs = await _prefs();
    final map = {
      'rawText': response.rawText,
      'suggestions': response.suggestions.map((s) => s.toJson()).toList(),
    };
    await prefs.setString(_keyFor(question), jsonEncode(map));
  }

  Future<AIResponse?> getCachedResponse(String question) async {
    final prefs = await _prefs();
    final s = prefs.getString(_keyFor(question));
    if (s == null) return null;
    try {
      final m = jsonDecode(s) as Map<String, dynamic>;
      final suggestions =
          (m['suggestions'] as List<dynamic>?)
              ?.map((e) => RepairSuggestion.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [];
      return AIResponse(
        rawText: m['rawText'] as String? ?? '',
        suggestions: suggestions,
      );
    } catch (_) {
      return null;
    }
  }
}
