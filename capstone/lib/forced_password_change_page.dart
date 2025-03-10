import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'home_page.dart';
import 'home_page_members.dart';

class ForcedPasswordChangePage extends StatefulWidget {
  const ForcedPasswordChangePage({super.key});

  @override
  _ForcedPasswordChangePageState createState() => _ForcedPasswordChangePageState();
}

class _ForcedPasswordChangePageState extends State<ForcedPasswordChangePage> {
  final supabase = Supabase.instance.client;
  final TextEditingController _newPasswordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();
  String? _errorText;
  bool _isPasswordChanged = false;
  String _userLevel = "Member";

  @override
  void initState() {
    super.initState();
    _loadUserDetails();
  }

  Future<void> _loadUserDetails() async {
    final prefs = await SharedPreferences.getInstance();
    final userLevel = prefs.getString("user_level_pref") ?? "Member";
    setState(() {
      _userLevel = userLevel;
    });

    Future.delayed(const Duration(milliseconds: 500), () {
      _showPasswordChangeDialog();
    });
  }

  Future<void> _updatePassword() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString("user_id_pref");
    final newPassword = _newPasswordController.text.trim();
    final confirmPassword = _confirmPasswordController.text.trim();

    if (newPassword.isEmpty || confirmPassword.isEmpty) {
      setState(() => _errorText = "Password fields cannot be empty");
      return;
    }
    if (newPassword != confirmPassword) {
      setState(() => _errorText = "Passwords do not match");
      return;
    }
    if (newPassword == "Temp1234!") {
      setState(() => _errorText = "You cannot use the temporary password.");
      return;
    }

    try {
      await supabase
          .from('Users')
          .update({'password': newPassword})
          .eq('user_id', int.parse(userId!));

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Password updated successfully!')),
      );

      setState(() {
        _isPasswordChanged = true;
      });

      Future.delayed(const Duration(seconds: 1), () {
        if (_userLevel == "Admin") {
          Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const HomePage()));
        } else {
          Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const HomePageMember()));
        }
      });
    } catch (error) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error updating password: $error')),
      );
    }
  }

  void _showPasswordChangeDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text("Password Change Required"),
        content: const Text("You must change your password before continuing."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("OK"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        return _isPasswordChanged;
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Reset Your Password'),
          automaticallyImplyLeading: false,
        ),
        body: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "Set a new password to continue:",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 20),
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
              ElevatedButton(
                onPressed: _updatePassword,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  minimumSize: const Size(double.infinity, 50),
                ),
                child: const Text("Change Password", style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
