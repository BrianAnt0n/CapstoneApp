import 'package:flutter/material.dart';
import 'home_page.dart';

class LoginPage extends StatelessWidget {
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
              padding: EdgeInsets.all(16.0),
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

                  SizedBox(height: 40), // Spacing between logo and text fields

                  // Email Field
                  TextField(
                    decoration: InputDecoration(
                      labelText: 'Email',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.email),
                    ),
                    keyboardType: TextInputType.emailAddress,
                  ),
                  SizedBox(height: 20),

                  // Password Field
                  TextField(
                    decoration: InputDecoration(
                      labelText: 'Password',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.lock),
                    ),
                    obscureText: true,
                  ),
                  SizedBox(height: 20),

                  // Login Button (Green Theme)
                  GestureDetector(
                    onTap: () {
                      // Add login logic here later
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(builder: (context) => HomePage()),
                      );
                    },
                    child: Container(
                      width: double.infinity, // Full-width button
                      height: 50, // Set the height of the button
                      decoration: BoxDecoration(
                        color: Colors.green, // Button background color (Green)
                        borderRadius:
                            BorderRadius.circular(8), // Rounded corners
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        'Login',
                        style: TextStyle(
                          color: Colors.white, // Text color
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),

                  SizedBox(height: 20),

                  // Signup link
                  GestureDetector(
                    onTap: () {
                      // Navigate to signup page or perform an action
                    },
                    child: Text(
                      'Don’t have an account? Sign up',
                      style: TextStyle(color: Colors.blue),
                    ),
                  ),
                  SizedBox(
                      height: 40), // Add some spacing before the guest button

                  // Continue as Guest Button (Yellow Theme)
                  GestureDetector(
                    onTap: () {
                      // Add guest login logic here
                      //Navigator.pushNamed(
                          //context, '/guestHome'); // Example navigation

                          Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(builder: (context) => HomePage()),
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
                      child: Text(
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
