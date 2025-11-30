import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:http/http.dart' as http;

import '../../models/ai_response.dart';
import '../../models/message.dart';
import '../ai_service.dart';

class GeminiAIService implements AIService {
  final GenerativeModel _model;
  final List<Message> _history = [];
  int _failedAttempts = 0;
  
  // Diagnostic conversation state
  String _conversationStage = 'initial'; // initial, gathering_info, diagnosing, solution_proposed, verification
  Map<String, dynamic> _diagnosticData = {};
  bool _waitingForFixConfirmation = false;

  GeminiAIService()
      : _model = GenerativeModel(
          model: 'models/gemini-2.5-flash',
          apiKey: dotenv.env['GEMINI_API_KEY']!,
          safetySettings: [
            SafetySetting(HarmCategory.harassment, HarmBlockThreshold.none),
            SafetySetting(HarmCategory.hateSpeech, HarmBlockThreshold.none),
            SafetySetting(HarmCategory.sexuallyExplicit, HarmBlockThreshold.none),
            SafetySetting(HarmCategory.dangerousContent, HarmBlockThreshold.none),
          ],
        );

  @override
  Future<AIResponse> diagnose({
    required List<Message> history,
    String? imagePath,
    double? temperature,
    double? topP,
    String? mode,
    Map<String, dynamic>? imageAnalysis,
  }) async {
    try {
      final prompt = _buildPrompt(
        problem: history.last.text,
        history,
        imagePath: imagePath,
        temperature: temperature,
        mode: mode,
        imageAnalysis: imageAnalysis,
      );

      if (imageAnalysis != null) {
        print('GeminiAIService: sending imageAnalysis to model: ${jsonEncode(imageAnalysis)}');
      }

      final response = await _model.generateContent([Content.text(prompt)]);

      if (response.text == null) {
        throw Exception('Response was blocked or empty.');
      }

      return _parseResponse(response.text!);
    } catch (e) {
      print('Error calling Gemini API: $e');
      if (e.toString().contains('is not found')) {
        await _logAvailableModels();
      }
      throw Exception('Failed to get diagnosis from AI.');
    }
  }

