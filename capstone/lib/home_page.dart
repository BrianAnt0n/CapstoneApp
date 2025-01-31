import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'login_page.dart';
import 'Others tab/account_management_page.dart';
import 'Others tab/esp_connection_page.dart';
import 'Others tab/app_guide_page.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'constants.dart';

// State Management: Tracks the selected container
class ContainerState extends ChangeNotifier {
  int? selectedContainerId;

  void selectContainer(int containerId) {
    selectedContainerId = containerId;
    notifyListeners();
  }
}

class HomePage extends StatefulWidget {
  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _currentIndex = 0; // Tracks the selected tab index

  // Pages for bottom navigation
  final List<Widget> _pages = [
    DashboardPage(),
    ContainerPage(),
    OthersPage(),
  ];

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => ContainerState(),
      child: Scaffold(
        appBar: AppBar(
          title: Text('E-ComposThink Home'), // AppBar title
        ),
        body: _pages[_currentIndex], // Show the selected page

        // Updated Bottom Navigation Bar with green theme
        bottomNavigationBar: BottomNavigationBar(
          currentIndex: _currentIndex,
          selectedItemColor: Colors.green, // Change selected icon color to green
          unselectedItemColor: Colors.green[300], // Light green for unselected icons
          onTap: (index) {
            setState(() {
              _currentIndex = index; // Update the selected tab
            });
          },
          items: [
            BottomNavigationBarItem(
              icon: Icon(Icons.dashboard),
              label: 'Dashboard',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.inbox),
              label: 'Container',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.more_horiz),
              label: 'Others',
            ),
          ],
        ),
      ),
    );
  }
}
// Dashboard Page: Displays sensor data for the selected container
// Dashboard Page with pull-to-refresh functionality
class DashboardPage extends StatefulWidget {
  @override
  _DashboardPageState createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  Future<Map<String, dynamic>>? _sensorDataFuture;
  Future<List<Map<String, dynamic>>>? _notesFuture;
  int? selectedContainerId;
  TextEditingController _notesController = TextEditingController();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final containerState = Provider.of<ContainerState>(context);
    selectedContainerId = containerState.selectedContainerId;
    if (selectedContainerId != null) {
      _sensorDataFuture = fetchSensorData(selectedContainerId!);
      _notesFuture = fetchNotes(selectedContainerId!);
    }
  }

  Future<void> _refreshData() async {
    if (selectedContainerId != null) {
      setState(() {
        _sensorDataFuture = fetchSensorData(selectedContainerId!);
        _notesFuture = fetchNotes(selectedContainerId!);
      });
    }
  }

  Future<void> _addNote() async {
    if (selectedContainerId != null && _notesController.text.isNotEmpty) {
      await addNoteToDatabase(selectedContainerId!, _notesController.text);
      _notesController.clear();
      setState(() {
        _notesFuture = fetchNotes(selectedContainerId!);
      });
    }
  }

  String formatTimestamp(String timestamp) {
  try {
    DateTime parsedDate = DateTime.parse(timestamp);
    return DateFormat('yyyy-MM-dd hh:mm a').format(parsedDate);
  } catch (e) {
    return 'Invalid Date';
  }
}


  @override
  Widget build(BuildContext context) {
    return selectedContainerId == null
        ? Center(
            child: Text('Please select a container from the Container tab.'))
        : RefreshIndicator(
            onRefresh: _refreshData,
            child: SingleChildScrollView(
              physics: AlwaysScrollableScrollPhysics(),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Dashboard Section
                    Text('Dashboard',
                        style: TextStyle(
                            fontSize: 24, fontWeight: FontWeight.bold)),
                    SizedBox(height: 20),
                    Text('Selected Container: $selectedContainerId',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.w500)),
                    SizedBox(height: 10),
                    FutureBuilder(
                      future: _sensorDataFuture,
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return Center(child: CircularProgressIndicator());
                        } else if (snapshot.hasError) {
                          return Text('Error fetching data');
                        } else {
                          final sensorData =
                              snapshot.data as Map<String, dynamic>;
                          return Column(
                            children: [
                              buildSensorCard(
                                  Icons.thermostat,
                                  'Temperature Monitoring',
                                  '${sensorData['temperature']}°C',
                                  Colors.green),
                              buildSensorCard(
                                  Icons.water_drop,
                                  'Moisture Level',
                                  '${sensorData['moisture']}%',
                                  Colors.blue),
                              buildSensorCard(Icons.science, 'pH Level 1',
                                  '${sensorData['ph_level']}', Colors.purple),
                              buildSensorCard(
                                  Icons.science_outlined,
                                  'pH Level 2',
                                  '${sensorData['ph_level2']}',
                                  Colors.deepPurple),
                              buildSensorCard(Icons.cloud, 'Humidity',
                                  '${sensorData['humidity']}%', Colors.orange),
                              buildSensorCard(Icons.access_time, 'Timestamp',
                                  formatTimestamp(sensorData['timestamp']),
                                  Colors.grey),
                            ],
                          );
                        }
                      },
                    ),

                    // Notes Section (placed below dashboard)
                    SizedBox(height: 30),
                    Divider(thickness: 2), // Adds a separator line
                    SizedBox(height: 10),
                    Text('Notes',
                        style: TextStyle(
                            fontSize: 24, fontWeight: FontWeight.bold)),
                    TextField(
                      controller: _notesController,
                      decoration: InputDecoration(
                          hintText: 'Enter a note',
                          suffixIcon: IconButton(
                              icon: Icon(Icons.add), onPressed: _addNote)),
                    ),
                    SizedBox(height: 10),
                    FutureBuilder(
                      future: _notesFuture,
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return Center(child: CircularProgressIndicator());
                        } else if (snapshot.hasError || snapshot.data == null) {
                          return Text('No notes found.');
                        } else {
                          final notes =
                              snapshot.data as List<Map<String, dynamic>>;
                          return Column(
                            children: notes
                                .map(
                                  (note) => Card(
                                    child: ListTile(
                                      title: Text(
                                          note['note'] ?? 'No note available'),
                                      subtitle: Text(
                                          formatTimestamp(note['created_date'])),
                                    ),
                                  ),
                                )
                                .toList(),
                          );
                        }
                      },
                    ),
                  ],
                ),
              ),
            ),
          );
  }
}

