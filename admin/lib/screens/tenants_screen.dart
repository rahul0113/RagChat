import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/api_service.dart';
import '../services/error_handler.dart';
import '../models/tenant_model.dart';
import '../widgets/tenant_card.dart';
import '../theme/app_theme.dart';

class TenantsScreen extends StatefulWidget {
  final Function(String) onTenantSelected;
  const TenantsScreen({super.key, required this.onTenantSelected});

  @override
  State<TenantsScreen> createState() => _TenantsScreenState();
}

class _TenantsScreenState extends State<TenantsScreen> {
  List<Tenant> _tenants = [];
  List<Tenant> _filtered = [];
  bool _loading = true;
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadTenants();
    _searchController.addListener(_filter);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadTenants() async {
    setState(() => _loading = true);
    try {
      final api = context.read<ApiService>();
      final tenants = await api.getTenants();
      if (mounted) {
        setState(() {
          _tenants = tenants;
          _filtered = tenants;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        ErrorHandler.showNetworkError(context, details: e.toString(), onRetry: _loadTenants);
      }
    }
  }

  void _filter() {
    final q = _searchController.text.toLowerCase();
    setState(() {
      _filtered = _tenants.where((t) =>
        t.name.toLowerCase().contains(q) ||
        t.orgName.toLowerCase().contains(q) ||
        t.slug.toLowerCase().contains(q)
      ).toList();
    });
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

          return AlertDialog(
            backgroundColor: surfaceBg,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Text('Create Tenant', style: TextStyle(color: textColor, fontWeight: FontWeight.w600)),
            content: SizedBox(
              width: 400,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: nameCtrl,
                      decoration: const InputDecoration(labelText: 'Name', hintText: 'e.g. ABC College'),
                      onChanged: (v) {
                        slugCtrl.text = v.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '-').replaceAll(RegExp(r'-+'), '-');
                        setDialogState(() {});
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
                      dropdownColor: surfaceBg,
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
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text('Cancel', style: TextStyle(color: subtextColor)),
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
                    _loadTenants();
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('${nameCtrl.text} created'), backgroundColor: AppTheme.success),
                      );
                    }
                  } catch (e) {
                    if (ctx.mounted) ErrorHandler.showError(ctx, title: 'Create Tenant Failed', message: 'Could not create tenant.', details: e.toString());
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

  void _confirmDeleteTenant(Tenant tenant) {
    showDialog(
      context: context,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        final textColor = isDark ? AppTheme.textPrimary : AppTheme.lightTextPrimary;
        final subtextColor = isDark ? AppTheme.textSecondary : AppTheme.lightTextSecondary;
        final surfaceBg = isDark ? AppTheme.surface : AppTheme.lightSurface;

        return AlertDialog(
          backgroundColor: surfaceBg,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text('Delete Tenant', style: TextStyle(color: textColor)),
          content: Text(
            'Are you sure you want to delete "${tenant.name}"? All data including documents and vectors will be permanently removed.',
            style: TextStyle(color: subtextColor, fontSize: 14),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(ctx);
                try {
                  final api = context.read<ApiService>();
                  await api.deleteTenant(tenant.id);
                  _loadTenants();
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('${tenant.name} deleted'), backgroundColor: AppTheme.error),
                    );
                  }
                } catch (e) {
                  if (mounted) ErrorHandler.showError(context, title: 'Delete Failed', message: 'Could not delete tenant.', details: e.toString());
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

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? AppTheme.textPrimary : AppTheme.lightTextPrimary;
    final subtextColor = isDark ? AppTheme.textSecondary : AppTheme.lightTextSecondary;

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Tenants', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700, color: textColor)),
              Row(
                children: [
                  IconButton(onPressed: _loadTenants, icon: Icon(Icons.refresh_rounded, color: subtextColor)),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: _showCreateTenantDialog,
                    icon: const Icon(Icons.add_rounded, size: 18),
                    label: const Text('Create Tenant'),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Search tenants...',
              prefixIcon: Icon(Icons.search_rounded, color: subtextColor),
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: _loading
                ? Center(child: CircularProgressIndicator(color: AppTheme.primary))
                : _filtered.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.apartment_rounded, size: 48, color: subtextColor.withOpacity(0.3)),
                            const SizedBox(height: 12),
                            Text('No tenants found', style: TextStyle(color: subtextColor, fontSize: 16)),
                            const SizedBox(height: 8),
                            Text('Create your first tenant to get started', style: TextStyle(color: subtextColor, fontSize: 13)),
                          ],
                        ),
                      )
                    : ListView.separated(
                        itemCount: _filtered.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 12),
                        itemBuilder: (ctx, i) => TenantCard(
                          tenant: _filtered[i],
                          onTap: () => widget.onTenantSelected(_filtered[i].id),
                          onLongPress: () => _confirmDeleteTenant(_filtered[i]),
                        ),
                      ),
          ),
        ],
      ),
    );
  }
}
