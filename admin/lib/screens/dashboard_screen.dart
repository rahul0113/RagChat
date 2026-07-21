import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import '../services/api_service.dart';
import '../services/error_handler.dart';
import '../models/tenant_model.dart';
import '../widgets/stat_card.dart';
import '../theme/app_theme.dart';

class DashboardScreen extends StatefulWidget {
  final VoidCallback? onOpenChat;
  const DashboardScreen({super.key, this.onOpenChat});

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
      if (mounted) {
        setState(() => _loading = false);
        ErrorHandler.showNetworkError(context, details: e.toString(), onRetry: _loadData);
      }
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
        builder: (ctx, setDialogState) {
          final isDark = Theme.of(ctx).brightness == Brightness.dark;
          final textColor = isDark ? AppTheme.textPrimary : AppTheme.lightTextPrimary;
          final subtextColor = isDark ? AppTheme.textSecondary : AppTheme.lightTextSecondary;
          final surfaceBg = isDark ? AppTheme.surface : AppTheme.lightSurface;
          final borderColor = isDark ? AppTheme.border : AppTheme.lightBorder;

          final keyboardHeight = MediaQuery.of(ctx).viewInsets.bottom;

          return AlertDialog(
            backgroundColor: surfaceBg,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Text('Create Tenant', style: TextStyle(color: textColor, fontWeight: FontWeight.w600)),
            content: Padding(
              padding: EdgeInsets.only(bottom: keyboardHeight > 0 ? keyboardHeight * 0.5 : 0),
              child: SizedBox(
                width: 400,
                child: SingleChildScrollView(
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
                      DropdownButtonFormField<String>(value: selectedPlan, dropdownColor: surfaceBg, decoration: const InputDecoration(labelText: 'Plan'),
                        items: const [DropdownMenuItem(value: 'free', child: Text('Free')), DropdownMenuItem(value: 'pro', child: Text('Pro')), DropdownMenuItem(value: 'enterprise', child: Text('Enterprise'))],
                        onChanged: (v) => setDialogState(() => selectedPlan = v ?? 'free')),
                    ],
                  ),
                ),
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: Text('Cancel', style: TextStyle(color: subtextColor))),
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
                    if (ctx.mounted) ErrorHandler.showError(ctx, title: 'Create Tenant Failed', message: 'Could not create tenant. Please try again.', details: e.toString());
                  }
                },
                child: const Text('Create'),
              ),
            ],
          );
        },
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
        builder: (ctx, setDialogState) {
          final isDark = Theme.of(ctx).brightness == Brightness.dark;
          final textColor = isDark ? AppTheme.textPrimary : AppTheme.lightTextPrimary;
          final subtextColor = isDark ? AppTheme.textSecondary : AppTheme.lightTextSecondary;
          final surfaceBg = isDark ? AppTheme.surface : AppTheme.lightSurface;

          return AlertDialog(
            backgroundColor: surfaceBg,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Text('Upload Document', style: TextStyle(color: textColor, fontWeight: FontWeight.w600)),
            content: SizedBox(
              width: 400,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<Tenant>(
                    decoration: const InputDecoration(labelText: 'Select Tenant'),
                    dropdownColor: surfaceBg,
                    items: _tenants.map((t) => DropdownMenuItem(value: t, child: Text(t.name, style: TextStyle(color: textColor)))).toList(),
                    onChanged: (v) => setDialogState(() => selectedTenant = v),
                  ),
                  const SizedBox(height: 16),
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
                          Text('Tap to select file', style: TextStyle(color: textColor, fontWeight: FontWeight.w500, fontSize: 14)),
                          const SizedBox(height: 4),
                          Text('PDF, DOCX, TXT, HTML, CSV, MD, JSON', style: TextStyle(fontSize: 12, color: subtextColor.withOpacity(0.7))),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: Text('Cancel', style: TextStyle(color: subtextColor))),
            ],
          );
        },
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
      if (mounted) ErrorHandler.showError(context, title: 'Upload Failed', message: 'Could not upload ${file.name}. Please try again.', details: e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
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
              InkWell(
                onTap: _loadData,
                borderRadius: BorderRadius.circular(8),
                child: Row(
                  children: [
                    Container(
                      width: 32, height: 32,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(colors: [AppTheme.primary, AppTheme.primary.withOpacity(0.7)]),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.chat_bubble_rounded, color: Colors.white, size: 18),
                    ),
                    const SizedBox(width: 10),
                    Text('RagChat Admin', style: TextStyle(fontSize: isNarrow ? 22 : 28, fontWeight: FontWeight.w700, color: textColor)),
                  ],
                ),
              ),
              IconButton(onPressed: _loadData, icon: Icon(Icons.refresh_rounded, color: subtextColor)),
            ],
          ),
          const SizedBox(height: 20),

          if (_loading)
            Center(child: CircularProgressIndicator(color: AppTheme.primary))
          else ...[
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

            Text('Quick Actions', style: TextStyle(fontSize: isNarrow ? 16 : 18, fontWeight: FontWeight.w600, color: textColor)),
            const SizedBox(height: 12),
            if (isNarrow) ...[
              _actionButton(Icons.add_rounded, 'Create Tenant', AppTheme.primary, _showCreateTenantDialog),
              const SizedBox(height: 8),
              _actionButton(Icons.upload_file_rounded, 'Upload Document', AppTheme.success, _showUploadDialog),
              const SizedBox(height: 8),
              _actionButton(Icons.chat_bubble_rounded, 'Open Chat', AppTheme.info, widget.onOpenChat ?? () {}),
            ] else
              Row(
                children: [
                  Expanded(child: _actionButton(Icons.add_rounded, 'Create Tenant', AppTheme.primary, _showCreateTenantDialog)),
                  const SizedBox(width: 16),
                  Expanded(child: _actionButton(Icons.upload_file_rounded, 'Upload Document', AppTheme.success, _showUploadDialog)),
                  const SizedBox(width: 16),
                  Expanded(child: _actionButton(Icons.chat_bubble_rounded, 'Open Chat', AppTheme.info, widget.onOpenChat ?? () {})),
                ],
              ),
            const SizedBox(height: 24),

            Text('Recent Activity', style: TextStyle(fontSize: isNarrow ? 16 : 18, fontWeight: FontWeight.w600, color: textColor)),
            const SizedBox(height: 12),
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: bgColor,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: borderColor, width: 1),
                ),
                child: _recentQueries.isEmpty
                    ? Center(child: Text('No recent activity', style: TextStyle(color: subtextColor)))
                    : ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: _recentQueries.length,
                        separatorBuilder: (_, __) => Divider(color: borderColor, height: 1),
                        itemBuilder: (ctx, i) {
                          final q = _recentQueries[i];
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: Row(
                              children: [
                                Icon(Icons.chat_bubble_outline_rounded, color: AppTheme.primary, size: 18),
                                const SizedBox(width: 12),
                                Expanded(child: Text(q['question'] ?? '', style: TextStyle(color: textColor, fontSize: 14))),
                                Text(_timeAgo(q['created_at'] ?? ''), style: TextStyle(color: subtextColor, fontSize: 12)),
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
