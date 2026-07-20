import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../main.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late TextEditingController _nameCtrl;
  late TextEditingController _emailCtrl;
  bool _editingProfile = false;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: 'Admin User');
    _emailCtrl = TextEditingController(text: 'admin@ragchat.com');
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    super.dispose();
  }

  void _saveProfile() {
    setState(() => _editingProfile = false);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Profile updated'), backgroundColor: AppTheme.success),
    );
  }

  void _applyAccentColor(Color color) {
    accentColorNotifier.value = color;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Accent color updated to #${color.value.toRadixString(16).substring(2).toUpperCase()}'),
        backgroundColor: color,
        duration: const Duration(seconds: 1),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Color>(
      valueListenable: accentColorNotifier,
      builder: (context, accentColor, _) {
        return ValueListenableBuilder<bool>(
          valueListenable: darkModeNotifier,
          builder: (context, darkMode, _) {
            final isDark = darkMode;
            final textColor = isDark ? AppTheme.textPrimary : AppTheme.lightTextPrimary;
            final subtextColor = isDark ? AppTheme.textSecondary : AppTheme.lightTextSecondary;
            final bgColor = isDark ? AppTheme.card : AppTheme.lightCard;
            final surfaceBg = isDark ? AppTheme.surface : AppTheme.lightSurface;
            final surfaceHigh = isDark ? AppTheme.surfaceContainerHigh : AppTheme.lightSurfaceContainerHigh;
            final borderColor = isDark ? AppTheme.border : AppTheme.lightBorder;
            final outlineColor = isDark ? AppTheme.outline : AppTheme.lightOutline;

            return Padding(
              padding: const EdgeInsets.all(24),
              child: ListView(
                children: [
                  Text('Settings', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700, color: textColor)),
                  const SizedBox(height: 24),

                  // Profile
                  _section('Profile', textColor, bgColor, borderColor, [
                    Row(
                      children: [
                        Container(
                          width: 56, height: 56,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(colors: [accentColor, accentColor.withOpacity(0.7)]),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Center(
                            child: Text(
                              _nameCtrl.text.isNotEmpty ? _nameCtrl.text.substring(0, _nameCtrl.text.length < 2 ? _nameCtrl.text.length : 2).toUpperCase() : 'AD',
                              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: Colors.white),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(_nameCtrl.text, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: textColor)),
                              Text(_emailCtrl.text, style: TextStyle(fontSize: 13, color: subtextColor)),
                            ],
                          ),
                        ),
                        TextButton.icon(
                          onPressed: () => setState(() => _editingProfile = !_editingProfile),
                          icon: Icon(_editingProfile ? Icons.close_rounded : Icons.edit_rounded, size: 16),
                          label: Text(_editingProfile ? 'Cancel' : 'Edit'),
                        ),
                      ],
                    ),
                    if (_editingProfile) ...[
                      const SizedBox(height: 16),
                      TextField(controller: _nameCtrl, decoration: const InputDecoration(labelText: 'Name'), onChanged: (_) => setState(() {})),
                      const SizedBox(height: 12),
                      TextField(controller: _emailCtrl, decoration: const InputDecoration(labelText: 'Email')),
                      const SizedBox(height: 12),
                      SizedBox(width: double.infinity, child: ElevatedButton(onPressed: _saveProfile, child: const Text('Save Profile'))),
                    ],
                  ]),
                  const SizedBox(height: 16),

                  // Appearance
                  _section('Appearance', textColor, bgColor, borderColor, [
                    // Theme selector
                    Row(
                      children: [
                        Icon(Icons.style_rounded, size: 20, color: outlineColor),
                        const SizedBox(width: 12),
                        Text('Theme', style: TextStyle(fontSize: 14, color: textColor)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _themePreset('Lumina', const Color(0xFF14121F), const Color(0xFFC0C1FF), 'Default dark', textColor, subtextColor, borderColor, darkMode),
                        _themePreset('Midnight', const Color(0xFF0A0A1A), const Color(0xFF6366F1), 'Deep dark', textColor, subtextColor, borderColor, darkMode),
                        _themePreset('Ocean', const Color(0xFF0B1628), const Color(0xFF38BDF8), 'Blue tones', textColor, subtextColor, borderColor, darkMode),
                        _themePreset('Forest', const Color(0xFF0A1A12), const Color(0xFF22C55E), 'Green tones', textColor, subtextColor, borderColor, darkMode),
                        _themePreset('Sunset', const Color(0xFF1A0F0A), const Color(0xFFF97316), 'Warm tones', textColor, subtextColor, borderColor, darkMode),
                        _themePreset('Lavender', const Color(0xFF16101F), const Color(0xFFA78BFA), 'Purple tones', textColor, subtextColor, borderColor, darkMode),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Dark mode toggle
                    Row(
                      children: [
                        Icon(darkMode ? Icons.dark_mode_rounded : Icons.light_mode_rounded, size: 20, color: outlineColor),
                        const SizedBox(width: 12),
                        Expanded(child: Text('Dark Mode', style: TextStyle(fontSize: 14, color: textColor))),
                        Switch(
                          value: darkMode,
                          onChanged: (v) {
                            darkModeNotifier.value = v;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(v ? 'Dark mode enabled — Lumina Interface' : 'Light mode enabled — clean white UI'),
                                backgroundColor: v ? accentColor : AppTheme.info,
                                duration: const Duration(seconds: 2),
                              ),
                            );
                          },
                          activeColor: accentColor,
                        ),
                      ],
                    ),
                    Divider(color: borderColor, height: 24),

                    // Accent color
                    Row(
                      children: [
                        Icon(Icons.palette_rounded, size: 20, color: outlineColor),
                        const SizedBox(width: 12),
                        Text('Accent Color', style: TextStyle(fontSize: 14, color: textColor)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        _colorOption(const Color(0xFFC0C1FF), 'Lumina Indigo'),
                        _colorOption(const Color(0xFF8083FF), 'Primary Container'),
                        _colorOption(const Color(0xFFDDB7FF), 'Lavender'),
                        _colorOption(const Color(0xFF4AE176), 'Emerald'),
                        _colorOption(const Color(0xFFF59E0B), 'Amber'),
                        _colorOption(const Color(0xFFEC4899), 'Pink'),
                        _colorOption(const Color(0xFF14B8A6), 'Teal'),
                        _colorOption(const Color(0xFFFFB4AB), 'Error Red'),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: accentColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: accentColor.withOpacity(0.3)),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.check_circle_rounded, color: accentColor, size: 18),
                          const SizedBox(width: 8),
                          Text('Active accent: #${accentColor.value.toRadixString(16).substring(2).toUpperCase()}',
                              style: TextStyle(color: accentColor, fontSize: 13, fontWeight: FontWeight.w500)),
                        ],
                      ),
                    ),
                  ]),
                  const SizedBox(height: 16),

                  // About
                  _section('About', textColor, bgColor, borderColor, [
                    _infoRow(Icons.info_outline_rounded, 'Version', '1.0.0', textColor, subtextColor),
                    Divider(color: borderColor, height: 20),
                    _infoRow(Icons.code_rounded, 'Source', 'github.com/rahul0113/RagChat', textColor, subtextColor),
                    Divider(color: borderColor, height: 20),
                    _infoRow(Icons.storage_rounded, 'Backend', 'ragchat-tsqf.onrender.com', textColor, subtextColor),
                  ]),
                  const SizedBox(height: 24),

                  // Logout
                  InkWell(
                    onTap: () {
                      showDialog(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          backgroundColor: surfaceBg,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          title: Text('Logout', style: TextStyle(color: textColor)),
                          content: Text('Are you sure you want to logout?', style: TextStyle(color: subtextColor)),
                          actions: [
                            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
                            ElevatedButton(
                              onPressed: () { Navigator.pop(ctx); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Logged out'), backgroundColor: AppTheme.info)); },
                              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.error),
                              child: const Text('Logout'),
                            ),
                          ],
                        ),
                      );
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(color: AppTheme.error.withOpacity(0.1), borderRadius: BorderRadius.circular(12), border: Border.all(color: AppTheme.error.withOpacity(0.3))),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [Icon(Icons.logout_rounded, color: AppTheme.error, size: 18), SizedBox(width: 8), Text('Logout', style: TextStyle(color: AppTheme.error, fontWeight: FontWeight.w600))],
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _section(String title, Color textColor, Color bgColor, Color borderColor, List<Widget> children) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(16), border: Border.all(color: borderColor)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: textColor)),
        const SizedBox(height: 16),
        ...children,
      ]),
    );
  }

  Widget _infoRow(IconData icon, String label, String value, Color textColor, Color subtextColor) {
    return Row(
      children: [
        Icon(icon, size: 18, color: subtextColor),
        const SizedBox(width: 12),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: TextStyle(fontSize: 12, color: subtextColor)),
          Text(value, style: TextStyle(fontSize: 14, color: textColor)),
        ]),
      ],
    );
  }

  Widget _themePreset(String name, Color bg, Color accent, String subtitle, Color textColor, Color subtextColor, Color borderColor, bool isDark) {
    final isSelected = accentColorNotifier.value.value == accent.value;
    // In light mode, use a lighter tinted version of the accent color as background
    final cardBg = isDark ? bg : Color.lerp(Colors.white, accent, 0.08)!;
    return GestureDetector(
      onTap: () {
        accentColorNotifier.value = accent;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$name theme selected'), backgroundColor: accent, duration: const Duration(seconds: 1)),
        );
      },
      child: Container(
        width: 120,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? accent : borderColor,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(width: 12, height: 12, decoration: BoxDecoration(color: accent, shape: BoxShape.circle)),
                const SizedBox(width: 6),
                if (isSelected) Icon(Icons.check_rounded, size: 14, color: accent) else const Spacer(),
              ],
            ),
            const SizedBox(height: 8),
            Text(name, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: isSelected ? accent : textColor)),
            const SizedBox(height: 2),
            Text(subtitle, style: TextStyle(fontSize: 10, color: subtextColor.withOpacity(0.7))),
          ],
        ),
      ),
    );
  }

  Widget _colorOption(Color color, String name) {
    final isSelected = accentColorNotifier.value.value == color.value;
    return GestureDetector(
      onTap: () => _applyAccentColor(color),
      child: Tooltip(
        message: name,
        child: Container(
          width: 36, height: 36,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(color: isSelected ? Colors.white : Colors.transparent, width: 3),
            boxShadow: isSelected ? [BoxShadow(color: color.withOpacity(0.5), blurRadius: 8, spreadRadius: 2)] : null,
          ),
          child: isSelected ? const Icon(Icons.check, color: Colors.white, size: 18) : null,
        ),
      ),
    );
  }
}
