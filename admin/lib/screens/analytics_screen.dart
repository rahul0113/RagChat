import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/api_service.dart';
import '../widgets/stat_card.dart';
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
    try {
      final api = context.read<ApiService>();
      final summary = await api.getAnalyticsSummary();
      final queries = await api.getTopQueries(limit: 20);
      if (mounted) {
        setState(() {
          _summary = summary;
          _topQueries = queries;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
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
              IconButton(onPressed: _loadData, icon: const Icon(Icons.refresh_rounded, color: AppTheme.textSecondary)),
            ],
          ),
          const SizedBox(height: 24),

          if (_loading)
            const Center(child: CircularProgressIndicator(color: AppTheme.primary))
          else ...[
            // Stats — using same StatCard widget as Dashboard for consistency
            Row(
              children: [
                Expanded(
                  child: StatCard(
                    title: 'Total Queries',
                    value: '${_summary['total_queries'] ?? 0}',
                    icon: Icons.chat_bubble_rounded,
                    accentColor: AppTheme.primary,
                    subtitle: '+${_summary['today'] ?? 0} today',
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: StatCard(
                    title: 'This Week',
                    value: '${_summary['this_week'] ?? 0}',
                    icon: Icons.trending_up_rounded,
                    accentColor: AppTheme.info,
                    subtitle: 'Active growth',
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: StatCard(
                    title: 'Tenants',
                    value: '${_summary['total_tenants'] ?? 0}',
                    icon: Icons.apartment_rounded,
                    accentColor: AppTheme.success,
                    subtitle: '${_summary['total_documents'] ?? 0} docs',
                  ),
                ),
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
                    ? const Text('No query data yet. Start chatting to see trends.', style: TextStyle(color: AppTheme.textSecondary))
                    : const Text('Query Trend Chart (fl_chart integration)', style: TextStyle(color: AppTheme.textSecondary)),
              ),
            ),
            const SizedBox(height: 24),

            // Top Queries header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Top Queries (${_topQueries.length})', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
                if (_topQueries.length > 5)
                  TextButton(
                    onPressed: () => setState(() => _showAll = !_showAll),
                    child: Text(_showAll ? 'Show Less' : 'View All', style: const TextStyle(color: AppTheme.primary, fontSize: 13)),
                  ),
              ],
            ),
            const SizedBox(height: 12),

            // Query list
            Expanded(
              child: _topQueries.isEmpty
                  ? Container(
                      decoration: BoxDecoration(color: AppTheme.card, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppTheme.border)),
                      child: const Center(child: Text('No queries recorded yet.', style: TextStyle(color: AppTheme.textSecondary))),
                    )
                  : Container(
                      decoration: BoxDecoration(color: AppTheme.card, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppTheme.border)),
                      child: ListView.separated(
                        padding: const EdgeInsets.all(12),
                        itemCount: visible.length,
                        separatorBuilder: (_, __) => const Divider(color: AppTheme.border, height: 1),
                        itemBuilder: (ctx, i) {
                          final q = visible[i];
                          return ListTile(
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => QueryDetailScreen(rank: i + 1, question: q['question'] ?? '', uses: '${q['uses'] ?? 0} uses')),
                            ),
                            leading: Container(
                              width: 32, height: 32,
                              decoration: BoxDecoration(color: AppTheme.primary.withOpacity(0.15), borderRadius: BorderRadius.circular(8)),
                              child: Center(child: Text('${i + 1}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppTheme.primary))),
                            ),
                            title: Text(q['question'] ?? '', style: const TextStyle(fontSize: 14, color: AppTheme.textPrimary)),
                            subtitle: (q['last_asked'] ?? '').toString().isNotEmpty
                                ? Text('Last: ${q['last_asked']}', style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary))
                                : null,
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text('${q['uses'] ?? 0} uses', style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
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
}
