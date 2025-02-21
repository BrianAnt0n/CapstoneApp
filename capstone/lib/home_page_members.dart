//import 'Others tab/account_management_page.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io';
import 'Others tab/account_settings_page.dart';
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
import 'package:fl_chart/fl_chart.dart';
import 'notification_page.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';

// State Management: Tracks the selected container
class ContainerState extends ChangeNotifier {
  int? selectedContainerId;

  ContainerState() {
    _loadSelectedContainer();
  }

  void selectContainer(int? containerId) async {
    selectedContainerId = containerId;
    notifyListeners();
    if (containerId != null && containerId != 0) {
      _saveSelectedContainer(containerId);
    } else {
      _removeSelectedContainer();
    }
  }

  void _saveSelectedContainer(int containerId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('selected_container_id', containerId);
  }

  void _removeSelectedContainer() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('selected_container_id');
  }

  void _loadSelectedContainer() async {
    final prefs = await SharedPreferences.getInstance();
    selectedContainerId = prefs.getInt('selected_container_id');
    notifyListeners();
  }
}

Future<String?> getStoredString(String key) async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getString(key);
}

class HomePageMember extends StatefulWidget {
  const HomePageMember({super.key});

  @override
  _HomePageMemberState createState() => _HomePageMemberState();
}

class _HomePageMemberState extends State<HomePageMember> {
  int _currentIndex = 1; // Tracks the selected tab index

  @override
  void initState() {
    super.initState();
    _checkSelectedContainer();
  }

  Future<void> _checkSelectedContainer() async {
    final prefs = await SharedPreferences.getInstance();
    final selectedContainerId = prefs.getInt('selected_container_id');
    if (selectedContainerId != null) {
      setState(() {
        _currentIndex = 0; // Redirect to Dashboard page
      });
    }
  }

  // Pages for bottom navigation
  final List<Widget> _pages = [
    const DashboardPage(),
    const ContainerPage(),
    const OthersPage(),
  ];

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
    return ChangeNotifierProvider(
      create: (_) => ContainerState(),
      child: Scaffold(
        appBar: AppBar(
          title: const Text('E-ComposThink Home - Member'), // AppBar title
          actions: [
            IconButton(
              icon: const Icon(Icons.notifications), // Notification bell icon
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) =>
                          NotificationPage()), // Navigate to NotificationPage
                );
              },
            ),
          ],
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

DateTime? _containerAddedDate; // Holds the compost start date

class _DashboardPageState extends State<DashboardPage> {
  Future<Map<String, dynamic>>? _sensorDataFuture;
  Future<List<Map<String, dynamic>>>? _notesFuture;
  Future<List<Map<String, dynamic>>>? _historyFuture;
  int? selectedContainerId;
  final TextEditingController _notesController = TextEditingController();
  DateTime _selectedDate = DateTime.now();
  String _containerAge = "";
  Color _ageColor = Colors.green;
  DateTime? _lastRefreshTime;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final containerState = Provider.of<ContainerState>(context);
    selectedContainerId = containerState.selectedContainerId;

    if (selectedContainerId != null) {
      // ✅ Fetch the correct hardware_id first
      fetchHardwareId(selectedContainerId!).then((hardwareId) {
        if (hardwareId != null) {
          if (mounted) {
            // ✅ Prevent setState() if the widget was disposed
            setState(() {
              _sensorDataFuture = fetchSensorData(selectedContainerId!);
              _notesFuture =
                  fetchNotes(hardwareId, _selectedDate); // ✅ Use hardwareId
              _historyFuture = fetchHistoryData(selectedContainerId!);
              fetchContainerDetails(selectedContainerId!);
            });
          }
        } else {
          print(
              "⚠️ Warning: No valid hardware_id found for container $selectedContainerId!");
        }
      }).catchError((error) {
        print("❌ Error fetching hardware_id: $error");
      });
    }
  }

  Future<void> _refreshData() async {
    setState(() {
      _lastRefreshTime = DateTime.now();
    });

    // ✅ Get the correct hardware_id before refreshing notes
    final hardwareId = await fetchHardwareId(selectedContainerId!);
    if (hardwareId != null) {
      setState(() {
        _sensorDataFuture = fetchSensorData(selectedContainerId!);
        _notesFuture =
            fetchNotes(hardwareId, _selectedDate); // ✅ Use hardwareId
        _historyFuture = fetchHistoryData(selectedContainerId!);
      });
    }

    FocusScope.of(context).unfocus();
  }

