import 'dart:developer' as developer;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:responsive_framework/responsive_framework.dart';

import 'services/api_service.dart';
import 'services/auth_service.dart';
import 'services/error_handler.dart';
import 'screens/dashboard_screen.dart';
import 'screens/tenants_screen.dart';
import 'screens/tenant_detail_screen.dart';
import 'screens/documents_screen.dart';
import 'screens/analytics_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/landing_screen.dart';
import 'theme/app_theme.dart';
import 'widgets/sidebar.dart';

// Global theme state
final ValueNotifier<bool> darkModeNotifier = ValueNotifier(true);
final ValueNotifier<Color> accentColorNotifier = ValueNotifier(AppTheme.primary);

void main() {
  // Global error handler for Flutter framework errors
  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
    developer.log(
      'Flutter Error: ${details.exception}',
      error: details.exception,
      stackTrace: details.stack,
    );
  };

  // Global error handler for async errors
  WidgetsBinding.instance.platformDispatcher.onError = (error, stackTrace) {
    developer.log(
      'Platform Error: $error',
      error: error,
      stackTrace: stackTrace,
    );
    return true;
  };

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
      child: ValueListenableBuilder2<bool, Color>(
        valueListenable1: darkModeNotifier,
        valueListenable2: accentColorNotifier,
        builder: (context, isDark, accentColor, _) {
          return MaterialApp(
            title: 'RagChat Admin',
            debugShowCheckedModeBanner: false,
            themeMode: isDark ? ThemeMode.dark : ThemeMode.light,
            darkTheme: AppTheme.darkTheme,
            theme: AppTheme.lightTheme,
            builder: (context, child) => ResponsiveBreakpoints.builder(
              child: child!,
              breakpoints: const [
                Breakpoint(start: 0, end: 450, name: MOBILE),
                Breakpoint(start: 451, end: 800, name: TABLET),
                Breakpoint(start: 801, end: 1920, name: DESKTOP),
                Breakpoint(start: 1921, end: 3840, name: '4K'),
              ],
            ),
            home: const LandingScreen(),
          );
        },
      ),
    );
  }
}

/// Helper widget to combine two ValueListenable
class ValueListenableBuilder2<A, B> extends StatelessWidget {
  final ValueNotifier<A> valueListenable1;
  final ValueNotifier<B> valueListenable2;
  final Widget Function(BuildContext, A, B, Widget?) builder;

  const ValueListenableBuilder2({
    super.key,
    required this.valueListenable1,
    required this.valueListenable2,
    required this.builder,
  });

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<A>(
      valueListenable: valueListenable1,
      builder: (context, a, _) {
        return ValueListenableBuilder<B>(
          valueListenable: valueListenable2,
          builder: (context, b, child) => builder(context, a, b, child),
        );
      },
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
    final isMobile = ResponsiveBreakpoints.of(context).isMobile;

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
