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

  void selectContainer(int containerId) {
    selectedContainerId = containerId;
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
  int _currentIndex = 0; // Tracks the selected tab index

  // Pages for bottom navigation
  final List<Widget> _pages = [
    const DashboardPage(),
    const ContainerPage(),
    const OthersPage(),
  ];

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
      _sensorDataFuture = fetchSensorData(selectedContainerId!);
      _notesFuture = fetchNotes(selectedContainerId!, _selectedDate);
      _historyFuture = fetchHistoryData(selectedContainerId!);
      fetchContainerDetails(selectedContainerId!);
    }
  }

  Future<void> _refreshData() async {
    setState(() {
      _lastRefreshTime = DateTime.now();
      _sensorDataFuture = fetchSensorData(selectedContainerId!);
      _notesFuture = fetchNotes(selectedContainerId!, _selectedDate);
      _historyFuture = fetchHistoryData(selectedContainerId!);
    });
    FocusScope.of(context).unfocus();
  }

  Future<void> _deleteNoteImage(int noteId, String imageUrl) async {
  bool confirmDelete = await _showDeleteImageDialog(); // Show confirmation dialog

  if (!confirmDelete) return; // If user cancels, do nothing

  try {
    // Extract file name from URL
    Uri uri = Uri.parse(imageUrl);
    String fileName = uri.pathSegments.last;

    // Delete from Supabase Storage
    await supabase.storage.from('Notes_Image_Test').remove([fileName]);
    print("Image deleted from Supabase: $fileName");

    // Remove image URL from the database (set `picture` column to NULL)
    await supabase
        .from('Notes_test_test')
        .update({'picture': null})
        .eq('note_id', noteId);

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
                await _pickAndReplaceImage(noteId, oldImageUrl, ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library, color: Colors.green),
              title: const Text("Choose from Gallery"),
              onTap: () async {
                Navigator.pop(context);
                await _pickAndReplaceImage(noteId, oldImageUrl, ImageSource.gallery);
              },
            ),
          ],
        ),
      );
    },
  );
}