// ✅ New function to fetch hardwareId from containerId
  Future<int?> fetchHardwareId(int containerId) async {
    final supabase = Supabase.instance.client;
    final containerResponse = await supabase
        .from('Containers_test')
        .select('hardware_id')
        .eq('container_id', containerId)
        .maybeSingle();

    return containerResponse?['hardware_id']; // ✅ Returns correct hardware_id
  }

  Future<void> _deleteNoteImage(int noteId, String imageUrl) async {
    bool confirmDelete =
        await _showDeleteImageDialog(); // Show confirmation dialog

    if (!confirmDelete) return; // If user cancels, do nothing

    try {
      // Extract file name from URL
      Uri uri = Uri.parse(imageUrl);
      String fileName = uri.pathSegments.last;

      // Delete from Supabase Storage
      await supabase.storage.from('Notes_Image_Test').remove([fileName]);
      print("Image deleted from Supabase: $fileName");

      String? editorName = await getStoredString("fullname");

      // Remove image URL from the database (set `picture` column to NULL)
      await supabase.from('Notes_test_test').update({
        'picture': null,
        'date_modified': getLocalTimestamp(),
        'last_modified_by': editorName,
      }).eq('note_id', noteId);

      print("Image removed from note in database");

      // Refresh the notes list
      setState(() {
        _notesFuture = fetchNotes(selectedContainerId!, _selectedDate);
      });
    } catch (e) {
      print("Error deleting image: $e");
    }
  }

  Future<void> _replaceNoteImage(int noteId, String oldImageUrl) async {
    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return SafeArea(
          child: Wrap(
            children: [
              ListTile(
                leading: const Icon(Icons.camera_alt, color: Colors.blue),
                title: const Text("Take a Photo"),
                onTap: () async {
                  Navigator.pop(context);
                  await _pickAndReplaceImage(
                      noteId, oldImageUrl, ImageSource.camera);
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library, color: Colors.green),
                title: const Text("Choose from Gallery"),
                onTap: () async {
                  Navigator.pop(context);
                  await _pickAndReplaceImage(
                      noteId, oldImageUrl, ImageSource.gallery);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _pickAndReplaceImage(
      int noteId, String oldImageUrl, ImageSource source) async {
    final XFile? newImage = await _picker.pickImage(source: source);

    if (newImage == null) return; // User canceled

    try {
      Uri oldUri = Uri.parse(oldImageUrl);
      String oldFileName = oldUri.pathSegments.last;

      await supabase.storage.from('Notes_Image_Test').remove([oldFileName]);
      print("Old image deleted from Supabase: $oldFileName");

      File file = File(newImage.path);
      String newFileName = '${DateTime.now().millisecondsSinceEpoch}.jpg';

      await supabase.storage.from('Notes_Image_Test').upload(
            newFileName,
            file,
            fileOptions: const FileOptions(upsert: true),
          );

      final String newImageUrl =
          supabase.storage.from('Notes_Image_Test').getPublicUrl(newFileName);
      print("New image uploaded: $newImageUrl");

      String? editorName = await getStoredString("fullname");

      await supabase.from('Notes_test_test').update({
        'picture': newImageUrl,
        'date_modified': getLocalTimestamp(),
        'last_modified_by': editorName,
      }).eq('note_id', noteId);
      print("Database updated with new image URL");

      setState(() {
        _notesFuture = fetchNotes(selectedContainerId!, _selectedDate);
      });
    } catch (e) {
      print("Error replacing image: $e");
    }
  }

  Future<bool> _showDeleteImageDialog() async {
    return await showDialog(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              title: const Text("Delete Image"),
              content: const Text(
                  "Are you sure you want to delete this image? This action cannot be undone."),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false), // Cancel
                  child: const Text("Cancel"),
                ),
                TextButton(
                  onPressed: () =>
                      Navigator.of(context).pop(true), // Confirm delete
                  child:
                      const Text("Delete", style: TextStyle(color: Colors.red)),
                ),
              ],
            );
          },
        ) ??
        false; // Default to false if dialog is dismissed
  }

  String _getLastRefreshedText() {
    if (_lastRefreshTime == null) return "Not refreshed yet";
    final difference = DateTime.now().difference(_lastRefreshTime!);
    if (difference.inMinutes < 1) {
      // Changed to minutes and checking if less than 1
      return "Last Refreshed: Less than a minute ago"; // More user-friendly
    } else if (difference.inMinutes < 60) {
      return "Last Refreshed: ${difference.inMinutes} minutes ago";
    } else {
      return "Last Refreshed: ${difference.inHours} hours ago";
    }
  }

  String _getTimeRefreshed() {
    return _lastRefreshTime != null
        ? "Time Refreshed: ${DateFormat('hh:mm:ss a').format(_lastRefreshTime!)}"
        : "Time Refreshed: Refresh Pending";
  }

  // Future<List<Map<String, dynamic>>> fetchHistoryData(int containerId) async {
  //   final supabase = Supabase.instance.client;

  //   final containerResponse = await supabase
  //     .from('Containers_test')
  //     .select('hardware_id')
  //     .eq('container_id', containerId)
  //     .single();
  // final hardwareId = containerResponse['hardware_id'];
  //   try {
  //     return await supabase
  //         .from('History_Test')
  //         .select('*')
  //         .eq('hardware_id', hardwareId)
  //         .order('timestamp', ascending: true);
  //   } catch (error) {
  //     return [];
  //   }
  // }

  Future<int?> fetchHardwareIdFromContainer(int containerId) async {
    final supabase = Supabase.instance.client;
    try {
      final response = await supabase
          .from('Containers_test')
          .select('hardware_id')
          .eq('container_id', containerId)
          .single(); // Ensures only one row is returned

      if (response != null && response['hardware_id'] != null) {
        return response['hardware_id'] as int;
      } else {
        print("No hardware_id found for container_id: $containerId");
        return null;
      }
    } catch (error) {
      print("Error fetching hardware_id: $error");
      return null;
    }
  }

  Future<List<Map<String, dynamic>>> fetchHistoryData(int containerId) async {
    final supabase = Supabase.instance.client;
    try {
      // Step 1: Fetch the correct hardware_id using container_id
      final hardwareId = await fetchHardwareIdFromContainer(containerId);

      if (hardwareId == null) {
        print("Cannot fetch historical data because hardware_id is null.");
        return [];
      }

      // Step 2: Fetch historical data using the correct hardware_id
      final response = await supabase
          .from('History_Test')
          .select(
              'historical_id, ph_level1, ph_level2, humidity, temperature, moisture, timestamp, container_id, hardware_id')
          .eq('hardware_id', hardwareId)
          .order('timestamp', ascending: true);

      if (response.isEmpty) {
        print("No historical data found for hardware_id: $hardwareId");
      } else {
        print("Fetched Historical Data: $response");
      }

      return response;
    } catch (error) {
      print("Error fetching historical data: $error");
      return [];
    }
  }

  Future<Map<String, dynamic>> fetchSensorData(int containerId) async {
    final supabase = Supabase.instance.client;

    // Fetch hardware_id from Containers_test
    final containerResponse = await supabase
        .from('Containers_test')
        .select('hardware_id')
        .eq('container_id', containerId)
        .single();
    final hardwareId = containerResponse['hardware_id'];

    // Fetch latest sensor data and start_date
    final sensorResponse = await supabase
        .from('Hardware_Sensors_Test')
        .select(
            'temperature, moisture, ph_level, ph_level2, humidity, refreshed_date, start_date')
        .eq('hardware_id', hardwareId)
        .order('refreshed_date', ascending: false)
        .limit(1)
        .single();

    return sensorResponse;
  }

  Widget buildSensorCard(
      IconData icon, String title, String value, Color color) {
    return Card(
      child: ListTile(
        leading: Icon(icon, color: color),
        title: Text(title),
        subtitle: Text(value,
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
      ),
    );
  }

  bool _isLoading = false; // ✅ Track loading state

  Future<void> _addNote() async {
    if (selectedContainerId == null) return;

    String trimmedNote = _notesController.text.trim();
    if (trimmedNote.isEmpty) {
      _showErrorDialog("Please provide notes.");
      return;
    }

    setState(() {
      _isLoading = true; // ✅ Show loading state
    });

    try {
      // ✅ Get the correct hardware_id before inserting the note
      int? hardwareId = await fetchHardwareId(selectedContainerId!);
      if (hardwareId == null) {
        print(
            "Error: No hardware ID found for container $selectedContainerId!");
        return;
      }

      // ✅ Add note with the correct hardware_id
      await addNoteToDatabase(selectedContainerId!, trimmedNote, _imageUrl);
      _notesController.clear();

      // ✅ Small delay to ensure Supabase updates before fetching notes
      await Future.delayed(const Duration(milliseconds: 500));

      setState(() {
        _notesFuture =
            fetchNotes(hardwareId, _selectedDate); // ✅ Use hardwareId
        _selectedImage = null;
        _imageUrl = null;
      });

      print("✅ Note added and refreshed successfully!");
    } catch (e) {
      print("Error adding note: $e");
    } finally {
      setState(() {
        _isLoading = false; // ✅ Hide loading state
      });
    }
  }

// Function to Show Error Popup
  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text("Error"),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("OK"),
            ),
          ],
        );
      },
    );
  }

  Future<void> _onDateSelected(DateTime selectedDate) async {
    setState(() {
      _selectedDate = selectedDate;
    });

    _notesFuture = fetchNotes(selectedContainerId!, _selectedDate);
    setState(() {});
  }

  String formatTimestamp(String timestamp) {
    try {
      DateTime parsedDate = DateTime.parse(timestamp);
      return DateFormat('yyyy-MM-dd hh:mm a').format(parsedDate);
    } catch (e) {
      return 'Invalid Date';
    }
  }

  Future<List<Map<String, dynamic>>> fetchNotes(
      int hardwareId, DateTime date) async {
    final supabase = Supabase.instance.client;

    DateTime startOfDayUtc = DateTime(date.year, date.month, date.day).toUtc();
    DateTime endOfDayUtc =
        startOfDayUtc.add(const Duration(hours: 23, minutes: 59, seconds: 59));

    try {
      print(
          "Fetching notes for hardware_id: $hardwareId between $startOfDayUtc and $endOfDayUtc");

      final response = await supabase
          .from('Notes_test_test')
          .select(
              'note_id, note, created_date, picture, created_by, date_modified, last_modified_by') // ✅ Correct relationship fetching
          .eq('hardware_id', hardwareId)
          .gte('created_date', startOfDayUtc.toIso8601String())
          .lt('created_date', endOfDayUtc.toIso8601String());

      if (response == null || response.isEmpty) {
        print("No notes found for this date.");
        return [];
      }

      print("Fetched ${response.length} notes.");
      return List<Map<String, dynamic>>.from(response);
    } catch (error) {
      print("Error fetching notes: $error");
      return [];
    }
  }

  Widget buildNoteCard(Map<String, dynamic> note) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(10.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (note['picture'] != null && note['picture'].isNotEmpty)
              Image.network(note['picture'],
                  width: double.infinity, height: 150, fit: BoxFit.cover),

            const SizedBox(height: 5),

            Text(
              note['note'] ?? 'No note available',
              style: const TextStyle(fontSize: 16),
            ),

            Text(
              formatTimestamp(note['created_date']),
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),

            if (note['date_modified'] != null) // Show only if not null
              Text(
                "Date modified: ${formatTimestamp(note['date_modified'])}",
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),

            const SizedBox(height: 5),

            // ✅ Fetch `created_by` and display Fullname properly
            Text(
              "Added by: ${note['created_by'] ?? 'Unknown User'}",
              style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue),
            ),

            if (note['last_modified_by'] != null) // Show only if not null
              Text(
                "Last modified by: ${note['last_modified_by']}",
                style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue),
              ),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                IconButton(
                  icon: const Icon(Icons.edit, color: Colors.blue),
                  onPressed: () =>
                      _showEditDialog(note['note_id'], note['note']),
                ),
                IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red),
                  onPressed: () =>
                      _showDeleteConfirmationDialog(note['note_id']),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget buildBarChart(
      List<Map<String, dynamic>> data, String title, String key, Color color) {
    try {
      // print("Building chart for $title with ${data.length} data points.");

      double fixedMaxY;
      if (key.contains('temperature')) {
        fixedMaxY = 100;
      } else if (key.contains('moisture') || key.contains('humidity')) {
        fixedMaxY = 100;
      } else if (key.contains('ph')) {
        fixedMaxY = 14;
      } else {
        fixedMaxY = 100;
      }

      double chartHeight = fixedMaxY > 50
          ? 320
          : 270; // Increased height to prevent tooltip cutoff

      return Container(
        height: chartHeight + 50, // Ensures extra space for tooltips
        width: data.length * 50.0,
        padding: const EdgeInsets.only(
            right: 30.0, top: 40.0), // More padding at the top
        child: BarChart(
          BarChartData(
            maxY: fixedMaxY,
            alignment: BarChartAlignment.spaceAround,
            titlesData: FlTitlesData(
              leftTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 40,
                  getTitlesWidget: (value, meta) {
                    return Padding(
                      padding: const EdgeInsets.only(right: 5.0),
                      child: Text(
                        value.toInt().toString(),
                        style:
                            const TextStyle(fontSize: 12, color: Colors.black),
                      ),
                    );
                  },
                ),
              ),
              rightTitles: AxisTitles(
                sideTitles: SideTitles(showTitles: false),
              ),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 20,
                  getTitlesWidget: (value, meta) {
                    int index = value.toInt();
                    if (index >= 0 && index < data.length) {
                      DateTime date = DateTime.parse(data[index]['timestamp']);
                      return Padding(
                        padding: const EdgeInsets.only(top: 8.0),
                        child: Text(
                          "${date.month}/${date.day}",
                          style: const TextStyle(fontSize: 10),
                        ),
                      );
                    }
                    print("Bottom label index out of range: $index");
                    return const SizedBox.shrink();
                  },
                ),
              ),
              topTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 20,
                  getTitlesWidget: (value, meta) {
                    int index = value.toInt();
                    int reversedIndex = data.length - index;
                    if (reversedIndex <= 0 || reversedIndex > data.length) {
                      print("Top label index out of range: $reversedIndex");
                      return const SizedBox.shrink();
                    }
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8.0),
                      child: Text(
                        "$reversedIndex",
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
            borderData: FlBorderData(show: false),
            gridData: FlGridData(
              show: true,
              drawVerticalLine: false,
              checkToShowHorizontalLine: (value) => value % 10 == 0,
            ),
            barGroups: data.asMap().entries.map((entry) {
              int index = entry.key;
              double value = (entry.value[key] as num?)?.toDouble() ?? 0;

              if (index >= data.length) {
                print("Bar chart index out of range: $index");
                return null!;
              }

              return BarChartGroupData(
                x: index,
                barsSpace: 12,
                barRods: [
                  BarChartRodData(
                    toY: value,
                    color: color,
                    width: 24,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ],
              );
            }).toList(),
          ),
        ),
      );
    } catch (e, stacktrace) {
      print("Error in buildBarChart: $e");
      print(stacktrace);
      return const Center(
        child: Text("Error loading chart"),
      );
    }
  }

  Future<void> fetchContainerDetails(int containerId) async {
    final supabase = Supabase.instance.client;

    try {
      final response = await supabase
          .from('Containers_test')
          .select('date_added')
          .eq('container_id', containerId)
          .single();

      if (response['date_added'] != null) {
        setState(() {
          _containerAddedDate = DateTime.parse(response['date_added']);
          _calculateContainerAge(); // ✅ Call to update compost age
        });
      }
    } catch (error) {
      print("Error fetching container details: $error");
    }
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

  void _openFullCalendar() {
    //Ensure keyboard is fully dismissed before opening the calendar
    FocusScope.of(context).requestFocus(FocusNode());

    //Use Future.delayed to wait for the keyboard to close completely
    Future.delayed(const Duration(milliseconds: 200), () {
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return Builder(
            builder: (context) {
              return Dialog(
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Full Calendar inside the popup
                      TableCalendar(
                        focusedDay: _selectedDate,
                        firstDay: DateTime(2000),
                        lastDay: DateTime(2100),
                        calendarFormat: CalendarFormat.month, // Show full month
                        selectedDayPredicate: (day) =>
                            isSameDay(_selectedDate, day),
                        onDaySelected: (selectedDay, focusedDay) {
                          setState(() {
                            _selectedDate = selectedDay;
                            _notesFuture =
                                fetchNotes(selectedContainerId!, _selectedDate);
                            _calculateContainerAge(); // Update the age when a date is selected
                          });
                          Navigator.pop(
                              context); // Close the popup after selection
                        },
                        headerStyle: const HeaderStyle(
                          formatButtonVisible:
                              false, // Hide the week toggle button
                          titleCentered: true,
                        ),
                      ),
                      const SizedBox(height: 10),
                      ElevatedButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text("Close"),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      );
    });
  }

  int _calculateContainerAge() {
    if (_containerAddedDate == null) {
      _containerAge = "Unknown";
      _ageColor = Colors.black;
      return 0; // Default to 0 when no date is available
    }

    final difference = _selectedDate.difference(_containerAddedDate!);
    int weeks = (difference.inDays / 7).floor(); // Always display in weeks

    if (weeks > 16) {
      _containerAge = "Over-composted";
      _ageColor = Colors.grey;
    } else {
      _containerAge = "$weeks ${weeks == 1 ? 'WEEK' : 'WEEKS'}";

      if (weeks >= 12) {
        _ageColor = Colors.green;
      } else if (weeks >= 7) {
        _ageColor = Colors.orange;
      } else {
        _ageColor = Colors.red;
      }
    }

    if (mounted) {
      setState(() {}); // Update UI
    }

    return weeks; // ✅ Returns weeks for other functions
  }

//notes image section
  final SupabaseClient supabase = Supabase.instance.client;

  final ImagePicker _picker = ImagePicker(); // ✅ Create instance
  File? _selectedImage; // Store selected image
  String? _imageUrl; // Store uploaded image URL

// Show Bottom Sheet for Image Selection
  Future<void> _uploadPicture() async {
    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return SafeArea(
          child: Wrap(
            children: [
              ListTile(
                leading: const Icon(Icons.camera_alt, color: Colors.blue),
                title: const Text("Take a Photo"),
                onTap: () async {
                  Navigator.pop(context); // Close modal
                  await _pickImage(ImageSource.camera);
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library, color: Colors.green),
                title: const Text("Choose from Gallery"),
                onTap: () async {
                  Navigator.pop(context); // Close modal
                  await _pickImage(ImageSource.gallery);
                },
              ),
            ],
          ),
        );
      },
    );
  }

// Pick Image and Upload to Supabase Storage
  Future<void> _pickImage(ImageSource source) async {
    final XFile? image = await _picker.pickImage(source: source);
    if (image != null) {
      try {
        File file = File(image.path);
        String fileName = '${DateTime.now().millisecondsSinceEpoch}.jpg';

        // Upload image to Supabase Storage
        await supabase.storage.from('Notes_Image_Test').upload(
              fileName,
              file,
              fileOptions:
                  const FileOptions(upsert: true), // Allows overwriting
            );

        // Get Public URL of the uploaded image
        final String imageUrl =
            supabase.storage.from('Notes_Image_Test').getPublicUrl(fileName);

        setState(() {
          _selectedImage = file;
          _imageUrl = imageUrl; // Store the image URL
        });

        print("Image uploaded successfully! URL: $_imageUrl");
      } catch (e) {
        print("Error uploading image: $e");
      }
    }
  }

  void _removeImage() async {
    if (_imageUrl != null) {
      try {
        // Extract file name from the URL
        Uri uri = Uri.parse(_imageUrl!);
        String fileName = uri.pathSegments.last;

        // Delete the file from Supabase Storage
        await supabase.storage.from('Notes_Image_Test').remove([fileName]);

        print("Image deleted from Supabase: $fileName");
      } catch (e) {
        print("Error deleting image: $e");
      }
    }

    // Clear the selected image from UI
    setState(() {
      _selectedImage = null;
      _imageUrl = null;
    });
  }

// Show Image in Fullscreen
  void _showFullScreenImage(String imagePath) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.black, // Full black background
          insetPadding: EdgeInsets.zero, // Remove extra padding
          child: Stack(
            children: [
              Center(
                child: imagePath
                        .startsWith("http") // Check if it's a network image
                    ? Image.network(imagePath, fit: BoxFit.contain)
                    : Image.file(File(imagePath),
                        fit: BoxFit.contain), // Local file
              ),
              Positioned(
                top: 20,
                right: 20,
                child: IconButton(
                  icon: const Icon(Icons.close, color: Colors.white, size: 30),
                  onPressed: () => Navigator.pop(context), // Close fullscreen
                ),
              ),
            ],
          ),
        );
      },
    );
  }

