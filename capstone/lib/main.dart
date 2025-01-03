import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'onboarding_page.dart';
import 'login_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  //for Testing, remove after
  prefs.clear(); // Clears all saved preferences
  //For Testing^^
  final seenOnboarding = prefs.getBool('seenOnboarding') ?? false;
  

  runApp(MyApp(seenOnboarding: seenOnboarding));
}

class MyApp extends StatelessWidget {
  final bool seenOnboarding;

  MyApp({required this.seenOnboarding});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'E-ComposThink',
      theme: ThemeData(
        primarySwatch: Colors.green,
      ),
      home: seenOnboarding ? LoginPage() : OnboardingPage(),
    );
  }
}

