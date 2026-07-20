import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'services/api_service.dart';
import 'services/auth_service.dart';
import 'screens/dashboard_screen.dart';
import 'screens/tenants_screen.dart';
import 'screens/tenant_detail_screen.dart';
import 'screens/documents_screen.dart';
import 'screens/analytics_screen.dart';
import 'screens/settings_screen.dart';
import 'theme/app_theme.dart';
import 'widgets/sidebar.dart';

// Global theme state
final ValueNotifier<bool> darkModeNotifier = ValueNotifier(true);
final ValueNotifier<Color> accentColorNotifier = ValueNotifier(AppTheme.primary);

void main() {
  runApp(const RagChatAdmin());
}

class RagChatAdmin extends StatelessWidget {
  const RagChatAdmin({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthService()),
        ChangeNotifierProvider(create: (_) => ApiService()),
      ],
      child: ValueListenableBuilder<bool>(
        valueListenable: darkModeNotifier,
        builder: (context, isDark, _) {
          return MaterialApp(
            title: 'RagChat Admin',
            debugShowCheckedModeBanner: false,
            themeMode: isDark ? ThemeMode.dark : ThemeMode.light,
            darkTheme: AppTheme.darkTheme,
            theme: AppTheme.lightTheme,
            home: const AdminShell(),
          );
        },
      ),
    );
  }
}

class AdminShell extends StatefulWidget {
  const AdminShell({super.key});

  @override
  State<AdminShell> createState() => _AdminShellState();
}

class _AdminShellState extends State<AdminShell> {
  int _selectedIndex = 0;
  String? _selectedTenantId;

  final List<String> _titles = [
    'Dashboard',
    'Tenants',
    'Documents',
    'Analytics',
    'Settings',
  ];

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;

    return Scaffold(
      body: Row(
        children: [
          if (!isMobile) Sidebar(
            selectedIndex: _selectedIndex,
            onSelected: (index) {
              setState(() {
                _selectedIndex = index;
                _selectedTenantId = null;
              });
            },
          ),
          Expanded(child: _buildPage()),
        ],
      ),
      drawer: isMobile ? Drawer(
        child: Sidebar(
          selectedIndex: _selectedIndex,
          onSelected: (index) {
            setState(() {
              _selectedIndex = index;
              _selectedTenantId = null;
            });
            Navigator.pop(context);
          },
        ),
      ) : null,
      appBar: isMobile ? AppBar(
        title: Text(_selectedTenantId != null ? 'Tenant Details' : _titles[_selectedIndex]),
        leading: Builder(
          builder: (ctx) => IconButton(
            icon: const Icon(Icons.menu),
            onPressed: () => Scaffold.of(ctx).openDrawer(),
          ),
        ),
      ) : null,
    );
  }

  Widget _buildPage() {
    if (_selectedTenantId != null) {
      return TenantDetailScreen(
        tenantId: _selectedTenantId!,
        onBack: () => setState(() => _selectedTenantId = null),
      );
    }

    switch (_selectedIndex) {
      case 0: return const DashboardScreen();
      case 1: return TenantsScreen(onTenantSelected: (id) => setState(() => _selectedTenantId = id));
      case 2: return const DocumentsScreen();
      case 3: return const AnalyticsScreen();
      case 4: return const SettingsScreen();
      default: return const DashboardScreen();
    }
  }
}
