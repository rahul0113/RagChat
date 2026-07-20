import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../main.dart';

class Sidebar extends StatelessWidget {
  final int selectedIndex;
  final Function(int) onSelected;

  const Sidebar({
    super.key,
    required this.selectedIndex,
    required this.onSelected,
  });

  static const _icons = [
    Icons.dashboard_rounded,
    Icons.apartment_rounded,
    Icons.description_rounded,
    Icons.analytics_rounded,
    Icons.settings_rounded,
  ];

  static const _labels = [
    'Dashboard',
    'Tenants',
    'Documents',
    'Analytics',
    'Settings',
  ];

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? AppTheme.surfaceContainerLow : AppTheme.lightSurface;
    final textColor = isDark ? AppTheme.textPrimary : AppTheme.lightTextPrimary;
    final subtextColor = isDark ? AppTheme.textSecondary : AppTheme.lightTextSecondary;
    final borderColor = isDark ? AppTheme.border : AppTheme.lightBorder;
    final outlineColor = isDark ? AppTheme.outline : AppTheme.lightOutline;
    final surfaceHigh = isDark ? AppTheme.surfaceContainerHigh : AppTheme.lightSurfaceContainerHigh;

    return ValueListenableBuilder<Color>(
      valueListenable: accentColorNotifier,
      builder: (context, accentColor, _) {
        return Container(
          width: 260,
          decoration: BoxDecoration(
            color: bgColor,
            border: Border(right: BorderSide(color: borderColor, width: 1)),
          ),
          child: Column(
            children: [
              // Logo
              Container(
                padding: const EdgeInsets.all(24),
                child: Row(
                  children: [
                    Container(
                      width: 40, height: 40,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(colors: [accentColor, accentColor.withOpacity(0.7)]),
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: [BoxShadow(color: accentColor.withOpacity(0.2), blurRadius: 12)],
                      ),
                      child: const Icon(Icons.chat_bubble_rounded, color: Colors.white, size: 22),
                    ),
                    const SizedBox(width: 12),
                    Text('RagChat', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: textColor, letterSpacing: -0.02)),
                  ],
                ),
              ),
              Divider(color: borderColor, height: 1),
              const SizedBox(height: 8),
              ...List.generate(_icons.length, (i) => _navItem(i, accentColor, textColor, subtextColor, outlineColor, borderColor)),
              const Spacer(),
              Container(
                margin: const EdgeInsets.all(12),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: surfaceHigh.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: borderColor, width: 1),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 28, height: 28,
                      decoration: BoxDecoration(color: accentColor.withOpacity(0.15), borderRadius: BorderRadius.circular(6)),
                      child: Icon(Icons.person_rounded, size: 16, color: accentColor),
                    ),
                    const SizedBox(width: 8),
                    Expanded(child: Text('Admin', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: textColor))),
                    Text('v1.0', style: TextStyle(fontSize: 11, color: outlineColor)),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _navItem(int index, Color accentColor, Color textColor, Color subtextColor, Color outlineColor, Color borderColor) {
    final isSelected = selectedIndex == index;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      child: ListTile(
        leading: Icon(_icons[index], color: isSelected ? accentColor : outlineColor, size: 22),
        title: Text(
          _labels[index],
          style: TextStyle(
            color: isSelected ? textColor : subtextColor,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
            fontSize: 14,
          ),
        ),
        selected: isSelected,
        selectedTileColor: accentColor.withOpacity(0.1),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        dense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
        onTap: () => onSelected(index),
      ),
    );
  }
}
