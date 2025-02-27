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
import 'package:intl/intl.dart'; // ✅ Import this at the top


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
  int lastSeenId = prefs.getInt('last_seen_notification') ?? -1;

  print("🔢 Last seen notification ID: $lastSeenId");

  try {
    final response = await supabase
        .from('Notifications_Test')
        .select()
        .gt('notification_id', lastSeenId)  // Fetch all new notifications
        .order('notification_id', ascending: true);

    print("🔍 Full Supabase Response: $response");

    if (response.isNotEmpty) {
      await _showGroupedNotifications(response);  // 🔥 Send grouped notification

      int newLastSeenId = response.last['notification_id'];  // ✅ Update latest seen ID
      await prefs.setInt('last_seen_notification', newLastSeenId);
      print("✅ Notification saved with ID: $newLastSeenId");
    } else {
      print("❌ No new notifications found.");
    }
  } catch (e) {
    print("❌ Error fetching notifications: $e");
  }
}


Future<void> _showGroupedNotifications(List<Map<String, dynamic>> notifications) async {
  print("🔔 Displaying ${notifications.length} grouped notifications...");

  const String groupKey = 'ecomposThink_notifications';
  const String channelId = 'channel_id';

  // 1️⃣ Show individual notifications in a group
  for (var notification in notifications) {
    int id = notification['notification_id'];
    String title = notification['title'];
    String message = notification['message'];
    String timestamp = notification['timestamp'];  // ✅ Fetch timestamp
    DateTime dateTime = DateTime.parse(timestamp); // ✅ Convert to DateTime

    // ✅ Format into 12-hour format with AM/PM
    String formattedTime = DateFormat('hh:mm a • MMM d, yyyy').format(dateTime);

    String messageWithTime = "$message\n🕒 $formattedTime";  // ✅ Add timestamp to message

    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      channelId,
      'E-ComposThink Alerts',
      channelDescription: 'Grouped App Notifications',
      importance: Importance.max,
      priority: Priority.high,
      playSound: true,
      enableLights: true,
      enableVibration: true,
      groupKey: groupKey, // 🚀 Group Key for Bundling Notifications
    );

    const NotificationDetails details = NotificationDetails(android: androidDetails);

    await flutterLocalNotificationsPlugin.show(
      id,  // Unique ID per notification
      title,
      messageWithTime, // ✅ Show message + timestamp
      details,
    );
  }

  // 2️⃣ Show summary notification (for collapsed view)
  const AndroidNotificationDetails summaryNotificationDetails = AndroidNotificationDetails(
    channelId,
    'E-ComposThink Alerts',
    channelDescription: 'Grouped App Notifications',
    importance: Importance.max,
    priority: Priority.high,
    styleInformation: InboxStyleInformation([]), // This makes it expandable
    setAsGroupSummary: true,
    groupKey: groupKey, // Same Group Key
  );

  const NotificationDetails summaryDetails = NotificationDetails(android: summaryNotificationDetails);

  await flutterLocalNotificationsPlugin.show(
    0,  // Static ID for the summary notification
    'E-ComposThink Alerts',
    '${notifications.length} new notifications',
    summaryDetails,
  );

  print("✅ Grouped notifications with timestamps displayed!");
}




// ✅ Corrected callbackDispatcher function
@pragma('vm:entry-point')
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
  List<Map<String, dynamic>> testNotifications = [
    {
      'notification_id': 999,
      'title': '🚀 Test Alert 1',
      'message': 'This is the first test notification!',
    },
    {
      'notification_id': 1000,
      'title': '🔥 Test Alert 2',
      'message': 'This is the second test notification!',
    }
  ];

  await _showGroupedNotifications(testNotifications);
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
    frequency: const Duration(minutes: 2),
  );

  await requestNotificationPermission(); // Request permission on startup

  // testNotification(); // 🔥 Trigger a test notification
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
