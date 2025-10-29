import 'repair_suggestion.dart';

class AIResponse {
  final List<RepairSuggestion> suggestions;
  final String rawText;


  AIResponse({
    required this.suggestions,
    required this.rawText,
  });


  factory AIResponse.fromJson(Map<String, dynamic> json, String originalText) {
    var suggestionsList = (json['suggestions'] as List? ?? [])
        .map((s) => RepairSuggestion.fromJson(s))
        .toList();

    return AIResponse(
      suggestions: suggestionsList,
      rawText: json['rawText'] ?? originalText,
    );
  }
}