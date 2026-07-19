import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import 'query_detail_screen.dart';

class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  List<Map<String, dynamic>> _topQueries = [];
  Map<String, dynamic> _summary = {};
  bool _loading = true;
  bool _showAll = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final api = context.read<ApiService>();
    final summary = await api.getAnalyticsSummary();
    final queries = await api.getTopQueries(limit: 20);
    setState(() {
      _summary = summary;
      _topQueries = queries;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final visible = _showAll ? _topQueries : _topQueries.take(5).toList();

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Analytics', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
              IconButton(
                onPressed: _loadData,
                icon: const Icon(Icons.refresh_rounded, color: AppTheme.textSecondary),
              ),
            ],
          ),
          const SizedBox(height: 24),

          if (_loading)
            const Center(child: CircularProgressIndicator(color: AppTheme.primary))
          else ...[
            // Stats from API
            Row(
              children: [
                _statCard('${_summary['total_queries'] ?? 0}', 'Total Queries', '+${_summary['today'] ?? 0} today', AppTheme.primary),
                const SizedBox(width: 12),
                _statCard('${_summary['this_week'] ?? 0}', 'This Week', 'Active growth', AppTheme.info),
                const SizedBox(width: 12),
                _statCard('${_summary['total_tenants'] ?? 0}', 'Tenants', '${_summary['total_documents'] ?? 0} docs', AppTheme.success),
              ],
            ),
            const SizedBox(height: 24),

            // Chart placeholder
            Container(
              height: 180,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppTheme.card,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.border),
              ),
              child: Center(
                child: _topQueries.isEmpty
                    ? const Text('No query data yet. Start chatting to see trends.',
                        style: TextStyle(color: AppTheme.textSecondary))
                    : const Text('Query Trend Chart (fl_chart integration)',
                        style: TextStyle(color: AppTheme.textSecondary)),
              ),
            ),
            const SizedBox(height: 24),

            // Top Queries header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Top Queries (${_topQueries.length})',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
                if (_topQueries.length > 5)
                  TextButton(
                    onPressed: () => setState(() => _showAll = !_showAll),
                    child: Text(_showAll ? 'Show Less' : 'View All',
                        style: const TextStyle(color: AppTheme.primary, fontSize: 13)),
                  ),
              ],
            ),
            const SizedBox(height: 12),

            // Query list from API
            Expanded(
              child: _topQueries.isEmpty
                  ? Container(
                      decoration: BoxDecoration(
                        color: AppTheme.card,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppTheme.border),
                      ),
                      child: const Center(
                        child: Text('No queries recorded yet.', style: TextStyle(color: AppTheme.textSecondary)),
                      ),
                    )
                  : Container(
                      decoration: BoxDecoration(
                        color: AppTheme.card,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppTheme.border),
                      ),
                      child: ListView.separated(
                        padding: const EdgeInsets.all(12),
                        itemCount: visible.length,
                        separatorBuilder: (_, __) => const Divider(color: AppTheme.border, height: 1),
                        itemBuilder: (ctx, i) {
                          final q = visible[i];
                          final question = q['question'] ?? '';
                          final uses = q['uses'] ?? 0;
                          final lastAsked = q['last_asked'] ?? '';
                          return ListTile(
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => QueryDetailScreen(
                                  rank: i + 1,
                                  question: question,
                                  uses: '$uses uses',
                                ),
                              ),
                            ),
                            leading: Container(
                              width: 32, height: 32,
                              decoration: BoxDecoration(
                                color: AppTheme.primary.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Center(
                                child: Text('${i + 1}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppTheme.primary)),
                              ),
                            ),
                            title: Text(question, style: const TextStyle(fontSize: 14, color: AppTheme.textPrimary)),
                            subtitle: lastAsked.isNotEmpty ? Text('Last: $lastAsked', style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary)) : null,
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text('$uses uses', style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                                const SizedBox(width: 4),
                                const Icon(Icons.chevron_right_rounded, size: 18, color: AppTheme.textSecondary),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _statCard(String value, String label, String subtitle, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(value, style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: color)),
            const SizedBox(height: 4),
            Text(label, style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
            Text(subtitle, style: TextStyle(fontSize: 11, color: color.withOpacity(0.7))),
          ],
        ),
      ),
    );
  }
}
