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
  String _conversationStage =
      'initial'; // initial, gathering_info, diagnosing, solution_proposed, verification
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
        print(
          'GeminiAIService: sending imageAnalysis to model: ${jsonEncode(imageAnalysis)}',
        );
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
    final historyString = history
        .map((msg) => "${msg.isFromUser ? 'User' : 'Assistant'}: ${msg.text}")
        .join('\n');

        

    // Mode instruction
    String modeInstruction = '';
    if (mode == 'experimental') {
      modeInstruction = '''
     **CURRENT MODE: 🧪 EXPERIMENTAL**
      - Your priority is **EDUCATION & DIY**.
      - You are allowed to suggest advanced, difficult, or risky repairs (e.g., screen replacement, component soldering).
      - **PHYSICAL DAMAGE:** If the user has physical damage (cracked screen, water damage), **WARN THEM STRONGLY** about the risks, but **PROVIDE THE STEPS** anyway.
      - Mark suggestions as "High Risk" in the title if applicable.
      - **STRATEGY:** Provide the most thorough, likely-to-work solution first, even if complex.
      - **NO ATTEMPTS LIMIT:** Provide the next logical solution regardless of how many previous attempts failed.
      - **ALWAYS SHOW SUGGESTION:** You MUST populate the `suggestions` array with a new fix if one is available. Never return an empty array just because of failure count.
      - **STORE RECOMMENDATION:** If `FAILED ATTEMPTS > 0`, adds a note in "rawText": "Since that didn't work, would you like to find a repair shop?" BUT **ALWAYS** provide the next solution in the card.
      ''';

    } else {
      modeInstruction = '''
      **CURRENT MODE: 🛡️ PRACTICAL (QUICK FIX)**
      - Priority: **SIMPLE TROUBLESHOOTING BEFORE SHOP VISITS**.
      - **WATER DAMAGE RULE:** If the user mentions water, liquid, or "green line after spill", **DO NOT** suggest charging or restarting. Suggest turning it off immediately.
      - **STRATEGY:** Suggest safe solution repair only (Force Restart, Clean Port, Safe Mode).
      
      **THE "TWO ATTEMPTS" RULE (Follow Strictly):**
      - CHECK the `FAILED ATTEMPTS` count below.
      
      1. **If FAILED ATTEMPTS = 0:** - Provide your **#1 Best** Quick Fix.
      
      2. **If FAILED ATTEMPTS = 1:** - Provide your **#2 Best** Quick Fix (Must be different).
      
      3. **If FAILED ATTEMPTS >= 2:** - **STOP IMMEDIATELY.**
          - Return "suggestions": [] (empty array).
         - **CRITICAL:** In your text response, explicitly tell the user: "Since the quick fixes didn't work, it is likely a hardware issue. I recommend finding a repair shop near you."
      
      - **PHYSICAL DAMAGE:** If clearly broken (shattered screen), treat as "FAILED ATTEMPTS = 2" immediately (Skip to Shop).
      ''';
    }

    // Image analysis handling
    final imageNote =
        (imagePath != null)
            ? '\nUser attached an image; use it to help diagnose visible issues.'
            : '';

    String analysisNote = '';
    if (imageAnalysis != null) {
      try {
        final rawLabels = imageAnalysis['labels'] ?? [];
        final ocr = imageAnalysis['ocr'] ?? '';
        final filename =
            imageAnalysis['attachedImageFilename'] ?? imagePath ?? '';
        final unavailable = imageAnalysis['analysisUnavailable'] == true;

        final formattedLabels = <String>[];
        double topConfidence = 0.0;

        if (rawLabels is List) {
          for (final l in rawLabels) {
            if (l is Map && l.containsKey('label')) {
              final lab = l['label'] as String;
              final conf =
                  (l['confidence'] is num)
                      ? (l['confidence'] as num).toDouble()
                      : 0.0;
              formattedLabels.add('$lab (${(conf * 100).toStringAsFixed(0)}%)');
              if (conf > topConfidence) {
                topConfidence = conf;
              }
            } else if (l is String) {
              formattedLabels.add(l);
            }
          }
        }

        analysisNote =
            '\nImage analysis for ${filename.isNotEmpty ? filename : 'attached image'}:';
        analysisNote +=
            '\n- labels: ${formattedLabels.isNotEmpty ? formattedLabels : rawLabels}';
        if (ocr != null && (ocr as String).isNotEmpty) {
          analysisNote += '\n- ocr: $ocr';
        }
        if (unavailable) {
          analysisNote +=
              '\n- note: Analysis unavailable, but image was attached.';
        }
      } catch (e) {
        analysisNote = '\nImage attached but analysis details unavailable.';
      }
    }

    return '''
You are an expert Electronics Repair Technician using a "Diagnostic Conversation" approach.
**GOAL:** Diagnose the user's issue through conversation, THEN provide a solution based on the current mode.


$modeInstruction

**DIAGNOSTIC CONVERSATION FLOW (You MUST follow these stages strictly):**
**STAGE 1: GATHERING INFO (The "Follow-Up" Phase)**
- If you don't know the **Device Model**, ask for it.
- If you don't know **When/How it started**, ask for it.
- **CRITICAL RULE:** Ask **ONE** question at a time. Do not overwhelm the user.
- **OUTPUT:** "rawText": "Your single question here", "suggestions": [], "followUp": true

**STAGE 2: HYPOTHESIS & CONFIRMATION**
- Once you have the context (Model + Symptoms), summarize the issue.
- State your diagnosis (what you think is wrong).
- Ask the user if they want to proceed with the repair steps.
- **OUTPUT:** "rawText": "It sounds like a faulty X. Shall I show you how to fix it?", "suggestions": [], "followUp": true

**STAGE 3: DIAGNOSING & SOLVING (Providing the Fix)**
- Provide 1-3 detailed solutions ranked by likelihood.
- **RETRY RULE:** If the user says "It didn't work" or "No", you MUST provide a **DIFFERENT** solution than the previous one. Do not repeat the same steps.
- APPLY MODE RULES (Experimental vs Practical).
- Output: "followUp": true, "suggestions": [{...}]


**STAGE 4: SOLUTION_PROPOSED**
- (You have just provided the solution steps)
- Ask the user to try them and let you know if it worked.
- **OUTPUT:** "rawText": "Let me know if this works...", "suggestions": [], "followUp": true

**STAGE 5: VERIFICATION**
- If user says "yes/fixed": Celebrate and offer further help.
- If user says "no/broken": Apologize and provide a **DIFFERENT** solution (Stage 3 again).
- If user says "no" and you have ran out of ideas, recommend a repair shop.

**RESPONSE FORMAT (Strict JSON):**
You MUST return ONLY a valid JSON object.
{
  "rawText": "Your conversational advice to the user...",
  "followUp": true,
  "suggestions": [
    {
      "id": "unique_id",
      "query": "Summarized Problem (e.g., Pixel 7 Water Damage)",
      "title": "The Solution Title (e.g., Drying & Desiccant Method)",
      "deviceType": "Phone",
      "steps": ["Step 1...", "Step 2..."],
      "tools": ["Tool A", "Tool B"],
      "confidence": 0.9,
      "estimatedTimeMinutes": 45,
      "safetyNotes": "Do not charge the device."
    }
  ]
}


--- CONVERSATION HISTORY ---
$historyString
--- END OF HISTORY ---

--- CURRENT DIAGNOSTIC STAGE: $_conversationStage ---
--- COLLECTED DIAGNOSTIC DATA ---
${jsonEncode(_diagnosticData)}
--- END OF DIAGNOSTIC DATA ---


--- USER'S LATEST MESSAGE ---
"$problem"
$imageNote
$analysisNote


**DIAGNOSTIC CONVERSATION FLOW (You MUST follow these stages strictly):**

**CURRENT STAGE: $_conversationStage**
**FAILED ATTEMPTS: $_failedAttempts**


**CRITICAL RULES:**
1. **ONE QUESTION RULE:** In Stage 1 & 2, never ask more than 1 question per turn.
2. Keep responses short and conversational (mobile-friendly).
3. DO NOT provide solutions until Stage 3.

**Example for GATHERING_INFO stage (CORRECT - Single Question):**
{
  "rawText": "I see. To help you better, could you tell me exactly which iPhone model this is?",
  "suggestions": [],
  "followUp": true
}

**Example for DIAGNOSING stage (Providing Solution):**
{
  "rawText": "Thanks. Since it's an iPhone 11 and the screen is black but vibrates, it's likely a **display connector issue**. Here is how to fix it:",
  "suggestions": [
    {
    "id": "unique_id",
      "query": "Summarized Problem (e.g., Pixel 7 Water Damage)",
      "title": "The Solution Title (e.g., Drying & Desiccant Method)",
      "deviceType": "Phone",
      "steps": ["Step 1...", "Step 2..."],
      "tools": ["Tool A", "Tool B"],
      "confidence": 0.9,
      "estimatedTimeMinutes": 45,
      "safetyNotes": "Do not charge the device."
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

    // 1. ALLOW SHORT ANSWERS
    if (lowerQuery.length < 5 ||
        ['yes', 'no', 'ok', 'sure', 'yup', 'nope'].contains(lowerQuery)) {
      return true;
    }

    // 2. THE FIX: ALLOW DEVICE BRANDS MANUALLY
    // If the text contains a brand name, we let it pass immediately.
    List<String> deviceKeywords = [
      'pixel',
      'iphone',
      'samsung',
      'huawei',
      'xiaomi',
      'oppo',
      'vivo',
      'redmi',
      'realme',
      'honor',
      'sony',
      'nokia',
      'motorola',
      'asus',
      'lenovo',
      'hp',
      'dell',
      'acer',
      'macbook',
      'ipad',
      'tab',
      'tv',
      'monitor',
    ];

    for (String brand in deviceKeywords) {
      if (lowerQuery.contains(brand)) {
        return true; // <--- This stops the error message!
      }
    }

    // 3. ASK AI (Only if it's not a brand name)
    try {
      final prompt = """
      Is the following query related to fixing, repairing, diagnosing electronics, 
      OR is it providing a device name (like "Pixel 7")? 
      Respond "YES" or "NO".
      Query: "$userQuery"
      """;

      final response = await _model.generateContent([Content.text(prompt)]);
      return response.text?.trim().toUpperCase().contains('YES') ?? true;
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
      bool isSuccess =
          lowerInput.contains('yes') ||
          lowerInput.contains('work') ||
          lowerInput.contains('fixed') ||
          lowerInput.contains('solved');

      bool isFailure =
          lowerInput.contains('no') ||
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
    print(
      'DEBUG: Current stage: $_conversationStage, Failed attempts: $_failedAttempts',
    );

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
        String failurePrompt =
            'FAILED ATTEMPT #$_failedAttempts: The previous solution did not work. User says: "$userText". Please provide a DIFFERENT approach.';
        await sendPromptToAI(failurePrompt);
      } else {
        // Too many failures - recommend professional help
        String finalPrompt =
            'FINAL FAILURE: After $_failedAttempts attempts, none worked. Recommend professional help.';
        await sendPromptToAI(finalPrompt);
        _resetConversation();
      }
    }
    // CASE 4: Still in diagnostic conversation (answering questions)
    else if (_conversationStage == 'gathering_info' ||
        _conversationStage == 'diagnosing') {
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
      // 1. Find the start and end of the JSON object
      final startIndex = responseText.indexOf('{');
      final endIndex = responseText.lastIndexOf('}');

      if (startIndex == -1 || endIndex == -1) {
        throw Exception("No JSON structure found in response");
      }

      // 2. Extract ONLY the JSON part
      final jsonString = responseText.substring(startIndex, endIndex + 1);

      // 3. Decode it
      final jsonMap = jsonDecode(jsonString) as Map<String, dynamic>;
      return AIResponse.fromJson(jsonMap, responseText);

    } catch (e) {
      print('Error parsing JSON response: $e');
      print('Raw AI Response: $responseText');
      
      // Fallback: Return a valid response object even if parsing fails, 
      // so the user doesn't get a dead end.
      return AIResponse(
        suggestions: [],
        rawText: "I apologize, but I'm having a technical glitch processing the solution. Could you please ask me to 'try again'?",
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
