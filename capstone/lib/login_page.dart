import 'package:capstone/shared_prefs_helper.dart';
import 'package:flutter/material.dart';
import 'home_page.dart';
import 'home_page_members.dart';
import 'home_page_guest.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  _LoginPageState createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final SupabaseClient supabase = Supabase.instance.client;

  // Future<String?> loginUser(String email, String password) async {
  //   final SupabaseClient supabase = Supabase.instance.client;

  //   try {
  //     // Fetch user from Supabase based on email
  //     final response = await supabase
  //         .from('Users')
  //         .select(
  //             'user_id, email, password, user_level') // Select necessary fields
  //         .eq('email', email)
  //         .maybeSingle(); // Get a single record or null

  //     // If no user is found
  //     if (response == null) {
  //       return "User not found";
  //     }

  //     // Compare passwords (⚠️ Should use **hashed passwords** in production)
  //     if (response['password'] != password) {
  //       return "Incorrect password";
  //     }

  //     // Retrieve user level
  //     String userLevel = response['user_level'];

  //     // Return success message
  //     return "Login successful, User Level: $userLevel";
  //   } catch (error) {
  //     return "Login failed: ${error.toString()}";
  //   }
  // }

  // void handleLogin() async {
  //   String email = _emailController.text.trim();
  //   String password = _passwordController.text.trim();

  //   String? result = await loginUser(email, password);

  //   if (result != null && result.startsWith("Login successful")) {
  //     // Navigate based on user level
  //     if (result.contains("User Level: Admin")) {
  //       Navigator.pushReplacement(
  //         context,
  //         MaterialPageRoute(builder: (context) => HomePage()),
  //       );
  //     } else if (result.contains("User Level: Member")) {
  //       Navigator.pushReplacement(
  //         context,
  //         MaterialPageRoute(builder: (context) => HomePageMember()),
  //       );
  //     }
  //   } else {
  //     // Show error message
  //     ScaffoldMessenger.of(context).showSnackBar(
  //       SnackBar(content: Text(result ?? "Unknown error")),
  //     );
  //   }
  // }

  void _login() async {
    String email = _emailController.text.trim();
    String password = _passwordController.text.trim();

    try {
      final response = await supabase
          .from('Users')
          .select('user_id, user_level, fullname, email, password')
          .eq('email', email)
          .single();

      String storedPassword = response['password'];
      int storedUserId = response['user_id'];
      String storedUserLevel = response['user_level'];
      String storedEmail = response['email'];
      String storedFullName = response['fullname'];

      String userIdString = storedUserId.toString();

      if (storedPassword == password) {
        await SharedPrefsHelper.saveUserLogin(userIdString, storedUserLevel, storedEmail, storedFullName);
        if (storedUserLevel == "Admin") {
          Navigator.pushReplacement(
              context, MaterialPageRoute(builder: (context) => const HomePage()));
        } else {
          Navigator.pushReplacement(
              context, MaterialPageRoute(builder: (context) => const HomePageMember()));
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Incorrect password. Please try again.")));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Login failed. Please try again.")));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        fit: StackFit.expand, // Makes the background image fill the screen
        children: [
          // Background Image
          Image.asset(
            'assets/bg.png', // Path to the background image
            fit: BoxFit.cover, // Ensures the image covers the screen
          ),

          // Foreground Content
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Placeholder for Logo
                  Container(
                    width: 150,
                    height: 150,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      shape: BoxShape.circle, // Makes the container circular
                    ),
                    child: ClipOval(
                      child: Image.asset(
                        'assets/logo_login.png', // Path to your logo image
                        fit: BoxFit
                            .contain, // Ensures the whole image is visible
                      ),
                    ),
                  ),

                  const SizedBox(height: 40), // Spacing between logo and text fields

                  // Email Field
                  TextField(
                    controller: _emailController,
                    decoration: const InputDecoration(
                      labelText: 'Email',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.email),
                    ),
                    keyboardType: TextInputType.emailAddress,
                  ),
                  const SizedBox(height: 20),

                  // Password Field
                  TextField(
                    controller: _passwordController,
                    decoration: const InputDecoration(
                      labelText: 'Password',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.lock),
                    ),
                    obscureText: true,
                  ),
                  const SizedBox(height: 20),
                  // Login Button (Green Theme)
                  GestureDetector(
                    onTap:
                        // Add login logic here later
                        _login,
                    child: Container(
                      width: double.infinity, // Full-width button
                      height: 50, // Set the height of the button
                      decoration: BoxDecoration(
                        color: Colors.green, // Button background color (Green)
                        borderRadius:
                            BorderRadius.circular(8), // Rounded corners
                      ),
                      alignment: Alignment.center,
                      child: const Text(
                        'Login',
                        style: TextStyle(
                          color: Colors.white, // Text color
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Forgot Password Link
                  GestureDetector(
                    onTap: () {
                      // Navigate to Forgot Password page or perform an action
                    },
                    child: const Text(
                      'Forgot Your Password? Click Here',
                      style: TextStyle(color: Colors.blue),
                    ),
                  ),
                  const SizedBox(
                      height: 40), // Add some spacing before the guest button

                  // Continue as Guest Button (Yellow Theme)
                  GestureDetector(
                    onTap: () {
                      // Add guest login logic here
                      //Navigator.pushNamed(
                      //context, '/guestHome'); // Example navigation

                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(builder: (context) => const HomePageGuest()),
                      );
                    },
                    child: Container(
                      width: double.infinity, // Full-width button
                      height: 50, // Set the height of the button
                      decoration: BoxDecoration(
                        color: Colors
                            .yellow[700], // Button background color (Yellow)
                        borderRadius:
                            BorderRadius.circular(8), // Rounded corners
                      ),
                      alignment: Alignment.center,
                      child: const Text(
                        'Continue as Guest',
                        style: TextStyle(
                          color: Colors.white, // Text color
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
