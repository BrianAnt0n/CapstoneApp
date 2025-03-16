import 'package:capstone/shared_prefs_helper.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'home_page.dart';
import 'home_page_members.dart';
import 'home_page_guest.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'forgot_password.dart';
import 'Others tab/account_settings_page.dart';
import 'forced_password_change_page.dart';
import 'package:bcrypt/bcrypt.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  _LoginPageState createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final SupabaseClient supabase = Supabase.instance.client;
  void _login() async {
    String username = _usernameController.text.trim().toLowerCase();
    String password = _passwordController.text.trim();

// ✅ Validate username (no spaces and only lowercase letters)
    final usernameRegex = RegExp(r'^[a-z0-9]+$');
    if (!usernameRegex.hasMatch(username)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Username must be lowercase and contain no spaces.')),
      );
      return;
    }

    try {
      final response = await supabase
          .from('Users')
          .select(
              'user_id, user_level, fullname, username, password, reset_requested')
          .eq('username', username)
          .maybeSingle();

      if (response == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Username not found. Please try again.")),
        );
        return;
      }

      String storedPasswordHash = response['password'];
      int storedUserId = response['user_id'];
      String storedUserLevel = response['user_level'];
      String storedFullName = response['fullname'];
      String storedUsername = response['username'];
      bool resetRequested = response['reset_requested'] ?? false;

    // ✅ Check if stored hash corresponds to "Temp1234!"
    bool isTempPassword = BCrypt.checkpw("Temp1234!", storedPasswordHash);

      if (BCrypt.checkpw(password, storedPasswordHash)) {
        await SharedPrefsHelper.saveUserLogin(storedUserId.toString(),
            storedUserLevel, storedFullName, storedUsername);

        // ✅ If reset_requested is TRUE, update it to NULL
        if (resetRequested) {
          await supabase
              .from('Users')
              .update({'reset_requested': null})
              .eq('user_id', storedUserId);
        }

        // ✅ If logging in with Temp1234!, force password change
        if (isTempPassword) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content:
                    Text("You must change your password before continuing.")),
          );

          // ✅ Redirect to the dedicated Forced Password Change Page
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
                builder: (context) => const ForcedPasswordChangePage()),
          );
          return;
        }

        // ✅ Redirect based on user level
        if (storedUserLevel == "Admin") {
          Navigator.pushReplacement(context,
              MaterialPageRoute(builder: (context) => const HomePage()));
        } else {
          Navigator.pushReplacement(context,
              MaterialPageRoute(builder: (context) => const HomePageMember()));
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text("Incorrect password. Please try again.")),
        );
      }
    } catch (e) {
      print("❌ Login error: $e");
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
                    width: 200,
                    height: 200,
                    // decoration: BoxDecoration(
                    //   //color: Colors.grey[300],
                    //   shape: BoxShape.circle, // Makes the container circular
                    // ),

                    child: Image.asset(
                      'assets/logo_login.png', // Path to your logo image
                      fit: BoxFit.contain, // Ensures the whole image is visible
                    ),
                  ),

                  const SizedBox(
                      height: 40), // Spacing between logo and text fields

                  // Username Field
                  TextField(
                    controller: _usernameController,
                    keyboardType: TextInputType.text,
                    decoration: const InputDecoration(
                      labelText: 'Username',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.person),
                    ),
                    onChanged: (value) {
                      _usernameController.value = _usernameController.value.copyWith(
                        text: value
                            .toLowerCase(), // ✅ Converts input to lowercase
                        selection:
                            TextSelection.collapsed(offset: value.length),
                      );
                    },
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
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) => const ForgotPasswordPage()),
                      );
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
                        MaterialPageRoute(
                            builder: (context) => const HomePageGuest()),
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