Future<void> _pickAndReplaceImage(int noteId, String oldImageUrl, ImageSource source) async {
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

    final String newImageUrl = supabase.storage.from('Notes_Image_Test').getPublicUrl(newFileName);
    print("New image uploaded: $newImageUrl");

    await supabase
        .from('Notes_test_test')
        .update({'picture': newImageUrl})
        .eq('note_id', noteId);

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
        content: const Text("Are you sure you want to delete this image? This action cannot be undone."),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false), // Cancel
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true), // Confirm delete
            child: const Text("Delete", style: TextStyle(color: Colors.red)),
          ),
        ],
      );
    },
  ) ?? false; // Default to false if dialog is dismissed
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

  Future<List<Map<String, dynamic>>> fetchHistoryData(int containerId) async {
    final supabase = Supabase.instance.client;
    try {
      return await supabase
          .from('History_Test')
          .select('*')
          .eq('container_id', containerId)
          .order('timestamp', ascending: true);
    } catch (error) {
      return [];
    }
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

  Future<void> _addNote() async {
    if (selectedContainerId == null) return;

    // Trim the note to remove leading/trailing spaces
    String trimmedNote = _notesController.text.trim();

    // Validate if the note is empty
    if (trimmedNote.isEmpty) {
      _showErrorDialog("Please provide notes."); // Show popup for empty input
      return;
    }

    // Save valid note to database
    await addNoteToDatabase(selectedContainerId!, trimmedNote, _imageUrl);
    _notesController.clear();

    setState(() {
      _notesFuture = fetchNotes(selectedContainerId!, _selectedDate);
       // Clear image after saving
        _selectedImage = null;
        _imageUrl = null; // Reset image URL after adding the note
    });
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

Widget buildNoteCard(Map<String, dynamic> note) {
  return Card(
    child: Padding(
      padding: const EdgeInsets.all(10.0), // Better spacing
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Display Image if Available
          if (note['picture'] != null && note['picture'].isNotEmpty)
            Column(
              children: [
                GestureDetector(
                  onTap: () => _showFullScreenImage(note['picture']), // Open fullscreen
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(
                      note['picture'], // ✅ Load image from Supabase URL
                      width: double.infinity,
                      height: 150,
                      fit: BoxFit.cover,
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) return child;
                        return const Center(child: CircularProgressIndicator());
                      },
                      errorBuilder: (context, error, stackTrace) {
                        return const Center(child: Text("Image failed to load"));
                      },
                    ),
                  ),
                ),

                const SizedBox(height: 5),

                // Delete & Replace Image Buttons
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Delete Image Button
                    TextButton.icon(
                      onPressed: () => _deleteNoteImage(note['note_id'], note['picture']),
                      icon: const Icon(Icons.delete, color: Colors.red),
                      label: const Text("Delete Image", style: TextStyle(color: Colors.red)),
                    ),

                    const SizedBox(width: 10), // Space between buttons

                    // Replace Image Button
                    TextButton.icon(
                      onPressed: () => _replaceNoteImage(note['note_id'], note['picture']),
                      icon: const Icon(Icons.camera_alt, color: Colors.blue),
                      label: const Text("Replace Image", style: TextStyle(color: Colors.blue)),
                    ),
                  ],
                ),
              ],
            ),

          const SizedBox(height: 8), // Spacing

          // Display Note Text
          Text(
            note['note'] ?? 'No note available',
            style: const TextStyle(fontSize: 16),
          ),

          // Timestamp
          Text(
            formatTimestamp(note['created_date']),
            style: const TextStyle(fontSize: 12, color: Colors.grey),
          ),

          const SizedBox(height: 5), // Spacing before buttons

          // Edit & Delete Buttons
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              IconButton(
                icon: const Icon(Icons.edit, color: Colors.blue),
                onPressed: () {
                  _showEditDialog(note['note_id'], note['note']);
                },
              ),
              IconButton(
                icon: const Icon(Icons.delete, color: Colors.red),
                onPressed: () {
                  _showDeleteConfirmationDialog(note['note_id']);
                },
              ),
            ],
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

  Widget buildBarChart(
      List<Map<String, dynamic>> data, String title, String key, Color color) {
    try {
      print("Building chart for $title with ${data.length} data points.");

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

  void _calculateContainerAge() {
    if (_containerAddedDate == null) {
      _containerAge = "Unknown";
      return;
    }

    final difference = _selectedDate.difference(_containerAddedDate!);
    int days = difference.inDays;
    int weeks = (days / 7).floor(); // Always display as weeks

    _containerAge = "$weeks ${weeks == 1 ? 'WEEK' : 'WEEKS'}";

    // Set color based on compost age
    if (weeks >= 12) {
      _ageColor = Colors.green;
    } else if (weeks >= 7) {
      _ageColor = Colors.orange;
    } else {
      _ageColor = Colors.red;
    }

    if (mounted) {
      setState(() {}); // Update UI
    }
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
        fileOptions: const FileOptions(upsert: true), // Allows overwriting
      );

      // Get Public URL of the uploaded image
      final String imageUrl = supabase.storage.from('Notes_Image_Test').getPublicUrl(fileName);

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
              child: imagePath.startsWith("http") // Check if it's a network image
                  ? Image.network(imagePath, fit: BoxFit.contain)
                  : Image.file(File(imagePath), fit: BoxFit.contain), // Local file
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
                    //  _getLastRefreshedText(),
                    // style: const TextStyle(
                    //   fontSize: 16, fontWeight: FontWeight.w500),
                    //),
                    Text(
                      _getTimeRefreshed(),
                      style: const TextStyle(fontSize: 14, color: Colors.grey),
                    ),
                    const SizedBox(height: 20),
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
                            ],
                          );
                        }
                      },
                    ),
                    const SizedBox(height: 30),
                    const Divider(thickness: 2),
                    const SizedBox(height: 10),

