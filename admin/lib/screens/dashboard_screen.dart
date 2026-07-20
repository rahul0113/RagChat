import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import '../services/api_service.dart';
import '../models/tenant_model.dart';
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
  List<Tenant> _tenants = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final api = context.read<ApiService>();
      final results = await Future.wait([api.getDashboardStats(), api.getRecentQueries(limit: 5), api.getTenants()]);
      if (mounted) {
        setState(() {
          _stats = results[0] as Map<String, dynamic>;
          _recentQueries = results[1] as List<Map<String, dynamic>>;
          _tenants = results[2] as List<Tenant>;
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
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Create Tenant', style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w600)),
          content: SizedBox(
            width: 400,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Name', hintText: 'e.g. ABC College'),
                  onChanged: (v) { slugCtrl.text = v.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '-').replaceAll(RegExp(r'-+'), '-'); setDialogState(() {}); }),
                const SizedBox(height: 12),
                TextField(controller: slugCtrl, decoration: const InputDecoration(labelText: 'Slug')),
                const SizedBox(height: 12),
                TextField(controller: orgCtrl, decoration: const InputDecoration(labelText: 'Organization Name')),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(value: selectedPlan, dropdownColor: AppTheme.surface, decoration: const InputDecoration(labelText: 'Plan'),
                  items: const [DropdownMenuItem(value: 'free', child: Text('Free')), DropdownMenuItem(value: 'pro', child: Text('Pro')), DropdownMenuItem(value: 'enterprise', child: Text('Enterprise'))],
                  onChanged: (v) => setDialogState(() => selectedPlan = v ?? 'free')),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel', style: TextStyle(color: AppTheme.textSecondary))),
            ElevatedButton(
              onPressed: () async {
                if (nameCtrl.text.isEmpty || slugCtrl.text.isEmpty || orgCtrl.text.isEmpty) {
                  ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('Please fill all fields'), backgroundColor: AppTheme.error));
                  return;
                }
                try {
                  final api = context.read<ApiService>();
                  await api.createTenant(name: nameCtrl.text.trim(), slug: slugCtrl.text.trim(), orgName: orgCtrl.text.trim(), plan: selectedPlan);
                  Navigator.pop(ctx);
                  _loadData();
                  if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${nameCtrl.text} created'), backgroundColor: AppTheme.success));
                } catch (e) {
                  ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: AppTheme.error));
                }
              },
              child: const Text('Create'),
            ),
          ],
        ),
      ),
    );
  }

  void _showUploadDialog() {
    if (_tenants.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Create a tenant first before uploading documents'), backgroundColor: AppTheme.warning),
      );
      return;
    }

    Tenant? selectedTenant;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: AppTheme.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Upload Document', style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w600)),
          content: SizedBox(
            width: 400,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<Tenant>(
                  decoration: const InputDecoration(labelText: 'Select Tenant'),
                  dropdownColor: AppTheme.surface,
                  items: _tenants.map((t) => DropdownMenuItem(value: t, child: Text(t.name, style: const TextStyle(color: AppTheme.textPrimary)))).toList(),
                  onChanged: (v) => setDialogState(() => selectedTenant = v),
                ),
                const SizedBox(height: 16),
                // File picker area
                InkWell(
                  onTap: () async {
                    final result = await FilePicker.platform.pickFiles();
                    if (result != null && result.files.isNotEmpty && selectedTenant != null) {
                      Navigator.pop(ctx);
                      _uploadFile(selectedTenant!, result.files.first);
                    } else if (selectedTenant == null) {
                      ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('Please select a tenant first'), backgroundColor: AppTheme.warning));
                    }
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppTheme.primary.withOpacity(0.3), width: 1.5),
                    ),
                    child: Column(
                      children: [
                        Container(
                          width: 56, height: 56,
                          decoration: BoxDecoration(
                            color: AppTheme.primary.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Icon(Icons.cloud_upload_rounded, size: 30, color: AppTheme.primary.withOpacity(0.7)),
                        ),
                        const SizedBox(height: 12),
                        const Text('Tap to select file', style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w500, fontSize: 14)),
                        const SizedBox(height: 4),
                        Text('PDF, DOCX, TXT, HTML, CSV, MD, JSON', style: TextStyle(fontSize: 12, color: AppTheme.textSecondary.withOpacity(0.7))),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel', style: TextStyle(color: AppTheme.textSecondary))),
          ],
        ),
      ),
    );
  }

  Future<void> _uploadFile(Tenant tenant, PlatformFile file) async {
    if (file.bytes == null) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Uploading ${file.name} to ${tenant.name}...'), backgroundColor: AppTheme.info));
    try {
      final api = context.read<ApiService>();
      await api.uploadDocument(tenant.id, file.bytes!, file.name);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${file.name} uploaded to ${tenant.name}'), backgroundColor: AppTheme.success));
        _loadData();
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Upload failed: $e'), backgroundColor: AppTheme.error));
    }
  }

  @override
  Widget build(BuildContext context) {
    final isNarrow = MediaQuery.of(context).size.width < 600;

    return Padding(
      padding: EdgeInsets.all(isNarrow ? 16 : 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('RagChat Admin', style: TextStyle(fontSize: isNarrow ? 22 : 28, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
              IconButton(onPressed: _loadData, icon: const Icon(Icons.refresh_rounded, color: AppTheme.textSecondary)),
            ],
          ),
          const SizedBox(height: 20),

          if (_loading)
            const Center(child: CircularProgressIndicator(color: AppTheme.primary))
          else ...[
            // Stats — stack vertically on mobile, horizontal on desktop
            if (isNarrow) ...[
              StatCard(title: 'Total Tenants', value: '${_stats?['total_tenants'] ?? 0}', icon: Icons.apartment_rounded, accentColor: AppTheme.primary),
              const SizedBox(height: 12),
              StatCard(title: 'Total Queries', value: '${_stats?['total_queries'] ?? 0}', icon: Icons.chat_bubble_rounded, accentColor: AppTheme.info),
              const SizedBox(height: 12),
              StatCard(title: 'Documents', value: '${_stats?['total_documents'] ?? 0}', icon: Icons.description_rounded, accentColor: AppTheme.success),
            ] else
              Row(
                children: [
                  Expanded(child: StatCard(title: 'Total Tenants', value: '${_stats?['total_tenants'] ?? 0}', icon: Icons.apartment_rounded, accentColor: AppTheme.primary)),
                  const SizedBox(width: 16),
                  Expanded(child: StatCard(title: 'Total Queries', value: '${_stats?['total_queries'] ?? 0}', icon: Icons.chat_bubble_rounded, accentColor: AppTheme.info)),
                  const SizedBox(width: 16),
                  Expanded(child: StatCard(title: 'Documents', value: '${_stats?['total_documents'] ?? 0}', icon: Icons.description_rounded, accentColor: AppTheme.success)),
                ],
              ),
            const SizedBox(height: 20),

            // Quick Actions — stack on mobile
            Text('Quick Actions', style: TextStyle(fontSize: isNarrow ? 16 : 18, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
            const SizedBox(height: 12),
            if (isNarrow) ...[
              _actionButton(Icons.add_rounded, 'Create Tenant', AppTheme.primary, _showCreateTenantDialog),
              const SizedBox(height: 8),
              _actionButton(Icons.upload_file_rounded, 'Upload Document', AppTheme.success, _showUploadDialog),
            ] else
              Row(
                children: [
                  Expanded(child: _actionButton(Icons.add_rounded, 'Create Tenant', AppTheme.primary, _showCreateTenantDialog)),
                  const SizedBox(width: 16),
                  Expanded(child: _actionButton(Icons.upload_file_rounded, 'Upload Document', AppTheme.success, _showUploadDialog)),
                ],
              ),
            const SizedBox(height: 24),

            Text('Recent Activity', style: TextStyle(fontSize: isNarrow ? 16 : 18, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
            const SizedBox(height: 12),
            Expanded(
              child: Container(
                decoration: AppTheme.glassCardDecoration(),
                child: _recentQueries.isEmpty
                    ? const Center(child: Text('No recent activity', style: TextStyle(color: AppTheme.textSecondary)))
                    : ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: _recentQueries.length,
                        separatorBuilder: (_, __) => const Divider(color: AppTheme.border, height: 1),
                        itemBuilder: (ctx, i) {
                          final q = _recentQueries[i];
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: Row(
                              children: [
                                const Icon(Icons.chat_bubble_outline_rounded, color: AppTheme.primary, size: 18),
                                const SizedBox(width: 12),
                                Expanded(child: Text(q['question'] ?? '', style: const TextStyle(color: AppTheme.textPrimary, fontSize: 14))),
                                Text(_timeAgo(q['created_at'] ?? ''), style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
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

  Widget _actionButton(IconData icon, String label, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.3), width: 1),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                label,
                style: TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 13),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            ),
          ],
        ),
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
