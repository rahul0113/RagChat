import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';

class QueryDetailScreen extends StatefulWidget {
  final int rank;
  final String question;
  final String uses;

  const QueryDetailScreen({
    super.key,
    required this.rank,
    required this.question,
    required this.uses,
  });

  @override
  State<QueryDetailScreen> createState() => _QueryDetailScreenState();
}

class _QueryDetailScreenState extends State<QueryDetailScreen> {
  List<Map<String, dynamic>> _recentConversations = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadConversations();
  }

  Future<void> _loadConversations() async {
    final api = context.read<ApiService>();
    final all = await api.getRecentQueries(limit: 50);
    // Filter to matching question
    final matching = all.where((q) => q['question'] == widget.question).toList();
    setState(() {
      _recentConversations = matching;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back_rounded, color: AppTheme.textPrimary),
        ),
        title: const Text('Query Details', style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w600)),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: ListView(
          children: [
            // Query Info Card
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppTheme.card,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 32, height: 32,
                        decoration: BoxDecoration(
                          color: AppTheme.primary.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Center(
                          child: Text('#${widget.rank}', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppTheme.primary)),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppTheme.success.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(widget.uses, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.success)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(widget.question, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: AppTheme.textPrimary, height: 1.3)),
                  const SizedBox(height: 12),
                  _infoRow(Icons.access_time_rounded, '${_recentConversations.length} conversations'),
                  const SizedBox(height: 6),
                  _infoRow(Icons.chat_bubble_rounded, 'Asked across tenants'),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Usage Trend
            Container(
              height: 180,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppTheme.card,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Usage Trend (7 Days)', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
                  const SizedBox(height: 16),
                  Expanded(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        _bar(0.6, 'Mon'), _bar(0.8, 'Tue'), _bar(0.5, 'Wed'),
                        _bar(1.0, 'Thu'), _bar(0.7, 'Fri'), _bar(0.4, 'Sat'), _bar(0.3, 'Sun'),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Recent Conversations header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Recent Conversations (${_recentConversations.length})',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
                TextButton(
                  onPressed: () => _showAllConversations(context),
                  child: const Text('View All', style: TextStyle(color: AppTheme.primary, fontSize: 13)),
                ),
              ],
            ),
            const SizedBox(height: 12),

            if (_loading)
              const Center(child: CircularProgressIndicator(color: AppTheme.primary))
            else if (_recentConversations.isEmpty)
              Container(
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: AppTheme.card,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.border),
                ),
                child: const Center(child: Text('No conversations found', style: TextStyle(color: AppTheme.textSecondary))),
              )
            else
              ..._recentConversations.take(3).map((q) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _conversationCard(
                  _tenantInitials(q['tenant_id'] ?? ''),
                  q['question'] ?? '',
                  q['answer'] ?? 'No answer recorded',
                  _timeAgo(q['created_at'] ?? ''),
                ),
              )),

            const SizedBox(height: 20),

            // Action buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _exportData(context),
                    icon: const Icon(Icons.download_rounded, size: 16),
                    label: const Text('Export Data'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.info,
                      side: const BorderSide(color: AppTheme.info),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _confirmDelete(context),
                    icon: const Icon(Icons.delete_outline_rounded, size: 16),
                    label: const Text('Delete Query'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.error,
                      side: const BorderSide(color: AppTheme.error),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 14, color: AppTheme.textSecondary),
        const SizedBox(width: 8),
        Text(text, style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
      ],
    );
  }

  Widget _bar(double height, String label) {
    return Expanded(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Container(
            height: height * 80,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topCenter, end: Alignment.bottomCenter,
                colors: [AppTheme.primary, Color(0xFF8B5CF6)],
              ),
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(height: 6),
          Text(label, style: const TextStyle(fontSize: 10, color: AppTheme.textSecondary)),
        ],
      ),
    );
  }

  Widget _conversationCard(String initials, String userQ, String botA, String time) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32, height: 32,
                decoration: BoxDecoration(
                  color: AppTheme.primary.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(child: Text(initials, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppTheme.primary))),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(userQ, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: AppTheme.textPrimary)),
                    Text(time, style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppTheme.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(botA, style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary), maxLines: 2, overflow: TextOverflow.ellipsis),
          ),
        ],
      ),
    );
  }

  void _showAllConversations(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        expand: false,
        builder: (ctx, scrollController) => Column(
          children: [
            Container(margin: const EdgeInsets.only(top: 12), width: 40, height: 4,
                decoration: BoxDecoration(color: AppTheme.border, borderRadius: BorderRadius.circular(2))),
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('All Conversations', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
            ),
            Expanded(
              child: ListView.builder(
                controller: scrollController,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: _recentConversations.length,
                itemBuilder: (ctx, i) {
                  final q = _recentConversations[i];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _conversationCard(
                      _tenantInitials(q['tenant_id'] ?? ''),
                      q['question'] ?? '',
                      q['answer'] ?? 'No answer',
                      _timeAgo(q['created_at'] ?? ''),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _exportData(BuildContext context) async {
    final api = context.read<ApiService>();
    final csv = await api.exportData();
    if (csv.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No data to export'), backgroundColor: AppTheme.warning),
        );
      }
      return;
    }
    if (mounted) {
      showModalBottomSheet(
        context: context,
        backgroundColor: AppTheme.surface,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
        builder: (ctx) => Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Export Data', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: AppTheme.card, borderRadius: BorderRadius.circular(8)),
                child: SelectableText(csv, style: const TextStyle(fontSize: 11, fontFamily: 'monospace', color: AppTheme.textSecondary)),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: csv));
                        Navigator.pop(ctx);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Copied to clipboard'), backgroundColor: AppTheme.success),
                        );
                      },
                      icon: const Icon(Icons.copy_rounded, size: 16),
                      label: const Text('Copy CSV'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    }
  }

  void _confirmDelete(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title: const Text('Delete Query', style: TextStyle(color: AppTheme.textPrimary)),
        content: Text(
          'Are you sure you want to delete "${widget.question}"? This action cannot be undone.',
          style: const TextStyle(color: AppTheme.textSecondary, fontSize: 14),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final api = context.read<ApiService>();
              final queries = await api.getRecentQueries(limit: 1000);
              final match = queries.firstWhere((q) => q['question'] == widget.question, orElse: () => {});
              if (match.isNotEmpty && match['id'] != null) {
                await api.deleteQuery(match['id']);
              }
              if (mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('"${widget.question}" deleted'),
                    backgroundColor: AppTheme.error,
                    action: SnackBarAction(label: 'Undo', textColor: Colors.white, onPressed: () {}),
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  String _timeAgo(String isoDate) {
    if (isoDate.isEmpty) return '';
    try {
      final dt = DateTime.parse(isoDate);
      final diff = DateTime.now().difference(dt);
      if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
      if (diff.inHours < 24) return '${diff.inHours}h ago';
      return '${diff.inDays}d ago';
    } catch (_) {
      return '';
    }
  }

  String _tenantInitials(String tenantId) {
    if (tenantId.isEmpty) return '?';
    return tenantId.substring(0, 2).toUpperCase();
  }
}
