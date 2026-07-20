import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/api_service.dart';
import '../services/error_handler.dart';
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
      if (mounted) {
        setState(() => _loading = false);
        ErrorHandler.showNetworkError(context, details: e.toString(), onRetry: _loadData);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final visible = _showAll ? _topQueries : _topQueries.take(5).toList();
    final isNarrow = MediaQuery.of(context).size.width < 600;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? AppTheme.textPrimary : AppTheme.lightTextPrimary;
    final subtextColor = isDark ? AppTheme.textSecondary : AppTheme.lightTextSecondary;
    final bgColor = isDark ? AppTheme.card : AppTheme.lightCard;
    final borderColor = isDark ? AppTheme.border : AppTheme.lightBorder;

    return Padding(
      padding: EdgeInsets.all(isNarrow ? 16 : 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Analytics', style: TextStyle(fontSize: isNarrow ? 22 : 28, fontWeight: FontWeight.w700, color: textColor)),
              IconButton(onPressed: _loadData, icon: Icon(Icons.refresh_rounded, color: subtextColor)),
            ],
          ),
          const SizedBox(height: 20),

          if (_loading)
            Center(child: CircularProgressIndicator(color: AppTheme.primary))
          else ...[
            // Stats — stack on mobile
            if (isNarrow) ...[
              StatCard(title: 'Total Queries', value: '${_summary['total_queries'] ?? 0}', icon: Icons.chat_bubble_rounded, accentColor: AppTheme.primary, subtitle: '+${_summary['today'] ?? 0} today'),
              const SizedBox(height: 12),
              StatCard(title: 'This Week', value: '${_summary['this_week'] ?? 0}', icon: Icons.trending_up_rounded, accentColor: AppTheme.info, subtitle: 'Active growth'),
              const SizedBox(height: 12),
              StatCard(title: 'Tenants', value: '${_summary['total_tenants'] ?? 0}', icon: Icons.apartment_rounded, accentColor: AppTheme.success, subtitle: '${_summary['total_documents'] ?? 0} docs'),
            ] else
              Row(
                children: [
                  Expanded(child: StatCard(title: 'Total Queries', value: '${_summary['total_queries'] ?? 0}', icon: Icons.chat_bubble_rounded, accentColor: AppTheme.primary, subtitle: '+${_summary['today'] ?? 0} today')),
                  const SizedBox(width: 16),
                  Expanded(child: StatCard(title: 'This Week', value: '${_summary['this_week'] ?? 0}', icon: Icons.trending_up_rounded, accentColor: AppTheme.info, subtitle: 'Active growth')),
                  const SizedBox(width: 16),
                  Expanded(child: StatCard(title: 'Tenants', value: '${_summary['total_tenants'] ?? 0}', icon: Icons.apartment_rounded, accentColor: AppTheme.success, subtitle: '${_summary['total_documents'] ?? 0} docs')),
                ],
              ),
            const SizedBox(height: 24),

            // Chart placeholder
            Container(
              height: isNarrow ? 140 : 180,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: borderColor, width: 1),
              ),
              child: Center(
                child: _topQueries.isEmpty
                    ? Text('No query data yet. Start chatting to see trends.', style: TextStyle(color: subtextColor))
                    : Text('Query Trend Chart (fl_chart integration)', style: TextStyle(color: subtextColor)),
              ),
            ),
            const SizedBox(height: 20),

            // Top Queries header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Top Queries (${_topQueries.length})', style: TextStyle(fontSize: isNarrow ? 16 : 18, fontWeight: FontWeight.w600, color: textColor)),
                if (_topQueries.length > 5)
                  TextButton(
                    onPressed: () => setState(() => _showAll = !_showAll),
                    child: Text(_showAll ? 'Show Less' : 'View All', style: TextStyle(color: AppTheme.primary, fontSize: 13)),
                  ),
              ],
            ),
            const SizedBox(height: 8),

            // Query list
            Expanded(
              child: _topQueries.isEmpty
                  ? Container(
                      decoration: BoxDecoration(
                        color: bgColor,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: borderColor, width: 1),
                      ),
                      child: Center(child: Text('No queries recorded yet.', style: TextStyle(color: subtextColor))),
                    )
                  : Container(
                      decoration: BoxDecoration(
                        color: bgColor,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: borderColor, width: 1),
                      ),
                      child: ListView.separated(
                        padding: EdgeInsets.all(isNarrow ? 8 : 12),
                        itemCount: visible.length,
                        separatorBuilder: (_, __) => Divider(color: borderColor, height: 1),
                        itemBuilder: (ctx, i) {
                          final q = visible[i];
                          return ListTile(
                            dense: isNarrow,
                            contentPadding: EdgeInsets.symmetric(horizontal: isNarrow ? 8 : 12),
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => QueryDetailScreen(rank: i + 1, question: q['question'] ?? '', uses: '${q['uses'] ?? 0} uses')),
                            ),
                            leading: Container(
                              width: 28, height: 28,
                              decoration: BoxDecoration(color: AppTheme.primary.withOpacity(0.15), borderRadius: BorderRadius.circular(6)),
                              child: Center(child: Text('${i + 1}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppTheme.primary))),
                            ),
                            title: Text(q['question'] ?? '', style: TextStyle(fontSize: isNarrow ? 13 : 14, color: textColor), maxLines: 2, overflow: TextOverflow.ellipsis),
                            subtitle: (q['last_asked'] ?? '').toString().isNotEmpty
                                ? Text('Last: ${q['last_asked']}', style: TextStyle(fontSize: 11, color: subtextColor))
                                : null,
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text('${q['uses'] ?? 0}', style: TextStyle(fontSize: 11, color: subtextColor)),
                                const SizedBox(width: 2),
                                Icon(Icons.chevron_right_rounded, size: 16, color: subtextColor),
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
