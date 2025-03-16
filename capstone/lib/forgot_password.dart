import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({super.key});

  @override
  _ForgotPasswordPageState createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  final TextEditingController _usernameController = TextEditingController();
  bool _isLoading = false;
  String? _message;
  bool _isError = false;

  Future<void> _requestPasswordReset() async {
    final String username = _usernameController.text.trim();

    if (username.isEmpty) {
      setState(() {
        _message = "Please enter your username.";
        _isError = true;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _message = null;
    });

    final supabase = Supabase.instance.client;

    try {
      // Check if the username exists in the database
      final response = await supabase
          .from('Users')
          .select('user_id') // Only fetch user_id
          .eq('username', username)
          .maybeSingle();

      if (response == null) {
        setState(() {
          _message = "username not found. Please check and try again.";
          _isError = true;
        });
        return;
      }

      // Store password reset request in the database
      await supabase.from('Users').update({
        'reset_requested': true,
      }).eq('username', username);

      setState(() {
        _message =
            "Password reset request sent. Please contact an Admin to reset your password.";
        _isError = false;
      });
    } catch (error) {
      setState(() {
        _message = "Error: ${error.toString()}";
        _isError = true;
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
      appBar: AppBar(title: const Text('Forgot Password')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.lock_reset, size: 80, color: Colors.green),
            const SizedBox(height: 20),
            const Text(
              'Enter your username to request a password reset. An Admin will reset your password manually.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _usernameController,
              keyboardType: TextInputType.text,
              decoration: InputDecoration(
                labelText: 'Username',
                border: OutlineInputBorder(),
                prefixIcon: const Icon(Icons.person, color: Colors.green),
              ),
            ),
            if (_message != null) ...[
              const SizedBox(height: 10),
              Text(
                _message!,
                style: TextStyle(
                  color: _isError ? Colors.red : Colors.green,
                ),
              ),
            ],
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _isLoading ? null : _requestPasswordReset,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                minimumSize: const Size(double.infinity, 50),
              ),
              child: _isLoading
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text('Request Password Reset',
                      style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }
}
