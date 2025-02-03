import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'login_page.dart';
import 'scanner_page.dart';
import 'container_details.dart';
import 'Others tab/account_management_page.dart';
import 'Others tab/esp_connection_page.dart';
import 'Others tab/app_guide_page.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'constants.dart';
import 'package:table_calendar/table_calendar.dart';

// State Management: Tracks the selected container
class ContainerState extends ChangeNotifier {
  int? selectedContainerId;

  void selectContainer(int containerId) {
    selectedContainerId = containerId;
    notifyListeners();
  }
}

class HomePageGuest extends StatefulWidget {
  const HomePageGuest({super.key});

  @override
  _HomePageGuestState createState() => _HomePageGuestState();
}

class _HomePageGuestState extends State<HomePageGuest> {
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
          title: const Text('E-ComposThink Home - Guest'), // AppBar title
        ),
        body: _pages[_currentIndex], // Show the selected page

        // Updated Bottom Navigation Bar with green theme
        bottomNavigationBar: BottomNavigationBar(
          currentIndex: _currentIndex,
          selectedItemColor:
              Colors.green, // Change selected icon color to green
          unselectedItemColor:
              Colors.green[300], // Light green for unselected icons
          onTap: (index) {
            setState(() {
              _currentIndex = index; // Update the selected tab
            });
          },
          items: const [
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
  const DashboardPage({super.key});

  @override
  _DashboardPageState createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  Future<Map<String, dynamic>>? _sensorDataFuture;
  Future<List<Map<String, dynamic>>>? _notesFuture;
  int? selectedContainerId;
  final TextEditingController _notesController = TextEditingController();
  DateTime _selectedDate = DateTime.now(); // Track selected date

  @override
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final containerState = Provider.of<ContainerState>(context);
    selectedContainerId = containerState.selectedContainerId;

    if (selectedContainerId != null) {
      _sensorDataFuture = fetchSensorData(selectedContainerId!);
      _notesFuture = fetchNotes(selectedContainerId!, _selectedDate);

      fetchContainerDetails(selectedContainerId!).then((_) {
        setState(() {}); // ✅ Force calendar to update with container age
      });
    }
  }

  Future<void> _refreshData() async {
    if (selectedContainerId != null) {
      setState(() {
        _sensorDataFuture = fetchSensorData(selectedContainerId!);
        _notesFuture = fetchNotes(selectedContainerId!, _selectedDate);
      });
    }
  }

  DateTime? _containerAddedDate;
  String _containerAge = "";

  Future<void> fetchContainerDetails(int containerId) async {
    final supabase = Supabase.instance.client;

    try {
      final response = await supabase
          .from('Containers_test')
          .select('date_added')
          .eq('container_id', containerId)
          .single();

      if (response != null && response['date_added'] != null) {
        _containerAddedDate = DateTime.parse(response['date_added']);

        _calculateContainerAge();
      } else {}
    } catch (error) {}
  }

// Declare this in your class
  Color _ageColor = Colors.green; // Default to green

  void _calculateContainerAge() {
    if (_containerAddedDate == null) {
      return;
    }

    final now = DateTime.now();
    final difference = now.difference(_containerAddedDate!);
    int days = difference.inDays;
    int weeks = (days / 7).floor(); // Only use weeks, no months

    if (days < 7) {
      _containerAge = "$days ${days == 1 ? 'day' : 'days'}";
    } else {
      _containerAge = "$weeks ${weeks == 1 ? 'week' : 'weeks'}";
    }

    // ✅ Update color based on weeks
    if (weeks >= 12) {
      _ageColor = Colors.red; // Critical (12+ weeks)
    } else if (weeks >= 7) {
      _ageColor = Colors.orange; // Warning (7-11 weeks)
    } else {
      _ageColor = Colors.green; // Safe (1-6 weeks)
    }

    if (mounted) {
      setState(() {}); // Update UI
    }
  }

  Future<void> _addNote() async {
    if (selectedContainerId != null && _notesController.text.isNotEmpty) {
      await addNoteToDatabase(selectedContainerId!, _notesController.text);
      _notesController.clear();
      setState(() {
        _notesFuture = fetchNotes(selectedContainerId!, _selectedDate);
      });
    }
  }

  Future<void> _onDateSelected(DateTime selectedDate) async {
    setState(() {
      _selectedDate = selectedDate;
    });

    _notesFuture = fetchNotes(selectedContainerId!, _selectedDate);
    setState(() {});
  }

  void _showDeleteConfirmationDialog(int noteId) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Delete Note'),
          content: const Text('Are you sure you want to delete this note?'),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () async {
                await deleteNoteFromDatabase(noteId);
                Navigator.pop(context);
                if (mounted) {
                  setState(() {
                    _notesFuture =
                        fetchNotes(selectedContainerId!, _selectedDate);
                  });
                }
              },
              child: const Text('Delete', style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );
  }

  void _showEditDialog(int noteId, String currentNote) {
    TextEditingController editController =
        TextEditingController(text: currentNote);

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Edit Note'),
          content: TextField(
            controller: editController,
            decoration: const InputDecoration(hintText: "Enter new note"),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () async {
                await updateNoteInDatabase(noteId, editController.text);
                Navigator.pop(context);
                if (mounted) {
                  setState(() {
                    _notesFuture =
                        fetchNotes(selectedContainerId!, _selectedDate);
                  });
                }
              },
              child: const Text('Save', style: TextStyle(color: Colors.blue)),
            ),
          ],
        );
      },
    );
  }

  Widget buildNoteCard(Map<String, dynamic> note) {
    return Card(
      child: ListTile(
        title: Text(note['note'] ?? 'No note available'),
        subtitle: Text(formatTimestamp(note['created_date'])),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: Icon(Icons.edit, color: Colors.blue),
              onPressed: () {
                _showEditDialog(note['note_id'], note['note']);
              },
            ),
            IconButton(
              icon: Icon(Icons.delete, color: Colors.red),
              onPressed: () {
                _showDeleteConfirmationDialog(note['note_id']);
              },
            ),
          ],
        ),
      ),
    );
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
        ? const Center(
            child: Text('Please select a container from the Container tab.'))
        : RefreshIndicator(
            onRefresh: _refreshData,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Dashboard',
                        style: TextStyle(
                            fontSize: 24, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 20),
                    Text('Selected Container: $selectedContainerId',
                        style: const TextStyle(
                            fontSize: 18, fontWeight: FontWeight.w500)),
                    const SizedBox(height: 10),
                    FutureBuilder(
                      future: _sensorDataFuture,
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const Center(
                              child: CircularProgressIndicator());
                        } else if (snapshot.hasError) {
                          return const Text('Error fetching data');
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
                              buildSensorCard(
                                  Icons.access_time,
                                  'Timestamp',
                                  formatTimestamp(sensorData['timestamp']),
                                  Colors.grey),
                            ],
                          );
                        }
                      },
                    ),
                    const SizedBox(height: 30),
                    const Divider(thickness: 2),
                    const SizedBox(height: 10),
                    TableCalendar(
                      headerVisible: true,
                      headerStyle: HeaderStyle(
                        titleCentered: true,
                        formatButtonVisible: false, // Hide format toggle
                        titleTextFormatter: (date, locale) {
                          return DateFormat.yMMMM(locale).format(date);
                        },
                      ),
                      calendarBuilders: CalendarBuilders(
                        headerTitleBuilder: (context, date) {
                          String formattedDate =
                              DateFormat.yMMMM().format(date);

                          // ✅ Determine color based on weeks
                          Color ageColor =
                              Colors.green; // Default: Green (1-6 weeks)

                          if (_containerAge.contains("weeks")) {
                            int? weeks =
                                int.tryParse(_containerAge.split(" ")[0]);
                            if (weeks != null) {
                              if (weeks >= 7 && weeks <= 11) {
                                ageColor = Colors.orange; // 7-11 weeks → Orange
                              } else if (weeks >= 12) {
                                ageColor = Colors.red; // 12+ weeks → Red
                              }
                            }
                          }

                          return Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Opacity(
                                opacity: 0.0, // Makes the button invisible
                                child: IconButton(
                                  icon: const Icon(Icons.arrow_circle_left),
                                  onPressed: () {
                                    setState(() {});
                                  },
                                ),
                              ),
                              Column(
                                children: [
                                  if (_containerAge
                                      .isNotEmpty) // Place age ABOVE the month name
                                    Container(
                                      margin: const EdgeInsets.only(bottom: 4),
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 10, vertical: 4),
                                      decoration: BoxDecoration(
                                        color:
                                            ageColor, // 🔥 Apply the correct color
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        _containerAge,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  Text(
                                    formattedDate,
                                    style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold),
                                    overflow: TextOverflow
                                        .ellipsis, // Prevents overflow issues
                                  ),
                                ],
                              ),
                              Opacity(
                                opacity: 0.0, // Makes the button invisible
                                child: IconButton(
                                  icon: const Icon(Icons.arrow_circle_right),
                                  onPressed: () {
                                    setState(() {});
                                  },
                                ),
                              )
                            ],
                          );
                        },
                      ),
                      focusedDay: _selectedDate,
                      firstDay: DateTime(2000),
                      lastDay: DateTime(2100),
                      calendarFormat: CalendarFormat.month,
                      selectedDayPredicate: (day) =>
                          isSameDay(_selectedDate, day),
                      onDaySelected: (selectedDay, focusedDay) {
                        _onDateSelected(selectedDay);
                      },
                    ),
                    const SizedBox(height: 20),
                    const Text('Notes',
                        style: TextStyle(
                            fontSize: 24, fontWeight: FontWeight.bold)),
                    TextField(
                      controller: _notesController,
                      decoration: InputDecoration(
                          hintText: 'Enter a note',
                          suffixIcon: IconButton(
                              icon: const Icon(Icons.add),
                              onPressed: _addNote)),
                    ),
                    const SizedBox(height: 10),
                    FutureBuilder(
                      future: _notesFuture,
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const Center(
                              child: CircularProgressIndicator());
                        } else if (snapshot.hasError || snapshot.data == null) {
                          return const Text('No notes found.');
                        } else {
                          final notes =
                              snapshot.data as List<Map<String, dynamic>>;
                          return Column(
                            children: notes
                                .map((note) => buildNoteCard(note))
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

Future<List<Map<String, dynamic>>> fetchNotes(
    int containerId, DateTime date) async {
  final supabase = Supabase.instance.client;

  // Format date to 'YYYY-MM-DD'
  String formattedDate = DateFormat('yyyy-MM-dd').format(date);

  try {
    final List<Map<String, dynamic>> response = await supabase
        .from('Notes_test_test')
        .select()
        .eq('container_id', containerId)
        .gte('created_date',
            '$formattedDate 00:00:00') // Start of the selected date
        .lt('created_date',
            '$formattedDate 23:59:59'); // End of the selected date

    print("Fetched notes for $formattedDate: $response"); // Debugging log

    return response;
  } catch (error) {
    print("Error fetching notes: $error");
    return [];
  }
}

//ending of notes section

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

//Container Page : Displays a list of available containers

class ContainerPage extends StatefulWidget {
  const ContainerPage({super.key});

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

  Future<void> _fetchContainers() async { // ✅ Updated for Pull-to-Refresh
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
          return const Center(child: CircularProgressIndicator());
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
                    minimumSize: const Size(double.infinity, 50),
                  ),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) =>
                              ScannerPage()), // Navigate to ScannerPage
                    );
                  },
                  icon: const Icon(Icons.add, color: Colors.white),
                  label: const Text('New container',
                      style: TextStyle(color: Colors.white)),
                ),
                const SizedBox(height: 16),

                // ✅ Added Pull-to-Refresh
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: _fetchContainers,
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
                            subtitle: Text(
                              'Date Added: ${_formatDate(container['date_added'])}',
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (isSelected)
                                  const Icon(Icons.check_circle,
                                      color: Colors.green),
                                IconButton(
                                  icon: const Icon(Icons.info,
                                      color: Colors.blueAccent),
                                  onPressed: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) =>
                                            ContainerDetails(),
                                      ),
                                    );
                                  },
                                ),
                                IconButton(
                                  icon:
                                      const Icon(Icons.edit, color: Colors.blue),
                                  onPressed: () {
                                    _showRenameContainerDialog(
                                        context, container['container_id']);
                                  },
                                ),
                                IconButton(
                                  icon:
                                      const Icon(Icons.delete, color: Colors.red),
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
                ),
              ],
            ),
          );
        }
      },
    );
  }

  String _formatDate(String dateString) {
    try {
      DateTime dateTime = DateTime.parse(dateString);
      return DateFormat('yyyy-MM-dd hh:mm a').format(dateTime);
    } catch (e) {
      return 'Invalid date';
    }
  }

  void _showRenameContainerDialog(BuildContext context, int containerId) {
    TextEditingController renameController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Rename Container"),
        content: TextField(
          controller: renameController,
          decoration:
              const InputDecoration(hintText: "Enter new container name"),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () async {
              await renameContainer(containerId, renameController.text);
              Navigator.pop(context);
              _fetchContainers(); // 🔄 Refresh UI after renaming
            },
            child: const Text("Rename"),
          ),
        ],
      ),
    );
  }

  void _showDeleteConfirmationDialog(BuildContext context, int containerId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Delete Container"),
        content: const Text("Are you sure you want to delete this container?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () {
              deleteContainer(containerId);
              Navigator.pop(context);
            },
            child: const Text("Delete"),
          ),
        ],
      ),
    );
  }
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


// Others Page: Displays options like Sign In and App Guide
class OthersPage extends StatelessWidget {
  const OthersPage({super.key});

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
        // Sign In
        ListTile(
          leading: const Icon(Icons.person, color: Colors.green),
          title: const Text('Sign In'),
          onTap: () {
            Navigator.pushAndRemoveUntil(
                          context,
                          MaterialPageRoute(
                              builder: (context) => const LoginPage()),
                              (Route<dynamic> route) => false,
                          );
          },
        ),
        /*
        // ESP Connection (Hidden for guests)
        ListTile(
          leading: Icon(Icons.wifi, color: Colors.blue),
          title: Text('ESP Connection'),
          onTap: _downloadApk, // Call the download function
        ),
        */
        // App Guide
        ListTile(
          leading: const Icon(Icons.help_outline, color: Colors.orange),
          title: const Text('App Guide'),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const AppGuidePage()),
            );
          },
        ),
        /*
        // Log Out (Hidden for guests)
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
        */
      ],
    );
  }
}
