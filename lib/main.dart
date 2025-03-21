import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:provider/provider.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'screens/main_screen.dart';
import 'theme_provider.dart';
import 'blocs/task/task_bloc.dart';
import 'blocs/task/task_event.dart';
import 'services/task_service.dart';
import 'package:timezone/timezone.dart' as tz;
import 'screens/splash_screen.dart';

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

Future<void> initializeNotifications() async {
  tz.initializeTimeZones();
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

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  tz.initializeTimeZones();
  tz.setLocalLocation(tz.getLocation('Africa/Cairo'));

  final bool shouldInitialize = await needsInitialization();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        BlocProvider(create: (_) => TaskBloc(TaskService())),
      ],
      child: MyApp(shouldInitialize: shouldInitialize),
    ),
  );
}

class MyApp extends StatelessWidget {
  final bool shouldInitialize;

  const MyApp({super.key, required this.shouldInitialize});

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
      home: shouldInitialize ? const SplashScreen() : const MainScreen(),
    );
  }
}