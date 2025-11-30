import '../models/ai_response.dart';
import '../models/message.dart';

abstract class AIService {
  /// Diagnose a user message.
  ///
  /// Optional parameters:
  /// - imagePath: local file path to an attached photo
  /// - temperature: creativity control (0.0 conservative -> 1.0 creative)
  /// - topP: nucleus sampling parameter
  /// - mode: either 'practical' or 'experimental'
  Future<AIResponse> diagnose({
    
    //required Message message,
    required List<Message> history, 
    String? imagePath,
    double? temperature,
    double? topP,
    String? mode,
    Map<String, dynamic>? imageAnalysis,
  });

  Future<bool> isRepairQuestion(String userQuery);
}
