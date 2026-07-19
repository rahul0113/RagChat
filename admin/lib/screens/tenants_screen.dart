import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/api_service.dart';
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

  Future<void> _loadTenants() async {
    final api = context.read<ApiService>();
    final tenants = await api.getTenants();
    setState(() {
      _tenants = tenants;
      _filtered = tenants;
      _loading = false;
    });
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
              const Text('Tenants', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
              ElevatedButton.icon(
                onPressed: _showCreateDialog,
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('Create Tenant'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Search
          TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Search tenants...',
              prefixIcon: const Icon(Icons.search_rounded, color: AppTheme.textSecondary),
            ),
          ),
          const SizedBox(height: 16),
          // List
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator(color: AppTheme.primary))
                : _filtered.isEmpty
                    ? const Center(child: Text('No tenants found', style: TextStyle(color: AppTheme.textSecondary)))
                    : ListView.separated(
                        itemCount: _filtered.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 12),
                        itemBuilder: (ctx, i) => TenantCard(
                          tenant: _filtered[i],
                          onTap: () => widget.onTenantSelected(_filtered[i].id),
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  void _showCreateDialog() {
    final nameCtrl = TextEditingController();
    final slugCtrl = TextEditingController();
    final orgCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title: const Text('Create Tenant', style: TextStyle(color: AppTheme.textPrimary)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Name')),
            const SizedBox(height: 12),
            TextField(controller: slugCtrl, decoration: const InputDecoration(labelText: 'Slug')),
            const SizedBox(height: 12),
            TextField(controller: orgCtrl, decoration: const InputDecoration(labelText: 'Organization Name')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              if (nameCtrl.text.isNotEmpty && slugCtrl.text.isNotEmpty && orgCtrl.text.isNotEmpty) {
                final api = context.read<ApiService>();
                await api.createTenant(name: nameCtrl.text, slug: slugCtrl.text, orgName: orgCtrl.text);
                Navigator.pop(ctx);
                _loadTenants();
              }
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }
}
