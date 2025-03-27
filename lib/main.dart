import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:new_app/screens/splash_screen.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:provider/provider.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'core/theme/theme_provider.dart';
import 'features/pomodoro/bloc/pomodoro_bloc.dart';
import 'core/services/task_service.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'features/task/bloc/task_bloc.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

Future<void> initializeNotifications() async {
  const AndroidInitializationSettings initializationSettingsAndroid =
  AndroidInitializationSettings('@mipmap/ic_launcher');
  const InitializationSettings initializationSettings =
  InitializationSettings(android: initializationSettingsAndroid);

  await flutterLocalNotificationsPlugin.initialize(
    initializationSettings,
    onDidReceiveNotificationResponse: (NotificationResponse response) {
      print('Notification received with payload: ${response.payload}');
    },
  );

  const AndroidNotificationChannel channel = AndroidNotificationChannel(
    'task_channel',
    'Task Notifications',
    description: 'Notifications for task reminders',
    importance: Importance.max,
    playSound: true,
    sound: RawResourceAndroidNotificationSound('notification_sound'),
    enableVibration: true,
    showBadge: true,
  );

  final androidPlugin = flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
  if (androidPlugin != null) {
    await androidPlugin.createNotificationChannel(channel);
    await androidPlugin.requestNotificationsPermission();
    await androidPlugin.requestExactAlarmsPermission();
    print('Notification channel created and permissions requested');
  } else {
    print('Failed to resolve Android notification plugin');
  }
}

Future<bool> needsInitialization() async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getBool('isInitialized') ?? true;
}

Future<void> setInitialized() async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setBool('isInitialized', true);
}

Future<bool> isGuestUser() async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getBool('isGuest') ?? false;
}

Future<void> setGuestUser(bool isGuest) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setBool('isGuest', isGuest);
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await dotenv.load(fileName: ".env");

  tz.initializeTimeZones();
  final location = tz.getLocation('Africa/Cairo');
  tz.setLocalLocation(location);
  print('Local time zone set to: ${tz.local.name}');
  print('Local time zone offset: ${tz.local.currentTimeZone.offset / 1000 / 60 / 60} hours');
  print('Current local time: ${tz.TZDateTime.now(tz.local)}');

  await Supabase.initialize(
    url: dotenv.env['SUPABASE_URL']!,
    anonKey: dotenv.env['SUPABASE_ANON_KEY']!,
  );

  final initialSession = supabase.auth.currentSession;
  print('Initial session: ${initialSession != null ? "User logged in: ${initialSession.user.email}" : "No user logged in"}');

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        BlocProvider(create: (_) => TaskBloc(TaskService())),
        BlocProvider(create: (_) => PomodoroBloc()),
      ],
      child: const MyApp(),
    ),
  );
}

SupabaseClient get supabase => Supabase.instance.client;

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'TaskFlow',
      theme: ThemeData(
        brightness: Brightness.light,
        primaryColor: const Color(0xFF5D737E),
        scaffoldBackgroundColor: const Color(0xFFF5F6F5),
        colorScheme: const ColorScheme.light(
          primary: Color(0xFF5D737E),
          secondary: Color(0xFFFF6F61),
          surface: Color(0xFFFFFFFF),
          background: Color(0xFFF5F6F5),
          onPrimary: Colors.white,
          onSecondary: Colors.white,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFFF5F6F5),
          foregroundColor: Color(0xFF4A4B5C),
          elevation: 0,
          titleTextStyle: TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1F2A44),
          ),
        ),
        floatingActionButtonTheme: const FloatingActionButtonThemeData(
          backgroundColor: Color(0xFFFF6F61),
          foregroundColor: Colors.white,
          elevation: 6,
          shape: CircleBorder(),
        ),
        cardTheme: CardTheme(
          elevation: 2,
          color: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          margin: const EdgeInsets.symmetric(vertical: 8),
        ),
        textTheme: GoogleFonts.poppinsTextTheme(
          const TextTheme(
            headlineSmall: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF1F2A44)),
            bodyMedium: TextStyle(fontSize: 16, color: Color(0xFF1F2A44)),
            bodySmall: TextStyle(fontSize: 14, color: Color(0xFF7A869A)),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          filled: true,
          fillColor: Colors.white,
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFF5D737E), width: 2),
          ),
        ),
      ),
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        primaryColor: const Color(0xFF5D737E),
        scaffoldBackgroundColor: const Color(0xFF1F2A44),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF5D737E),
          secondary: Color(0xFFFF6F61),
          surface: Color(0xFF2A3756),
          background: Color(0xFF1F2A44),
          onPrimary: Colors.white,
          onSecondary: Colors.white,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF1F2A44),
          foregroundColor: Color(0xFFF5F6F5),
          elevation: 0,
          titleTextStyle: TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.bold,
            color: Color(0xFFF5F6F5),
          ),
        ),
        floatingActionButtonTheme: const FloatingActionButtonThemeData(
          backgroundColor: Color(0xFFFF6F61),
          foregroundColor: Colors.white,
          elevation: 6,
          shape: CircleBorder(),
        ),
        cardTheme: CardTheme(
          elevation: 2,
          color: const Color(0xFF2A3756),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          margin: const EdgeInsets.symmetric(vertical: 8),
        ),
        textTheme: GoogleFonts.poppinsTextTheme(
          const TextTheme(
            headlineSmall: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFFF5F6F5)),
            bodyMedium: TextStyle(fontSize: 16, color: Color(0xFFF5F6F5)),
            bodySmall: TextStyle(fontSize: 14, color: Color(0xFFA3B1C6)),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          filled: true,
          fillColor: const Color(0xFF2A3756),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFF5D737E), width: 2),
          ),
        ),
      ),
      themeMode: themeProvider.themeMode,
      home: const SplashScreen(),
    );
  }
}