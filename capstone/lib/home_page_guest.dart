import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
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

// State Management: Tracks the selected container
class ContainerState extends ChangeNotifier {
  int? selectedContainerId;
  final List<Map<String, dynamic>> guestContainers =
      []; // Persist scanned containers

  void selectContainer(int containerId) {
    selectedContainerId = containerId;
    notifyListeners();
  }

  void addContainer(Map<String, dynamic> container) {
    if (!guestContainers
        .any((c) => c['hardware_id'] == container['hardware_id'])) {
      guestContainers.add(container);
      notifyListeners();
    }
  }
}

class HomePageGuest extends StatefulWidget {
  const HomePageGuest({super.key});

  @override
  _HomePageGuestState createState() => _HomePageGuestState();
}

class _HomePageGuestState extends State<HomePageGuest> {
  int _currentIndex = 1; // Tracks the selected tab index

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
          title: const Text('E-ComposThink Home - Guest'),
        ),
        body: _pages[_currentIndex],
        bottomNavigationBar: BottomNavigationBar(
          currentIndex: _currentIndex,
          selectedItemColor: Colors.green,
          unselectedItemColor: Colors.green[300],
          onTap: (index) {
            setState(() {
              _currentIndex = index;
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

  Future<List<Map<String, dynamic>>>? _historyFuture;
  int? selectedContainerId;
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

      _historyFuture = fetchHistoryData(selectedContainerId!);
      fetchContainerDetails(selectedContainerId!);
    }
  }

  Future<void> _refreshData() async {
    setState(() {
      _lastRefreshTime = DateTime.now();
      _sensorDataFuture = fetchSensorData(selectedContainerId!);

      _historyFuture = fetchHistoryData(selectedContainerId!);
    });
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
      final hardwareResponse = await supabase
          .from('Hardware_Sensors_Test')
          .select('start_date')
          .eq('hardware_id', containerId)
          .maybeSingle();

      DateTime startDate = DateTime.parse(hardwareResponse?['start_date']);

      // Step 2: Fetch historical data using the correct hardware_id
      final response = await supabase
          .from('History_Average')
          .select()
          .eq('hardware_id', containerId)
          .gte('timestamp', startDate)
          .order('timestamp', ascending: true);

      if (response.isEmpty) {
        print("No historical data found for hardware_id: $containerId");
      } else {
        print("Fetched Historical Data: $response");
      }

      return response;
    } catch (error) {
      print("Error fetching historical data: $error");
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
          .from('Hardware_Sensors_Test')
          .select('start_date')
          .eq('hardware_id', containerId)
          .maybeSingle(); // Use maybeSingle() to prevent exceptions

      setState(() {
        _containerAddedDate = response != null && response['start_date'] != null
            ? DateTime.parse(response['start_date'])
            : null; // Reset to null if no start_date
      });
    } catch (error) {
      print("Error fetching container details: $error");
    }
  }

// Function to check if a date is within the compost cycle
  bool isWithinCompostCycle(DateTime day, DateTime? startDate) {
    if (startDate == null) return false;
    final endDate =
        startDate.add(const Duration(days: 16 * 7)); // 16-week cycle
    return day.isAfter(startDate.subtract(const Duration(days: 1))) &&
        day.isBefore(endDate.add(const Duration(days: 1)));
  }

  void _openFullCalendar() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
                  calendarFormat: CalendarFormat.month,
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
                    defaultBuilder: (context, day, focusedDay) {
                      if (isWithinCompostCycle(day, _containerAddedDate)) {
                        DateTime today = DateTime.now();
                        if (_containerAddedDate != null) {
                          DateTime compostEndDate = _containerAddedDate!
                              .add(const Duration(days: 112)); // 16 weeks later
                          DateTime cycleDayOne = _containerAddedDate!.add(
                              const Duration(days: 1)); // Day 1 of the cycle

                          bool isWithinCycle =
                              day.isAfter(_containerAddedDate!) &&
                                  day.isBefore(compostEndDate);
                          bool isToday = day.year == today.year &&
                              day.month == today.month &&
                              day.day == today.day;

                          if (isWithinCycle || isToday) {
                            bool isDayOne = day.year == cycleDayOne.year &&
                                day.month == cycleDayOne.month &&
                                day.day == cycleDayOne.day;
                            bool isEndDate = day.year == compostEndDate.year &&
                                day.month == compostEndDate.month &&
                                day.day == compostEndDate.day;
                            return Container(
                              margin: const EdgeInsets.symmetric(
                                  vertical: 6, horizontal: 0),
                              padding: const EdgeInsets.symmetric(
                                  vertical:
                                      4), // Shortens top and bottom spacing
                              decoration: BoxDecoration(
                                color: Colors.grey
                                    .withOpacity(0.3), // Gray shading effect
                                borderRadius: BorderRadius.horizontal(
                                  left: isDayOne
                                      ? const Radius.circular(20)
                                      : Radius.zero,
                                  right: isEndDate
                                      ? const Radius.circular(20)
                                      : Radius.zero,
                                ),
                              ),
                              child: Center(
                                child: Text(
                                  day.day.toString(),
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black87,
                                  ),
                                ),
                              ),
                            );
                          }
                        }
                        return null;
                      }
                    },
                    todayBuilder: (context, day, _) {
                      if (_containerAddedDate != null) {
                        return Stack(
                          alignment: Alignment.center,
                          children: [
                            // Background shading extending to adjacent dates
                            Container(
                              margin: const EdgeInsets.symmetric(
                                  vertical: 6, horizontal: 0),
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.grey.withOpacity(
                                    0.3), // Maintain shading effect
                                // borderRadius: BorderRadius.horizontal(
                                //   left: const Radius.circular(20), // Smooth connection on the left
                                //   right: const Radius.circular(20), // Smooth connection on the right
                                // ),
                              ),
                              height: 40, // Maintain shading visibility
                              width: double.infinity,
                            ),

                            // Today indicator
                            Container(
                              height: 36,
                              width: 36,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.green
                                    .withOpacity(0.5), // Highlight today's date
                              ),
                            ),

                            // Date number
                            Center(
                              child: Text(
                                day.day.toString(),
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black87, // Ensure visibility
                                ),
                              ),
                            ),
                          ],
                        );
                      } else {
                        return Stack(
                          alignment: Alignment.center,
                          children: [
                            // Today indicator
                            Container(
                              height: 36,
                              width: 36,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.green
                                    .withOpacity(0.5), // Highlight today's date
                              ),
                            ),

                            // Date number
                            Center(
                              child: Text(
                                day.day.toString(),
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black87, // Ensure visibility
                                ),
                              ),
                            ),
                          ],
                        );
                      }
                    },
                    selectedBuilder: (context, day, _) {
                      if (_containerAddedDate != null) {
                        DateTime compostEndDate = _containerAddedDate != null
                            ? _containerAddedDate!
                                .add(const Duration(days: 112))
                            : DateTime.now();
                        DateTime cycleDayOne = _containerAddedDate != null
                            ? _containerAddedDate!.add(const Duration(days: 1))
                            : DateTime.now();

                        bool isWithinCycle =
                            day.isAfter(_containerAddedDate!) &&
                                day.isBefore(compostEndDate);
                        bool isDayOne = day.year == cycleDayOne.year &&
                            day.month == cycleDayOne.month &&
                            day.day == cycleDayOne.day;

                        bool isEndDate = day.year == compostEndDate.year &&
                            day.month == compostEndDate.month &&
                            day.day == compostEndDate.day;

                        return Stack(
                          alignment: Alignment.center,
                          children: [
                            // Preserve shading effect
                            if (isWithinCycle)
                              Container(
                                decoration: BoxDecoration(
                                  color: Colors.grey
                                      .withOpacity(0.3), // Shading effect
                                  borderRadius: BorderRadius.horizontal(
                                    left: isDayOne
                                        ? const Radius.circular(20)
                                        : Radius.zero,
                                    right: isEndDate
                                        ? const Radius.circular(20)
                                        : Radius.zero,
                                  ),
                                ),
                                height: 40, // Maintain shading visibility
                                width: double.infinity,
                              ),

                            // Selection circle (on top)
                            Container(
                              height: 36,
                              width: 36,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                    color: Colors.green,
                                    width: 2), // Green outline for selection
                                color:
                                    Colors.transparent, // Keep shading visible
                              ),
                            ),
                            // Date number (ensures readability)
                            Center(
                              child: Text(
                                day.day.toString(),
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black87, // Keep text readable
                                ),
                              ),
                            ),
                          ],
                        );
                      } else {
                        return Stack(
                          alignment: Alignment.center,
                          children: [
                            // Selection circle (on top)
                            Container(
                              height: 36,
                              width: 36,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                    color: Colors.green,
                                    width: 2), // Green outline for selection
                                color:
                                    Colors.transparent, // Keep shading visible
                              ),
                            ),
                            // Date number (ensures readability)
                            Center(
                              child: Text(
                                day.day.toString(),
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black87, // Keep text readable
                                ),
                              ),
                            ),
                          ],
                        );
                      }
                    },
                  ),
                  selectedDayPredicate: (day) => isSameDay(_selectedDate, day),
                  onDaySelected: (selectedDay, focusedDay) async {
                    setState(() {
                      _selectedDate = selectedDay;
                    });
                    Navigator.pop(context);
                  },
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
  }

  int _calculateContainerAge() {
    if (_containerAddedDate == null) {
      _containerAge = "NOT YET STARTED";
      _ageColor = Colors.black;
      return 0;
    }

    final difference = _selectedDate.difference(_containerAddedDate!);

    if (difference.isNegative) {
      _containerAge = "NOT STARTED YET";
      _ageColor = Colors.black;
      return 0;
    }

    int weeks = difference.inDays ~/ 7;
    int days = difference.inDays % 7;

    // Handle singular/plural properly
    String weekText = weeks == 1 ? "1 WEEK" : "$weeks WEEKS";
    String dayText = days == 1 ? "1 DAY" : "$days DAYS";

    if (weeks == 0) {
      _containerAge = dayText; // Only display days if weeks is 0
    } else if (days == 0) {
      _containerAge = weekText; // Only display weeks if days is 0
    } else {
      _containerAge = "$weekText AND $dayText"; // Display both
    }

    if (weeks >= 16) {
      _ageColor = Colors.grey;
    } else if (weeks >= 12) {
      _ageColor = Colors.green;
    } else if (weeks >= 7) {
      _ageColor = Colors.orange;
    } else {
      _ageColor = Colors.red;
    }

    if (mounted) {
      setState(() {});
    }

    return weeks;
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

                          String compostStartDate =
                              sensorData['start_date'] != null
                                  ? DateFormat('yyyy-MM-dd').format(
                                      DateTime.parse(sensorData['start_date']))
                                  : "Not Set"; // ✅ Displays "Not Set" if null

                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text("Compost Start Date: $compostStartDate",
                                  style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold)),
                              const SizedBox(height: 5),
                              Text(
                                _getTimeRefreshed(),
                                style: const TextStyle(
                                    fontSize: 14, color: Colors.grey),
                              ),
                              buildSensorCard(
                                  Icons.thermostat,
                                  'Temperature Monitoring',
                                  '${sensorData['temperature']}°C',
                                  Colors.green),
                              buildSensorCard(Icons.water_drop, 'Dryness Level',
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
                        }
                      },
                    ),
                    const SizedBox(height: 20),
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
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment
                                    .stretch, // ✅ Full width alignment
                                children: [
                                  // 📌 Full Calendar Section (Sleek, Minimalist, and Structured)
                                  Container(
                                    margin: const EdgeInsets.symmetric(
                                        horizontal: 16,
                                        vertical: 8), // ✅ Balanced spacing
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 12, horizontal: 16),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(
                                          12), // ✅ Smooth rounded corners
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black12,
                                          blurRadius: 4,
                                          offset: Offset(0,
                                              2), // ✅ Subtle shadow for depth
                                        ),
                                      ],
                                    ),
                                    child: InkWell(
                                      onTap:
                                          _openFullCalendar, // ✅ Opens full calendar
                                      borderRadius: BorderRadius.circular(12),
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment
                                            .center, // ✅ Centers everything
                                        children: [
                                          const Icon(Icons.calendar_month,
                                              color: Colors.blueGrey, size: 24),
                                          const SizedBox(
                                              width: 10), // ✅ Proper spacing
                                          const Text(
                                            "Full Calendar",
                                            style: TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w600,
                                              color: Colors.black87,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),

                                  const SizedBox(
                                      height:
                                          10), // ✅ Space before the month display

                                  // 📌 Month Display (Perfectly Centered)
                                  Align(
                                    alignment: Alignment
                                        .center, // ✅ Ensures text is perfectly centered
                                    child: Text(
                                      DateFormat.yMMMM().format(date),
                                      style: const TextStyle(
                                        fontSize: 22,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.black87,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ),

                                  const SizedBox(
                                      height: 8), // ✅ Space before divider

                                  // 📌 Clean Divider for Structure
                                  const Divider(
                                    thickness: 1.5,
                                    color: Colors.black26,
                                    indent: 20,
                                    endIndent: 20,
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
                              (selectedContainerId!, _selectedDate);
                              _calculateContainerAge(); // ✅ Update age dynamically
                            });
                          },
                        ),

                        const SizedBox(
                            height: 30), // Space between calendar and age text

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

                    const SizedBox(height: 15),
                    const Divider(thickness: 2),
                    const SizedBox(height: 10),
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
                        }

                        List<Map<String, dynamic>> historyData =
                            (snapshot.data as List<Map<String, dynamic>>)
                                .toList();

                        ScrollController scrollController = ScrollController();

                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          scrollController.jumpTo(
                              scrollController.position.maxScrollExtent);
                        });

                        Widget buildChartOrMessage(
                            String title, String key, Color color) {
                          if (historyData.length <= 2) {
                            return Container(
                              height: 250, // ✅ Keep consistent chart height
                              alignment: Alignment.center,
                              child: const Text(
                                'Insufficient Historical Data',
                                style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.red),
                              ),
                            );
                          } else if (_containerAddedDate == null) {
                            return Container(
                              height: 250,
                              alignment: Alignment.center,
                              child: const Text(
                                'No Compost',
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
                              child:
                                  buildBarChart(historyData, title, key, color),
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
                                    fontSize: 20, fontWeight: FontWeight.bold),
                              ),
                              const Text(
                                '• Safe: Between 10°C to 54°C  |  Critical: Above 54°C',
                                style:
                                    TextStyle(fontSize: 14, color: Colors.grey),
                              ),
                              buildChartOrMessage(
                                  'Temperature', 'temperature', Colors.green),
                              const SizedBox(height: 20),
                              Divider(
                                  thickness: 2, color: Colors.grey.shade400),
                              const SizedBox(height: 20),
                              const Text(
                                'Dryness Level',
                                style: TextStyle(
                                    fontSize: 20, fontWeight: FontWeight.bold),
                              ),
                              const Text(
                                '• Optimal: 50-60%  |  Wet: Below 50%  |  Too Dry: Above 60%',
                                style:
                                    TextStyle(fontSize: 14, color: Colors.grey),
                              ),
                              buildChartOrMessage(
                                  'Dryness', 'moisture', Colors.blue),
                              const SizedBox(height: 20),
                              Divider(
                                  thickness: 2, color: Colors.grey.shade400),
                              const SizedBox(height: 20),
                              const Text(
                                'pH Level 1',
                                style: TextStyle(
                                    fontSize: 20, fontWeight: FontWeight.bold),
                              ),
                              const Text(
                                '• Ideal: 6.0 - 8.0 | Too Acidic: Below 6.0 | Too Basic: Above 8',
                                style:
                                    TextStyle(fontSize: 14, color: Colors.grey),
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
                                    fontSize: 20, fontWeight: FontWeight.bold),
                              ),
                              const Text(
                                '• Ideal: 6.0 - 8.0 | Too Acidic: Below 6.0 | Too Basic: Above 8',
                                style:
                                    TextStyle(fontSize: 14, color: Colors.grey),
                              ),
                              buildChartOrMessage(
                                  'pH Level 2', 'ph_level2', Colors.deepPurple),
                              const SizedBox(height: 20),
                              Divider(
                                  thickness: 2, color: Colors.grey.shade400),
                              const SizedBox(height: 20),
                              const Text(
                                'Humidity Level',
                                style: TextStyle(
                                    fontSize: 20, fontWeight: FontWeight.bold),
                              ),
                              const Text(
                                '• Optimal: 30-60%  |  Low: Below 30%  |  High: Above 60%',
                                style:
                                    TextStyle(fontSize: 14, color: Colors.grey),
                              ),
                              buildChartOrMessage(
                                  'Humidity', 'humidity', Colors.orange),
                            ],
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          );
  }
}

