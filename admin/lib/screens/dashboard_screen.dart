import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/api_service.dart';
import '../widgets/stat_card.dart';
import '../theme/app_theme.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  Map<String, dynamic>? _stats;
  List<Map<String, dynamic>> _recentQueries = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final api = context.read<ApiService>();
      final stats = await api.getDashboardStats();
      final recent = await api.getRecentQueries(limit: 5);
      setState(() {
        _stats = stats;
        _recentQueries = recent;
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'RagChat Admin',
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700, color: AppTheme.textPrimary),
              ),
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
                Expanded(
                  child: StatCard(
                    title: 'Total Tenants',
                    value: '${_stats?['total_tenants'] ?? _stats?['totalTenants'] ?? 0}',
                    icon: Icons.apartment_rounded,
                    accentColor: AppTheme.primary,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: StatCard(
                    title: 'Total Queries',
                    value: '${_stats?['total_queries'] ?? _stats?['totalQueries'] ?? 0}',
                    icon: Icons.chat_bubble_rounded,
                    accentColor: AppTheme.info,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: StatCard(
                    title: 'Documents',
                    value: '${_stats?['total_documents'] ?? _stats?['totalDocuments'] ?? 0}',
                    icon: Icons.description_rounded,
                    accentColor: AppTheme.success,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Quick Actions
            const Text('Quick Actions', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: _actionButton(Icons.add_rounded, 'Create Tenant', AppTheme.primary, () {
                  Scaffold.of(context).openEndDrawer(); // triggers tenant creation
                })),
                const SizedBox(width: 16),
                Expanded(child: _actionButton(Icons.upload_file_rounded, 'Upload Documents', AppTheme.success, () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Go to Tenants → select a tenant → Upload Document'), backgroundColor: AppTheme.info),
                  );
                })),
              ],
            ),
            const SizedBox(height: 24),

            // Recent Activity from API
            const Text('Recent Activity', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
            const SizedBox(height: 12),
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: AppTheme.card,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppTheme.border),
                ),
                child: _recentQueries.isEmpty
                    ? const Center(child: Text('No recent activity', style: TextStyle(color: AppTheme.textSecondary)))
                    : ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: _recentQueries.length,
                        separatorBuilder: (_, __) => const Divider(color: AppTheme.border, height: 1),
                        itemBuilder: (ctx, i) {
                          final q = _recentQueries[i];
                          return _activityItem(
                            Icons.chat_bubble_outline_rounded,
                            AppTheme.primary,
                            q['question'] ?? '',
                            _timeAgo(q['created_at'] ?? ''),
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

  Widget _actionButton(IconData icon, String label, Color color, [VoidCallback? onTap]) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(width: 8),
          Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 14)),
        ],
      ),
    ),
    );
  }

  Widget _activityItem(IconData icon, Color color, String text, String time) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 12),
          Expanded(
            child: Text(text, style: const TextStyle(color: AppTheme.textPrimary, fontSize: 14)),
          ),
          Text(time, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
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
}