// TableCalendar with Compost Age and Built-in Navigation
                    Column(
                      children: [
                        // Weekly Calendar
                        TableCalendar(
                          focusedDay: _selectedDate,
                          firstDay: DateTime(2000),
                          lastDay: DateTime(2100),
                          calendarFormat:
                              CalendarFormat.week, // Show only one week
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
                                      _openFullCalendar(); // Open full calendar
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
                              _calculateContainerAge(); //  Update age dynamically
                            });
                          },
                        ),

                        const SizedBox(
                            height: 16), // Space between calendar and age text

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
                              _containerAge, // ✅ Show container age
                              style: TextStyle(
                                fontSize: 26, // Large Text
                                fontWeight: FontWeight.bold,
                                color: _ageColor, // ✅ Color dynamically updates
                              ),
                            ),

                            const SizedBox(height: 30), // Space before legend

                            // Legend
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                // Red (Not Ready)
                                Container(
                                  width: 16,
                                  height: 16,
                                  decoration: BoxDecoration(
                                      color: Colors.red,
                                      shape: BoxShape.circle),
                                ),
                                const SizedBox(width: 8),
                                const Text("Not Ready",
                                    style: TextStyle(fontSize: 14)),

                                const SizedBox(
                                    width: 16), // Space between legends

                                // Yellow (Decomposing)
                                Container(
                                  width: 16,
                                  height: 16,
                                  decoration: BoxDecoration(
                                      color: Colors.orange,
                                      shape: BoxShape.circle),
                                ),
                                const SizedBox(width: 8),
                                const Text("Decomposing",
                                    style: TextStyle(fontSize: 14)),

                                const SizedBox(
                                    width: 16), // Space between legends

                                // Green (Ready)
                                Container(
                                  width: 16,
                                  height: 16,
                                  decoration: BoxDecoration(
                                      color: Colors.green,
                                      shape: BoxShape.circle),
                                ),
                                const SizedBox(width: 8),
                                const Text("Ready",
                                    style: TextStyle(fontSize: 14)),
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
    onTap: () => _showFullScreenImage(_selectedImage!.path), // ✅ Pass file path as String
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
                                onPressed: _addNote,
                                icon: const Icon(Icons.add_comment_outlined),
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

                          return SingleChildScrollView(
                            scrollDirection: Axis.vertical,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const SizedBox(height: 20),

                                // Temperature Graph Section
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
                                SingleChildScrollView(
                                  controller: scrollController,
                                  scrollDirection: Axis.horizontal,
                                  reverse: true,
                                  child: buildBarChart(
                                      historyData,
                                      'Temperature',
                                      'temperature',
                                      Colors.green),
                                ),
                                const SizedBox(height: 20),
                                Divider(
                                    thickness: 2, color: Colors.grey.shade400),

                                const SizedBox(height: 20),

                                // Moisture Graph Section
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
                                SingleChildScrollView(
                                  controller: scrollController,
                                  scrollDirection: Axis.horizontal,
                                  reverse: true,
                                  child: buildBarChart(historyData, 'Moisture',
                                      'moisture', Colors.blue),
                                ),
                                const SizedBox(height: 20),
                                Divider(
                                    thickness: 2, color: Colors.grey.shade400),

                                const SizedBox(height: 20),

                                // pH Level 1 Graph Section
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
                                SingleChildScrollView(
                                  controller: scrollController,
                                  scrollDirection: Axis.horizontal,
                                  reverse: true,
                                  child: buildBarChart(historyData,
                                      'pH Level 1', 'ph_level1', Colors.purple),
                                ),
                                const SizedBox(height: 20),
                                Divider(
                                    thickness: 2, color: Colors.grey.shade400),

                                const SizedBox(height: 20),

                                // pH Level 2 Graph Section
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
                                SingleChildScrollView(
                                  controller: scrollController,
                                  scrollDirection: Axis.horizontal,
                                  reverse: true,
                                  child: buildBarChart(
                                      historyData,
                                      'pH Level 2',
                                      'ph_level2',
                                      Colors.deepPurple),
                                ),
                                const SizedBox(height: 20),
                                Divider(
                                    thickness: 2, color: Colors.grey.shade400),

                                const SizedBox(height: 20),

                                // Humidity Graph Section
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
                                SingleChildScrollView(
                                  controller: scrollController,
                                  scrollDirection: Axis.horizontal,
                                  reverse: true,
                                  child: buildBarChart(historyData, 'Humidity',
                                      'humidity', Colors.orange),
                                ),
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
Future<void> addNoteToDatabase(int containerId, String note, String? imageUrl) async {
  final supabase = Supabase.instance.client;

  try {
    await supabase.from('Notes_test_test').insert({
      'container_id': containerId,
      'note': note,
      'picture': imageUrl,  // ✅ Store image URL in the 'picture' column
      'created_date': DateTime.now().toIso8601String(),
    });

    print("Note added successfully with image URL: $imageUrl");

  } catch (error) {
    print("Error adding note: $error");
  }
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
        'date_added': DateFormat('yyyy-MM-dd kk:mm:ss').format(DateTime.now()),
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
