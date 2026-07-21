import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  final hasCompletedOnboarding = prefs.getBool('onboarding_complete') ?? false;
  runApp(RagChatAdmin(hasCompletedOnboarding: hasCompletedOnboarding));
}

class RagChatAdmin extends StatelessWidget {
  final bool hasCompletedOnboarding;
  const RagChatAdmin({super.key, required this.hasCompletedOnboarding});

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
            home: hasCompletedOnboarding ? const AdminShell() : const LandingScreen(),
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

class _AdminShellState extends State<AdminShell> with SingleTickerProviderStateMixin {
  int _selectedIndex = 0;
  String? _selectedTenantId;
  bool _showChat = false;
  bool _showUpload = false;
  bool _fabOpen = false;
  bool _keyboardVisible = false;
  late AnimationController _fabController;
  late Animation<double> _fabAnimation;

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
    _fabController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
    _fabAnimation = CurvedAnimation(parent: _fabController, curve: Curves.easeOut);
    _setupNavigationListener();
  }

  @override
  void dispose() {
    _fabController.dispose();
    super.dispose();
  }

  void _setupNavigationListener() {
    _navChannel.setMethodCallHandler((call) async {
      if (call.method == 'navigateTo') {
        final destination = call.arguments as String? ?? 'dashboard';
        _handleNavigation(destination);
      }
    });

    if (!kIsWeb) {
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

  void _navigateTo(int index) {
    setState(() {
      _selectedIndex = index;
      _selectedTenantId = null;
      _showChat = false;
      _showUpload = false;
    });
  }

  void _toggleFab() {
    setState(() => _fabOpen = !_fabOpen);
    if (_fabOpen) {
      _fabController.forward();
    } else {
      _fabController.reverse();
    }
  }

  void _closeFab() {
    if (_fabOpen) {
      setState(() => _fabOpen = false);
      _fabController.reverse();
    }
  }

  String _currentTitle() {
    if (_showChat) return 'Chat';
    if (_showUpload) return 'Upload Document';
    if (_selectedTenantId != null) return 'Tenant Details';
    return _titles[_selectedIndex];
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;
    final keyboardOpen = MediaQuery.of(context).viewInsets.bottom > 0;

    // Auto-close FAB when keyboard opens
    if (keyboardOpen && _fabOpen) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _fabOpen) _closeFab();
      });
    }

    return Scaffold(
      body: Stack(
        children: [
          Row(
            children: [
              if (!isMobile) Sidebar(
                selectedIndex: _selectedIndex,
                onSelected: _navigateTo,
                onChat: () => setState(() {
                  _showChat = true;
                  _showUpload = false;
                  _selectedTenantId = null;
                }),
              ),
              Expanded(child: _buildPage()),
            ],
          ),

          // FAB overlay backdrop
          if (isMobile && _fabOpen)
            GestureDetector(
              onTap: _closeFab,
              child: AnimatedBuilder(
                animation: _fabAnimation,
                builder: (context, child) {
                  return Container(
                    color: Colors.black.withOpacity(0.4 * _fabAnimation.value),
                  );
                },
              ),
            ),
        ],
      ),
      appBar: isMobile ? AppBar(
        title: Text(_currentTitle()),
        automaticallyImplyLeading: false,
      ) : null,
      // Hide FAB when keyboard is open on mobile
      floatingActionButton: isMobile
          ? (keyboardOpen
              ? null
              : Padding(
                  padding: const EdgeInsets.only(bottom: 72),
                  child: _buildFabMenu(),
                ))
          : _buildDesktopFab(),
    );
  }

  Widget _buildPage() {
    if (_showChat) {
      return ChatScreen(onBack: () => setState(() => _showChat = false));
    }
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
      case 0: return DashboardScreen(onOpenChat: () => setState(() {
        _showChat = true;
        _showUpload = false;
        _selectedTenantId = null;
      }));
      case 1: return TenantsScreen(onTenantSelected: (id) => setState(() => _selectedTenantId = id));
      case 2: return const DocumentsScreen();
      case 3: return const AnalyticsScreen();
      case 4: return const SettingsScreen();
      default: return const DashboardScreen();
    }
  }

  // ---- Mobile FAB Menu ----
  Widget _buildFabMenu() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surfaceBg = isDark ? AppTheme.surface : AppTheme.lightSurface;
    final textColor = isDark ? AppTheme.textPrimary : AppTheme.lightTextPrimary;
    final borderColor = isDark ? AppTheme.border : AppTheme.lightBorder;

    final items = [
      _FabItem(Icons.dashboard_rounded, 'Dashboard', 0),
      _FabItem(Icons.apartment_rounded, 'Tenants', 1),
      _FabItem(Icons.description_rounded, 'Documents', 2),
      _FabItem(Icons.analytics_rounded, 'Analytics', 3),
      _FabItem(Icons.settings_rounded, 'Settings', 4),
      _FabItem(Icons.chat_bubble_rounded, 'Chat', -1),
      _FabItem(Icons.upload_file_rounded, 'Upload', -2),
    ];

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        // Menu items
        ...List.generate(items.length, (i) {
          final item = items[i];
          final delay = (items.length - 1 - i) * 0.05;
          return AnimatedBuilder(
            animation: _fabAnimation,
            builder: (context, child) {
              final progress = _fabAnimation.value;
              final itemProgress = progress > delay ? ((progress - delay) / (1 - delay)).clamp(0.0, 1.0) : 0.0;
              return Transform.translate(
                offset: Offset(0, 20 * (1 - itemProgress)),
                child: Opacity(
                  opacity: itemProgress,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: surfaceBg,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: borderColor),
                            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 4)],
                          ),
                          child: Text(item.label, style: TextStyle(color: textColor, fontSize: 13, fontWeight: FontWeight.w500)),
                        ),
                        const SizedBox(width: 8),
                        Material(
                          color: item.index == -1
                              ? AppTheme.primary
                              : item.index == -2
                                  ? AppTheme.success
                                  : surfaceBg,
                          borderRadius: BorderRadius.circular(28),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(28),
                            onTap: () {
                              _closeFab();
                              if (item.index >= 0) {
                                _navigateTo(item.index);
                              } else if (item.index == -1) {
                                setState(() { _showChat = true; _showUpload = false; _selectedTenantId = null; });
                              } else {
                                setState(() { _showUpload = true; _showChat = false; _selectedTenantId = null; });
                              }
                            },
                            child: Container(
                              width: 48,
                              height: 48,
                              alignment: Alignment.center,
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                item.icon,
                                color: (item.index == -1 || item.index == -2) ? Colors.white : textColor,
                                size: 22,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        }),

        // Main FAB
        FloatingActionButton(
          onPressed: _toggleFab,
          backgroundColor: AppTheme.primary,
          foregroundColor: Colors.white,
          elevation: 4,
          shape: const CircleBorder(),
          child: AnimatedRotation(
            turns: _fabOpen ? 0.125 : 0,
            duration: const Duration(milliseconds: 250),
            child: const Icon(Icons.menu_rounded, size: 26),
          ),
        ),
      ],
    );
  }

  // ---- Desktop FAB (quick actions) ----
  Widget _buildDesktopFab() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        AnimatedBuilder(
          animation: _fabAnimation,
          builder: (context, child) {
            return Transform.scale(
              scale: _fabAnimation.value,
              child: Opacity(
                opacity: _fabAnimation.value,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    _desktopFabAction(Icons.upload_file_rounded, 'Upload', AppTheme.success, () {
                      _closeFab();
                      setState(() { _showUpload = true; _showChat = false; _selectedTenantId = null; });
                    }),
                    const SizedBox(height: 8),
                    _desktopFabAction(Icons.chat_bubble_rounded, 'Chat', AppTheme.primary, () {
                      _closeFab();
                      setState(() { _showChat = true; _showUpload = false; _selectedTenantId = null; });
                    }),
                    const SizedBox(height: 12),
                  ],
                ),
              ),
            );
          },
        ),
        FloatingActionButton(
          onPressed: _toggleFab,
          backgroundColor: AppTheme.primary,
          foregroundColor: Colors.white,
          child: AnimatedRotation(
            turns: _fabOpen ? 0.125 : 0,
            duration: const Duration(milliseconds: 250),
            child: const Icon(Icons.add_rounded, size: 28),
          ),
        ),
      ],
    );
  }

  Widget _desktopFabAction(IconData icon, String label, Color color, VoidCallback onTap) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surfaceBg = isDark ? AppTheme.surface : AppTheme.lightSurface;
    final textColor = isDark ? AppTheme.textPrimary : AppTheme.lightTextPrimary;
    final borderColor = isDark ? AppTheme.border : AppTheme.lightBorder;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: surfaceBg,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: borderColor),
          ),
          child: Text(label, style: TextStyle(color: textColor, fontSize: 13, fontWeight: FontWeight.w500)),
        ),
        const SizedBox(width: 8),
        FloatingActionButton(
          onPressed: onTap,
          backgroundColor: color,
          foregroundColor: Colors.white,
          mini: true,
          child: Icon(icon, size: 20),
        ),
      ],
    );
  }
}

class _FabItem {
  final IconData icon;
  final String label;
  final int index; // 0-4 = nav pages, -1 = chat, -2 = upload
  const _FabItem(this.icon, this.label, this.index);
}
