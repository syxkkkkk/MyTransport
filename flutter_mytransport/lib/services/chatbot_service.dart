import 'dart:convert';
import 'package:http/http.dart' as http;

// ---------------------------------------------------------------------------
// Calls Google Gemini directly — no backend required.
// ---------------------------------------------------------------------------

const _geminiApiKey = 'AIzaSyASdx8ZT8yfZMKC4fIm2McH9g8nT4xH6yk';
const _geminiUrl =
    'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent';

const _systemPrompt = '''
You are MyTransport AI — a friendly, knowledgeable transit assistant for Malaysia.
You help users navigate Kuala Lumpur and Malaysia using public transport.

You know about:
- KTM Komuter (intercity rail), MRT Putrajaya Line, MRT Kajang Line, LRT Kelana Jaya Line (KJ Line), LRT Ampang Line, BRT Sunway Line, Monorail KL, ERL (KLIA Ekspres / KLIA Transit), Rapid Bus KL, GoKL free bus
- Major stations: KL Sentral, KLCC, Bukit Bintang, Masjid Jamek, Pasar Seni, Titiwangsa, Bank Negara, Chow Kit, Pudu, Brickfields, Subang Jaya, Shah Alam, Petaling Jaya, Cyberjaya, Putrajaya
- Fares, tokens, MyRapid cards, Touch 'n Go
- Typical journey times and transfers

Reply concisely (2–4 sentences unless more detail is needed).
Format multi-step routes as a numbered list.
Always mention the train/bus line name, not just the station names.
If you are unsure of a specific fare or timetable, say so and suggest checking the official operator's app.
Reply in the same language the user uses (English or Malay).
''';

class ChatMessage {
  final String role; // 'user' | 'assistant'
  final String content;
  final DateTime createdAt;

  ChatMessage({
    required this.role,
    required this.content,
    required this.createdAt,
  });
}

class ChatbotService {
  // Conversation history kept in memory for the current session.
  final List<Map<String, dynamic>> _history = [];

  String? get sessionId => null; // not used with direct Gemini calls

  Future<ChatMessage> sendMessage(String message) async {
    // Append user turn to history
    _history.add({
      'role': 'user',
      'parts': [
        {'text': message}
      ],
    });

    final body = jsonEncode({
      'system_instruction': {
        'parts': [
          {'text': _systemPrompt}
        ],
      },
      'contents': _history,
      'generationConfig': {
        'temperature': 0.4,
        'maxOutputTokens': 512,
      },
    });

    final response = await http
        .post(
          Uri.parse('$_geminiUrl?key=$_geminiApiKey'),
          headers: {'Content-Type': 'application/json'},
          body: body,
        )
        .timeout(const Duration(seconds: 30));

    if (response.statusCode != 200) {
      // Remove the user turn we just added so it can be retried
      _history.removeLast();
      final err = jsonDecode(response.body);
      final msg = err['error']?['message'] as String? ??
          'Gemini returned HTTP ${response.statusCode}';
      throw Exception(msg);
    }

    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    final candidates =
        decoded['candidates'] as List<dynamic>;
    final text = (candidates.first['content']['parts'] as List<dynamic>)
        .map((p) => p['text'] as String)
        .join();

    // Append assistant turn to history
    _history.add({
      'role': 'model',
      'parts': [
        {'text': text}
      ],
    });

    return ChatMessage(
      role: 'assistant',
      content: text,
      createdAt: DateTime.now(),
    );
  }

  void resetSession() => _history.clear();
}
