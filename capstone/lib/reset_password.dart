import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ResetPasswordPage extends StatefulWidget {
  final String resetToken; // Token from the email link

  const ResetPasswordPage({super.key, required this.resetToken});

  @override
  _ResetPasswordPageState createState() => _ResetPasswordPageState();
}

class _ResetPasswordPageState extends State<ResetPasswordPage> {
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;
  String? _successMessage;

  Future<void> _resetPassword() async {
    final String newPassword = _passwordController.text.trim();
    final String confirmPassword = _confirmPasswordController.text.trim();

    if (newPassword.isEmpty || confirmPassword.isEmpty) {
      setState(() {
        _errorMessage = "Please fill in all fields.";
      });
      return;
    }

    if (newPassword != confirmPassword) {
      setState(() {
        _errorMessage = "Passwords do not match.";
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _successMessage = null;
    });

    final supabase = Supabase.instance.client;

    try {
      // Validate the token and get user
      final response = await supabase
          .from('Users')
          .select('user_id')
          .eq('reset_token', widget.resetToken)
          .maybeSingle();

      if (response == null) {
        setState(() {
          _errorMessage = "Invalid or expired reset link.";
        });
        return;
      }

      final int userId = response['user_id'];

      // Update password in Supabase
      await supabase.from('Users').update({
        'password': newPassword, // Store securely in a real app
        'reset_token': null, // Clear the reset token after successful update
      }).eq('user_id', userId);

      setState(() {
        _successMessage = "Password reset successfully! You can now log in.";
      });

      Future.delayed(const Duration(seconds: 2), () {
        Navigator.pop(context); // Navigate back to login
      });
    } catch (error) {
      setState(() {
        _errorMessage = "Error: ${error.toString()}";
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Reset Password'),
        backgroundColor: Colors.green, // Themed AppBar
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.lock_outline, size: 80, color: Colors.green),
            const SizedBox(height: 15),
            const Text(
              'Enter your new password below.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 20),
            // Password Field
            TextField(
              controller: _passwordController,
              obscureText: true,
              decoration: InputDecoration(
                labelText: 'New Password',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10), // Rounded corners
                ),
                prefixIcon: const Icon(Icons.lock, color: Colors.green),
              ),
            ),
            const SizedBox(height: 10),
            // Confirm Password Field
            TextField(
              controller: _confirmPasswordController,
              obscureText: true,
              decoration: InputDecoration(
                labelText: 'Confirm Password',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10), // Rounded corners
                ),
                prefixIcon: const Icon(Icons.lock, color: Colors.green),
              ),
            ),
            if (_errorMessage != null) ...[
              const SizedBox(height: 10),
              Text(
                _errorMessage!,
                style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
              ),
            ],
            if (_successMessage != null) ...[
              const SizedBox(height: 10),
              Text(
                _successMessage!,
                style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold),
              ),
            ],
            const SizedBox(height: 20),
            // Reset Password Button
            ElevatedButton(
              onPressed: _isLoading ? null : _resetPassword,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                minimumSize: const Size(double.infinity, 50),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10), // Button rounded edges
                ),
              ),
              child: _isLoading
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text('Reset Password', style: TextStyle(color: Colors.white, fontSize: 16)),
            ),
          ],
        ),
      ),
    );
  }
}