  String _buildPrompt(
    List<Message> history, {
    required String problem,
    String? imagePath,
    double? temperature,
    String? mode,
    Map<String, dynamic>? imageAnalysis,
  }) {
    // Build chat history
    final historyString = history.map((msg) {
      final role = msg.isFromUser ? 'User' : 'Assistant';
      return "$role: ${msg.text}";
    }).join('\n');

    // Mode instruction
    String modeInstruction = '';
    if (mode == 'experimental') {
      modeInstruction = '''
      IMPORTANT: You are in EXPERIMENTAL mode.
      After completing diagnosis, provide one safe solution first, then a creative experimental alternative.
      Label the second solution "🧪 Experimental Hack:" with appropriate warnings.
      ''';
    } else {
      modeInstruction = '''
      IMPORTANT: You are in PRACTICAL mode.
      Provide ONLY the most common, safest, and most reliable solutions.
      ''';
    }

    // Image analysis handling
    final imageNote = (imagePath != null)
        ? '\nUser attached an image; use it to help diagnose visible issues.'
        : '';

    String analysisNote = '';
    if (imageAnalysis != null) {
      try {
        final rawLabels = imageAnalysis['labels'] ?? [];
        final ocr = imageAnalysis['ocr'] ?? '';
        final filename = imageAnalysis['attachedImageFilename'] ?? imagePath ?? '';
        final unavailable = imageAnalysis['analysisUnavailable'] == true;

        final formattedLabels = <String>[];
        double topConfidence = 0.0;

        if (rawLabels is List) {
          for (final l in rawLabels) {
            if (l is Map && l.containsKey('label')) {
              final lab = l['label'] as String;
              final conf = (l['confidence'] is num) ? (l['confidence'] as num).toDouble() : 0.0;
              formattedLabels.add('$lab (${(conf * 100).toStringAsFixed(0)}%)');
              if (conf > topConfidence) {
                topConfidence = conf;
              }
            } else if (l is String) {
              formattedLabels.add(l);
            }
          }
        }

        analysisNote = '\nImage analysis for ${filename.isNotEmpty ? filename : 'attached image'}:';
        analysisNote += '\n- labels: ${formattedLabels.isNotEmpty ? formattedLabels : rawLabels}';
        if (ocr != null && (ocr as String).isNotEmpty) {
          analysisNote += '\n- ocr: $ocr';
        }
        if (unavailable) {
          analysisNote += '\n- note: Analysis unavailable, but image was attached.';
        }
      } catch (e) {
        analysisNote = '\nImage attached but analysis details unavailable.';
      }
    }

    return '''
You are an expert electronics repair assistant conducting a DIAGNOSTIC CONVERSATION with a user.

**CRITICAL: You must follow a structured diagnostic process. DO NOT jump to solutions immediately.**

--- USER'S LATEST MESSAGE ---
"$problem"

--- CONVERSATION HISTORY ---
$historyString
--- END OF HISTORY ---

--- CURRENT DIAGNOSTIC STAGE: $_conversationStage ---
--- COLLECTED DIAGNOSTIC DATA ---
${jsonEncode(_diagnosticData)}
--- END OF DIAGNOSTIC DATA ---

$modeInstruction
$imageNote
$analysisNote

**DIAGNOSTIC CONVERSATION FLOW (You MUST follow these stages strictly):**

**CURRENT STAGE: $_conversationStage**
**FAILED ATTEMPTS: $_failedAttempts**

**STAGE 1: INITIAL ASSESSMENT (stage = 'initial')**
When user first describes a problem:
- Acknowledge their issue warmly
- Ask 2-3 KEY diagnostic questions
- DO NOT provide solutions yet
- Set "followUp": true, "suggestions": []

**STAGE 2: GATHERING_INFO (stage = 'gathering_info')**
Continue asking clarifying questions until you have:
- Device type, brand, model
- Exact symptoms
- Timeline of when it started
- Any incidents (spills, drops, updates)
- Previous troubleshooting attempts

When you have ENOUGH information, propose your diagnosis:
- Summarize what you've learned
- State your diagnosis with confidence level
- Ask: "Does this match what you're experiencing? Would you like me to provide repair steps?"
- Set "followUp": true, "suggestions": []

**STAGE 3: DIAGNOSING (stage = 'diagnosing')**
User has confirmed they want repair steps.
NOW provide detailed solutions:
- Offer 1-3 solutions ranked by likelihood
- Include full steps, tools, safety warnings
- End with: "Please try this solution and let me know if it worked!"
- Set "followUp": true, "suggestions": [... detailed solutions ...]

**STAGE 4: SOLUTION_PROPOSED (stage = 'solution_proposed')**
You've already provided solutions. Move to verification stage.
- Set "followUp": true

**STAGE 5: VERIFICATION (stage = 'verification')**
User is testing your solution.

If user input contains "yes"/"worked"/"fixed":
{
  "rawText": "🎉 Excellent! Your device is repaired. Feel free to ask about any other issues!",
  "suggestions": [],
  "followUp": false
}

If user input contains "no"/"didn't work"/"still broken" AND attempts < 3:
- Acknowledge the failed attempt
- Ask what happened during the attempt
- Provide a COMPLETELY DIFFERENT solution approach
- Set "followUp": true, "suggestions": [... new different solution ...]

If attempts >= 3:
{
  "rawText": "I understand this is challenging. Based on the symptoms and failed attempts, I recommend consulting a professional repair technician who can physically inspect the device.",
  "suggestions": [
    {
      "id": "professional_help",
      "title": "Seek Professional Repair",
      "steps": ["Contact a certified repair shop for hands-on diagnosis"],
      "tools": [],
      "confidence": 1.0,
      "estimatedTimeMinutes": 0,
      "safetyNotes": "Professional diagnosis recommended for complex issues."
    }
  ],
  "followUp": false
}

**CRITICAL RULES:**
1. DO NOT provide solutions during INITIAL or GATHERING_INFO stages
2. DO NOT congratulate the user unless they explicitly said it worked
3. ONLY provide "suggestions" array when in DIAGNOSING stage or later
4. If current stage is "gathering_info", you MUST ask more questions
5. If current stage is "diagnosing", you MUST provide detailed repair solutions

**Example for GATHERING_INFO stage:**
{
  "rawText": "Thank you for that information! Just a few more questions to narrow this down:\\n\\n1. Is the battery completely dead, or does the charging indicator light up?\\n2. How long have you tried charging it?\\n3. Are you using the original charger?",
  "suggestions": [],
  "followUp": true
}

**Example for DIAGNOSING stage (providing solution):**
{
  "rawText": "Based on your RK61 mechanical keyboard with one key not working after water spill, here's my diagnosis:\\n\\n**Most Likely Cause:** Corrosion or residue on the switch contacts from water damage\\n\\nHere are the solutions:",
  "suggestions": [
    {
      "id": "clean_switch",
      "title": "Clean and Dry the Keyboard Switch",
      "steps": [
        "Unplug the keyboard immediately",
        "Remove the keycap using a keycap puller or carefully with your fingers",
        "Use isopropyl alcohol (90%+) on a cotton swab to clean around the switch",
        "Let it dry completely for 2-3 hours",
        "Test the key before reassembling"
      ],
      "tools": ["Isopropyl alcohol 90%+", "Cotton swabs", "Keycap puller (optional)"],
      "confidence": 0.8,
      "estimatedTimeMinutes": 30,
      "safetyNotes": "Ensure keyboard is unplugged. Let alcohol dry completely before use."
    }
  ],
  "followUp": true
}

**CRITICAL JSON FORMATTING RULES:**
- The "rawText" field MUST be a valid JSON string
- Use \\n for line breaks (not actual newlines)
- Escape all special characters: \\" for quotes, \\\\ for backslashes
- Do NOT include literal newlines or unescaped control characters
- Example of CORRECT formatting:
  "rawText": "Line 1\\n\\nLine 2\\n1. First item\\n2. Second item"

**RESPONSE FORMAT:**
You MUST return ONLY a valid JSON object with these exact keys:
- "rawText": Your message to the user (string)
- "suggestions": Array of solution objects (empty array [] during diagnostic stages)
- "followUp": Boolean (true if expecting user response, false when conversation ends)

**Suggestion object format** (only include when providing solutions in Stage 4+):
{
  "id": "unique_id",
  "title": "Solution Title",
  "steps": ["step 1", "step 2", ...],
  "tools": ["tool1", "tool2", ...],
  "confidence": 0.0-1.0,
  "estimatedTimeMinutes": integer,
  "safetyNotes": "safety information"
}

**Example Stage 1 Response (Initial Contact):**
{
  "rawText": "I understand your device isn't turning on - that's frustrating! To help diagnose this properly, I need to ask a few questions:\n\n1. What device is this exactly? (Brand and model if you know it)\n2. When did this problem start?\n3. Does anything happen when you press the power button? (lights, sounds, vibration?)\n4. Has the device been dropped, exposed to water, or had any recent software updates?",
  "suggestions": [],
  "followUp": true
}

**Example Stage 2 Response (Gathering Info):**
{
  "rawText": "Thank you for that information! A few more questions to narrow this down:\n\n1. Is the battery completely dead, or does the charging indicator light up?\n2. How long have you tried charging it?\n3. Are you using the original charger, or a different one?",
  "suggestions": [],
  "followUp": true
}

**Example Stage 3 Response (Diagnosis):**
{
  "rawText": "Based on what you've told me, here's my diagnosis:\n\nMost likely cause: **Faulty charging port or battery connection**\n\nReasons:\n- Device won't turn on even after charging overnight\n- No charging indicator lights\n- Started after being dropped\n- Device is 2 years old\n\nConfidence: 75%\n\nDoes this match your experience? Would you like me to provide step-by-step repair instructions?",
  "suggestions": [],
  "followUp": true
}

Only output valid JSON. No code blocks, no extra text.
''';
  }

