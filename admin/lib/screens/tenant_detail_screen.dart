import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import '../services/api_service.dart';
import '../models/tenant_model.dart';
import '../theme/app_theme.dart';

class TenantDetailScreen extends StatefulWidget {
  final String tenantId;
  final VoidCallback onBack;
  const TenantDetailScreen({super.key, required this.tenantId, required this.onBack});

  @override
  State<TenantDetailScreen> createState() => _TenantDetailScreenState();
}

class _TenantDetailScreenState extends State<TenantDetailScreen> {
  TenantDetail? _tenant;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadTenant();
  }

  Future<void> _loadTenant() async {
    try {
      final api = context.read<ApiService>();
      final tenant = await api.getTenant(widget.tenantId);
      setState(() {
        _tenant = tenant;
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? AppTheme.textPrimary : AppTheme.lightTextPrimary;
    final subtextColor = isDark ? AppTheme.textSecondary : AppTheme.lightTextSecondary;
    final bgColor = isDark ? AppTheme.card : AppTheme.lightCard;
    final surfaceHigh = isDark ? AppTheme.surfaceContainerHigh : AppTheme.lightSurfaceContainerHigh;
    final borderColor = isDark ? AppTheme.border : AppTheme.lightBorder;

    if (_loading) {
      return Center(child: CircularProgressIndicator(color: AppTheme.primary));
    }
    if (_tenant == null) {
      return Center(child: Text('Tenant not found', style: TextStyle(color: subtextColor)));
    }

    return Padding(
      padding: const EdgeInsets.all(24),
      child: ListView(
        children: [
          // Header
          Row(
            children: [
              IconButton(onPressed: widget.onBack, icon: Icon(Icons.arrow_back_rounded, color: textColor)),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_tenant!.name, style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: textColor)),
                    Text(_tenant!.orgName, style: TextStyle(fontSize: 14, color: subtextColor)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Stats
          Row(
            children: [
              _statCard('${_tenant!.totalQueries}', 'Queries', AppTheme.info, textColor, subtextColor),
              const SizedBox(width: 12),
              _statCard('${_tenant!.totalDocuments}', 'Documents', AppTheme.success, textColor, subtextColor),
              const SizedBox(width: 12),
              _statCard('${_tenant!.vectorStats['total_vectors'] ?? 0}', 'Vectors', AppTheme.primary, textColor, subtextColor),
            ],
          ),
          const SizedBox(height: 24),

          // Actions
          Row(
            children: [
              Expanded(child: _actionButton(Icons.upload_file_rounded, 'Upload Document', AppTheme.success, _uploadDocument)),
              const SizedBox(width: 12),
              Expanded(child: _actionButton(Icons.code_rounded, 'View Embed Code', AppTheme.primary, _showEmbedCode)),
            ],
          ),
          const SizedBox(height: 24),

          // Theme Customization
          Text('Theme Customization', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: textColor)),
          const SizedBox(height: 12),
          _buildThemeEditor(textColor, subtextColor, bgColor, surfaceHigh, borderColor),
          const SizedBox(height: 24),

          // Documents
          Text('Documents', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: textColor)),
          const SizedBox(height: 12),
          if (_tenant!.totalDocuments == 0)
            Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(16), border: Border.all(color: borderColor)),
              child: Center(child: Text('No documents uploaded yet', style: TextStyle(color: subtextColor))),
            ),
        ],
      ),
    );
  }

  Widget _statCard(String value, String label, Color color, Color textColor, Color subtextColor) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          children: [
            Text(value, style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: color)),
            const SizedBox(height: 4),
            Text(label, style: TextStyle(fontSize: 12, color: subtextColor)),
          ],
        ),
      ),
    );
  }

  Widget _actionButton(IconData icon, String label, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 8),
            Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 13)),
          ],
        ),
      ),
    );
  }

  Widget _buildThemeEditor(Color textColor, Color subtextColor, Color bgColor, Color surfaceHigh, Color borderColor) {
    final colors = [
      AppTheme.primary, const Color(0xFF8B5CF6), const Color(0xFF3B82F6),
      AppTheme.success, AppTheme.warning, const Color(0xFFEC4899),
      const Color(0xFF14B8A6), AppTheme.error,
    ];

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: colors.map((c) => GestureDetector(
              onTap: () => _updateTheme(c),
              child: Container(
                width: 40, height: 40,
                decoration: BoxDecoration(color: c, shape: BoxShape.circle,
                  border: Border.all(color: Colors.white24, width: 2),
                ),
              ),
            )).toList(),
          ),
          const SizedBox(height: 16),
          Text('Live Preview', style: TextStyle(fontSize: 13, color: subtextColor)),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: surfaceHigh,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text('Hello! How can I help?', style: TextStyle(fontSize: 13, color: textColor)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _uploadDocument() async {
    final result = await FilePicker.platform.pickFiles();
    if (result != null && result.files.isNotEmpty) {
      final file = result.files.first;
      if (file.bytes != null) {
        try {
          final api = context.read<ApiService>();
          await api.uploadDocument(widget.tenantId, file.bytes!, file.name);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('${file.name} uploaded successfully'), backgroundColor: AppTheme.success),
          );
          _loadTenant();
        } catch (e) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Upload failed: $e'), backgroundColor: AppTheme.error),
          );
        }
      }
    }
  }

  void _showEmbedCode() {
    final code = _tenant?.embedCode ?? '';
    showDialog(
      context: context,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        final textColor = isDark ? AppTheme.textPrimary : AppTheme.lightTextPrimary;
        final subtextColor = isDark ? AppTheme.textSecondary : AppTheme.lightTextSecondary;
        final surfaceBg = isDark ? AppTheme.surface : AppTheme.lightSurface;

        return AlertDialog(
          backgroundColor: surfaceBg,
          title: Text('Embed Code', style: TextStyle(color: textColor)),
          content: SelectableText(code, style: TextStyle(fontFamily: 'monospace', fontSize: 12, color: subtextColor)),
          actions: [
            TextButton(
              onPressed: () {
                Clipboard.setData(ClipboardData(text: code));
                Navigator.pop(ctx);
              },
              child: const Text('Copy'),
            ),
          ],
        );
      },
    );
  }

  void _updateTheme(Color color) async {
    final api = context.read<ApiService>();
    final hex = '#${color.value.toRadixString(16).substring(2)}';
    await api.updateTheme(widget.tenantId, {'primary_color': hex});
    _loadTenant();
  }
}