// Helper function for legend items
  Widget _buildLegendItem(Color color, String label) {
    return Row(
      children: [
        Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 8),
        Text(label, style: const TextStyle(fontSize: 14)),
        const SizedBox(width: 16),
      ],
    );
  }

  int? selectedHardwareId; // ✅ Global variable to store hardware_id

  Future<void> _fetchAndSetHardwareId(int containerId) async {
    final supabase = Supabase.instance.client;

    try {
      print("Fetching hardware_id for container_id: $containerId");

      // ✅ Fetch hardware_id using container_id
      final containerResponse = await supabase
          .from('Containers_test')
          .select('hardware_id')
          .eq('container_id', containerId)
          .maybeSingle();

      if (containerResponse == null ||
          containerResponse['hardware_id'] == null) {
        print("⚠️ No hardware_id found for container_id: $containerId");
        return;
      }

      int hardwareId =
          containerResponse['hardware_id']; // ✅ Extract hardware_id

      // ✅ Fetch start_date from Hardware_Sensors_Test using the retrieved hardware_id
      final hardwareResponse = await supabase
          .from('Hardware_Sensors_Test')
          .select('start_date')
          .eq('hardware_id', hardwareId)
          .maybeSingle();

      setState(() {
        selectedHardwareId = hardwareId; // ✅ Store hardware_id globally
        _containerAddedDate =
            hardwareResponse?['start_date']; // ✅ Store start_date
      });

      print("✅ Hardware ID set: $selectedHardwareId");
      print("✅ Start date retrieved: $_containerAddedDate");
    } catch (error) {
      print("❌ Error fetching hardware_id: $error");
    }
  }

  Future<void> _retrieveCompost() async {
    final supabase = Supabase.instance.client;

    if (selectedContainerId == null) {
      print("❌ Error: selectedContainerId is null. Cannot fetch hardware_id.");
      return;
    }

    // Show confirmation dialog before proceeding
    bool confirm = await showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text("Confirm Compost Retrieval"),
          content: const Text(
              "Are you sure you want to retrieve the compost? This will reset the compost start date."),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false), // Cancel
              child: const Text("Cancel"),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true), // Confirm
              child: const Text("Retrieve"),
            ),
          ],
        );
      },
    );

    if (!confirm) return; // User canceled

    try {
      // Get hardware_id from Containers_test
      final containerResponse = await supabase
          .from('Containers_test')
          .select('hardware_id')
          .eq('container_id', selectedContainerId!)
          .maybeSingle();

      if (containerResponse == null ||
          containerResponse['hardware_id'] == null) {
        print(
            "❌ Error: No hardware_id found for container_id $selectedContainerId.");
        return;
      }

      final hardwareId = containerResponse['hardware_id'];
      print("✅ Resolved hardware_id: $hardwareId");

      // Update Hardware_Sensors_Test to set start_date as NULL
      final updateResponse = await supabase
          .from('Hardware_Sensors_Test')
          .update({'start_date': null}) // ✅ Set start_date to NULL
          .eq('hardware_id', hardwareId);

      print("✅ Compost start date reset in database.");

      setState(() {
        _containerAddedDate = null; // Reset UI state
        _containerAge = "Empty"; // Update display
        _ageColor = Colors.black;
      });
    } catch (error) {
      print("❌ Error resetting compost start date: $error");
    }
  }

  void _startCompost() async {
    DateTime tempDate = DateTime.now();
    TimeOfDay tempTime = TimeOfDay.now();
    DateTime? selectedDate;

    await showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Center(
                    child: Text(
                      "Start Composting",
                      style:
                          TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(height: 20),
                  ListTile(
                    leading:
                        const Icon(Icons.calendar_today, color: Colors.blue),
                    title: const Text("Select Date",
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w500)),
                    subtitle: Text(DateFormat.yMMMMd().format(tempDate)),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 18),
                    onTap: () async {
                      DateTime? pickedDate = await showDatePicker(
                        context: context,
                        initialDate: tempDate,
                        firstDate: DateTime(2000),
                        lastDate: DateTime(2100),
                      );
                      if (pickedDate != null) {
                        setState(() => tempDate = pickedDate);
                      }
                    },
                  ),
                  ListTile(
                    leading:
                        const Icon(Icons.access_time, color: Colors.orange),
                    title: const Text("Select Time",
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w500)),
                    subtitle: Text(tempTime.format(context)),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 18),
                    onTap: () async {
                      TimeOfDay? pickedTime = await showTimePicker(
                        context: context,
                        initialTime: tempTime,
                      );
                      if (pickedTime != null) {
                        setState(() => tempTime = pickedTime);
                      }
                    },
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text("Cancel",
                            style: TextStyle(fontSize: 16)),
                      ),
                      ElevatedButton(
                        onPressed: () {
                          selectedDate = DateTime(
                            tempDate.year,
                            tempDate.month,
                            tempDate.day,
                            tempTime.hour,
                            tempTime.minute,
                          );
                          Navigator.pop(context);
                        },
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 24, vertical: 12),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8)),
                          backgroundColor: Colors.green,
                        ),
                        child: const Text("Confirm",
                            style:
                                TextStyle(fontSize: 16, color: Colors.white)),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );

    // ✅ Ensure user selected a date
    if (selectedDate == null) {
      print("⚠️ No date selected. Compost start cancelled.");
      return;
    }

    try {
      // ✅ Ensure selectedHardwareId is set
      if (selectedHardwareId == null) {
        print("🔍 Fetching hardware ID...");
        await _fetchAndSetHardwareId(selectedContainerId!);
      }

      if (selectedHardwareId == null) {
        print("❌ Error: No hardware_id found for container.");
        return;
      }

      String formattedDate = selectedDate!.toIso8601String();

      // ✅ Update `start_date` in `Hardware_Sensors_Test`
      final updateResponse = await Supabase.instance.client
          .from('Hardware_Sensors_Test')
          .update({'start_date': formattedDate})
          .eq('hardware_id', selectedHardwareId!)
          .select()
          .single();

      if (updateResponse == null) {
        print("❌ Error: Update failed, no rows affected.");
        return;
      }

      setState(() {
        _containerAddedDate = selectedDate;
        _calculateContainerAge();
      });

      print("✅ Compost start date updated successfully!");
    } catch (error) {
      print("🚨 Error starting compost: $error");
    }
  }

  Widget _buildCompostButtons() {
    int weeks =
        _calculateContainerAge(); // This should calculate based on the actual date.

    return Column(
      children: [
        // "Retrieve Compost" button for compost between 12 and 16 weeks
        if (weeks >= 12 && weeks <= 16)
          ElevatedButton(
            onPressed: _retrieveCompost,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text(
              "Retrieve Compost",
              style: TextStyle(fontSize: 18, color: Colors.white),
            ),
          ),
        // "Start Compost" button should be shown when the state is "Empty"
        if (_containerAge == "Empty" || _containerAddedDate == null)
          ElevatedButton(
            onPressed: _startCompost,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text(
              "Start Compost",
              style: TextStyle(fontSize: 18, color: Colors.white),
            ),
          ),
      ],
    );
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
                    const SizedBox(height: 5),

                    // Text(
                    //   _getTimeRefreshed(),
                    //   style: const TextStyle(fontSize: 14, color: Colors.grey),
                    // ),
                    const SizedBox(height: 20),
                    FutureBuilder<Map<String, dynamic>>(
                      future: _sensorDataFuture,
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const Center(
                              child: CircularProgressIndicator());
                        } else if (snapshot.hasError) {
                          return const Center(
                              child: Text('Error fetching data'));
                        } else if (!snapshot.hasData || snapshot.data == null) {
                          return const Center(child: Text('No data available'));
                        }

                        final sensorData = snapshot.data!;
                        String compostStartDate = "Not Set";
                        DateTime? fetchedStartDate;

                        if (sensorData['start_date'] != null) {
                          fetchedStartDate =
                              DateTime.parse(sensorData['start_date']);
                          compostStartDate =
                              DateFormat('yyyy-MM-dd').format(fetchedStartDate);
                        }

                        // Avoid redundant setState calls during the build phase
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          if (_containerAddedDate != fetchedStartDate) {
                            setState(() {
                              _containerAddedDate = fetchedStartDate;
                              _calculateContainerAge();
                            });
                          }
                        });

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text("Compost Start Date: $compostStartDate",
                                style: const TextStyle(
                                    fontSize: 16, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 5),
                            Text(_getTimeRefreshed(),
                                style: const TextStyle(
                                    fontSize: 14, color: Colors.grey)),
                            const SizedBox(height: 10),
                            buildSensorCard(
                                Icons.thermostat,
                                'Temperature Monitoring',
                                '${sensorData['temperature']}°C',
                                Colors.green),
                            buildSensorCard(Icons.water_drop, 'Moisture Level',
                                '${sensorData['moisture']}%', Colors.blue),
                            buildSensorCard(Icons.science, 'pH Level 1',
                                '${sensorData['ph_level']}', Colors.purple),
                            buildSensorCard(
                                Icons.science_outlined,
                                'pH Level 2',
                                '${sensorData['ph_level2']}',
                                Colors.deepPurple),
                            buildSensorCard(Icons.cloud, 'Humidity',
                                '${sensorData['humidity']}%', Colors.orange),
                          ],
                        );
                      },
                    ),

                    const SizedBox(height: 20),
                    const Divider(thickness: 2),
                    const SizedBox(height: 10),
                    Column(
                      children: [
                        // Weekly Calendar
                        TableCalendar(
                          focusedDay: _selectedDate,
                          firstDay: DateTime(2000),
                          lastDay: DateTime(2100),
                          calendarFormat: CalendarFormat.week,
                          headerStyle: HeaderStyle(
                            titleCentered: true,
                            formatButtonVisible: false,
                            leftChevronIcon: const Icon(Icons.chevron_left),
                            rightChevronIcon: const Icon(Icons.chevron_right),
                            titleTextFormatter: (date, locale) {
                              return DateFormat.yMMMM(locale).format(date);
                            },
                          ),
                          calendarBuilders: CalendarBuilders(
                            headerTitleBuilder: (context, date) {
                              return Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Opacity(
                                    opacity: 0.0,
                                    child: IconButton(
                                      icon: const Icon(Icons.arrow_left),
                                      onPressed: () {},
                                    ),
                                  ),
                                  Text(
                                    DateFormat.yMMMM().format(date),
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.calendar_month),
                                    onPressed: () {
                                      _openFullCalendar();
                                    },
                                  ),
                                ],
                              );
                            },
                          ),
                          selectedDayPredicate: (day) =>
                              isSameDay(_selectedDate, day),
                          onDaySelected: (selectedDay, focusedDay) {
                            setState(() {
                              _selectedDate = selectedDay;
                              _notesFuture = fetchNotes(
                                  selectedContainerId!, _selectedDate);
                              _calculateContainerAge();
                            });
                          },
                        ),

                        const SizedBox(height: 16),

                        // Container Age Display
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            const Text(
                              "Container Age:",
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: Colors.black,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _containerAge,
                              style: TextStyle(
                                fontSize: 26,
                                fontWeight: FontWeight.bold,
                                color: _ageColor,
                              ),
                            ),

                            const SizedBox(height: 20),

                            // Compost Action Button (Retrieve Compost / Start Compost)
                            _buildCompostButtons(), // ✅ This ensures the button is always rendered in place

                            const SizedBox(height: 30),

                            // Legend
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                _buildLegendItem(Colors.red, "Not Ready"),
                                _buildLegendItem(Colors.orange, "Decomposing"),
                                _buildLegendItem(Colors.green, "Ready"),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),

                    const SizedBox(height: 20),
                    const Divider(thickness: 2),
                    const SizedBox(height: 10),
                    const Text(
                      'Notes',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 10),

