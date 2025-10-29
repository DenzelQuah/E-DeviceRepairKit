import 'repair_suggestion.dart';

class Message {
  final String id;
  final String text;
  final bool isFromUser;
  final List<RepairSuggestion>? suggestions;

  Message({
    required this.id,
    required this.text,
    required this.isFromUser,
    this.suggestions,
  });
}


