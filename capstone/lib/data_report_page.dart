import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class DataReportPage extends StatefulWidget {
  final int selectedContainerId;

  const DataReportPage({super.key, required this.selectedContainerId});

  @override
  _DataReportPageState createState() => _DataReportPageState();
}

class _DataReportPageState extends State<DataReportPage> {
  late int hardwareId;
  late DateTime firstSelectedDate;
  late DateTime secondSelectedDate;
  bool hasSecondDate = false;
  Map<String, String> firstDateData = {};
  Map<String, String> secondDateData = {};

  @override
  void initState() {
    super.initState();
    firstSelectedDate = DateTime.now(); // Default to today
    secondSelectedDate = DateTime.now(); // Default second date (same as first)
    _initializeData();
  }

  Future<void> _initializeData() async {
    int? fetchedHardwareId = await _fetchHardwareId(widget.selectedContainerId);
    if (fetchedHardwareId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Error: No hardware ID found.")));
      Navigator.pop(context);
      return;
    }

    setState(() {
      hardwareId = fetchedHardwareId;
    });

    firstDateData = await _fetchHistoricalData(firstSelectedDate, hardwareId);
    setState(() {});
  }

  Future<int?> _fetchHardwareId(int selectedContainerId) async {
    try {
      final response = await Supabase.instance.client
          .from('Containers_test')
          .select('hardware_id')
          .eq('container_id', selectedContainerId)
          .maybeSingle();

      return response?['hardware_id'] as int?;
    } catch (e) {
      print("Error fetching hardware ID: $e");
      return null;
    }
  }

  Future<Map<String, String>> _fetchHistoricalData(
      DateTime date, int hardwareId) async {
    try {
      final response = await Supabase.instance.client
          .from('History_Test')
          .select()
          .eq('hardware_id', hardwareId)
          .gte('timestamp', DateFormat('yyyy-MM-dd 00:00:00').format(date))
          .lte('timestamp', DateFormat('yyyy-MM-dd 23:59:59').format(date))
          .order('timestamp', ascending: false)
          .limit(1)
          .maybeSingle();

      if (response == null) {
        return _defaultData("No Data");
      }

      return {
        "Temperature": "${response['temperature'] ?? 'N/A'}°C",
        "Moisture Level": "${response['moisture'] ?? 'N/A'}%",
        "pH Level 1": "${response['ph_level1'] ?? 'N/A'}",
        "pH Level 2": "${response['ph_level2'] ?? 'N/A'}",
        "Humidity": "${response['humidity'] ?? 'N/A'}%",
      };
    } catch (e) {
      print("Error fetching historical data: $e");
      return _defaultData("Error");
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
      appBar: AppBar(title: const Text("Historical Data Report")),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // First Date Picker
            ListTile(
              leading: const Icon(Icons.calendar_today, color: Colors.blue),
              title: const Text("Select First Date",
                  style: TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text(DateFormat.yMMMMd().format(firstSelectedDate),
                  style: TextStyle(color: Colors.grey[600])),
              trailing: const Icon(Icons.arrow_forward_ios, size: 18),
              onTap: () async {
                DateTime? pickedDate = await showDatePicker(
                  context: context,
                  initialDate: firstSelectedDate,
                  firstDate: DateTime(2000),
                  lastDate: DateTime(2100),
                );
                if (pickedDate != null) {
                  setState(() {
                    firstSelectedDate = pickedDate;
                  });
                  firstDateData =
                      await _fetchHistoricalData(firstSelectedDate, hardwareId);
                  setState(() {});
                }
              },
            ),

            // Second Date Picker (Optional)
            ListTile(
              leading: const Icon(Icons.calendar_today, color: Colors.orange),
              title: const Text("Select Second Date",
                  style: TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text(
                hasSecondDate
                    ? DateFormat.yMMMMd().format(secondSelectedDate)
                    : "Comparing with Today",
                style: TextStyle(color: Colors.grey[600]),
              ),
              trailing: const Icon(Icons.arrow_forward_ios, size: 18),
              onTap: () async {
                DateTime? pickedDate = await showDatePicker(
                  context: context,
                  initialDate: secondSelectedDate,
                  firstDate: DateTime(2000),
                  lastDate: DateTime(2100),
                );
                if (pickedDate != null) {
                  setState(() {
                    secondSelectedDate = pickedDate;
                    hasSecondDate = true;
                  });
                  secondDateData = await _fetchHistoricalData(
                      secondSelectedDate, hardwareId);
                  setState(() {});
                }
              },
            ),

            const SizedBox(height: 20),
            Expanded(
              child: SingleChildScrollView(
                child: _buildAnalyticsComparisonView(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAnalyticsComparisonView() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          "Data Insights",
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 10),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
                child: _buildDataColumn(
                    "Data from ${DateFormat.yMd().format(firstSelectedDate)}",
                    firstDateData,
                    Colors.blueAccent)),
            Expanded(
                child: _buildDataColumn(
                    "Data from ${DateFormat.yMd().format(secondSelectedDate)}",
                    secondDateData,
                    Colors.orange)),
          ],
        ),
      ],
    );
  }

  Widget _buildDataColumn(String title, Map<String, String> data, Color color) {
    return Card(
      margin: const EdgeInsets.all(8),
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: TextStyle(
                    fontSize: 16, fontWeight: FontWeight.bold, color: color)),
            const Divider(),
            ...data.entries.map((entry) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(entry.key,
                            style: const TextStyle(
                                fontSize: 14, fontWeight: FontWeight.w500)),
                      ),
                      Expanded(
                        child: Text(entry.value,
                            textAlign: TextAlign.right,
                            style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: color)),
                      ),
                    ],
                  ),
                )),
          ],
        ),
      ),
    );
  }
}
