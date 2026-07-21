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
  final List<Map<String, dynamic>> _chatHistory = [];
  bool _isTyping = false;
  String? _selectedTenantSlug;
  String? _selectedTenantId;
  String? _tenantName;
  int _documentCount = 0;
  List<Map<String, dynamic>> _tenants = [];

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
        setState(() {
          _tenants = tenants.map((t) => {'id': t.id, 'slug': t.slug, 'name': t.name}).toList();
          _selectedTenantSlug = tenants.first.slug;
          _selectedTenantId = tenants.first.id;
          _tenantName = tenants.first.name;
        });
        _loadTenantDocs();
      }
    } catch (_) {}
  }

  Future<void> _loadTenantDocs() async {
    if (_selectedTenantId == null) return;
    final api = context.read<ApiService>();
    try {
      final docs = await api.getDocuments(_selectedTenantId!);
      if (mounted) {
        setState(() => _documentCount = docs['total_vectors'] ?? 0);
      }
    } catch (_) {}
  }

  void _selectTenant(Map<String, dynamic> tenant) {
    setState(() {
      _selectedTenantSlug = tenant['slug'];
      _selectedTenantId = tenant['id'];
      _tenantName = tenant['name'];
      _messages.clear();
      _chatHistory.clear();
    });
    _loadTenantDocs();
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
      final response = await api.chat(
        _selectedTenantSlug!,
        text,
        chatHistory: _chatHistory,
      );

      if (mounted) {
        final answer = response['answer'] ?? 'No response received.';
        final sources = response['sources'] ?? [];
        final timings = response['timings'];
        final qualitySignals = response['quality_signals'];

        setState(() {
          _messages.add(_ChatMessage(
            text: answer,
            isUser: false,
            sources: sources,
            timings: timings,
            qualitySignals: qualitySignals,
          ));
          _isTyping = false;
        });

        // Add to chat history for context
        _chatHistory.add({'role': 'user', 'content': text});
        _chatHistory.add({'role': 'assistant', 'content': answer});

        // Keep history manageable (last 20 exchanges)
        if (_chatHistory.length > 40) {
          _chatHistory.removeRange(0, _chatHistory.length - 40);
        }

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

  void _clearChat() {
    setState(() {
      _messages.clear();
      _chatHistory.clear();
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
              Text('RAG Chat', style: TextStyle(
                fontSize: 18, fontWeight: FontWeight.w600, color: textColor,
              )),
              const Spacer(),
              // Tenant selector dropdown
              _buildTenantDropdown(surfaceBg, textColor, borderColor),
              const SizedBox(width: 8),
              // Clear chat button
              if (_messages.isNotEmpty)
                IconButton(
                  icon: Icon(Icons.delete_outline, size: 18, color: subtextColor),
                  onPressed: _clearChat,
                  tooltip: 'Clear chat',
                ),
            ],
          ),
        ),

        // Tenant info bar
        if (_selectedTenantSlug != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            decoration: BoxDecoration(
              color: AppTheme.primary.withOpacity(0.05),
              border: Border(bottom: BorderSide(color: borderColor)),
            ),
            child: Row(
              children: [
                Icon(Icons.business_rounded, size: 14, color: AppTheme.primary),
                const SizedBox(width: 6),
                Text(_tenantName ?? _selectedTenantSlug!, style: TextStyle(
                  fontSize: 12, color: AppTheme.primary, fontWeight: FontWeight.w500,
                )),
                const SizedBox(width: 12),
                Icon(Icons.description_outlined, size: 14, color: subtextColor),
                const SizedBox(width: 4),
                Text('$_documentCount vectors indexed', style: TextStyle(
                  fontSize: 12, color: subtextColor,
                )),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppTheme.success.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text('Online', style: TextStyle(
                    fontSize: 10, color: AppTheme.success, fontWeight: FontWeight.w600,
                  )),
                ),
              ],
            ),
          ),

        // Messages
        Expanded(
          child: _messages.isEmpty
              ? _buildEmptyState(textColor, subtextColor, surfaceBg, borderColor)
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

  Widget _buildTenantDropdown(Color surfaceBg, Color textColor, Color borderColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: surfaceBg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: borderColor),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _selectedTenantSlug,
          isDense: true,
          dropdownColor: surfaceBg,
          icon: Icon(Icons.expand_more, size: 16, color: textColor),
          style: TextStyle(color: textColor, fontSize: 12),
          items: _tenants.map((t) {
            return DropdownMenuItem<String>(
              value: t['slug'] as String?,
              child: Text(t['name'] as String? ?? '', style: TextStyle(fontSize: 12)),
            );
          }).toList(),
          onChanged: (slug) {
            if (slug != null) {
              final tenant = _tenants.firstWhere((t) => t['slug'] == slug);
              _selectTenant(tenant);
            }
          },
        ),
      ),
    );
  }

  Widget _buildEmptyState(Color textColor, Color subtextColor, Color surfaceBg, Color borderColor) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80, height: 80,
              decoration: BoxDecoration(
                color: AppTheme.primary.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.auto_awesome, size: 36, color: AppTheme.primary),
            ),
            const SizedBox(height: 20),
            Text('RAG-Powered Assistant', style: TextStyle(
              fontSize: 22, fontWeight: FontWeight.w700, color: textColor,
            )),
            const SizedBox(height: 8),
            Text(
              'Ask questions about your documents.\nThe AI will search through your knowledge base\nand provide answers with citations.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: subtextColor, height: 1.5),
            ),
            const SizedBox(height: 24),
            if (_selectedTenantSlug != null && _documentCount > 0)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: surfaceBg,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: borderColor),
                ),
                child: Column(
                  children: [
                    Text('Try asking:', style: TextStyle(fontSize: 12, color: subtextColor, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 12),
                    _suggestionChip('What is this document about?'),
                    _suggestionChip('Summarize the key points'),
                    _suggestionChip('What are the main topics covered?'),
                  ],
                ),
              )
            else if (_selectedTenantSlug != null && _documentCount == 0)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.warning.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.warning.withOpacity(0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.info_outline, size: 16, color: AppTheme.warning),
                    const SizedBox(width: 8),
                    Text('Upload documents to start chatting', style: TextStyle(
                      fontSize: 13, color: AppTheme.warning,
                    )),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _suggestionChip(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: () {
          _messageController.text = text;
          _sendMessage();
        },
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: AppTheme.primary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(text, style: TextStyle(fontSize: 13, color: AppTheme.primary)),
        ),
      ),
    );
  }

  Widget _buildTypingIndicator(Color subtextColor) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: subtextColor.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 16, height: 16,
              child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.primary),
            ),
            const SizedBox(width: 10),
            Text('Searching knowledge base...', style: TextStyle(color: subtextColor, fontSize: 13)),
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
        margin: const EdgeInsets.only(bottom: 16),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.85),
        child: Column(
          crossAxisAlignment: isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            // Message bubble
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: isUser
                    ? AppTheme.primary
                    : msg.isError
                        ? AppTheme.error.withOpacity(0.1)
                        : surfaceBg,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(12),
                  topRight: const Radius.circular(12),
                  bottomLeft: Radius.circular(isUser ? 12 : 4),
                  bottomRight: Radius.circular(isUser ? 4 : 12),
                ),
                border: isUser ? null : Border.all(color: msg.isError ? AppTheme.error.withOpacity(0.3) : borderColor),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(msg.text, style: TextStyle(
                    color: isUser ? Colors.white : (msg.isError ? AppTheme.error : textColor),
                    fontSize: 14, height: 1.6,
                  )),
                  // Show timing info for AI responses
                  if (!isUser && !msg.isError && msg.timings != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.speed, size: 12, color: subtextColor.withOpacity(0.5)),
                          const SizedBox(width: 4),
                          Text(
                            '${msg.timings!['total_ms'] ?? 0}ms',
                            style: TextStyle(fontSize: 10, color: subtextColor.withOpacity(0.5)),
                          ),
                          if (msg.qualitySignals?['search_mode'] != null) ...[
                            const SizedBox(width: 8),
                            Icon(Icons.search, size: 12, color: subtextColor.withOpacity(0.5)),
                            const SizedBox(width: 4),
                            Text(
                              msg.qualitySignals!['search_mode'],
                              style: TextStyle(fontSize: 10, color: subtextColor.withOpacity(0.5)),
                            ),
                          ],
                        ],
                      ),
                    ),
                ],
              ),
            ),

            // Sources section
            if (!isUser && !msg.isError && msg.sources != null && (msg.sources as List).isNotEmpty)
              _buildSourcesSection(msg.sources as List, surfaceBg, borderColor, subtextColor),
          ],
        ),
      ),
    );
  }

  Widget _buildSourcesSection(List sources, Color surfaceBg, Color borderColor, Color subtextColor) {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: surfaceBg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.library_books, size: 14, color: AppTheme.primary),
              const SizedBox(width: 6),
              Text('Sources (${sources.length})', style: TextStyle(
                fontSize: 11, color: AppTheme.primary, fontWeight: FontWeight.w600,
              )),
            ],
          ),
          const SizedBox(height: 8),
          ...sources.take(5).map((s) => _buildSourceItem(s, borderColor, subtextColor)),
          if (sources.length > 5)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text('+ ${sources.length - 5} more sources', style: TextStyle(
                fontSize: 10, color: subtextColor.withOpacity(0.6),
              )),
            ),
        ],
      ),
    );
  }

  Widget _buildSourceItem(dynamic source, Color borderColor, Color subtextColor) {
    final docName = source['document'] ?? source['source'] ?? 'Unknown';
    final score = source['score'] ?? 0;
    final excerpt = source['excerpt'] ?? '';
    final page = source['page'] ?? source['page_number'];
    final section = source['section_heading'];

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: borderColor.withOpacity(0.2),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(docName, style: TextStyle(
                  fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.primary,
                )),
              ),
              if (score > 0)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: _scoreColor(score).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text('${(score * 100).round()}%', style: TextStyle(
                    fontSize: 9, fontWeight: FontWeight.w600, color: _scoreColor(score),
                  )),
                ),
            ],
          ),
          if (page != null || section != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                [
                  if (page != null) 'Page $page',
                  if (section != null) section,
                ].join(' • '),
                style: TextStyle(fontSize: 10, color: subtextColor),
              ),
            ),
          if (excerpt.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                excerpt.length > 150 ? '${excerpt.substring(0, 150)}...' : excerpt,
                style: TextStyle(fontSize: 11, color: subtextColor, height: 1.4),
              ),
            ),
        ],
      ),
    );
  }

  Color _scoreColor(double score) {
    if (score >= 0.8) return AppTheme.success;
    if (score >= 0.5) return AppTheme.warning;
    return AppTheme.error;
  }

  Widget _buildInput(Color surfaceBg, Color borderColor, Color textColor) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 14),
      decoration: BoxDecoration(
        color: surfaceBg,
        border: Border(top: BorderSide(color: borderColor)),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: Container(
                constraints: const BoxConstraints(maxHeight: 120),
                decoration: BoxDecoration(
                  color: borderColor.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: TextField(
                  controller: _messageController,
                  style: TextStyle(color: textColor, fontSize: 14),
                  maxLines: null,
                  keyboardType: TextInputType.multiline,
                  textInputAction: TextInputAction.newline,
                  decoration: InputDecoration(
                    hintText: _selectedTenantSlug != null
                        ? 'Ask about your documents...'
                        : 'Select a tenant first...',
                    hintStyle: TextStyle(color: textColor.withOpacity(0.4)),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: _isTyping ? null : _sendMessage,
                customBorder: const CircleBorder(),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: _canSend ? AppTheme.primary : borderColor,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    _isTyping ? Icons.hourglass_top_rounded : Icons.send_rounded,
                    size: 18,
                    color: _canSend ? Colors.white : textColor.withOpacity(0.3),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  bool get _canSend => !_isTyping && _messageController.text.trim().isNotEmpty;
}

class _ChatMessage {
  final String text;
  final bool isUser;
  final bool isError;
  final dynamic sources;
  final dynamic timings;
  final dynamic qualitySignals;

  _ChatMessage({
    required this.text,
    required this.isUser,
    this.isError = false,
    this.sources,
    this.timings,
    this.qualitySignals,
  });
}
