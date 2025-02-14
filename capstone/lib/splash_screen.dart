import 'package:flutter/material.dart';
import 'shared_prefs_helper.dart';
import 'home_page.dart';
import 'home_page_members.dart';
import 'login_page.dart';
import 'onboarding_page.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  _SplashScreenState createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _checkLoginStatus();
  }

  Future<void> _checkLoginStatus() async {
    bool hasSeenOnboarding = await SharedPrefsHelper.hasSeenOnboarding();
    
    if (!hasSeenOnboarding) {
      // Navigate to onboarding screen
      Navigator.pushReplacement(
          context, MaterialPageRoute(builder: (context) => const OnboardingPage()));
      return;
    }

    // Check user login details
    Map<String, String?> userLogin = await SharedPrefsHelper.getUserLogin();
    String? userId = userLogin["user_id_pref"];
    String? userLevel = userLogin["user_level_pref"];

    if (userId != null && userLevel != null) {
      // Navigate based on user level
      if (userLevel == "Admin") {
        Navigator.pushReplacement(
            context, MaterialPageRoute(builder: (context) =>  HomePage()));
      } else {
        Navigator.pushReplacement(
            context, MaterialPageRoute(builder: (context) =>  HomePageMember()));
      }
    } else {
      // Navigate to login page
      Navigator.pushReplacement(
          context, MaterialPageRoute(builder: (context) => const LoginPage()));
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }
}
