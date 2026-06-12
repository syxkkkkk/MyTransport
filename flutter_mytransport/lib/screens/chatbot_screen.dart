import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import '../widgets/bottom_nav_bar.dart';
import '../services/chatbot_service.dart';

class ChatbotScreen extends StatefulWidget {
  const ChatbotScreen({super.key});

  @override
  State<ChatbotScreen> createState() => _ChatbotScreenState();
}

class _ChatbotScreenState extends State<ChatbotScreen> {
  final _chatbotService = ChatbotService();
  final _scrollController = ScrollController();
  final _inputController = TextEditingController();
  final _focusNode = FocusNode();

  final List<_Message> _messages = [
    _Message(
      role: 'assistant',
      text: 'Hi! I\'m your MyTransport AI assistant 🚇\n\nAsk me anything about getting around KL — routes, fares, stations, or real-time alerts!',
      time: DateTime.now(),
    ),
  ];

  bool _isLoading = false;

  static const _suggestions = [
    'How do I get to KLCC?',
    'Best route to Bukit Bintang?',
    'KL Sentral to Putrajaya?',
    'LRT fare from Gombak to Kelana Jaya?',
  ];

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _inputController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _send(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty || _isLoading) return;
    _inputController.clear();
    setState(() {
      _messages.add(_Message(role: 'user', text: trimmed, time: DateTime.now()));
      _isLoading = true;
    });
    _scrollToBottom();
    try {
      final reply = await _chatbotService.sendMessage(trimmed);
      if (mounted) {
        setState(() {
          _messages.add(_Message(role: 'assistant', text: reply.content, time: reply.createdAt));
          _isLoading = false;
        });
        _scrollToBottom();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _messages.add(_Message(role: 'assistant', text: 'Sorry, I couldn\'t get a response. Please check your connection and try again.\n\n($e)', time: DateTime.now()));
          _isLoading = false;
        });
        _scrollToBottom();
      }
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          _buildHeader(),
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              itemCount: _messages.length + (_isLoading ? 1 : 0),
              itemBuilder: (ctx, i) {
                if (i == _messages.length) return const _TypingIndicator();
                return _MessageBubble(message: _messages[i]);
              },
            ),
          ),
          if (_messages.length == 1) _buildSuggestions(),
          _buildInputBar(),
        ],
      ),
      bottomNavigationBar: const BottomNavBar(currentTab: NavTab.home),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 52, 16, 16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(bottom: BorderSide(color: AppColors.surfaceVariant)),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back, color: AppColors.onSurface),
            onPressed: () => Navigator.pop(context),
            padding: EdgeInsets.zero,
          ),
          const SizedBox(width: 8),
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppColors.primary, AppColors.secondary],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.smart_toy_rounded, color: Colors.white, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('MyTransport AI', style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 16, color: AppColors.onSurface)),
                Row(
                  children: [
                    Container(width: 6, height: 6, decoration: const BoxDecoration(color: Color(0xFF22C55E), shape: BoxShape.circle)),
                    const SizedBox(width: 4),
                    Text('Online · Gemini AI', style: GoogleFonts.inter(fontSize: 12, color: AppColors.onSurfaceVariant)),
                  ],
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.refresh, color: AppColors.onSurfaceVariant),
            onPressed: () {
              _chatbotService.resetSession();
              setState(() {
                _messages.clear();
                _messages.add(_Message(role: 'assistant', text: 'New session started! How can I help you navigate KL today?', time: DateTime.now()));
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSuggestions() {
    return SizedBox(
      height: 44,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _suggestions.length,
        itemBuilder: (ctx, i) => Padding(
          padding: const EdgeInsets.only(right: 8),
          child: ActionChip(
            label: Text(_suggestions[i], style: GoogleFonts.inter(fontSize: 12, color: AppColors.primary)),
            backgroundColor: AppColors.primaryContainer,
            side: BorderSide(color: AppColors.primary.withOpacity(0.3)),
            onPressed: () => _send(_suggestions[i]),
          ),
        ),
      ),
    );
  }

  Widget _buildInputBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.surfaceVariant)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.surfaceContainer,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: AppColors.surfaceVariant),
              ),
              child: TextField(
                controller: _inputController,
                focusNode: _focusNode,
                maxLines: null,
                textCapitalization: TextCapitalization.sentences,
                onSubmitted: _send,
                decoration: InputDecoration(
                  hintText: 'Ask about routes, fares, stations...',
                  hintStyle: GoogleFonts.inter(color: AppColors.onSurfaceVariant, fontSize: 14),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                ),
                style: GoogleFonts.inter(fontSize: 14, color: AppColors.onSurface),
              ),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () => _send(_inputController.text),
            child: Container(
              width: 44, height: 44,
              decoration: BoxDecoration(
                gradient: _isLoading ? null : const LinearGradient(colors: [AppColors.primary, AppColors.secondary], begin: Alignment.topLeft, end: Alignment.bottomRight),
                color: _isLoading ? AppColors.surfaceVariant : null,
                shape: BoxShape.circle,
              ),
              child: Icon(_isLoading ? Icons.hourglass_top : Icons.send_rounded, color: _isLoading ? AppColors.onSurfaceVariant : Colors.white, size: 20),
            ),
          ),
        ],
      ),
    );
  }
}