// Show Image Above Text Field (if selected)
                    if (_selectedImage != null)
                      GestureDetector(
                        onTap: () => _showFullScreenImage(
                            _selectedImage!.path), // ✅ Pass file path as String
                        child: Stack(
                          alignment: Alignment.topRight,
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Image.file(
                                _selectedImage!,
                                width: double.infinity,
                                height: 200,
                                fit: BoxFit.cover,
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.cancel, color: Colors.red),
                              onPressed: _removeImage,
                            ),
                          ],
                        ),
                      ),

                    const SizedBox(height: 10),

// Styled TextField for Notes with Inline Buttons
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.grey[200],
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          // Expanded TextField
                          Expanded(
                            child: TextField(
                              controller: _notesController,
                              maxLines: 3,
                              style: const TextStyle(fontSize: 16),
                              decoration: const InputDecoration(
                                hintText: 'Write your note here...',
                                border: InputBorder.none,
                              ),
                            ),
                          ),

                          const SizedBox(width: 8),

                          // Column for Buttons (Stacked Vertically)
                          Column(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              IconButton(
                                onPressed: _isLoading
                                    ? null
                                    : _addNote, // ✅ Disable button when loading
                                icon: _isLoading
                                    ? const CircularProgressIndicator() // ✅ Show loading animation
                                    : const Icon(Icons.add_comment_outlined),
                                color: Colors.green,
                                tooltip: "Add Note",
                              ),
                              IconButton(
                                onPressed: _uploadPicture,
                                icon: const Icon(Icons.image),
                                color: Colors.brown,
                                tooltip: "Upload Picture",
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 10),

// Display Notes List
                    FutureBuilder(
                      future: _notesFuture,
                      builder: (context, snapshot) {
                        print(
                            "Notes FutureBuilder State: ${snapshot.connectionState}");
                        print("Notes Data: ${snapshot.data}");

                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const Center(
                              child: CircularProgressIndicator());
                        } else if (snapshot.hasError || snapshot.data == null) {
                          print("Error fetching notes: ${snapshot.error}");
                          return const Text('No notes found.');
                        } else {
                          final notes =
                              snapshot.data as List<Map<String, dynamic>>;

                          print("Fetched ${notes.length} notes.");
                          return Column(
                            children: notes
                                .map((note) => buildNoteCard(note))
                                .toList(),
                          );
                        }
                      },
                    ),

                    const SizedBox(height: 20),
                    const Divider(thickness: 2),
                    const SizedBox(height: 20),
                    const Text('Historical Data Graph',
                        style: TextStyle(
                            fontSize: 24, fontWeight: FontWeight.bold)),
                    const Text(
                      'Data for the last 24 hours',
                      style: TextStyle(
                          fontSize: 14, fontWeight: FontWeight.normal),
                    ),

                    FutureBuilder(
                      future: _historyFuture,
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const Center(
                              child: CircularProgressIndicator());
                        } else if (snapshot.hasError || snapshot.data == null) {
                          return const Center(
                              child: Text('No historical data available.'));
                        } else {
                          List<Map<String, dynamic>> historyData =
                              (snapshot.data as List<Map<String, dynamic>>)
                                  .toList();

                          ScrollController scrollController =
                              ScrollController();

                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            scrollController.jumpTo(
                                scrollController.position.maxScrollExtent);
                          });

                          Widget buildChartOrMessage(
                              String title, String key, Color color) {
                            if (historyData.length <= 1) {
                              return Container(
                                height: 250, // Adjust height as needed
                                alignment: Alignment.center,
                                child: const Text(
                                  'Insufficient Data',
                                  style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.red),
                                ),
                              );
                            } else {
                              return SingleChildScrollView(
                                controller: scrollController,
                                scrollDirection: Axis.horizontal,
                                reverse: true,
                                child: buildBarChart(
                                    historyData, title, key, color),
                              );
                            }
                          }

                          return SingleChildScrollView(
                            scrollDirection: Axis.vertical,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const SizedBox(height: 20),
                                const Text(
                                  'Temperature Monitoring',
                                  style: TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold),
                                ),
                                const Text(
                                  '• Safe: Between 10°C to 54°C  |  Critical: Above 54°C',
                                  style: TextStyle(
                                      fontSize: 14, color: Colors.grey),
                                ),
                                buildChartOrMessage(
                                    'Temperature', 'temperature', Colors.green),
                                const SizedBox(height: 20),
                                Divider(
                                    thickness: 2, color: Colors.grey.shade400),
                                const SizedBox(height: 20),
                                const Text(
                                  'Moisture Level',
                                  style: TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold),
                                ),
                                const Text(
                                  '• Optimal: 50-60%  |  Dry: Below 50%  |  Too Wet: Above 60%',
                                  style: TextStyle(
                                      fontSize: 14, color: Colors.grey),
                                ),
                                buildChartOrMessage(
                                    'Moisture', 'moisture', Colors.blue),
                                const SizedBox(height: 20),
                                Divider(
                                    thickness: 2, color: Colors.grey.shade400),
                                const SizedBox(height: 20),
                                const Text(
                                  'pH Level 1',
                                  style: TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold),
                                ),
                                const Text(
                                  '• Ideal: 6.0 - 8.0 | Too Acidic: Below 6.0 | Too Basic: Above 8',
                                  style: TextStyle(
                                      fontSize: 14, color: Colors.grey),
                                ),
                                buildChartOrMessage(
                                    'pH Level 1', 'ph_level1', Colors.purple),
                                const SizedBox(height: 20),
                                Divider(
                                    thickness: 2, color: Colors.grey.shade400),
                                const SizedBox(height: 20),
                                const Text(
                                  'pH Level 2',
                                  style: TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold),
                                ),
                                const Text(
                                  '• Ideal: 6.0 - 8.0 | Too Acidic: Below 6.0 | Too Basic: Above 8',
                                  style: TextStyle(
                                      fontSize: 14, color: Colors.grey),
                                ),
                                buildChartOrMessage('pH Level 2', 'ph_level2',
                                    Colors.deepPurple),
                                const SizedBox(height: 20),
                                Divider(
                                    thickness: 2, color: Colors.grey.shade400),
                                const SizedBox(height: 20),
                                const Text(
                                  'Humidity Level',
                                  style: TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold),
                                ),
                                const Text(
                                  '• Optimal: 30-60%  |  Low: Below 30%  |  High: Above 60%',
                                  style: TextStyle(
                                      fontSize: 14, color: Colors.grey),
                                ),
                                buildChartOrMessage(
                                    'Humidity', 'humidity', Colors.orange),
                              ],
                            ),
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

  String? editorName = await getStoredString("fullname");

  try {
    await supabase.from('Notes_test_test').update({
      'note': updatedNote,
      'date_modified': getLocalTimestamp(),
      'last_modified_by': editorName,
    }).eq('note_id', noteId);
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

// ✅ Function to get current time in UTC format
String getLocalTimestamp() {
  final now = DateTime.now()
      .toUtc()
      .add(const Duration(hours: 8)); // ✅ Convert to GMT+8
  return now.toIso8601String();
}

//notes database
Future<void> addNoteToDatabase(
    int containerId, String note, String? imageUrl) async {
  final supabase = Supabase.instance.client;

  try {
    // ✅ Fetch the correct hardware_id from Containers_test
    final containerResponse = await supabase
        .from('Containers_test')
        .select('hardware_id')
        .eq('container_id', containerId)
        .maybeSingle();

    if (containerResponse == null || containerResponse['hardware_id'] == null) {
      print("Error: No valid hardware_id found for container_id $containerId.");
      return;
    }

    int hardwareId =
        containerResponse['hardware_id']; // ✅ Use correct hardware_id
    print("Resolved Hardware ID for container_id $containerId: $hardwareId");

    // ✅ Ensure hardware_id exists in Hardware_Sensors_Test before inserting
    final checkHardware = await supabase
        .from('Hardware_Sensors_Test')
        .select('hardware_id')
        .eq('hardware_id', hardwareId)
        .maybeSingle();

    if (checkHardware == null) {
      print(
          "Error: hardware_id $hardwareId does not exist in Hardware_Sensors_Test.");
      return;
    }

    String? authorName =
        await getStoredString('fullname'); // ✅ Store author name

    // ✅ Insert note with user full name
    await supabase.from('Notes_test_test').insert({
      'hardware_id': hardwareId,
      'created_by': authorName, // ✅ Store creator's name
      'note': note,
      'picture': imageUrl,
      'created_date': getLocalTimestamp(),
    });

    print("Note added successfully for hardware ID: $hardwareId");
  } catch (error) {
    print("Error adding note: $error");
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
// Fetch sensor data for a specific container & trigger alerts if needed
Future<Map<String, dynamic>> fetchSensorData(int containerId) async {
  final supabase = Supabase.instance.client;

  // 1️⃣ Get hardware_id from the container
  final containerResponse = await supabase
      .from('Containers_test')
      .select('hardware_id')
      .eq('container_id', containerId)
      .single();

  final hardwareId = containerResponse['hardware_id'];

  // 2️⃣ Fetch latest sensor data
  final sensorResponse = await supabase
      .from('Hardware_Sensors_Test')
      .select(
          'temperature, moisture, ph_level, ph_level2, humidity, refreshed_date')
      .eq('hardware_id', hardwareId)
      .order('refreshed_date', ascending: false)
      .limit(1)
      .single();

  // 3️⃣ Define acceptable sensor ranges
  const double minTemp = 10.0, maxTemp = 54.0;
  const double minMoisture = 50.0, maxMoisture = 60.0;
  const double minPH = 6.0, maxPH = 8.0;
  const double minHumidity = 40.0, maxHumidity = 60.0;

  // 4️⃣ Extract sensor values
  final double temp = sensorResponse['temperature'];
  final double moisture = sensorResponse['moisture'];
  final double ph1 = sensorResponse['ph_level'];
  final double ph2 = sensorResponse['ph_level2'];
  final double humidity = sensorResponse['humidity'];

  // 5️⃣ Check for alerts & insert into Notifications_Test table
  Future<void> logNotification(String title, String message) async {
    await supabase.from('Notifications_Test').insert({
      'container_id': containerId,
      'title': title,
      'message': message,
      'timestamp': DateTime.now().toIso8601String(),
    });
  }

  if (temp < minTemp) {
    await logNotification(
        "Temperature Alert", "Temperature is $temp°C, below normal range.");
  } else if (temp > maxTemp) {
    await logNotification(
        "Temperature Alert", "Temperature is $temp°C, above normal range.");
  }

  if (moisture < minMoisture) {
    await logNotification(
        "Moisture Alert", "Moisture level is $moisture%, below normal range.");
  } else if (moisture > maxMoisture) {
    await logNotification(
        "Moisture Alert", "Moisture level is $moisture%, above normal range.");
  }

  if (ph1 < minPH || ph1 > maxPH) {
    await logNotification(
        "pH Level 1 Alert", "pH Level 1 is $ph1, out of range.");
  }

  if (ph2 < minPH || ph2 > maxPH) {
    await logNotification(
        "pH Level 2 Alert", "pH Level 2 is $ph2, out of range.");
  }

  if (humidity < minHumidity) {
    await logNotification(
        "Humidity Alert", "Humidity is $humidity%, below normal range.");
  } else if (humidity > maxHumidity) {
    await logNotification(
        "Humidity Alert", "Humidity is $humidity%, above normal range.");
  }

  return sensorResponse;
}

// Container Page : Displays a list of available containers

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

  Future<void> _fetchContainers() async {
    // Updated for Pull-to-Refresh
    setState(() {
      _containersFuture = fetchContainers();
    });
  }

  Future<void> fetchData(int storedInt, String scannedCode) async {
    final contSupabase = Supabase.instance.client;

    final checkHardwareTableResponse = await contSupabase
        .from('Hardware_Sensors_Test')
        .select()
        .eq('qr_value', scannedCode)
        .maybeSingle();

    final checkContainerResponse = await contSupabase
        .from('Containers_test')
        .select(
            'container_id, hardware_id, user_id') // Use dot notation with !inner for join
        .eq('hardware_id', checkHardwareTableResponse?['hardware_id'])
        .eq('user_id', storedInt)
        .maybeSingle(); // Use `maybeSingle()` to avoid errors if no match is found

    if (checkContainerResponse != null) {
      print("Data fetched: $checkContainerResponse");
      showToast("This container is already added");
    } else {
      await contSupabase.from('Containers_test').insert({
        'hardware_id': checkHardwareTableResponse?['hardware_id'],
        'user_id': storedInt,
        'container_name': 'Container',
        'date_added': DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now()),
      });
      _fetchContainers();
      showToast("Container addded");
    }
  }

  void showToast(String message) {
    Fluttertoast.showToast(
      msg: message,
      toastLength: Toast.LENGTH_SHORT,
      gravity: ToastGravity.BOTTOM,
      backgroundColor: const Color(0xAA000000),
      textColor: const Color(0xFFFFFFFF),
      fontSize: 16.0,
    );
  }

  void performQuery(BuildContext context) async {
    String? storedString = await getStoredString("user_id_pref");

    int storedInt = int.parse(storedString ?? "");

    if (storedInt == null) {
      print("No int found in SharedPreferences.");
      return;
    }

    // Navigate to the scanner screen
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ScannerPage(
          onScanned: (scannedCode) {
            fetchData(storedInt, scannedCode);
          },
        ),
      ),
    );
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
                  onPressed: () async {
                    performQuery(context);
                    _fetchContainers;
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
                                            const ContainerDetails(),
                                      ),
                                    );
                                  },
                                ),
                                IconButton(
                                  icon: const Icon(Icons.edit,
                                      color: Colors.blue),
                                  onPressed: () {
                                    _showRenameContainerDialog(
                                        context, container['container_id']);
                                  },
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete,
                                      color: Colors.red),
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
              _removeSelectedContainer();
              _fetchContainers();
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

