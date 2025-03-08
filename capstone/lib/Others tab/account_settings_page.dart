import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:capstone/home_page.dart';
import 'package:capstone/home_page_members.dart';


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
  String _email = "Loading..."; // ✅ Store email
  String _userLevel = "Loading..."; // ✅ Store user level
  final TextEditingController _fullnameController = TextEditingController(); // ✅ Controller for full name


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
      _fullname = "User";
      _email = "No Email"; // ✅ Default value for email
      _userLevel = "Member"; // ✅ Default value for role
    });
    return;
  }

  try {
    final response = await supabase
        .from('Users')
        .select('fullname, email, user_level') // ✅ Fetch email & role
        .eq('user_id', int.parse(userId))
        .single();

    setState(() {
      _fullname = response['fullname'] ?? "User";
      _email = response['email'] ?? "No Email"; // ✅ Store email
      _userLevel = response['user_level'] ?? "Member"; // ✅ Store user role
    });
  } catch (error) {
    setState(() {
      _fullname = "User";
      _email = "Error loading email";
      _userLevel = "Member";
    });
  }
}

Future<void> _updateFullName() async {
  final prefs = await SharedPreferences.getInstance();
  final userId = prefs.getString("user_id_pref");
  final newFullName = _fullnameController.text.trim(); // ✅ Get new full name

  if (userId == null) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('User session not found. Please log in again.')),
    );
    return;
  }

  if (newFullName.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Full Name cannot be empty.")),
    );
    return;
  }

  try {
    await supabase.from('Users').update({'fullname': newFullName}).eq('user_id', int.parse(userId));

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Full Name updated successfully!')),
    );

    setState(() {
      _fullname = newFullName; // ✅ Update UI with new name
    });

    _fullnameController.clear(); // ✅ Clear the text field after update

  } catch (error) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Error updating full name: $error')),
    );
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

  // ✅ Email format validation
  final emailRegex = RegExp(r'^[a-z0-9._%+-]+@[a-z0-9.-]+\.[a-z]{2,}$');
  if (!emailRegex.hasMatch(newEmail)) {
    setState(() => _errorText = "Invalid email format");
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
           Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ✅ Display User Name
                Text(
                  "Hello, $_fullname",
                  style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.green),
                ),
                const SizedBox(height: 5),

                // ✅ Display Email
                Text(
                  "Email: $_email",
                  style: const TextStyle(fontSize: 16, color: Colors.black),
                ),
                const SizedBox(height: 5),

                // ✅ Display User Role
                Text(
                  "Role: $_userLevel",
                  style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue),
                ),
                const SizedBox(height: 20),
              ],
            ),

            const SizedBox(height: 20),

            _buildSectionCard(
              title: "Update Full Name",
              child: Column(
                children: [
                  TextField(
                    controller: _fullnameController,
                    decoration:
                        const InputDecoration(labelText: 'New Full Name'),
                  ),
                  const SizedBox(height: 10),
                  _buildButton("Update Full Name", _updateFullName),
                ],
              ),
            ),
            const SizedBox(height: 20), // ✅ Add spacing before "Update Email"


            const SizedBox(height: 20),

            _buildSectionCard(
              title: "Update Email",
              child: Column(
                children: [
                  TextField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(labelText: 'New Email'),
                    onChanged: (value) {
                      _emailController.value = _emailController.value.copyWith(
                        text: value
                            .toLowerCase(), // ✅ Converts input to lowercase
                        selection:
                            TextSelection.collapsed(offset: value.length),
                      );
                    },
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
