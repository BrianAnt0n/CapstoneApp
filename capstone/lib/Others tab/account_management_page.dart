import 'package:flutter/material.dart';
import 'add_account_page.dart'; // Import the new AddAccountPage

class AccountManagementPage extends StatelessWidget {
  const AccountManagementPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Account Management'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                minimumSize: const Size(double.infinity, 50),
              ),
              onPressed: () {
                // Navigate to Add Account Page
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => AddAccountPage()),
                );
              },
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.add, color: Colors.white),
                  SizedBox(width: 8),
                  Text(
                    'New Account',
                    style: TextStyle(color: Colors.white),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Account list',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            // TODO: Display list of accounts here from Supabase
          ],
        ),
      ),
    );
  }
}
