import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/api_service.dart';
import '../widgets/stat_card.dart';
import '../theme/app_theme.dart';
import 'tenants_screen.dart';

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
      if (mounted) {
        setState(() {
          _stats = stats;
          _recentQueries = recent;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showCreateTenantDialog() {
    final nameCtrl = TextEditingController();
    final slugCtrl = TextEditingController();
    final orgCtrl = TextEditingController();
    String selectedPlan = 'free';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: AppTheme.surface,
          title: const Text('Create Tenant', style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w600)),
          content: SizedBox(
            width: 400,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(labelText: 'Name', hintText: 'e.g. ABC College'),
                  onChanged: (v) {
                    slugCtrl.text = v.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '-').replaceAll(RegExp(r'-+'), '-');
                  },
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: slugCtrl,
                  decoration: const InputDecoration(labelText: 'Slug (URL-safe)', hintText: 'e.g. abc-college'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: orgCtrl,
                  decoration: const InputDecoration(labelText: 'Organization Name', hintText: 'e.g. ABC College of Engineering'),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: selectedPlan,
                  dropdownColor: AppTheme.surface,
                  decoration: const InputDecoration(labelText: 'Plan'),
                  items: const [
                    DropdownMenuItem(value: 'free', child: Text('Free')),
                    DropdownMenuItem(value: 'pro', child: Text('Pro')),
                    DropdownMenuItem(value: 'enterprise', child: Text('Enterprise')),
                  ],
                  onChanged: (v) => setDialogState(() => selectedPlan = v ?? 'free'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel', style: TextStyle(color: AppTheme.textSecondary)),
            ),
            ElevatedButton(
              onPressed: () async {
                if (nameCtrl.text.isEmpty || slugCtrl.text.isEmpty || orgCtrl.text.isEmpty) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    const SnackBar(content: Text('Please fill all fields'), backgroundColor: AppTheme.error),
                  );
                  return;
                }
                try {
                  final api = context.read<ApiService>();
                  await api.createTenant(
                    name: nameCtrl.text.trim(),
                    slug: slugCtrl.text.trim(),
                    orgName: orgCtrl.text.trim(),
                    plan: selectedPlan,
                  );
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('${nameCtrl.text} created'), backgroundColor: AppTheme.success),
                  );
                  _loadData();
                } catch (e) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    SnackBar(content: Text('Error: $e'), backgroundColor: AppTheme.error),
                  );
                }
              },
              child: const Text('Create'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('RagChat Admin', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
              IconButton(onPressed: _loadData, icon: const Icon(Icons.refresh_rounded, color: AppTheme.textSecondary)),
            ],
          ),
          const SizedBox(height: 24),

          if (_loading)
            const Center(child: CircularProgressIndicator(color: AppTheme.primary))
          else ...[
            // Stats
            Row(
              children: [
                Expanded(child: StatCard(title: 'Total Tenants', value: '${_stats?['total_tenants'] ?? 0}', icon: Icons.apartment_rounded, accentColor: AppTheme.primary)),
                const SizedBox(width: 16),
                Expanded(child: StatCard(title: 'Total Queries', value: '${_stats?['total_queries'] ?? 0}', icon: Icons.chat_bubble_rounded, accentColor: AppTheme.info)),
                const SizedBox(width: 16),
                Expanded(child: StatCard(title: 'Documents', value: '${_stats?['total_documents'] ?? 0}', icon: Icons.description_rounded, accentColor: AppTheme.success)),
              ],
            ),
            const SizedBox(height: 24),

            // Quick Actions
            const Text('Quick Actions', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _actionButton(Icons.add_rounded, 'Create Tenant', AppTheme.primary, _showCreateTenantDialog),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _actionButton(Icons.upload_file_rounded, 'Upload Documents', AppTheme.success, () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Go to Tenants > Select a tenant > Upload Document'), backgroundColor: AppTheme.info),
                    );
                  }),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Recent Activity
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
                          return _activityItem(Icons.chat_bubble_outline_rounded, AppTheme.primary, q['question'] ?? '', _timeAgo(q['created_at'] ?? ''));
                        },
                      ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _actionButton(IconData icon, String label, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
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
          Expanded(child: Text(text, style: const TextStyle(color: AppTheme.textPrimary, fontSize: 14))),
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
