import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'services/api_service.dart';
import 'services/auth_service.dart';
import 'screens/dashboard_screen.dart';
import 'screens/tenants_screen.dart';
import 'screens/tenant_detail_screen.dart';
import 'screens/documents_screen.dart';
import 'screens/analytics_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/landing_screen.dart';
import 'screens/chat_screen.dart';
import 'screens/upload_screen.dart';
import 'theme/app_theme.dart';
import 'widgets/sidebar.dart';

// Global theme state
final ValueNotifier<bool> darkModeNotifier = ValueNotifier(true);
final ValueNotifier<Color> accentColorNotifier = ValueNotifier(AppTheme.primary);

// Navigation channel for Android widgets/tiles
const _navChannel = MethodChannel('com.ragchat.admin/navigation');

void main() {
  WidgetsFlutterBinding.ensureInitialized();
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
            home: const LandingScreen(),
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
  bool _showChat = false;
  bool _showUpload = false;

  final List<String> _titles = [
    'Dashboard',
    'Tenants',
    'Documents',
    'Analytics',
    'Settings',
  ];

  @override
  void initState() {
    super.initState();
    _setupNavigationListener();
  }

  void _setupNavigationListener() {
    // Handle navigation from Android widgets/tiles (method channel)
    _navChannel.setMethodCallHandler((call) async {
      if (call.method == 'navigateTo') {
        final destination = call.arguments as String? ?? 'dashboard';
        _handleNavigation(destination);
      }
    });

    // Check for initial destination from cold start
    if (Platform.isAndroid) {
      _navChannel.invokeMethod<String>('getInitialDestination').then((dest) {
        if (dest != null && dest != 'dashboard') {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _handleNavigation(dest);
          });
        }
      }).catchError((_) {});
    }
  }

  void _handleNavigation(String destination) {
    switch (destination) {
      case 'chat':
        setState(() {
          _showChat = true;
          _showUpload = false;
          _selectedIndex = 0;
          _selectedTenantId = null;
        });
        break;
      case 'upload':
        setState(() {
          _showUpload = true;
          _showChat = false;
          _selectedIndex = 0;
          _selectedTenantId = null;
        });
        break;
      case 'documents':
        setState(() {
          _selectedIndex = 2;
          _selectedTenantId = null;
          _showChat = false;
          _showUpload = false;
        });
        break;
      default:
        setState(() {
          _selectedIndex = 0;
          _selectedTenantId = null;
          _showChat = false;
          _showUpload = false;
        });
    }
  }

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
                _showChat = false;
                _showUpload = false;
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
              _showChat = false;
              _showUpload = false;
            });
            Navigator.pop(context);
          },
        ),
      ) : null,
      appBar: isMobile ? AppBar(
        title: Text(
          _showChat ? 'Chat' :
          _showUpload ? 'Upload Document' :
          _selectedTenantId != null ? 'Tenant Details' : _titles[_selectedIndex]
        ),
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
    // Show chat screen when launched from widget/tile
    if (_showChat) {
      return ChatScreen(onBack: () => setState(() => _showChat = false));
    }

    // Show upload screen when launched from widget/tile
    if (_showUpload) {
      return UploadScreen(onBack: () => setState(() => _showUpload = false));
    }

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
