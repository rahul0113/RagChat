import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/api_service.dart';
import '../models/tenant_model.dart';
import '../theme/app_theme.dart';

class DocumentsScreen extends StatefulWidget {
  const DocumentsScreen({super.key});

  @override
  State<DocumentsScreen> createState() => _DocumentsScreenState();
}

class _DocumentsScreenState extends State<DocumentsScreen> {
  List<Tenant> _tenants = [];
  bool _loading = true;
  int _totalDocs = 0;
  String _selectedFilter = 'All';

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final api = context.read<ApiService>();
    final tenants = await api.getTenants();
    int totalDocs = 0;
    for (final t in tenants) {
      totalDocs += t.totalDocuments;
    }
    setState(() {
      _tenants = tenants;
      _totalDocs = totalDocs;
      _loading = false;
    });
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
              const Text('Documents', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
              IconButton(
                onPressed: _loadData,
                icon: const Icon(Icons.refresh_rounded, color: AppTheme.textSecondary),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Stats from API
          Row(
            children: [
              _statCard('$_totalDocs', 'Total Files', Icons.description_rounded, AppTheme.primary),
              const SizedBox(width: 12),
              _statCard('${_tenants.length}', 'Tenants', Icons.apartment_rounded, AppTheme.info),
            ],
          ),
          const SizedBox(height: 16),
          // Filter chips
          Wrap(
            spacing: 8,
            children: ['All', 'PDF', 'DOCX', 'TXT', 'HTML'].map((f) {
              final isActive = _selectedFilter == f;
              return FilterChip(
                label: Text(f, style: TextStyle(
                  color: isActive ? Colors.white : AppTheme.textSecondary,
                  fontWeight: FontWeight.w500,
                )),
                selected: isActive,
                selectedColor: AppTheme.primary,
                backgroundColor: AppTheme.card,
                side: const BorderSide(color: AppTheme.border),
                onSelected: (_) => setState(() => _selectedFilter = f),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),
          // Document list grouped by tenant
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator(color: AppTheme.primary))
                : _tenants.isEmpty
                    ? const Center(child: Text('No tenants yet. Create one to upload documents.', style: TextStyle(color: AppTheme.textSecondary)))
                    : ListView.separated(
                        itemCount: _tenants.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 12),
                        itemBuilder: (ctx, i) {
                          final t = _tenants[i];
                          return _tenantDocCard(t);
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _tenantDocCard(Tenant tenant) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36, height: 36,
                decoration: BoxDecoration(
                  color: AppTheme.primary.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Center(
                  child: Text(tenant.name.isNotEmpty ? tenant.name[0].toUpperCase() : '?',
                      style: const TextStyle(fontWeight: FontWeight.w700, color: AppTheme.primary)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(tenant.name, style: const TextStyle(fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
                    Text('${tenant.totalDocuments} documents uploaded', style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                  ],
                ),
              ),
            ],
          ),
          if (tenant.totalDocuments == 0) ...[
            const SizedBox(height: 12),
            const Text('No documents uploaded yet. Go to Tenant Details to upload.',
                style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
          ],
        ],
      ),
    );
  }

  Widget _statCard(String value, String label, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: color)),
                Text(label, style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