Future<void> updateNoteInDatabase(int noteId, String updatedNote) async {
  final supabase = Supabase.instance.client;

  try {
    await supabase
        .from('Notes_test_test')
        .update({'note': updatedNote}).eq('note_id', noteId);
    print('Note updated successfully');
  } catch (error) {
    print('Error updating note: $error');
  }
}

Future<void> deleteNoteFromDatabase(int noteId) async {
  final supabase = Supabase.instance.client;

  try {
    await supabase.from('Notes_test_test').delete().eq('note_id', noteId);
    print('Note deleted successfully');
  } catch (error) {
    print('Error deleting note: $error');
  }
}

//notes database
Future<void> addNoteToDatabase(int containerId, String note) async {
  final supabase = Supabase.instance.client;
  await supabase.from('Notes_test_test').insert({
    'container_id': containerId,
    'note': note,
    'created_date': DateTime.now().toIso8601String(), // ✅ Use ISO format
  });
}

Future<List<Map<String, dynamic>>> fetchNotes(int containerId) async {
  final supabase = Supabase.instance.client;

  try {
    final response = await supabase
        .from('Notes_test_test')
        .select('note_id, container_id, note, created_date')
        .eq('container_id', containerId)
        .order('created_date', ascending: false);

    if (response == null || response.isEmpty) {
      print("No notes found for container $containerId");
      return [];
    }

    return response.map((note) {
      return {
        'note_id': note['note_id'] ?? 0,
        'container_id': note['container_id'] ?? 0,
        'note': note['note']?.toString() ?? 'No note available',
        'created_date': note['created_date']?.toString() ?? 'Unknown date',
      };
    }).toList();
  } catch (error) {
    print("Error fetching notes: $error");
    return [];
  }
}

