import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/theme/theme_provider.dart';
import '../features/task/bloc/task_bloc.dart';
import '../features/task/bloc/task_event.dart';
import 'main_screen.dart';
import '../main.dart';
import '../core/services/task_service.dart';
import '../features/auth/screens/auth_screen.dart';
import '../features/onboarding/screens/onboarding_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.2).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeIn),
    );

    _controller.forward();
    _initializeApp();
  }

  Future<bool> _hasSeenOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('hasSeenOnboarding') ?? false;
  }

  Future<void> _initializeApp() async {
    final taskService = TaskService();

    try {
      await initializeNotifications();
      await taskService.initDatabase();
      print('SplashScreen: Notifications and database initialized');

      final hasSeenOnboarding = await _hasSeenOnboarding();

      if (!hasSeenOnboarding) {
        print('SplashScreen: Showing OnboardingScreen');
        if (mounted) {
          _navigateTo(const OnboardingScreen());
        }
        return;
      }

      final session = supabase.auth.currentSession;
      final prefs = await SharedPreferences.getInstance();
      final isGuest = prefs.getBool('isGuest') ?? false;

      if (session != null) {
        print('SplashScreen: User logged in (${session.user.email}), importing data');
        await taskService.importFromSupabase();
        context.read<TaskBloc>().add(LoadTasks());
        await setInitialized();
        if (mounted) {
          _navigateTo(const MainScreen());
        }
      } else if (isGuest) {
        print('SplashScreen: Continuing as guest');
        await taskService.clearAllData();
        context.read<TaskBloc>().add(LoadTasks());
        await setInitialized();
        if (mounted) {
          _navigateTo(const MainScreen());
        }
      } else {
        print('SplashScreen: No user logged in, showing AuthScreen');
        await setInitialized();
        if (mounted) {
          _navigateTo(const AuthScreen());
        }
      }
    } catch (e) {
      print('SplashScreen: Error during initialization: $e');
      if (mounted) {
        _navigateTo(const AuthScreen());
      }
    }
  }

  void _navigateTo(Widget screen) {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => screen),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDarkMode = themeProvider.themeMode == ThemeMode.dark;

    return Scaffold(
      body: Container(
        color: isDarkMode ? const Color(0xFF1E293B) : const Color(0xFFF9FAFB),
        child: Center(
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              return Transform.scale(
                scale: _scaleAnimation.value,
                child: FadeTransition(
                  opacity: _fadeAnimation,
                  child: Text(
                    'TaskFlow',
                    style: GoogleFonts.poppins(
                      fontSize: 36,
                      fontWeight: FontWeight.w700,
                      color: isDarkMode ? Colors.white : const Color(0xFF2D3748),
                      shadows: [
                        Shadow(
                          color: isDarkMode
                              ? Colors.black.withOpacity(0.3)
                              : const Color(0xFF60A5FA).withOpacity(0.2),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}