//Database Fetching: Fetch sensor data for a specific container
Future<Map<String, dynamic>> fetchSensorData(int containerId) async {
  final supabase = Supabase.instance.client;
  final sensorResponse = await supabase
      .from('Hardware_Sensors_Test')
      .select(
          'temperature, moisture, ph_level, ph_level2, humidity, refreshed_date, start_date')
      .eq('hardware_id', containerId)
      .order('refreshed_date', ascending: false)
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
  void fetchData(String scannedCode) async {
    final supabase = Supabase.instance.client;
    final containerState = Provider.of<ContainerState>(context, listen: false);

    final response = await supabase
        .from('Hardware_Sensors_Test')
        .select('*')
        .eq('qr_value', scannedCode)
        .maybeSingle();

    if (response == null) {
      showToast("QR code not linked to any container.");
      return;
    }

    containerState.addContainer(response);
    showToast("Container added to session.");
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

  void performQuery(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ScannerPage(
          onScanned: (scannedCode) {
            fetchData(scannedCode);
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final containerState = Provider.of<ContainerState>(context);

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              minimumSize: const Size(double.infinity, 50),
            ),
            onPressed: () => performQuery(context),
            icon: const Icon(Icons.add, color: Colors.white),
            label: const Text('Scan Container',
                style: TextStyle(color: Colors.white)),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: ListView.builder(
              itemCount: containerState.guestContainers.length,
              itemBuilder: (context, index) {
                final container = containerState.guestContainers[index];
                final isSelected = containerState.selectedContainerId ==
                    container['hardware_id'];
                if (container['start_date'] == null) {
                  String formattedDate = "Not Set";
                  return Card(
                      color: isSelected ? Colors.green[100] : null,
                      child: ListTile(
                        title: Text('Container: ${container['hardware_id']}'),
                        subtitle: Text('Date Started: $formattedDate'),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (isSelected)
                              const Icon(Icons.check_circle,
                                  color: Colors.green),
                            // IconButton(
                            //       icon: const Icon(Icons.delete,
                            //           color: Colors.red),
                            //       onPressed: () {
                            //         _showDeleteConfirmationDialog(
                            //             context, container['container_id']);
                            //       },
                            //     ),
                          ],
                        ),
                        onTap: () {
                          containerState
                              .selectContainer(container['hardware_id']);
                        },
                      ));
                } else if (container['start_date'] != null) {
                  DateTime dateTime = DateTime.parse(container['start_date']);
                  String formattedDate =
                      DateFormat('yyyy-MM-dd').format(dateTime);
                  return Card(
                      color: isSelected ? Colors.green[100] : null,
                      child: ListTile(
                        title: Text('Container: ${container['hardware_id']}'),
                        subtitle: Text('Date Started: $formattedDate'),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (isSelected)
                              const Icon(Icons.check_circle,
                                  color: Colors.green),
                            // IconButton(
                            //       icon: const Icon(Icons.delete,
                            //           color: Colors.red),
                            //       onPressed: () {
                            //         _showDeleteConfirmationDialog(
                            //             context, container['container_id']);
                            //       },
                            //     ),
                          ],
                        ),
                        onTap: () {
                          containerState
                              .selectContainer(container['hardware_id']);
                        },
                      ));
                }
              },
            ),
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
              final containerState =
                  Provider.of<ContainerState>(context, listen: false);
              containerState.guestContainers.removeWhere(
                  (container) => container['hardware_id'] == containerId);

              // Reset selected container if it's deleted
              if (containerState.selectedContainerId == containerId) {
                containerState.selectedContainerId = null;
              }

              containerState.notifyListeners();
              Navigator.pop(context); // Close the dialog
            },
            child: const Text("Delete"),
          ),
        ],
      ),
    );
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
              MaterialPageRoute(builder: (context) => const LoginPage()),
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
        // ListTile(
        //   leading: const Icon(Icons.help_outline, color: Colors.orange),
        //   title: const Text('App Guide'),
        //   onTap: () {
        //     Navigator.push(
        //       context,
        //       MaterialPageRoute(builder: (context) => const AppGuidePage()),
        //     );
        //   },
        // ),
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
