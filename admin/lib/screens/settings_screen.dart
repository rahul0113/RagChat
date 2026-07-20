import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late TextEditingController _urlCtrl;
  late TextEditingController _apiKeyCtrl;
  late TextEditingController _nameCtrl;
  late TextEditingController _emailCtrl;
  bool _darkMode = true;
  Color _accentColor = AppTheme.primary;
  bool _editingProfile = false;
  bool _editingApi = false;
  bool _testingConnection = false;

  @override
  void initState() {
    super.initState();
    final api = context.read<ApiService>();
    _urlCtrl = TextEditingController(text: api.baseUrl);
    _apiKeyCtrl = TextEditingController();
    _nameCtrl = TextEditingController(text: 'Admin User');
    _emailCtrl = TextEditingController(text: 'admin@ragchat.com');
  }

  @override
  void dispose() {
    _urlCtrl.dispose();
    _apiKeyCtrl.dispose();
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    super.dispose();
  }

  void _saveApiConfig() {
    final api = context.read<ApiService>();
    api.configure(baseUrl: _urlCtrl.text.trim(), apiKey: _apiKeyCtrl.text.trim());
    setState(() => _editingApi = false);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('API configuration saved & connected'), backgroundColor: AppTheme.success),
    );
  }

  Future<void> _testConnection() async {
    setState(() => _testingConnection = true);
    final api = context.read<ApiService>();
    try {
      api.configure(baseUrl: _urlCtrl.text.trim(), apiKey: _apiKeyCtrl.text.trim());
      await api.getTenants();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Connection successful!'), backgroundColor: AppTheme.success),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Connection failed: $e'), backgroundColor: AppTheme.error),
        );
      }
    } finally {
      if (mounted) setState(() => _testingConnection = false);
    }
  }

  void _saveProfile() {
    setState(() => _editingProfile = false);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Profile updated'), backgroundColor: AppTheme.success),
    );
  }

  void _applyAccentColor(Color color) {
    setState(() => _accentColor = color);
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
    final api = context.watch<ApiService>();

    return Padding(
      padding: const EdgeInsets.all(24),
      child: ListView(
        children: [
          const Text('Settings', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
          const SizedBox(height: 24),

          // Profile
          _section('Profile', [
            Row(
              children: [
                Container(
                  width: 56, height: 56,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: [_accentColor, _accentColor.withOpacity(0.7)]),
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
                      Text(_nameCtrl.text, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
                      Text(_emailCtrl.text, style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
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

          // API Configuration
          _section('API Configuration', [
            if (!_editingApi) ...[
              _infoRow(Icons.language_rounded, 'API Base URL', api.baseUrl),
              const SizedBox(height: 12),
              _infoRow(Icons.key_rounded, 'API Key', api.isConfigured ? 'Connected' : 'Not Set'),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => setState(() => _editingApi = true),
                      icon: const Icon(Icons.edit_rounded, size: 16),
                      label: const Text('Configure'),
                      style: OutlinedButton.styleFrom(foregroundColor: AppTheme.primary, side: const BorderSide(color: AppTheme.primary), padding: const EdgeInsets.symmetric(vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                    ),
                  ),
                ],
              ),
            ] else ...[
              TextField(controller: _urlCtrl, decoration: const InputDecoration(labelText: 'API Base URL', hintText: 'http://localhost:8000/api')),
              const SizedBox(height: 12),
              TextField(controller: _apiKeyCtrl, decoration: const InputDecoration(labelText: 'API Key (optional)', hintText: 'rc_...'), obscureText: true),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _testingConnection ? null : _testConnection,
                  icon: _testingConnection
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.info))
                      : const Icon(Icons.wifi_find_rounded, size: 16),
                  label: Text(_testingConnection ? 'Testing...' : 'Test Connection'),
                  style: OutlinedButton.styleFrom(foregroundColor: AppTheme.info, side: const BorderSide(color: AppTheme.info), padding: const EdgeInsets.symmetric(vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(child: OutlinedButton(onPressed: () => setState(() => _editingApi = false), child: const Text('Cancel'))),
                  const SizedBox(width: 12),
                  Expanded(child: ElevatedButton(onPressed: _saveApiConfig, child: const Text('Save & Connect'))),
                ],
              ),
            ],
          ]),
          const SizedBox(height: 16),

          // Appearance
          _section('Appearance', [
            // Theme selector
            Row(
              children: const [
                Icon(Icons.style_rounded, size: 20, color: AppTheme.outline),
                SizedBox(width: 12),
                Text('Theme', style: TextStyle(fontSize: 14, color: AppTheme.textPrimary)),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _themePreset('Lumina', const Color(0xFF14121F), const Color(0xFFC0C1FF), 'Default dark'),
                _themePreset('Midnight', const Color(0xFF0A0A1A), const Color(0xFF6366F1), 'Deep dark'),
                _themePreset('Ocean', const Color(0xFF0B1628), const Color(0xFF38BDF8), 'Blue tones'),
                _themePreset('Forest', const Color(0xFF0A1A12), const Color(0xFF22C55E), 'Green tones'),
                _themePreset('Sunset', const Color(0xFF1A0F0A), const Color(0xFFF97316), 'Warm tones'),
                _themePreset('Lavender', const Color(0xFF16101F), const Color(0xFFA78BFA), 'Purple tones'),
              ],
            ),
            const SizedBox(height: 16),

            // Dark mode
            Row(
              children: [
                Icon(_darkMode ? Icons.dark_mode_rounded : Icons.light_mode_rounded, size: 20, color: AppTheme.outline),
                const SizedBox(width: 12),
                const Expanded(child: Text('Dark Mode', style: TextStyle(fontSize: 14, color: AppTheme.textPrimary))),
                Switch(
                  value: _darkMode,
                  onChanged: (v) {
                    setState(() => _darkMode = v);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(v ? 'Dark mode enabled — Lumina Interface' : 'Light mode enabled'),
                        backgroundColor: v ? _accentColor : AppTheme.info,
                        duration: const Duration(seconds: 2),
                      ),
                    );
                  },
                  activeColor: _accentColor,
                ),
              ],
            ),
            const Divider(color: AppTheme.border, height: 24),

            // Accent color
            Row(
              children: const [
                Icon(Icons.palette_rounded, size: 20, color: AppTheme.outline),
                SizedBox(width: 12),
                Text('Accent Color', style: TextStyle(fontSize: 14, color: AppTheme.textPrimary)),
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
                color: _accentColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: _accentColor.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  Icon(Icons.check_circle_rounded, color: _accentColor, size: 18),
                  const SizedBox(width: 8),
                  Text('Active accent: #${_accentColor.value.toRadixString(16).substring(2).toUpperCase()}',
                      style: TextStyle(color: _accentColor, fontSize: 13, fontWeight: FontWeight.w500)),
                ],
              ),
            ),
          ]),
          const SizedBox(height: 16),

          // About
          _section('About', [
            _infoRow(Icons.info_outline_rounded, 'Version', '1.0.0'),
            const Divider(color: AppTheme.border, height: 20),
            _infoRow(Icons.code_rounded, 'Source', 'github.com/rahul0113/RagChat'),
            const Divider(color: AppTheme.border, height: 20),
            _infoRow(Icons.storage_rounded, 'Backend', api.baseUrl),
          ]),
          const SizedBox(height: 24),

          // Logout
          InkWell(
            onTap: () {
              showDialog(
                context: context,
                builder: (ctx) => AlertDialog(
                  backgroundColor: AppTheme.surface,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  title: const Text('Logout', style: TextStyle(color: AppTheme.textPrimary)),
                  content: const Text('Are you sure you want to logout?', style: TextStyle(color: AppTheme.textSecondary)),
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
  }

  Widget _section(String title, List<Widget> children) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: AppTheme.card, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppTheme.border)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
        const SizedBox(height: 16),
        ...children,
      ]),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppTheme.textSecondary),
        const SizedBox(width: 12),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
          Text(value, style: const TextStyle(fontSize: 14, color: AppTheme.textPrimary)),
        ]),
      ],
    );
  }

  Widget _themePreset(String name, Color bg, Color accent, String subtitle) {
    final isSelected = _accentColor.value == accent.value;
    return GestureDetector(
      onTap: () {
        setState(() => _accentColor = accent);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$name theme selected'), backgroundColor: accent, duration: const Duration(seconds: 1)),
        );
      },
      child: Container(
        width: 120,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? accent : AppTheme.border,
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
            Text(name, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: isSelected ? accent : AppTheme.textPrimary)),
            const SizedBox(height: 2),
            Text(subtitle, style: TextStyle(fontSize: 10, color: AppTheme.textSecondary.withOpacity(0.7))),
          ],
        ),
      ),
    );
  }

  Widget _colorOption(Color color, String name) {
    final isSelected = _accentColor.value == color.value;
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
