import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'onboarding_page.dart';
import 'login_page.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'constants.dart';


void main() async {
  WidgetsFlutterBinding.ensureInitialized();

//Supabase Initialization
//const supabaseUrl = 'https://mibhnlcgkbgesgmkmufy.supabase.co';
//const supabaseAnonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im1pYmhubGNna2JnZXNnbWttdWZ5Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3MzEzNzg2MDIsImV4cCI6MjA0Njk1NDYwMn0.0_pCroFd0IaLCpzaxI2FE2juS0wRaszcf3OtYFK5iA4';

  await Supabase.initialize(
     url: supabaseUrl,
     anonKey: supabaseAnonKey,
  );
  
 //Android Init 
  final prefs = await SharedPreferences.getInstance();
  //for Testing, remove after
  prefs.clear(); // Clears all saved preferences
  //For Testing^^
  final seenOnboarding = prefs.getBool('seenOnboarding') ?? false;
  

  runApp(MyApp(seenOnboarding: seenOnboarding));
}

class MyApp extends StatelessWidget {
  final bool seenOnboarding;

  const MyApp({super.key, required this.seenOnboarding});

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

