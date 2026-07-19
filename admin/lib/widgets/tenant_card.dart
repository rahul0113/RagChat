import 'package:flutter/material.dart';
import '../models/tenant_model.dart';
import '../theme/app_theme.dart';

class TenantCard extends StatelessWidget {
  final Tenant tenant;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  const TenantCard({
    super.key,
    required this.tenant,
    this.onTap,
    this.onLongPress,
  });

  Color get _planColor {
    switch (tenant.plan) {
      case 'enterprise': return AppTheme.warning;
      case 'pro': return AppTheme.primary;
      default: return AppTheme.textSecondary;
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Container(
        padding: const EdgeInsets.all(20),
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
                  width: 44, height: 44,
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: Text(
                      tenant.name.isNotEmpty ? tenant.name[0].toUpperCase() : '?',
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppTheme.primary),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(tenant.name, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppTheme.textPrimary), overflow: TextOverflow.ellipsis),
                      Text(tenant.orgName, style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary), overflow: TextOverflow.ellipsis),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _planColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(tenant.plan.toUpperCase(), style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: _planColor)),
                ),
                const SizedBox(width: 8),
                const Icon(Icons.chevron_right_rounded, size: 20, color: AppTheme.textSecondary),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                _stat(Icons.chat_bubble_outline, '${tenant.totalQueries} queries'),
                const SizedBox(width: 16),
                _stat(Icons.description_outlined, '${tenant.totalDocuments} docs'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _stat(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 14, color: AppTheme.textSecondary),
        const SizedBox(width: 4),
        Text(text, style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
      ],
    );
  }
}
