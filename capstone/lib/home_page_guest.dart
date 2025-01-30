import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
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
        bottomNavigationBar: BottomNavigationBar(
          currentIndex: _currentIndex,
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

// Dashboard Page with pull-to-refresh functionality
class DashboardPage extends StatefulWidget {
  @override
  _DashboardPageState createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  Future<Map<String, dynamic>>? _sensorDataFuture;
  int? selectedContainerId;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final containerState = Provider.of<ContainerState>(context);
    selectedContainerId = containerState.selectedContainerId;
    if (selectedContainerId != null) {
      _sensorDataFuture = fetchSensorData(selectedContainerId!);
    }
  }

  Future<void> _refreshData() async {
    if (selectedContainerId != null) {
      setState(() {
        _sensorDataFuture = fetchSensorData(selectedContainerId!);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return selectedContainerId == null
        ? Center(child: Text('Please select a container from the Container tab.'))
        : RefreshIndicator(
            onRefresh: _refreshData,
            child: SingleChildScrollView(
              physics: AlwaysScrollableScrollPhysics(),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Dashboard',
                      style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: 20),
                    Text('Selected Container: $selectedContainerId',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500)),
                    SizedBox(height: 10),
                    FutureBuilder(
                      future: _sensorDataFuture,
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return Center(child: CircularProgressIndicator());
                        } else if (snapshot.hasError) {
                          return Text('Error fetching data');
                        } else {
                          final sensorData = snapshot.data as Map<String, dynamic>;
                          return Column(
                            children: [
                              buildSensorCard(Icons.thermostat, 'Temperature Monitoring', '${sensorData['temperature']}°C', Colors.green),
                              buildSensorCard(Icons.water_drop, 'Moisture Level', '${sensorData['moisture']}%', Colors.blue),
                              buildSensorCard(Icons.science, 'pH Level 1', '${sensorData['ph_level']}', Colors.purple),
                              buildSensorCard(Icons.science_outlined, 'pH Level 2', '${sensorData['ph_level2']}', Colors.deepPurple),
                              buildSensorCard(Icons.cloud, 'Humidity', '${sensorData['humidity']}%', Colors.orange),
                              buildSensorCard(Icons.access_time, 'Timestamp', '${sensorData['timestamp']}', Colors.grey),
                            ],
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
class ContainerPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final containerState = Provider.of<ContainerState>(context);
    return FutureBuilder(
      future: fetchContainers(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator());
        } else if (snapshot.hasError) {
          return Center(child: Text('Error fetching containers: ${snapshot.error}'));
        } else {
          final containers = snapshot.data as List<Map<String, dynamic>>;
          return ListView.builder(
            itemCount: containers.length,
            itemBuilder: (context, index) {
              final container = containers[index];
              final isSelected = container['container_id'] == containerState.selectedContainerId;
              return Card(
                color: isSelected ? Colors.green[100] : null, // Highlight selected container
                child: ListTile(
                  title: Text('Container ${container['container_id']}'),
                  subtitle: Text('Hardware ID: ${container['hardware_id']}'),
                  trailing: isSelected ? Icon(Icons.check_circle, color: Colors.green) : null,
                  onTap: () {
                    containerState.selectContainer(container['container_id']);
                  },
                ),
              );
            },
          );
        }
      },
    );
  }
}

  Future<List<Map<String, dynamic>>> fetchContainers() async {
    final supabase = Supabase.instance.client;
    try {
    final response = await supabase.from('Containers_test').select('*');
      print ('Supabase Response: $response');
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