class _Message {
  final String role;
  final String text;
  final DateTime time;
  _Message({required this.role, required this.text, required this.time});
  bool get isUser => role == 'user';
}

class _MessageBubble extends StatelessWidget {
  final _Message message;
  const _MessageBubble({required this.message});

  @override
  Widget build(BuildContext context) {
    final isUser = message.isUser;
    return Padding(
      padding: EdgeInsets.only(top: 6, bottom: 6, left: isUser ? 48 : 0, right: isUser ? 0 : 48),
      child: Row(
        mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isUser) ...[
            Container(
              width: 28, height: 28,
              decoration: BoxDecoration(gradient: const LinearGradient(colors: [AppColors.primary, AppColors.secondary]), borderRadius: BorderRadius.circular(8)),
              child: const Icon(Icons.smart_toy_rounded, color: Colors.white, size: 16),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isUser ? AppColors.primary : AppColors.surface,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: Radius.circular(isUser ? 16 : 4),
                  bottomRight: Radius.circular(isUser ? 4 : 16),
                ),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 6, offset: const Offset(0, 2))],
              ),
              child: Text(message.text, style: GoogleFonts.inter(fontSize: 14, height: 1.5, color: isUser ? Colors.white : AppColors.onSurface)),
            ),
          ),
          if (isUser) const SizedBox(width: 8),
        ],
      ),
    );
  }
}

class _TypingIndicator extends StatefulWidget {
  const _TypingIndicator();
  @override
  State<_TypingIndicator> createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends State<_TypingIndicator> with TickerProviderStateMixin {
  late final List<AnimationController> _controllers;

  @override
  void initState() {
    super.initState();
    _controllers = List.generate(3, (i) => AnimationController(vsync: this, duration: const Duration(milliseconds: 500)));
    for (var i = 0; i < 3; i++) {
      Future.delayed(Duration(milliseconds: i * 160), () {
        if (mounted) _controllers[i].repeat(reverse: true);
      });
    }
  }

  @override
  void dispose() {
    for (final c in _controllers) c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 6, bottom: 6),
      child: Row(
        children: [
          Container(
            width: 28, height: 28,
            decoration: BoxDecoration(gradient: const LinearGradient(colors: [AppColors.primary, AppColors.secondary]), borderRadius: BorderRadius.circular(8)),
            child: const Icon(Icons.smart_toy_rounded, color: Colors.white, size: 16),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: const BorderRadius.only(topLeft: Radius.circular(16), topRight: Radius.circular(16), bottomRight: Radius.circular(16), bottomLeft: Radius.circular(4)),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 6, offset: const Offset(0, 2))],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(3, (i) => AnimatedBuilder(
                animation: _controllers[i],
                builder: (_, __) => Container(
                  width: 6, height: 6,
                  margin: EdgeInsets.only(right: i < 2 ? 4 : 0),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.4 + 0.6 * _controllers[i].value),
                    shape: BoxShape.circle,
                  ),
                ),
              )),
            ),
          ),
        ],
      ),
    );
  }
}