Widget buildSensorCard(IconData icon, String title, String value, Color color) {
  return Card(
    elevation: 4,
    child: ListTile(
      leading: Icon(icon, color: color),
      title: Text(title),
      subtitle: Text(value),
    ),
  );
}

//Database Fetching: Fetch sensor data for a specific container
Future<Map<String, dynamic>> fetchSensorData(int containerId) async {
  final supabase = Supabase.instance.client;
  final containerResponse = await supabase
      .from('Containers_test')
      .select('hardware_id')
      .eq('container_id', containerId)
      .single();
  final hardwareId = containerResponse['hardware_id'];

  final sensorResponse = await supabase
      .from('Hardware_Sensors_Test')
      .select('temperature, moisture, ph_level, ph_level2, humidity, timestamp')
      .eq('hardware_id', hardwareId)
      .order('timestamp', ascending: false)
      .limit(1)
      .single();

  return sensorResponse;
}

// Container Page: Displays a list of available containers

class ContainerPage extends StatefulWidget {
  @override
  _ContainerPageState createState() => _ContainerPageState();
}

class _ContainerPageState extends State<ContainerPage> {
  late Future<List<Map<String, dynamic>>> _containersFuture;

  @override
  void initState() {
    super.initState();
    _fetchContainers();
  }

  void _fetchContainers() {
    setState(() {
      _containersFuture = fetchContainers();
    });
  }

  @override
  Widget build(BuildContext context) {
    final containerState = Provider.of<ContainerState>(context);

    return FutureBuilder(
      future: _containersFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator());
        } else if (snapshot.hasError) {
          return Center(
              child: Text('Error fetching containers: ${snapshot.error}'));
        } else {
          final containers = snapshot.data as List<Map<String, dynamic>>;

          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    minimumSize: Size(double.infinity, 50),
                  ),
                  onPressed: () {
                    _showAddContainerDialog(context);
                  },
                  icon: Icon(Icons.add, color: Colors.white),
                  label: Text('New container',
                      style: TextStyle(color: Colors.white)),
                ),
                SizedBox(height: 16),
                Expanded(
                  child: ListView.builder(
                    itemCount: containers.length,
                    itemBuilder: (context, index) {
                      final container = containers[index];
                      final isSelected = container['container_id'] ==
                          containerState.selectedContainerId;

                      return Card(
                        color: isSelected ? Colors.green[100] : null,
                        child: ListTile(
                          title: Text('${container['container_name']}'),
                          subtitle:
                              Text('Date Added: ${container['date_added']}'),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (isSelected)
                                Icon(Icons.check_circle, color: Colors.green),
                              IconButton(
                                icon: Icon(Icons.edit, color: Colors.blue),
                                onPressed: () {
                                  _showRenameContainerDialog(
                                      context, container['container_id']);
                                },
                              ),
                              IconButton(
                                icon: Icon(Icons.delete, color: Colors.red),
                                onPressed: () {
                                  _showDeleteConfirmationDialog(
                                      context, container['container_id']);
                                },
                              ),
                            ],
                          ),
                          onTap: () {
                            if (isSelected) {
                              containerState.selectContainer(0);
                            } else {
                              containerState
                                  .selectContainer(container['container_id']);
                            }
                          },
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        }
      },
    );
  }

  void _showAddContainerDialog(BuildContext context) {
    TextEditingController _nameController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("Add New Container"),
        content: TextField(
          controller: _nameController,
          decoration: InputDecoration(hintText: "Enter container name"),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text("Cancel"),
          ),
          TextButton(
            onPressed: () {
              addContainer(_nameController.text);
              Navigator.pop(context);
            },
            child: Text("Add"),
          ),
        ],
      ),
    );
  }

  void _showRenameContainerDialog(BuildContext context, int containerId) {
    TextEditingController _renameController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("Rename Container"),
        content: TextField(
          controller: _renameController,
          decoration: InputDecoration(hintText: "Enter new container name"),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text("Cancel"),
          ),
          TextButton(
            onPressed: () async {
              await renameContainer(containerId, _renameController.text);
              Navigator.pop(context);
              _fetchContainers(); // 🔄 Refresh UI after renaming
            },
            child: Text("Rename"),
          ),
        ],
      ),
    );
  }

  void _showDeleteConfirmationDialog(BuildContext context, int containerId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("Delete Container"),
        content: Text("Are you sure you want to delete this container?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text("Cancel"),
          ),
          TextButton(
            onPressed: () {
              deleteContainer(containerId);
              Navigator.pop(context);
            },
            child: Text("Delete"),
          ),
        ],
      ),
    );
  }
}

