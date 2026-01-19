import 'repair_suggestion.dart';

class AIResponse {
  final List<RepairSuggestion> suggestions;
  final String rawText;
  final bool followUp;


  AIResponse({
    required this.suggestions,
    required this.rawText,
    required this.followUp,
  });

  


  factory AIResponse.fromJson(Map<String, dynamic> json, String originalText) {
    var suggestionsList = (json['suggestions'] as List? ?? [])
        .map((s) => RepairSuggestion.fromJson(s))
        .toList();

    return AIResponse(
      suggestions: suggestionsList,
      followUp: json['followUp'] as bool? ?? true, // Safely extract the boolean
      rawText: json['rawText'] ?? originalText,
    );
    
  }
}
