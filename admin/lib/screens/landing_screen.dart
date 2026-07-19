import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../main.dart';

class LandingScreen extends StatefulWidget {
  const LandingScreen({super.key});

  @override
  State<LandingScreen> createState() => _LandingScreenState();
}

class _LandingScreenState extends State<LandingScreen> with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late AnimationController _slideController;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim1;
  late Animation<Offset> _slideAnim2;
  late Animation<Offset> _slideAnim3;
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(vsync: this, duration: const Duration(milliseconds: 800));
    _slideController = AnimationController(vsync: this, duration: const Duration(milliseconds: 1000));

    _fadeAnim = CurvedAnimation(parent: _fadeController, curve: Curves.easeIn);
    _slideAnim1 = Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero).animate(CurvedAnimation(parent: _slideController, curve: const Interval(0.0, 0.4, curve: Curves.easeOut)));
    _slideAnim2 = Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero).animate(CurvedAnimation(parent: _slideController, curve: const Interval(0.2, 0.6, curve: Curves.easeOut)));
    _slideAnim3 = Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero).animate(CurvedAnimation(parent: _slideController, curve: const Interval(0.4, 0.8, curve: Curves.easeOut)));

    _fadeController.forward();
    _slideController.forward();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _slideController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnim,
          child: Column(
            children: [
              const Spacer(flex: 1),

              // Logo
              SlideTransition(
                position: _slideAnim1,
                child: Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [AppTheme.primary, Color(0xFF8B5CF6)]),
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(color: AppTheme.primary.withOpacity(0.3), blurRadius: 24, spreadRadius: 4),
                    ],
                  ),
                  child: const Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 40),
                ),
              ),
              const SizedBox(height: 32),

              // Title
              SlideTransition(
                position: _slideAnim1,
                child: const Text(
                  'RagChat',
                  style: TextStyle(fontSize: 36, fontWeight: FontWeight.w800, color: AppTheme.textPrimary, letterSpacing: -1),
                ),
              ),
              const SizedBox(height: 8),
              SlideTransition(
                position: _slideAnim2,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text('AI-Powered Knowledge Base', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: AppTheme.primary)),
                ),
              ),
              const SizedBox(height: 40),

              // Tagline
              SlideTransition(
                position: _slideAnim2,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Text(
                    'Your own AI assistant that knows your business.\nOne line of code, no technical skill needed.\nUpload your documents, and it\'s super patient.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 16, color: AppTheme.textSecondary.withOpacity(0.9), height: 1.6),
                  ),
                ),
              ),
              const SizedBox(height: 48),

              // Feature cards
              SlideTransition(
                position: _slideAnim3,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Row(
                    children: [
                      _featureCard(Icons.upload_file_rounded, 'Upload', 'PDF, DOCX,\nTXT, HTML', AppTheme.success),
                      const SizedBox(width: 12),
                      _featureCard(Icons.auto_awesome_rounded, 'AI Answers', 'Instant &\nAccurate', AppTheme.primary),
                      const SizedBox(width: 12),
                      _featureCard(Icons.public_rounded, 'Embed', 'One line\nof code', AppTheme.info),
                    ],
                  ),
                ),
              ),

              const Spacer(flex: 2),

              // Page indicator
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(3, (i) => Container(
                  width: i == _currentPage ? 24 : 8,
                  height: 8,
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  decoration: BoxDecoration(
                    color: i == _currentPage ? AppTheme.primary : AppTheme.border,
                    borderRadius: BorderRadius.circular(4),
                  ),
                )),
              ),
              const SizedBox(height: 32),

              // Get Started button
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(builder: (_) => const AdminShell()),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primary,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      elevation: 0,
                    ),
                    child: const Text('Get Started', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white)),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Skip
              TextButton(
                onPressed: () {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (_) => const AdminShell()),
                  );
                },
                child: Text('Skip for now', style: TextStyle(color: AppTheme.textSecondary.withOpacity(0.6), fontSize: 14)),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _featureCard(IconData icon, String title, String subtitle, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 8),
            Text(title, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: color)),
            const SizedBox(height: 4),
            Text(subtitle, textAlign: TextAlign.center, style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary, height: 1.3)),
          ],
        ),
      ),
    );
  }
}
