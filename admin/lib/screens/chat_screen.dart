import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';

class ChatScreen extends StatefulWidget {
  final VoidCallback? onBack;
  const ChatScreen({super.key, this.onBack});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  final List<_ChatMessage> _messages = [];
  bool _isTyping = false;
  String? _selectedTenantSlug;

  @override
  void initState() {
    super.initState();
    _loadTenants();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadTenants() async {
    final api = context.read<ApiService>();
    try {
      final tenants = await api.getTenants();
      if (tenants.isNotEmpty && mounted) {
        setState(() => _selectedTenantSlug = tenants.first.slug);
      }
    } catch (_) {}
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty || _selectedTenantSlug == null) return;

    _messageController.clear();
    setState(() {
      _messages.add(_ChatMessage(text: text, isUser: true));
      _isTyping = true;
    });

    _scrollToBottom();

    try {
      final api = context.read<ApiService>();
      final response = await api.chat(_selectedTenantSlug!, text);

      if (mounted) {
        setState(() {
          _messages.add(_ChatMessage(
            text: response['answer'] ?? 'No response received.',
            isUser: false,
            sources: response['sources'],
          ));
          _isTyping = false;
        });
        _scrollToBottom();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _messages.add(_ChatMessage(
            text: 'Error: ${e.toString()}',
            isUser: false,
            isError: true,
          ));
          _isTyping = false;
        });
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? AppTheme.textPrimary : AppTheme.lightTextPrimary;
    final subtextColor = isDark ? AppTheme.textSecondary : AppTheme.lightTextSecondary;
    final bgColor = isDark ? AppTheme.background : AppTheme.lightBackground;
    final surfaceBg = isDark ? AppTheme.surface : AppTheme.lightSurface;
    final borderColor = isDark ? AppTheme.border : AppTheme.lightBorder;

    return Column(
      children: [
        // Header
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          decoration: BoxDecoration(
            color: surfaceBg,
            border: Border(bottom: BorderSide(color: borderColor)),
          ),
          child: Row(
            children: [
              if (widget.onBack != null)
                IconButton(
                  icon: const Icon(Icons.arrow_back_ios, size: 18),
                  onPressed: widget.onBack,
                  color: textColor,
                ),
              Icon(Icons.chat_bubble_outline, color: AppTheme.primary, size: 20),
              const SizedBox(width: 8),
              Text('Chat', style: TextStyle(
                fontSize: 18, fontWeight: FontWeight.w600, color: textColor,
              )),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: _selectedTenantSlug != null
                      ? AppTheme.success.withOpacity(0.15)
                      : AppTheme.warning.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  _selectedTenantSlug ?? 'No tenant',
                  style: TextStyle(
                    fontSize: 11, color: _selectedTenantSlug != null
                        ? AppTheme.success : AppTheme.warning,
                  ),
                ),
              ),
            ],
          ),
        ),

        // Messages
        Expanded(
          child: _messages.isEmpty
              ? _buildEmptyState(textColor, subtextColor)
              : ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(16),
                  itemCount: _messages.length + (_isTyping ? 1 : 0),
                  itemBuilder: (context, index) {
                    if (index == _messages.length) {
                      return _buildTypingIndicator(subtextColor);
                    }
                    return _buildMessageBubble(_messages[index], textColor, subtextColor, surfaceBg, borderColor);
                  },
                ),
        ),

        // Input
        _buildInput(surfaceBg, borderColor, textColor),
      ],
    );
  }

  Widget _buildEmptyState(Color textColor, Color subtextColor) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.chat_bubble_outline, size: 64, color: subtextColor.withOpacity(0.3)),
          const SizedBox(height: 16),
          Text('Start a conversation', style: TextStyle(
            fontSize: 18, fontWeight: FontWeight.w600, color: textColor,
          )),
          const SizedBox(height: 8),
          Text('Ask questions about your documents', style: TextStyle(
            fontSize: 13, color: subtextColor,
          )),
        ],
      ),
    );
  }

  Widget _buildTypingIndicator(Color subtextColor) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: subtextColor.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 16, height: 16,
              child: CircularProgressIndicator(strokeWidth: 2, color: subtextColor),
            ),
            const SizedBox(width: 8),
            Text('Thinking...', style: TextStyle(color: subtextColor, fontSize: 13)),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageBubble(_ChatMessage msg, Color textColor, Color subtextColor, Color surfaceBg, Color borderColor) {
    final isUser = msg.isUser;
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
        child: Column(
          crossAxisAlignment: isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isUser
                    ? AppTheme.primary.withOpacity(0.15)
                    : msg.isError
                        ? AppTheme.error.withOpacity(0.1)
                        : surfaceBg,
                borderRadius: BorderRadius.circular(12),
                border: isUser
                    ? null
                    : Border.all(color: msg.isError ? AppTheme.error.withOpacity(0.3) : borderColor),
              ),
              child: Text(msg.text, style: TextStyle(
                color: msg.isError ? AppTheme.error : textColor,
                fontSize: 14, height: 1.5,
              )),
            ),
            if (msg.sources != null && msg.sources is List && (msg.sources as List).isNotEmpty)
              Container(
                margin: const EdgeInsets.only(top: 6),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: surfaceBg,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: borderColor),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Sources', style: TextStyle(fontSize: 10, color: subtextColor, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 4),
                    ...((msg.sources as List).take(3).map((s) => Text(
                      '${s['source'] ?? 'Unknown'} (${((s['score'] ?? 0) * 100).round()}%)',
                      style: TextStyle(fontSize: 10, color: subtextColor),
                    ))),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildInput(Color surfaceBg, Color borderColor, Color textColor) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: surfaceBg,
        border: Border(top: BorderSide(color: borderColor)),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _messageController,
              style: TextStyle(color: textColor, fontSize: 14),
              maxLines: null,
              keyboardType: TextInputType.multiline,
              decoration: InputDecoration(
                hintText: 'Ask a question...',
                hintStyle: TextStyle(color: textColor.withOpacity(0.4)),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
              onSubmitted: (_) => _sendMessage(),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            decoration: BoxDecoration(
              color: AppTheme.primary,
              borderRadius: BorderRadius.circular(8),
            ),
            child: IconButton(
              icon: const Icon(Icons.send, size: 18),
              color: AppTheme.onPrimary,
              onPressed: _isTyping ? null : _sendMessage,
            ),
          ),
        ],
      ),
    );
  }
}

class _ChatMessage {
  final String text;
  final bool isUser;
  final bool isError;
  final dynamic sources;

  _ChatMessage({
    required this.text,
    required this.isUser,
    this.isError = false,
    this.sources,
  });
}
