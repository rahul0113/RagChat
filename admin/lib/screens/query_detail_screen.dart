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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? AppTheme.textPrimary : AppTheme.lightTextPrimary;
    final subtextColor = isDark ? AppTheme.textSecondary : AppTheme.lightTextSecondary;
    final bgColor = isDark ? AppTheme.card : AppTheme.lightCard;
    final surfaceBg = isDark ? AppTheme.surface : AppTheme.lightSurface;
    final surfaceHigh = isDark ? AppTheme.surfaceContainerHigh : AppTheme.lightSurfaceContainerHigh;
    final borderColor = isDark ? AppTheme.border : AppTheme.lightBorder;
    final scaffoldBg = isDark ? AppTheme.background : AppTheme.lightBackground;

    return Scaffold(
      backgroundColor: scaffoldBg,
      appBar: AppBar(
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: Icon(Icons.arrow_back_rounded, color: textColor),
        ),
        title: Text('Query Details', style: TextStyle(color: textColor, fontWeight: FontWeight.w600)),
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
                color: bgColor,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: borderColor),
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
                  Text(widget.question, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: textColor, height: 1.3)),
                  const SizedBox(height: 12),
                  _infoRow(Icons.access_time_rounded, '${_recentConversations.length} conversations', subtextColor),
                  const SizedBox(height: 6),
                  _infoRow(Icons.chat_bubble_rounded, 'Asked across tenants', subtextColor),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Usage Trend
            Container(
              height: 180,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: borderColor),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Usage Trend (7 Days)', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: textColor)),
                  const SizedBox(height: 16),
                  Expanded(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        _bar(0.6, 'Mon', subtextColor), _bar(0.8, 'Tue', subtextColor), _bar(0.5, 'Wed', subtextColor),
                        _bar(1.0, 'Thu', subtextColor), _bar(0.7, 'Fri', subtextColor), _bar(0.4, 'Sat', subtextColor), _bar(0.3, 'Sun', subtextColor),
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
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: textColor)),
                TextButton(
                  onPressed: () => _showAllConversations(context),
                  child: Text('View All', style: TextStyle(color: AppTheme.primary, fontSize: 13)),
                ),
              ],
            ),
            const SizedBox(height: 12),

            if (_loading)
              Center(child: CircularProgressIndicator(color: AppTheme.primary))
            else if (_recentConversations.isEmpty)
              Container(
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: bgColor,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: borderColor),
                ),
                child: Center(child: Text('No conversations found', style: TextStyle(color: subtextColor))),
              )
            else
              ..._recentConversations.take(3).map((q) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _conversationCard(
                  _tenantInitials(q['tenant_id'] ?? ''),
                  q['question'] ?? '',
                  q['answer'] ?? 'No answer recorded',
                  _timeAgo(q['created_at'] ?? ''),
                  textColor, subtextColor, bgColor, borderColor, surfaceHigh,
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

  Widget _infoRow(IconData icon, String text, Color subtextColor) {
    return Row(
      children: [
        Icon(icon, size: 14, color: subtextColor),
        const SizedBox(width: 8),
        Text(text, style: TextStyle(fontSize: 13, color: subtextColor)),
      ],
    );
  }

  Widget _bar(double height, String label, Color subtextColor) {
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
          Text(label, style: TextStyle(fontSize: 10, color: subtextColor)),
        ],
      ),
    );
  }

  Widget _conversationCard(String initials, String userQ, String botA, String time, Color textColor, Color subtextColor, Color bgColor, Color borderColor, Color surfaceHigh) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
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
                    Text(userQ, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: textColor)),
                    Text(time, style: TextStyle(fontSize: 11, color: subtextColor)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: surfaceHigh,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(botA, style: TextStyle(fontSize: 12, color: subtextColor), maxLines: 2, overflow: TextOverflow.ellipsis),
          ),
        ],
      ),
    );
  }

  void _showAllConversations(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? AppTheme.textPrimary : AppTheme.lightTextPrimary;
    final subtextColor = isDark ? AppTheme.textSecondary : AppTheme.lightTextSecondary;
    final bgColor = isDark ? AppTheme.card : AppTheme.lightCard;
    final surfaceHigh = isDark ? AppTheme.surfaceContainerHigh : AppTheme.lightSurfaceContainerHigh;
    final borderColor = isDark ? AppTheme.border : AppTheme.lightBorder;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? AppTheme.surface : AppTheme.lightSurface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        expand: false,
        builder: (ctx, scrollController) => Column(
          children: [
            Container(margin: const EdgeInsets.only(top: 12), width: 40, height: 4,
                decoration: BoxDecoration(color: borderColor, borderRadius: BorderRadius.circular(2))),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text('All Conversations', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: textColor)),
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
                      textColor, subtextColor, bgColor, borderColor, surfaceHigh,
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
        builder: (ctx) {
          final isDark = Theme.of(ctx).brightness == Brightness.dark;
          final textColor = isDark ? AppTheme.textPrimary : AppTheme.lightTextPrimary;
          final subtextColor = isDark ? AppTheme.textSecondary : AppTheme.lightTextSecondary;
          final bgColor = isDark ? AppTheme.card : AppTheme.lightCard;

          return Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Export Data', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: textColor)),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(8)),
                  child: SelectableText(csv, style: TextStyle(fontSize: 11, fontFamily: 'monospace', color: subtextColor)),
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
          );
        },
      );
    }
  }

  void _confirmDelete(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        final textColor = isDark ? AppTheme.textPrimary : AppTheme.lightTextPrimary;
        final subtextColor = isDark ? AppTheme.textSecondary : AppTheme.lightTextSecondary;
        final surfaceBg = isDark ? AppTheme.surface : AppTheme.lightSurface;

        return AlertDialog(
          backgroundColor: surfaceBg,
          title: Text('Delete Query', style: TextStyle(color: textColor)),
          content: Text(
            'Are you sure you want to delete "${widget.question}"? This action cannot be undone.',
            style: TextStyle(color: subtextColor, fontSize: 14),
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
        );
      },
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
