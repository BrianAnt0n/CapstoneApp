import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'shared_prefs_helper.dart';

class DataReportPage extends StatefulWidget {
  final int selectedHardwareId; // ✅ Using hardware_id

  const DataReportPage({super.key, required this.selectedHardwareId});

  @override
  _DataReportPageState createState() => _DataReportPageState();
}

class _DataReportPageState extends State<DataReportPage> {
  late DateTime firstSelectedDate;
  late DateTime secondSelectedDate;
  bool hasSecondDate = false;
  int? hardwareId;
  Map<String, String> firstDateData = {};
  Map<String, String> secondDateData = {};
  List<Map<String, dynamic>> frequencyAnalysisData = [];

  @override
  void initState() {
    super.initState();
    firstSelectedDate = DateTime.now();
    secondSelectedDate = DateTime.now();
    _initializeData();
  }

  Future<void> _initializeData() async {
    final userLogin = await SharedPrefsHelper.getUserLogin();
    String? storedEmail = userLogin['email'];

    print("🔍 Initializing data for User: $storedEmail");

    int? fetchedHardwareId = widget.selectedHardwareId;
    if (fetchedHardwareId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Error: No hardware ID found.")),
      );
      Navigator.pop(context);
      return;
    }

    setState(() {
      hardwareId = fetchedHardwareId;
    });

    firstDateData = await _fetchHistoricalData(firstSelectedDate, hardwareId!);
    frequencyAnalysisData = await _fetchFrequencyAnalysis(hardwareId!);

    setState(() {
      print("🔄 UI Updated with fetched data for User: $storedEmail");
    });
  }

  // Date Picker Tile Widget
Widget _buildDatePickerTile(String title, DateTime selectedDate, Function(DateTime?) onDatePicked) {
  return ListTile(
    title: Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
    subtitle: Text(DateFormat('yyyy-MM-dd').format(selectedDate), style: const TextStyle(fontSize: 16)),
    trailing: const Icon(Icons.calendar_today, color: Colors.green),
    onTap: () async {
      DateTime? pickedDate = await showDatePicker(
        context: context,
        initialDate: selectedDate,
        firstDate: DateTime(2020),
        lastDate: DateTime.now(),
      );
      onDatePicked(pickedDate);
    },
  );
}

// Data Card Widget
Widget _buildDataCard(String title, Map<String, String> data) {
  return Card(
    color: Colors.white,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    elevation: 3,
    margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
    child: Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black)),
          const Divider(color: Colors.black45),
          ...data.entries.map((entry) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(entry.key, style: const TextStyle(fontSize: 16, color: Colors.black54)),
                  Text(entry.value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.blueAccent)),
                ],
              ),
            );
          }),
        ],
      ),
    ),
  );
}


  Future<Map<String, String>> _fetchHistoricalData(DateTime date, int hardwareId) async {
    String startOfDay = "${DateFormat('yyyy-MM-dd').format(date)} 00:00:00";
    String endOfDay = "${DateFormat('yyyy-MM-dd').format(date)} 23:59:59";

    print("🔍 Fetching historical data for hardware_id: $hardwareId between $startOfDay and $endOfDay");

    try {
      final response = await Supabase.instance.client
          .from('History_Test')
          .select()
          .eq('hardware_id', hardwareId)
          .gte('timestamp', startOfDay)
          .lte('timestamp', endOfDay)
          .order('timestamp', ascending: false)
          .limit(1)
          .maybeSingle();

      if (response == null) {
        print("🚨 No data found for hardware_id: $hardwareId on $startOfDay");
        return _defaultData("N/A");
      }

      return {
        "Temperature": "${response['temperature'] ?? 'N/A'}°C",
        "Moisture Level": "${response['moisture'] ?? 'N/A'}%",
        "pH Level 1": "${response['ph_level1'] ?? 'N/A'}",
        "pH Level 2": "${response['ph_level2'] ?? 'N/A'}",
        "Humidity": "${response['humidity'] ?? 'N/A'}%",
      };
    } catch (e) {
      print("❌ Error fetching historical data: $e");
      return _defaultData("Error");
    }
  }

  Future<List<Map<String, dynamic>>> _fetchFrequencyAnalysis(int hardwareId) async {
  print("🔍 Fetching frequency analysis data for hardware_id: $hardwareId");

  try {
    final response = await Supabase.instance.client
        .from('Notifications_Test') // ✅ Ensure correct table name
        .select('sensor_type, sensor_value, timestamp') // ✅ Fetch only necessary columns
        .eq('hardware_id', hardwareId)
        .order('timestamp', ascending: false)
        .limit(10); // ✅ Fetch last 10 alerts

    if (response.isEmpty) {
      print("🚨 No notifications found for hardware_id: $hardwareId");
      return [];
    }

    return response.map<Map<String, dynamic>>((entry) {
      // ✅ Handle missing timestamp
      String formattedTime = "Unknown Time";
      if (entry['timestamp'] != null) {
        try {
          formattedTime = DateFormat.jm().format(DateTime.parse(entry['timestamp'].toString()));
        } catch (e) {
          print("⚠️ Error parsing timestamp: ${entry['timestamp']} - $e");
        }
      }

      return {
        "Sensor": entry['sensor_type'] ?? "Unknown Sensor",
        "Value": entry['sensor_value']?.toString() ?? "N/A", // ✅ Ensure value is a string
        "Time": formattedTime, // ✅ Display formatted time
      };
    }).toList();
  } catch (e) {
    print("❌ Error fetching notification data: $e");
    return [];
  }
}


  Map<String, String> _defaultData(String message) {
    return {
      "Temperature": message,
      "Moisture Level": message,
      "pH Level 1": message,
      "pH Level 2": message,
      "Humidity": message,
    };
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white, // ✅ White theme background
      appBar: AppBar(
        title: const Text("Data Report", style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.green[700], // ✅ Nature theme
        elevation: 4,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            _buildDatePickerTile("Select First Date", firstSelectedDate, (pickedDate) async {
              if (pickedDate != null) {
                setState(() {
                  firstSelectedDate = pickedDate;
                });
                firstDateData = await _fetchHistoricalData(firstSelectedDate, hardwareId!);
                setState(() {});
              }
            }),

            _buildDatePickerTile("Select Second Date", secondSelectedDate, (pickedDate) async {
              if (pickedDate != null) {
                setState(() {
                  secondSelectedDate = pickedDate;
                  hasSecondDate = true;
                });
                secondDateData = await _fetchHistoricalData(secondSelectedDate, hardwareId!);
                setState(() {});
              }
            }),

            Expanded(
              child: ListView(
                children: [
                  _buildDataCard("First Date Data", firstDateData),
                  if (hasSecondDate) _buildDataCard("Second Date Data", secondDateData),
                  _buildFrequencyAnalysisCard(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFrequencyAnalysisCard() {
    return Card(
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 3,
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Time-Based Frequency Analysis",
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black)),
            const Divider(color: Colors.black45),
            if (frequencyAnalysisData.isEmpty)
              const Text("No alerts recorded.", style: TextStyle(fontSize: 16, color: Colors.black54)),
            ...frequencyAnalysisData.map((entry) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(entry["Sensor"], style: const TextStyle(fontSize: 16, color: Colors.black54)),
                    Text("${entry["Value"]} at ${entry["Time"]}",
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.red)),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}
