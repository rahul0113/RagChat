import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

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
    return Container(
      width: 260,
      decoration: const BoxDecoration(
        color: AppTheme.surface,
        border: Border(right: BorderSide(color: AppTheme.border)),
      ),
      child: Column(
        children: [
          // Logo
          Container(
            padding: const EdgeInsets.all(24),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [AppTheme.primary, Color(0xFF8B5CF6)],
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.chat_bubble_rounded,
                      color: Colors.white, size: 22),
                ),
                const SizedBox(width: 12),
                const Text(
                  'RagChat',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary,
                  ),
                ),
              ],
            ),
          ),
          const Divider(color: AppTheme.border, height: 1),
          const SizedBox(height: 8),
          // Nav items
          ...List.generate(_icons.length, (i) => _navItem(i)),
          const Spacer(),
          // Footer
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'v1.0.0',
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _navItem(int index) {
    final isSelected = selectedIndex == index;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      child: ListTile(
        leading: Icon(
          _icons[index],
          color: isSelected ? AppTheme.primary : AppTheme.textSecondary,
          size: 22,
        ),
        title: Text(
          _labels[index],
          style: TextStyle(
            color: isSelected ? AppTheme.textPrimary : AppTheme.textSecondary,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
            fontSize: 14,
          ),
        ),
        selected: isSelected,
        selectedTileColor: AppTheme.primary.withOpacity(0.1),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        dense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
        onTap: () => onSelected(index),
      ),
    );
  }
}
