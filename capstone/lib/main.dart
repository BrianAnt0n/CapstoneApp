import 'package:capstone/splash_screen.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart'; // ✅ Import Provider package
import 'onboarding_page.dart';
import 'login_page.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'constants.dart';
import 'home_page.dart'; // ✅ Import home_page.dart where ContainerState is defined

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
     url: supabaseUrl,
     anonKey: supabaseAnonKey,
  );

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (context) => ContainerState()), // ✅ Provide ContainerState globally
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'E-ComposThink',
      theme: ThemeData(
        primarySwatch: Colors.green,
      ),
      home: SplashScreen(), // ✅ Starts with SplashScreen
    );
  }
}
