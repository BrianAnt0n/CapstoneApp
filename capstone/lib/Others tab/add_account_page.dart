import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '/constants.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final supabase = Supabase.instance.client;

class AddAccountPage extends StatefulWidget {
  const AddAccountPage({super.key});

  @override
  _AddAccountPageState createState() => _AddAccountPageState();
}

class _AddAccountPageState extends State<AddAccountPage> {
  final TextEditingController _fullnameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  String _selectedUserLevel = 'Admin';

  Future<void> _addAccount() async {
    final String fullname = _fullnameController.text.trim();
    final String email = _emailController.text.trim();
    final String password = _passwordController.text.trim();
    final String userLevel = _selectedUserLevel;

    if (fullname.isEmpty ||
        email.isEmpty ||
        password.isEmpty ||
        userLevel.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill in all fields')),
      );
      return;
    }

    try {
      final response = await supabase.from('Users').insert({
        'fullname': fullname,
        'email': email,
        'password': password,
        'user_level': userLevel,
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Account added successfully!')),
      );
      Navigator.pop(context);
    } catch (error) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error adding account: $error')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Add Account')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Fullname'),
            TextField(controller: _fullnameController),
            const SizedBox(height: 10),
            const Text('Email'),
            TextField(controller: _emailController),
            const SizedBox(height: 10),
            const Text('Password'),
            TextField(controller: _passwordController, obscureText: true),
            const SizedBox(height: 10),
            const Text('User Level'),
            DropdownButton<String>(
              value: _selectedUserLevel,
              onChanged: (String? newValue) {
                setState(() {
                  _selectedUserLevel = newValue!;
                });
              },
              items: <String>['Admin', 'Member']
                  .map<DropdownMenuItem<String>>((String value) {
                return DropdownMenuItem<String>(
                  value: value,
                  child: Text(value),
                );
              }).toList(),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _addAccount,
              child: const Text('Add Account'),
            ),
          ],
        ),
      ),
    );
  }
}
