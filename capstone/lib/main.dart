import 'package:capstone/splash_screen.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'onboarding_page.dart';
import 'login_page.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'constants.dart';
import 'reset_password.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:workmanager/workmanager.dart';
import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';
import 'dart:developer';
import 'package:permission_handler/permission_handler.dart';


final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

Future<void> _initNotifications() async {
  const AndroidInitializationSettings androidSettings =
      AndroidInitializationSettings('@mipmap/ic_launcher');

  const InitializationSettings settings =
      InitializationSettings(android: androidSettings);

  await flutterLocalNotificationsPlugin.initialize(settings);
}

Future<void> checkForNotifications() async {
  print("🔍 Checking for new notifications...");

  // ✅ Ensure Supabase is initialized before making requests
  if (Supabase.instance.client == null) {
    print("⚡ Reinitializing Supabase...");
    await Supabase.initialize(
      url: 'https://mibhnlcgkbgesgmkmufy.supabase.co',
      anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im1pYmhubGNna2JnZXNnbWttdWZ5Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3MzEzNzg2MDIsImV4cCI6MjA0Njk1NDYwMn0.0_pCroFd0IaLCpzaxI2FE2juS0wRaszcf3OtYFK5iA4',
    );
  }

  final supabase = Supabase.instance.client;
  final prefs = await SharedPreferences.getInstance();

  int lastSeenId = prefs.getInt('last_seen_notification') ?? 0;
  print("🔢 Last seen notification ID: $lastSeenId");

  try {
    final response = await supabase
        .from('Notification_Test')
        .select()
        .gt('id', lastSeenId)
        .order('id', ascending: true)
        .limit(1);

    if (response.isNotEmpty) {
      final newNotification = response[0];
      int newId = newNotification['id'];
      String message = newNotification['message'];

      print("📩 New notification found: $message");

      await _showNotification(message);
      await prefs.setInt('last_seen_notification', newId);
      print("✅ Notification saved with ID: $newId");
    } else {
      print("❌ No new notifications found.");
    }
  } catch (e, stacktrace) {
  log("❌ Error fetching notifications: $e", stackTrace: stacktrace);
  }
}

Future<void> _showNotification(String message) async {
  print("🔔 Attempting to show notification: $message");

  const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
    'channel_id',
    'E-ComposThink Alerts',
    channelDescription: 'App Notifications',
    importance: Importance.max,
    priority: Priority.high,
    playSound: true,
    enableLights: true,
    enableVibration: true,
  );

  const NotificationDetails details = NotificationDetails(android: androidDetails);

  await flutterLocalNotificationsPlugin.show(
    0,
    'New Alert',
    message,
    details,
  );

  print("✅ Notification should now be displayed!");
}

// ✅ Corrected callbackDispatcher function
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    print("🔄 Running background task: $task");

    await Supabase.initialize(
      url: 'https://mibhnlcgkbgesgmkmufy.supabase.co',
      anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im1pYmhubGNna2JnZXNnbWttdWZ5Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3MzEzNzg2MDIsImV4cCI6MjA0Njk1NDYwMn0.0_pCroFd0IaLCpzaxI2FE2juS0wRaszcf3OtYFK5iA4',
    );

    await checkForNotifications();
    return Future.value(true);
  });
}

Future<void> requestNotificationPermission() async {
  var status = await Permission.notification.status;
  if (!status.isGranted) {
    await Permission.notification.request();
  }
}

Future<void> testNotification() async {
  await _showNotification("🚀 This is a test floating notification!");
}




void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await _initNotifications();
  await Supabase.initialize(
    url: 'https://mibhnlcgkbgesgmkmufy.supabase.co',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im1pYmhubGNna2JnZXNnbWttdWZ5Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3MzEzNzg2MDIsImV4cCI6MjA0Njk1NDYwMn0.0_pCroFd0IaLCpzaxI2FE2juS0wRaszcf3OtYFK5iA4',
  );

  // ✅ Initialize WorkManager before registering tasks
  await Workmanager().initialize(
    callbackDispatcher,
    isInDebugMode: true,
  );

  // ✅ Schedule background work every 15 minutes
  Workmanager().registerPeriodicTask(
    "fetchNotifications",
    "checkForNotificationsTask",
    frequency: const Duration(minutes: 15),
  );

  await requestNotificationPermission(); // Request permission on startup

  testNotification(); // 🔥 Trigger a test notification
  checkForNotifications(); // 🔥 Check for new notifications


  runApp(MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  void initState() {
    super.initState();
    _handleDeepLinks();
  }

  void _handleDeepLinks() {
    Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      final session = data.session;
      if (session != null && session.accessToken.isNotEmpty) {
        final Uri uri = Uri.parse(session.providerRefreshToken ?? '');
        if (uri.queryParameters.containsKey('token')) {
          String? resetToken = uri.queryParameters['token'];
          if (resetToken != null) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => ResetPasswordPage(resetToken: resetToken),
              ),
            );
          }
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'E-ComposThink',
      theme: ThemeData(
        primarySwatch: Colors.green,
      ),
      home: SplashScreen(),
    );
  }
}
