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

  @override
  void initState() {
    super.initState();
    final api = context.read<ApiService>();
    _urlCtrl = TextEditingController(text: api.baseUrl);
    _apiKeyCtrl = TextEditingController(text: '');
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
      const SnackBar(content: Text('API configuration saved'), backgroundColor: AppTheme.success),
    );
  }

  void _saveProfile() {
    setState(() => _editingProfile = false);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Profile updated'), backgroundColor: AppTheme.success),
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

          // Profile Section
          _section('Profile', [
            Row(
              children: [
                Container(
                  width: 56, height: 56,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [AppTheme.primary, Color(0xFF8B5CF6)]),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Center(
                    child: Text(
                      _nameCtrl.text.isNotEmpty ? _nameCtrl.text.substring(0, 2).toUpperCase() : 'AD',
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
              TextField(
                controller: _nameCtrl,
                decoration: const InputDecoration(labelText: 'Name'),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _emailCtrl,
                decoration: const InputDecoration(labelText: 'Email'),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _saveProfile,
                  child: const Text('Save Profile'),
                ),
              ),
            ],
          ]),
          const SizedBox(height: 16),

          // API Configuration Section
          _section('API Configuration', [
            if (!_editingApi) ...[
              _infoRow(Icons.language_rounded, 'API Base URL', api.baseUrl),
              const SizedBox(height: 12),
              _infoRow(Icons.key_rounded, 'API Key', api.isConfigured ? 'Configured' : 'Not Set'),
              const SizedBox(height: 12),
              _infoRow(Icons.vpn_key_rounded, 'Groq API Key', 'Set in .env on server'),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => setState(() => _editingApi = true),
                  icon: const Icon(Icons.edit_rounded, size: 16),
                  label: const Text('Configure'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.primary,
                    side: const BorderSide(color: AppTheme.primary),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
            ] else ...[
              TextField(
                controller: _urlCtrl,
                decoration: const InputDecoration(labelText: 'API Base URL', hintText: 'http://localhost:8000/api'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _apiKeyCtrl,
                decoration: const InputDecoration(labelText: 'API Key', hintText: 'rc_...'),
                obscureText: true,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => setState(() => _editingApi = false),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _saveApiConfig,
                      child: const Text('Save'),
                    ),
                  ),
                ],
              ),
            ],
          ]),
          const SizedBox(height: 16),

          // Appearance Section
          _section('Appearance', [
            // Dark Mode Toggle
            Row(
              children: [
                const Icon(Icons.dark_mode_rounded, size: 20, color: AppTheme.textSecondary),
                const SizedBox(width: 12),
                const Expanded(child: Text('Dark Mode', style: TextStyle(fontSize: 14, color: AppTheme.textPrimary))),
                Switch(
                  value: _darkMode,
                  onChanged: (v) => setState(() => _darkMode = v),
                  activeColor: AppTheme.primary,
                ),
              ],
            ),
            const Divider(color: AppTheme.border, height: 24),
            // Accent Color
            const Row(
              children: [
                Icon(Icons.palette_rounded, size: 20, color: AppTheme.textSecondary),
                SizedBox(width: 12),
                Text('Accent Color', style: TextStyle(fontSize: 14, color: AppTheme.textPrimary)),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _colorOption(AppTheme.primary),
                _colorOption(const Color(0xFF8B5CF6)),
                _colorOption(const Color(0xFF3B82F6)),
                _colorOption(const Color(0xFF22C55E)),
                _colorOption(const Color(0xFFF59E0B)),
                _colorOption(const Color(0xFFEC4899)),
                _colorOption(const Color(0xFF14B8A6)),
                _colorOption(const Color(0xFFEF4444)),
              ],
            ),
          ]),
          const SizedBox(height: 16),

          // About Section
          _section('About', [
            _infoRow(Icons.info_outline_rounded, 'Version', '1.0.0'),
            const Divider(color: AppTheme.border, height: 20),
            InkWell(
              onTap: () {},
              child: _infoRow(Icons.open_in_new_rounded, 'API Docs', '${api.baseUrl}/docs'),
            ),
            const Divider(color: AppTheme.border, height: 20),
            _infoRow(Icons.code_rounded, 'Source', 'github.com/rahul0113/RagChat'),
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
                      onPressed: () {
                        Navigator.pop(ctx);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Logged out'), backgroundColor: AppTheme.info),
                        );
                      },
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
              decoration: BoxDecoration(
                color: AppTheme.error.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.error.withOpacity(0.3)),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.logout_rounded, color: AppTheme.error, size: 18),
                  SizedBox(width: 8),
                  Text('Logout', style: TextStyle(color: AppTheme.error, fontWeight: FontWeight.w600)),
                ],
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
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppTheme.textSecondary),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
            Text(value, style: const TextStyle(fontSize: 14, color: AppTheme.textPrimary)),
          ],
        ),
      ],
    );
  }

  Widget _colorOption(Color color) {
    final isSelected = _accentColor.value == color.value;
    return GestureDetector(
      onTap: () => setState(() => _accentColor = color),
      child: Container(
        width: 36, height: 36,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(
            color: isSelected ? Colors.white : Colors.transparent,
            width: 3,
          ),
          boxShadow: isSelected ? [
            BoxShadow(color: color.withOpacity(0.5), blurRadius: 8, spreadRadius: 2),
          ] : null,
        ),
        child: isSelected ? const Icon(Icons.check, color: Colors.white, size: 18) : null,
      ),
    );
  }
}
