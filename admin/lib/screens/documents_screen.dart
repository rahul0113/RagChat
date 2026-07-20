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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? AppTheme.textPrimary : AppTheme.lightTextPrimary;
    final subtextColor = isDark ? AppTheme.textSecondary : AppTheme.lightTextSecondary;
    final bgColor = isDark ? AppTheme.card : AppTheme.lightCard;
    final surfaceBg = isDark ? AppTheme.surface : AppTheme.lightSurface;
    final borderColor = isDark ? AppTheme.border : AppTheme.lightBorder;

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Documents', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700, color: textColor)),
              IconButton(
                onPressed: _loadData,
                icon: Icon(Icons.refresh_rounded, color: subtextColor),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Stats from API
          Row(
            children: [
              _statCard('$_totalDocs', 'Total Files', Icons.description_rounded, AppTheme.primary, subtextColor),
              const SizedBox(width: 12),
              _statCard('${_tenants.length}', 'Tenants', Icons.apartment_rounded, AppTheme.info, subtextColor),
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
                  color: isActive ? Colors.white : subtextColor,
                  fontWeight: FontWeight.w500,
                )),
                selected: isActive,
                selectedColor: AppTheme.primary,
                backgroundColor: surfaceBg,
                side: BorderSide(color: borderColor),
                onSelected: (_) => setState(() => _selectedFilter = f),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),
          // Document list grouped by tenant
          Expanded(
            child: _loading
                ? Center(child: CircularProgressIndicator(color: AppTheme.primary))
                : _tenants.isEmpty
                    ? Center(child: Text('No tenants yet. Create one to upload documents.', style: TextStyle(color: subtextColor)))
                    : ListView.separated(
                        itemCount: _tenants.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 12),
                        itemBuilder: (ctx, i) {
                          final t = _tenants[i];
                          return _tenantDocCard(t, textColor, subtextColor, bgColor, borderColor);
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _tenantDocCard(Tenant tenant, Color textColor, Color subtextColor, Color bgColor, Color borderColor) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
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
                    Text(tenant.name, style: TextStyle(fontWeight: FontWeight.w600, color: textColor)),
                    Text('${tenant.totalDocuments} documents uploaded', style: TextStyle(fontSize: 12, color: subtextColor)),
                  ],
                ),
              ),
            ],
          ),
          if (tenant.totalDocuments == 0) ...[
            const SizedBox(height: 12),
            Text('No documents uploaded yet. Go to Tenant Details to upload.',
                style: TextStyle(fontSize: 12, color: subtextColor)),
          ],
        ],
      ),
    );
  }

  Widget _statCard(String value, String label, IconData icon, Color color, Color subtextColor) {
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
                Text(label, style: TextStyle(fontSize: 12, color: subtextColor)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
