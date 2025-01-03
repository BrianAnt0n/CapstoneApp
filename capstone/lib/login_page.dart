import 'package:flutter/material.dart';
import 'home_page.dart';

class LoginPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white, // Set the background color
      body: Center(
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
                  borderRadius: BorderRadius.circular(75),
                ),
                child: Center(
                  child: Text(
                    'LOGO',
                    style: TextStyle(fontSize: 20, color: Colors.grey),
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

              // Login Button
              ElevatedButton(
                onPressed: () {
                  // Add login logic here later
                    Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (context) => HomePage()),
                              );
                },
                style: ElevatedButton.styleFrom(
                  minimumSize: Size(double.infinity, 50), // Full-width button
                ),
                child: Text('Login'),
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
              SizedBox(height: 40), // Add some spacing before the guest button

              // Continue as Guest Button
              OutlinedButton(
                onPressed: () {
                  // Add guest login logic here
                  Navigator.pushNamed(context, '/guestHome'); // Example navigation
                },
                style: OutlinedButton.styleFrom(
                  minimumSize: Size(double.infinity, 50), // Full-width button
                  side: BorderSide(color: Colors.blue),
                ),
                child: Text(
                  'Continue as Guest',
                  style: TextStyle(color: Colors.blue),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