void _removeSelectedContainer() async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.remove('selected_container_id');
}

Future<List<Map<String, dynamic>>> fetchContainers() async {
  final supabase = Supabase.instance.client;
  String? storedString = await getStoredString("user_id_pref");

  int storedInt = int.parse(storedString ?? "");

  try {
    final response = await supabase
        .from('Containers_test')
        .select('*')
        .eq('user_id', storedInt);
    print('Supabase Response: $response');
    return List<Map<String, dynamic>>.from(response);
  } catch (error) {
    print('Error fetching containers: $error');
    throw Exception('Error fetching containers: $error');
  }
}

// Others Page: Displays options like Account Management, ESP Connection, App Guide, and Log Out
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
        // Account Management
        ListTile(
          leading: const Icon(Icons.person, color: Colors.green),
          title: const Text('Account Settings'),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (context) => const AccountSettingsPage()),
            );
          },
        ),
        // ESP Connection
        ListTile(
          leading: const Icon(Icons.wifi, color: Colors.blue),
          title: const Text('ESP Connection'),
          onTap: _downloadApk, // Call the download function
        ),
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
        // Log Out
        ListTile(
          leading: const Icon(Icons.logout, color: Colors.red),
          title: const Text('Log Out'),
          onTap: () {
            showDialog(
              context: context,
              builder: (BuildContext context) {
                return AlertDialog(
                  title: const Text('Log Out'),
                  content: const Text('Are you sure you want to log out?'),
                  actions: [
                    TextButton(
                      onPressed: () {
                        Navigator.of(context).pop(); // Close dialog
                      },
                      child: const Text('Cancel'),
                    ),
                    TextButton(
                      onPressed: () async {
                        Future<void> logoutUser() async {
                          final SharedPreferences prefs =
                              await SharedPreferences.getInstance();
                          await prefs.remove('user_id_pref');
                          await prefs.remove('user_level');
                          await prefs.remove('fullname');
                          await prefs.remove('email');
                          await prefs.remove('selected_container_id');
                          await prefs.reload();
                          Navigator.pushAndRemoveUntil(
                            context,
                            MaterialPageRoute(
                                builder: (context) => const LoginPage()),
                            (Route<dynamic> route) => false,
                          );
                        }

                        await logoutUser();
                      },
                      child: const Text('Log Out'),
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