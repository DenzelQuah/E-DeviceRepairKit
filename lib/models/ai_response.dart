import 'repair_suggestion.dart';

class AIResponse {
  final List<RepairSuggestion> suggestions;
  final String rawText;

  AIResponse({
    required this.suggestions,
    required this.rawText,
  });
}