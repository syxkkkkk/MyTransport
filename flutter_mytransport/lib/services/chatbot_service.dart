import 'api_service.dart';

class ChatMessage {
  final String role; // 'user' | 'assistant'
  final String content;
  final DateTime createdAt;

  ChatMessage({
    required this.role,
    required this.content,
    required this.createdAt,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json) => ChatMessage(
        role: json['role'] == 'USER' ? 'user' : 'assistant',
        content: json['content'] as String,
        createdAt: DateTime.parse(json['createdAt'] as String),
      );
}

class ChatbotService {
  final _api = ApiService();
  String? _sessionId;

  String? get sessionId => _sessionId;

  Future<ChatMessage> sendMessage(String message) async {
    final res = await _api.post(
      '/chatbot/message',
      {
        'message': message,
        if (_sessionId != null) 'sessionId': _sessionId,
      },
      auth: true,
    );

    final data = res['data'] as Map<String, dynamic>;
    _sessionId = data['sessionId'] as String;
    final msg = data['message'] as Map<String, dynamic>;
    return ChatMessage.fromJson(msg);
  }

  void resetSession() => _sessionId = null;
}