  @override
  Future<bool> isRepairQuestion(String userQuery) async {
    final lowerQuery = userQuery.toLowerCase().trim();

    if (lowerQuery.length < 10 || 
      ['yes', 'no', 'ok', 'sure', 'okay', 'yup', 'nope'].contains(lowerQuery)) {
    return true;  // Allow it through
  }
  
    try {
      final prompt = """
      Is the following query related to fixing, repairing, diagnosing, troubleshooting electronics, or finding repair shops? 
      Respond with only "YES" or "NO".

      Query: "$userQuery"
      """;

      final response = await _model.generateContent([Content.text(prompt)]);
      
      if (response.text == null) {
        return true;
      }
      return response.text!.toLowerCase().contains('yes');
    } catch (e) {
      return true;
    }
  }

  Future<AIResponse> sendPromptToAI(String promptText) async {
    final newMessage = Message(
      text: promptText,
      isFromUser: true,
      timestamp: Timestamp.now(),
      id: '',
      edited: false,
    );

    _history.add(newMessage);

    final aiResponse = await diagnose(
      history: List.unmodifiable(_history),
      mode: 'practical',
    );

    _waitingForFixConfirmation = aiResponse.followUp;
    
    final assistantMessage = Message(
      text: aiResponse.rawText,
      isFromUser: false,
      timestamp: Timestamp.now(),
      id: '',
      edited: false,
    );
    _history.add(assistantMessage);

    // Update conversation stage based on response
    _updateConversationStage(promptText, aiResponse);

    return aiResponse;
  }

// Replace your _updateConversationStage and handleUserMessage methods with these:

void _updateConversationStage(String userInput, AIResponse response) {
  final lowerInput = userInput.toLowerCase();
  final lowerResponse = response.rawText.toLowerCase();
  
  print('DEBUG: Current stage: $_conversationStage');
  print('DEBUG: User input: $userInput');
  print('DEBUG: Has suggestions: ${response.suggestions.isNotEmpty}');
  
  // Stage 1: Initial → Gathering Info
  if (_conversationStage == 'initial') {
    _conversationStage = 'gathering_info';
    print('DEBUG: Moved to gathering_info');
  }
  
  // Stage 2: Gathering Info → Still gathering or move to diagnosing
  else if (_conversationStage == 'gathering_info') {
    // Check if AI is proposing a diagnosis (contains phrases like "based on", "diagnosis", "most likely")
    if (lowerResponse.contains('diagnosis') || 
        lowerResponse.contains('based on what you') ||
        lowerResponse.contains('most likely') ||
        lowerResponse.contains('here\'s what i think')) {
      _conversationStage = 'diagnosing';
      print('DEBUG: Moved to diagnosing');
    }
    // Otherwise stay in gathering_info
  }
  
  // Stage 3: Diagnosing → Solution Proposed (when user confirms and AI provides solutions)
  else if (_conversationStage == 'diagnosing') {
    if (response.suggestions.isNotEmpty) {
      _conversationStage = 'solution_proposed';
      print('DEBUG: Moved to solution_proposed');
    }
  }
  
  // Stage 4: Solution Proposed → Verification (waiting for user to try solution)
  else if (_conversationStage == 'solution_proposed') {
    _conversationStage = 'verification';
    print('DEBUG: Moved to verification');
  }
  
  // Stage 5: Verification → Handle success/failure
  else if (_conversationStage == 'verification') {
    bool isSuccess = lowerInput.contains('yes') || 
                      lowerInput.contains('work') || 
                      lowerInput.contains('fixed') ||
                      lowerInput.contains('solved');
    
    bool isFailure = lowerInput.contains('no') || 
                      lowerInput.contains('didn\'t work') || 
                      lowerInput.contains('still') ||
                      lowerInput.contains('not work');
    
    if (isSuccess) {
      print('DEBUG: User confirmed success - resetting');
      // Will be reset in handleUserMessage
    } else if (isFailure) {
      print('DEBUG: User reported failure - attempt ${_failedAttempts + 1}');
      // Stay in verification to try another solution
    }
  }
}

Future<void> handleUserMessage(String userText) async {
  print('DEBUG: handleUserMessage called with: $userText');
  print('DEBUG: Current stage: $_conversationStage, Failed attempts: $_failedAttempts');
  
  final lowerText = userText.toLowerCase();
  
  // CASE 1: Initial problem or new conversation
  if (_conversationStage == 'initial' || !_waitingForFixConfirmation) {
    print('DEBUG: Starting new diagnostic conversation');
    _failedAttempts = 0;
    _conversationStage = 'initial';
    _diagnosticData = {'initialProblem': userText};
    _history.clear();
    
    await sendPromptToAI(userText);
  }
  
  // CASE 2: User confirms solution worked
  else if (_conversationStage == 'verification' && 
           (lowerText.contains('yes') || 
            lowerText.contains('work') || 
            lowerText.contains('fixed'))) {
    print('DEBUG: Solution confirmed successful');
    _failedAttempts = 0;
    await sendPromptToAI('SUCCESS: The solution worked! Problem is fixed.');
    _resetConversation();
  }
  
  // CASE 3: Solution failed - try again
  else if (_conversationStage == 'verification' && 
            (lowerText.contains('no') || 
            lowerText.contains('didn\'t') || 
            lowerText.contains('still'))) {
    _failedAttempts++;
    print('DEBUG: Solution failed - attempt $_failedAttempts');
    
    if (_failedAttempts < 3) {
      String failurePrompt = 'FAILED ATTEMPT #$_failedAttempts: The previous solution did not work. User says: "$userText". Please provide a DIFFERENT approach.';
      await sendPromptToAI(failurePrompt);
    } else {
      // Too many failures - recommend professional help
      String finalPrompt = 'FINAL FAILURE: After $_failedAttempts attempts, none worked. Recommend professional help.';
      await sendPromptToAI(finalPrompt);
      _resetConversation();
    }
  }
  
  // CASE 4: Still in diagnostic conversation (answering questions)
  else if (_conversationStage == 'gathering_info' || _conversationStage == 'diagnosing') {
    print('DEBUG: Continuing diagnostic conversation');
    _diagnosticData['response_${_history.length}'] = userText;
    await sendPromptToAI(userText);
  }
  
  // CASE 5: User provided info, expecting solution
  else if (_conversationStage == 'solution_proposed') {
    print('DEBUG: Moving to provide solution');
    await sendPromptToAI(userText);
  }
  
  // CASE 6: Default - continue conversation
  else {
    print('DEBUG: Default case - continuing conversation');
    await sendPromptToAI(userText);
  }
}

