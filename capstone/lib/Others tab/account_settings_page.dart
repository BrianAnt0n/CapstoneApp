import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AccountSettingsPage extends StatefulWidget {
  const AccountSettingsPage({super.key});

  @override
  _AccountSettingsPageState createState() => _AccountSettingsPageState();
}

class _AccountSettingsPageState extends State<AccountSettingsPage> {
  final supabase = Supabase.instance.client;
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _newPasswordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();
  String? _errorText;
  String _fullname = "Loading..."; // Placeholder while fetching data

  @override
  void initState() {
    super.initState();
    _loadUserDetails();
  }

  Future<void> _loadUserDetails() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString("user_id_pref");

    if (userId == null) {
      setState(() {
        _fullname = "User"; // Default if no user is logged in
      });
      return;
    }

    try {
      final response = await supabase
          .from('Users')
          .select('fullname')
          .eq('user_id', int.parse(userId))
          .single();

      setState(() {
        _fullname = response['fullname'] ?? "User";
      });
    } catch (error) {
      setState(() {
        _fullname = "User";
      });
    }
  }

  Future<void> _updateEmail() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString("user_id_pref");
    final newEmail = _emailController.text.trim();

    if (userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('User session not found. Please log in again.')),
      );
      return;
    }

    if (newEmail.isEmpty) {
      setState(() => _errorText = "Email cannot be empty");
      return;
    }

    try {
      await supabase.from('Users').update({'email': newEmail}).eq('user_id', int.parse(userId));

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Email updated successfully!')),
      );

      _refreshPage();
    } catch (error) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error updating email: $error')),
      );
    }
  }

  Future<void> _updatePassword() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString("user_id_pref");
    final newPassword = _newPasswordController.text.trim();
    final confirmPassword = _confirmPasswordController.text.trim();

    if (userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('User session not found. Please log in again.')),
      );
      return;
    }

    if (newPassword.isEmpty || confirmPassword.isEmpty) {
      setState(() => _errorText = "Password fields cannot be empty");
      return;
    }
    if (newPassword != confirmPassword) {
      setState(() => _errorText = "Passwords do not match");
      return;
    }

    try {
      await supabase.from('Users').update({'password': newPassword}).eq('user_id', int.parse(userId));

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Password updated successfully!')),
      );

      _refreshPage();
    } catch (error) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error updating password: $error')),
      );
    }
  }

  void _refreshPage() {
    setState(() {
      _loadUserDetails();
      _newPasswordController.clear();
      _confirmPasswordController.clear();
      _emailController.clear();
      _errorText = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Account Settings', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.green,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Welcome message with correct full name
            Text(
              "Change your Credentials Here, $_fullname",
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.green),
            ),
            const SizedBox(height: 20),

            _buildSectionCard(
              title: "Update Email",
              child: Column(
                children: [
                  TextField(
                    controller: _emailController,
                    decoration: const InputDecoration(labelText: 'New Email'),
                  ),
                  const SizedBox(height: 10),
                  _buildButton("Update Email", _updateEmail),
                ],
              ),
            ),
            const SizedBox(height: 20),
            _buildSectionCard(
              title: "Change Password",
              child: Column(
                children: [
                  TextField(
                    controller: _newPasswordController,
                    obscureText: true,
                    decoration: const InputDecoration(labelText: 'New Password'),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _confirmPasswordController,
                    obscureText: true,
                    decoration: const InputDecoration(labelText: 'Confirm New Password'),
                  ),
                  if (_errorText != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Text(_errorText!, style: const TextStyle(color: Colors.red)),
                    ),
                  const SizedBox(height: 10),
                  _buildButton("Change Password", _updatePassword),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionCard({required String title, required Widget child}) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            child,
          ],
        ),
      ),
    );
  }

  Widget _buildButton(String text, VoidCallback onPressed) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.green,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          padding: const EdgeInsets.symmetric(vertical: 12),
        ),
        onPressed: onPressed,
        child: Text(text, style: const TextStyle(color: Colors.white, fontSize: 16)),
      ),
    );
  }
}
