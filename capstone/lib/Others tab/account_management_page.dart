import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'add_account_page.dart';
import 'account_settings_page.dart';
import 'package:flutter/services.dart';


class AccountManagementPage extends StatefulWidget {
  const AccountManagementPage({super.key});

  @override
  _AccountManagementPageState createState() => _AccountManagementPageState();
}

class _AccountManagementPageState extends State<AccountManagementPage> {
  late Future<List<Map<String, dynamic>>> _accountsFuture;

  @override
  void initState() {
    super.initState();
    _fetchAccounts();
  }

  void _fetchAccounts() {
    setState(() {
      _accountsFuture = fetchAccounts();
    });
  }

  Future<List<Map<String, dynamic>>> fetchAccounts() async {
    final supabase = Supabase.instance.client;
    final response = await supabase
        .from('Users')
        .select('user_id, user_level, fullname, email, reset_requested')
        .order('user_id', ascending: true);
    return List<Map<String, dynamic>>.from(response);
  }

  Future<void> editAccount(int userId, String newName) async {
    final supabase = Supabase.instance.client;
    await supabase
        .from('Users')
        .update({'fullname': newName})
        .eq('user_id', userId);
    _fetchAccounts(); // Refresh the list
  }

  Future<void> deleteAccount(int userId, String userLevel) async {
    if (userLevel == 'Admin') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Admins cannot delete other Admins.")),
      );
      return;
    }

    final supabase = Supabase.instance.client;
    await supabase.from('Containers_test').delete().eq('user_id', userId);
    await supabase.from('Users').delete().eq('user_id', userId);
    _fetchAccounts(); // Refresh the list
  }

  Future<void> resetPassword(int userId) async {
  final supabase = Supabase.instance.client;
  const String defaultPassword = "Temp1234!"; // Default reset password

  await supabase.from('Users').update({'password': defaultPassword}).eq('user_id', userId);

  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(
      content: Text("Password reset successfully! New password: Temp1234!"),
      backgroundColor: Colors.orange,
    ),
  );
}


  void _showEditDialog(BuildContext context, int userId, String currentName) {
    TextEditingController nameController = TextEditingController(text: currentName);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Edit Account"),
        content: TextField(
          controller: nameController,
          decoration: const InputDecoration(hintText: "Enter new name"),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () async {
              await editAccount(userId, nameController.text);
              Navigator.pop(context);
            },
            child: const Text("Save"),
          ),
        ],
      ),
    );
  }

  void _showDeleteConfirmation(BuildContext context, int userId, String userLevel) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Delete Account"),
        content: const Text("Are you sure you want to delete this account?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () async {
              await deleteAccount(userId, userLevel);
              Navigator.pop(context);
            },
            child: const Text("Delete"),
          ),
        ],
      ),
    );
  }

  void _showResetPasswordDialog(BuildContext context, int userId) {
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text("Reset Password"),
      content: const Text("Are you sure you want to reset this user's password?"),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text("Cancel"),
        ),
        TextButton(
  onPressed: () async {
    await resetPassword(userId);
    Navigator.pop(context);
    
    // Show new password and copy button
    _showPasswordCopiedDialog(context);
  },
  child: const Text("Reset", style: TextStyle(color: Colors.orange)),

        ),
      ],
    ),
  );
}

void _showPasswordCopiedDialog(BuildContext context) {
  const String newPassword = "Temp1234!"; // Same default password

  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text("Password Reset Successful"),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text("New password:"),
          const SizedBox(height: 8),
          SelectableText(
            newPassword,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
          ),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed: () {
              Clipboard.setData(const ClipboardData(text: newPassword));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("Password copied to clipboard!")),
              );
            },
            icon: const Icon(Icons.copy),
            label: const Text("Copy Password"),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text("Close"),
        ),
      ],
    ),
  );
}



  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Account Management')),
      body: RefreshIndicator(
        onRefresh: () async {
          _fetchAccounts();
        },
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  minimumSize: const Size(double.infinity, 50),
                ),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const AccountSettingsPage()),
                  );
                },
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.settings, color: Colors.white),
                    SizedBox(width: 8),
                    Text('Account Settings', style: TextStyle(color: Colors.white)),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  minimumSize: const Size(double.infinity, 50),
                ),
                onPressed: () async {
                  final result = await Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const AddAccountPage()),
                  );
                  if (result == true) {
                    _fetchAccounts(); // Refresh the account list when returning
                  }
                },
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.add, color: Colors.white),
                    SizedBox(width: 8),
                    Text('New Account', style: TextStyle(color: Colors.white)),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              const Text('Account List', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              Expanded(
                child: FutureBuilder(
                  future: _accountsFuture,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    } else if (snapshot.hasError) {
                      return Center(child: Text('Error: ${snapshot.error}'));
                    } else {
                      final accounts = snapshot.data as List<Map<String, dynamic>>;
                      if (accounts.isEmpty) {
                        return const Center(child: Text('No accounts found.'));
                      }
                      return ListView.builder(
                        itemCount: accounts.length,
                        itemBuilder: (context, index) {
                          final account = accounts[index];
                          return Card(
                            child: ListTile(
                              leading: Icon(
                                account['user_level'] == 'Admin'
                                    ? Icons.admin_panel_settings
                                    : Icons.person,
                                color: account['user_level'] == 'Admin' ? Colors.red : Colors.blue,
                              ),
                              title: Text(account['fullname']),
                              subtitle: Text('${account['user_level']} | ${account['email']}'),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  // ✅ Show Reset Password button **ONLY** if reset_requested is true and user is not an Admin
                                  if (account['reset_requested'] == true &&
                                      account['user_level'] != 'Admin')
                                    IconButton(
                                      icon: const Icon(Icons.lock_reset,
                                          color: Colors.orange),
                                      onPressed: () {
                                        _showResetPasswordDialog(
                                            context, account['user_id']);
                                      },
                                    ),

                                  // ✅ Edit button (always available)
                                  IconButton(
                                    icon: const Icon(Icons.edit,
                                        color: Colors.blue),
                                    onPressed: () {
                                      _showEditDialog(
                                          context,
                                          account['user_id'],
                                          account['fullname']);
                                    },
                                  ),

                                  // ✅ Delete button (Admins cannot delete other Admins)
                                  //if (account['user_level'] != 'Admin')
                                    IconButton(
                                      icon: const Icon(Icons.delete,
                                          color: Colors.red),
                                      onPressed: () {
                                        _showDeleteConfirmation(
                                            context,
                                            account['user_id'],
                                            account['user_level']);

                                    },
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      );
                    }
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