  void _resetConversation() {
    _conversationStage = 'initial';
    _failedAttempts = 0;
    _diagnosticData.clear();
    _history.clear();
    _waitingForFixConfirmation = false;
  }

  AIResponse _parseResponse(String responseText) {
    try {
      final cleanedText = responseText
          .replaceAll('```json', '')
          .replaceAll('```', '')
          .trim();

      final jsonMap = jsonDecode(cleanedText) as Map<String, dynamic>;
      return AIResponse.fromJson(jsonMap, responseText);
    } catch (e) {
      print('Error parsing JSON response: $e');
      print('Raw AI Response: $responseText');
      return AIResponse(
        suggestions: [],
        rawText: "Sorry, I had trouble formatting my response. Please try again.",
        followUp: true,
      );
    }
  }

  Future<void> _logAvailableModels() async {
    final key = dotenv.env['GEMINI_API_KEY'];
    if (key == null) {
      print('No API key found in env; cannot list models.');
      return;
    }
    try {
      final uri = Uri.parse(
        'https://generativelanguage.googleapis.com/v1/models?key=$key',
      );
      final res = await http.get(uri);
      print('ListModels status: ${res.statusCode}');
      print('ListModels body: ${res.body}');
    } catch (err) {
      print('Failed to list models: $err');
    }
  }
}