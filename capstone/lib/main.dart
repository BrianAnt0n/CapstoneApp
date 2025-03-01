import 'dart:async';

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

  Future<String?> getStoredString(String key) async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getString(key);
}

  final supabase = Supabase.instance.client;
  final prefs = await SharedPreferences.getInstance();
    String? storedString = await getStoredString("user_id_pref");

    
    int userId = int.parse(storedString!);

  if (userId == null) {
    print("❌ No user logged in. Skipping notification check.");
    return;
  }

  // Fetch hardware_ids linked to the user_id
  final containerResponse = await supabase
      .from('Containers_test')
      .select('hardware_id, container_name')
      .eq('user_id', userId);
  
  if (containerResponse.isEmpty) {
    print("❌ No linked containers for user $userId.");
    return;
  }

  Map<int, String> hardwareIdToContainerName = {
    for (var entry in containerResponse) entry['hardware_id']: entry['container_name']
  };
  List<int> hardwareIds = hardwareIdToContainerName.keys.toList();
  int lastSeenId = prefs.getInt('last_seen_notification') ?? -1;
  //DateTime fiveMinutesAgo = DateTime.now().subtract(Duration(minutes: 5));
  print("🔢 Last seen notification ID: $lastSeenId");

  try {
    final response = await supabase
        .from('Notifications_Test')
        .select()
        .order('notification_id', ascending: true);

    final filteredNotifications = response.where((n) => 
      hardwareIds.contains(n['hardware_id']) && 
      n['notification_id'] > lastSeenId && 
      hardwareIdToContainerName.containsKey(n['hardware_id'])
    ).toList();

    if (filteredNotifications.isEmpty) {
      print("⚠ No new notifications found.");
      return;
    }

    print("🔍 Full Supabase Response: $response");

    if (response.isEmpty) {
      print("⚠ Table was truncated! Resetting last seen notification ID...");
      await prefs.setInt('last_seen_notification', -1); // ✅ Reset last seen ID
      return;
    }

    //final newNotifications = response.where((n) => n['notification_id'] > lastSeenId).toList();

    if (filteredNotifications.isNotEmpty) {
      await _showGroupedNotifications(filteredNotifications, hardwareIdToContainerName);
      int newLastSeenId = filteredNotifications.last['notification_id'];
      await prefs.setInt('last_seen_notification', newLastSeenId);
      print("✅ Updated last seen notification ID to: $newLastSeenId");
    }
  } catch (e) {
    print("❌ Error fetching notifications: $e");
  }
}


Future<void> _showGroupedNotifications(List<Map<String, dynamic>> notifications, Map<int, String> hardwareIdToContainerName) async {
  print("🔔 Displaying ${notifications.length} grouped notifications...");

  const String groupKey = 'ecomposThink_notifications';
  const String channelId = 'channel_id';

  // 1️⃣ Show individual notifications in a group
  for (var notification in notifications) {
int id = notification['notification_id'];
    String title = notification['title'];
    String message = notification['message'];
    int hardwareId = notification['hardware_id'];
    String containerName = hardwareIdToContainerName[hardwareId]!;
    DateTime dateTime = DateTime.parse(notification['timestamp']);
    String formattedTime = DateFormat('hh:mm a • MMM d, yyyy').format(dateTime);
    String fullTitle = "$containerName - $title";
    String fullMessage = "$message\n🕒 $formattedTime";

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
      id,
      fullTitle,
      fullMessage, // ✅ Show message + timestamp
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

// Future<void> testNotification() async {
//   List<Map<String, dynamic>> testNotifications = [
//     {
//       'notification_id': 999,
//       'title': '🚀 Test Alert 1',
//       'message': 'This is the first test notification!',
//     },
//     {
//       'notification_id': 1000,
//       'title': '🔥 Test Alert 2',
//       'message': 'This is the second test notification!',
//     }
//   ];

//   await _showGroupedNotifications(testNotifications);
// }





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

  // // ✅ Schedule background work every 15 minutes
  // Workmanager().registerPeriodicTask(
  //   "fetchNotifications",
  //   "checkForNotificationsTask",
  //   frequency: const Duration(minutes: 2),
  // );

  const Duration customInterval = Duration(seconds: 30); // Set your preferred interval
  void startCustomNotificationCheck() {
  Timer.periodic(customInterval, (timer) {
    checkForNotifications();
  });
}

  await requestNotificationPermission(); // Request permission on startup

  // testNotification(); // 🔥 Trigger a test notification
  //checkForNotifications(); // 🔥 Check for new notifications
  startCustomNotificationCheck();

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
