import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

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
                  width: 48, height: 48,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [AppTheme.primary, Color(0xFF8B5CF6)]),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Center(child: Text('AD', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white))),
                ),
                const SizedBox(width: 12),
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Admin User', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
                    Text('admin@ragchat.com', style: TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
                  ],
                ),
              ],
            ),
          ]),
          const SizedBox(height: 16),

          // API Configuration — REAL data from service
          _section('API Configuration', [
            _settingField('API Base URL', api.baseUrl, Icons.language_rounded),
            const SizedBox(height: 12),
            _settingField('API Key', api.isConfigured ? 'Configured' : 'Not Set', Icons.key_rounded),
            const SizedBox(height: 12),
            const _settingField('Groq API Key', 'Set in .env file on server', Icons.vpn_key_rounded),
          ]),
          const SizedBox(height: 16),

          // Appearance
          _section('Appearance', [
            _toggleRow('Dark Mode', true, Icons.dark_mode_rounded),
            const SizedBox(height: 12),
            _colorRow('Accent Color'),
          ]),
          const SizedBox(height: 16),

          // About
          _section('About', [
            const _infoRow('Version', '1.0.0'),
            const Divider(color: AppTheme.border, height: 20),
            _infoRow('API Docs', '${api.baseUrl}/docs', icon: Icons.open_in_new_rounded),
          ]),
          const SizedBox(height: 16),

          // Logout
          InkWell(
            onTap: () async {
              await context.read<AuthService>().logout();
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

  Widget _settingField(String label, String value, IconData icon, {bool isMasked = false}) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppTheme.textSecondary),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
              Text(value, style: const TextStyle(fontSize: 14, color: AppTheme.textPrimary)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _toggleRow(String label, bool value, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppTheme.textSecondary),
        const SizedBox(width: 12),
        Text(label, style: const TextStyle(fontSize: 14, color: AppTheme.textPrimary)),
        const Spacer(),
        Switch(value: value, onChanged: (_) {}, activeColor: AppTheme.primary),
      ],
    );
  }

  Widget _colorRow(String label) {
    return Row(
      children: [
        const Icon(Icons.palette_rounded, size: 18, color: AppTheme.textSecondary),
        const SizedBox(width: 12),
        Text(label, style: const TextStyle(fontSize: 14, color: AppTheme.textPrimary)),
        const Spacer(),
        Container(
          width: 28, height: 28,
          decoration: const BoxDecoration(color: AppTheme.primary, shape: BoxShape.circle),
        ),
      ],
    );
  }

  Widget _infoRow(String label, String value, {IconData? icon}) {
    return Row(
      children: [
        Text(label, style: const TextStyle(fontSize: 14, color: AppTheme.textPrimary)),
        const Spacer(),
        if (value.isNotEmpty) Text(value, style: const TextStyle(fontSize: 14, color: AppTheme.textSecondary)),
        if (icon != null) Padding(
          padding: const EdgeInsets.only(left: 4),
          child: Icon(icon, size: 16, color: AppTheme.textSecondary),
        ),
      ],
    );
  }
}