Future<void> addContainer(String name) async {
  final supabase = Supabase.instance.client;
  await supabase.from('Containers_test').insert({'container_name': name});
}

Future<void> renameContainer(int containerId, String newName) async {
  final supabase = Supabase.instance.client;
  await supabase
      .from('Containers_test')
      .update({'container_name': newName}).eq('container_id', containerId);
}

Future<void> deleteContainer(int containerId) async {
  final supabase = Supabase.instance.client;
  await supabase
      .from('Containers_test')
      .delete()
      .eq('container_id', containerId);
}

Future<List<Map<String, dynamic>>> fetchContainers() async {
  final supabase = Supabase.instance.client;
  try {
    final response = await supabase.from('Containers_test').select('*');
    print('Supabase Response: $response');
    return List<Map<String, dynamic>>.from(response);
  } catch (error) {
    print('Error fetching containers: $error');
    throw Exception('Error fetching containers: $error');
  }
}

// Others Page: Displays options like Account Management, ESP Connection, App Guide, and Log Out
class OthersPage extends StatelessWidget {
  // Function to launch the URL for downloading the APK
  Future<void> _downloadApk() async {
    final Uri apkUri = Uri.parse(
      "https://github.com/BrianAnt0n/ESP-CONNECTION-APP/releases/download/ESP.V.2.4.0/EspTouch.vv2.4.0.apk",
    );

    if (!await launchUrl(apkUri, mode: LaunchMode.externalApplication)) {
      throw 'Could not launch $apkUri';
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        // Account Management
        ListTile(
          leading: Icon(Icons.person, color: Colors.green),
          title: Text('Account Management'),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => AccountManagementPage()),
            );
          },
        ),
        // ESP Connection
        ListTile(
          leading: Icon(Icons.wifi, color: Colors.blue),
          title: Text('ESP Connection'),
          onTap: _downloadApk, // Call the download function
        ),
        // App Guide
        ListTile(
          leading: Icon(Icons.help_outline, color: Colors.orange),
          title: Text('App Guide'),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => AppGuidePage()),
            );
          },
        ),
        // Log Out
        ListTile(
          leading: Icon(Icons.logout, color: Colors.red),
          title: Text('Log Out'),
          onTap: () {
            showDialog(
              context: context,
              builder: (BuildContext context) {
                return AlertDialog(
                  title: Text('Log Out'),
                  content: Text('Are you sure you want to log out?'),
                  actions: [
                    TextButton(
                      onPressed: () {
                        Navigator.of(context).pop(); // Close dialog
                      },
                      child: Text('Cancel'),
                    ),
                    TextButton(
                      onPressed: () {
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(builder: (context) => LoginPage()),
                        );
                      },
                      child: Text('Log Out'),
                    ),
                  ],
                );
              },
            );
          },
        ),
      ],
    );
  }
}
