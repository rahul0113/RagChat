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

  Color _planColor(String plan) {
    switch (plan) {
      case 'enterprise': return AppTheme.warning;
      case 'pro': return AppTheme.primary;
      default: return AppTheme.textSecondary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? AppTheme.card : AppTheme.lightCard;
    final textColor = isDark ? AppTheme.textPrimary : AppTheme.lightTextPrimary;
    final subtextColor = isDark ? AppTheme.textSecondary : AppTheme.lightTextSecondary;
    final borderColor = isDark ? AppTheme.border : AppTheme.lightBorder;

    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: borderColor, width: 1),
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
                    borderRadius: BorderRadius.circular(10),
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
                      Text(tenant.name, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: textColor), overflow: TextOverflow.ellipsis),
                      Text(tenant.orgName, style: TextStyle(fontSize: 12, color: subtextColor), overflow: TextOverflow.ellipsis),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _planColor(tenant.plan).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(tenant.plan.toUpperCase(), style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: _planColor(tenant.plan))),
                ),
                const SizedBox(width: 8),
                Icon(Icons.chevron_right_rounded, size: 20, color: subtextColor),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Icon(Icons.chat_bubble_outline, size: 14, color: subtextColor),
                const SizedBox(width: 4),
                Text('${tenant.totalQueries} queries', style: TextStyle(fontSize: 12, color: subtextColor)),
                const SizedBox(width: 16),
                Icon(Icons.description_outlined, size: 14, color: subtextColor),
                const SizedBox(width: 4),
                Text('${tenant.totalDocuments} docs', style: TextStyle(fontSize: 12, color: subtextColor)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
