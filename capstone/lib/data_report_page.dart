import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'shared_prefs_helper.dart';
import 'package:fl_chart/fl_chart.dart';

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
  Map<String, List<dynamic>> frequencyAnalysisData = {};

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
    frequencyAnalysisData = await _fetchFrequencyAnalysis(hardwareId!) ?? {}; // ✅ Fetch data for the graph

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
Widget _buildDataCard(String title, Map<String, String> data, bool isFirstDate) {
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
                  Text(
                    entry.value,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: isFirstDate ? Colors.blue : Colors.green, // ✅ Dynamic Color Matching Graph
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    ),
  );
}

String selectedFilter = "Daily"; // Default filter


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

    Future<Map<String, List<Map<String, dynamic>>>> _fetchFrequencyAnalysis(int hardwareId) async {
  print("🔍 Fetching frequency analysis data for hardware_id: $hardwareId with filter: $selectedFilter");

  try {
    DateTime now = DateTime.now();
    String startDate, endDate;

    // ✅ Apply time range filter (Daily or Weekly)
    if (selectedFilter == "Daily") {
      startDate = DateFormat('yyyy-MM-dd').format(now) + " 00:00:00";
      endDate = DateFormat('yyyy-MM-dd').format(now) + " 23:59:59";
    } else if (selectedFilter == "Weekly") {
      DateTime weekAgo = now.subtract(const Duration(days: 7));
      startDate = DateFormat('yyyy-MM-dd').format(weekAgo) + " 00:00:00";
      endDate = DateFormat('yyyy-MM-dd').format(now) + " 23:59:59";
    } else {
      print("⚠️ Unknown filter type: $selectedFilter");
      return {};
    }

    // ✅ Fetch alerts within the selected time range
    final response = await Supabase.instance.client
        .from('Notifications_Test')
        .select('sensor_type, sensor_value, timestamp')
        .eq('hardware_id', hardwareId)
        .gte('timestamp', startDate)
        .lte('timestamp', endDate)
        .order('timestamp', ascending: true);

    if (response.isEmpty) {
      print("🚨 No notifications found for hardware_id: $hardwareId in the selected range");
      return {};
    }

    // ✅ Process and group notifications by sensor type
    Map<String, List<Map<String, dynamic>>> groupedData = {};
    for (var entry in response) {
      String sensor = entry['sensor_type'] ?? "Unknown Sensor";
      
      // ✅ Remove non-numeric characters (°C, %)
      String cleanValue = entry['sensor_value'].toString().replaceAll(RegExp('[^0-9.]'), '');
      double value = double.tryParse(cleanValue) ?? 0;

      // ✅ Filter out 0.0 values (only show alerts)
      if (value == 0) continue;

      // ✅ Format timestamp as "YYYY-MM-DD HH:MM AM/PM"
      String formattedTime = "Unknown";
      if (entry['timestamp'] != null) {
        try {
          formattedTime = DateFormat("yyyy-MM-dd hh:mm a").format(DateTime.parse(entry['timestamp'].toString()));
        } catch (e) {
          print("⚠️ Error parsing timestamp: ${entry['timestamp']} - $e");
        }
      }

      if (!groupedData.containsKey(sensor)) {
        groupedData[sensor] = [];
      }

      groupedData[sensor]!.add({"Value": value, "Time": formattedTime});
    }

    return groupedData;
  } catch (e) {
    print("❌ Error fetching notification data: $e");
    return {};
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

  Color _getSensorColor(String sensorType) {
  switch (sensorType.toLowerCase()) {
    case "temperature":
      return Colors.red;
    case "moisture":
      return Colors.blue;
    case "ph_level": // ✅ Match database name
      return Colors.green;
    case "ph_level2": // ✅ Match database name
      return Colors.orange;
    case "humidity":
      return Colors.purple;
    default:
      return Colors.grey; // Default color for unknown sensors
  }
}



  Widget _buildComparisonGraph() {
  if (firstDateData.isEmpty || secondDateData.isEmpty) {
    return const Center(child: Text("Select two dates to compare data."));
  }

  List<String> labels = ["Temperature", "Moisture Level", "pH Level 1", "pH Level 2", "Humidity"];
  List<double> firstValues = labels.map((label) {
    return double.tryParse(firstDateData[label]?.replaceAll(RegExp('[^0-9.]'), '') ?? "0") ?? 0;
  }).toList();

  List<double> secondValues = labels.map((label) {
    return double.tryParse(secondDateData[label]?.replaceAll(RegExp('[^0-9.]'), '') ?? "0") ?? 0;
  }).toList();

  return Column(
    children: [
      // ✅ Legend Row
      Wrap(
        spacing: 12,
        children: labels.map((sensor) {
          return Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(_getSensorIcon(sensor), size: 18, color: Colors.black),
              const SizedBox(width: 5),
              Text(sensor, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
            ],
          );
        }).toList(),
      ),

      const SizedBox(height: 13), // ✅ Adds spacing before the graph

      // ✅ The Graph
      SizedBox(
        height: 300,
        child: BarChart(
          BarChartData(
            barGroups: List.generate(labels.length, (index) {
              return BarChartGroupData(
                x: index, // ✅ Use index directly for positioning
                barRods: [
                  BarChartRodData(toY: firstValues[index], color: Colors.blue, width: 16),
                  BarChartRodData(toY: secondValues[index], color: Colors.green, width: 16),
                ],
              );
            }),
            titlesData: FlTitlesData(
              topTitles: AxisTitles(
                sideTitles: SideTitles(showTitles: false), // ✅ Hide numbers on top
              ),
              leftTitles: AxisTitles(
                sideTitles: SideTitles(showTitles: true, reservedSize: 40),
              ),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  getTitlesWidget: (value, _) {
                    return Icon(
                      _getSensorIcon(labels[value.toInt()]),
                      size: 24,
                      color: Colors.black54,
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    ],
  );
}




// Function to Map Sensor Type to Icons
IconData _getSensorIcon(String sensorType) {
  switch (sensorType.toLowerCase()) {
    case "temperature":
      return Icons.thermostat; // 🌡️ Temperature
    case "moisture level":
      return Icons.water_drop; // 💧 Moisture Level
    case "ph level 1":
    case "ph level 2":
      return Icons.science; // 🧪 pH Levels
    case "humidity":
      return Icons.cloud; // ☁️ Humidity
    default:
      return Icons.device_unknown; // ❓ Default Icon
  }
}

String _formatSensorValue(String sensorType, dynamic value) {
  double parsedValue = double.tryParse(value.toString()) ?? 0; // ✅ Ensure it's a number

  if (sensorType.toLowerCase() == "moisture" || sensorType.toLowerCase() == "humidity") {
    return "${parsedValue.round()}%"; // ✅ Round to whole number
  } else if (sensorType.toLowerCase() == "temperature") {
    return "${parsedValue.toStringAsFixed(1)}°C"; // ✅ Keep 1 decimal place
  }

  return value.toString(); // ✅ Keep pH values as-is
}

FlTitlesData _buildChartTitles(List<String> timestamps) {
  return FlTitlesData(
    topTitles: AxisTitles(
      sideTitles: SideTitles(showTitles: false), // ✅ Hide numbers at the top
    ),
    leftTitles: AxisTitles(
      sideTitles: SideTitles(showTitles: true, reservedSize: 40),
    ),
    bottomTitles: AxisTitles(
      sideTitles: SideTitles(
        showTitles: true,
        reservedSize: 60,
        getTitlesWidget: (value, meta) {
          int index = value.toInt();
          if (index >= 0 && index < timestamps.length) {
            String formattedTime = "Invalid Time";

            try {
              DateTime parsedTime;
              if (timestamps[index].contains("AM") || timestamps[index].contains("PM")) {
                parsedTime = DateFormat("yyyy-MM-dd hh:mm a").parse(timestamps[index]);
              } else {
                parsedTime = DateFormat("yyyy-MM-dd HH:mm:ss").parse(timestamps[index]);
              }

              // ✅ Show Day + Time for Weekly, Only Time for Daily
              formattedTime = (selectedFilter == "Weekly")
                  ? DateFormat("EEE hh:mm a").format(parsedTime) // Mon 08:00 AM
                  : DateFormat("hh:mm a").format(parsedTime); // 08:00 AM
            } catch (e) {
              print("⚠️ Error parsing timestamp: ${timestamps[index]} - $e");
            }

            // ✅ Adaptive Label Spacing
            bool showLabel = timestamps.length <= 4 || index % 2 == 0; // Show every other label if > 4

            return showLabel
                ? Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      formattedTime,
                      style: const TextStyle(fontSize: 10),
                      textAlign: TextAlign.center,
                    ),
                  )
                : const SizedBox.shrink(); // ✅ Hide label if skipping
          }
          return const Text("");
        },
      ),
    ),
  );
}




@override
Widget build(BuildContext context) {
  return Scaffold(
    backgroundColor: Colors.white,
    appBar: AppBar(
      title: const Text("Data Report", style: TextStyle(color: Colors.white)),
      backgroundColor: Colors.green[700],
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
      _buildDataCard("First Date Data", firstDateData, true),
      if (hasSecondDate) _buildDataCard("Second Date Data", secondDateData, false),
      const SizedBox(height: 16), // ✅ Adds spacing between _buildDataCard and _buildComparisonGraph
      if (hasSecondDate) _buildComparisonGraph(),

      const SizedBox(height: 12), // ✅ Adds spacing before the graph

      const Divider(thickness: 2, color: Colors.black26), // ✅ Adds a Visual Separator
      

      // ✅ Filter Dropdown for Daily/Weekly (AFTER Divider)
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text("Filter: ", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            DropdownButton<String>(
              value: selectedFilter,
              items: ["Daily", "Weekly"].map((String value) {
                return DropdownMenuItem<String>(
                  value: value,
                  child: Text(value, style: const TextStyle(fontSize: 16)),
                );
              }).toList(),
              onChanged: (newValue) async {
                if (newValue != null) {
                  setState(() {
                    selectedFilter = newValue;
                  });

                  // ✅ Fetch Updated Data Based on Filter
                  frequencyAnalysisData = await _fetchFrequencyAnalysis(hardwareId!);
                  setState(() {});
                }
              },
            ),
          ],
        ),
      ),
      
      // Build Frequency Analysis Card
       _buildFrequencyAnalysisCard(),

      const SizedBox(height: 16), // ✅ Adds spacing before the graph
      if (frequencyAnalysisData.isNotEmpty) _buildTimeBasedFrequencyGraph(),
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
          ...frequencyAnalysisData.entries.expand((entry) {
            String sensorType = entry.key;
            List<dynamic> sensorValues = entry.value
                .where((data) => (double.tryParse(data["Value"].toString()) ?? 0) > 0.0) // ✅ Filters out 0.0 values
                .toList();

            if (sensorValues.isEmpty) return []; // ✅ Skip empty categories

            return [
              Text(sensorType, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black)),
              ...sensorValues.map((data) {
                // ✅ Format timestamp properly
                String formattedTime = "Unknown Time";
                try {
                  DateTime parsedTime = DateFormat("yyyy-MM-dd hh:mm a").parse(data["Time"]); 
                  if (selectedFilter == "Weekly") {
                      formattedTime = DateFormat("EEE hh:mm a")
                          .format(parsedTime); // ✅ Show day (Mon, Tue, etc.)
                    } else {
                      formattedTime = DateFormat("hh:mm a")
                          .format(parsedTime); // ✅ Keep time-only for "Daily"
                    }
                } catch (e) {
                  print("⚠️ Error parsing timestamp: ${data["Time"]} - $e");
                }

                return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                            _formatSensorValue(sensorType,
                                data["Value"]), // ✅ Apply formatting
                            style: const TextStyle(
                                fontSize: 16, color: Colors.black54)),
                        Text(
                            data["Time"] ??
                                "Unknown Time", // ✅ Use pre-formatted string
                            style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.red)),
                      ],
                  ),
                );
              }).toList(),
            ];
          }).toList(),
        ],
      ),
    ),
  );
}



Widget _buildTimeBasedFrequencyGraph() {
  if (frequencyAnalysisData.isEmpty) {
    return const Center(child: Text("No alerts recorded to display."));
  }

  List<String> sensorTypes = frequencyAnalysisData.keys.toList();
  List<String> timestamps = [];

  // ✅ Collect unique timestamps for X-axis labels
  for (var sensor in sensorTypes) {
    for (var entry in frequencyAnalysisData[sensor] ?? []) {
      if (!timestamps.contains(entry["Time"])) {
        timestamps.add(entry["Time"]);
      }
    }
  }

  // ✅ If "Daily", show a single combined graph
  if (selectedFilter == "Daily") {
    return Column(
      children: [
        // ✅ Add the Legend Row
        Wrap(
          spacing: 10,
          children: sensorTypes.map((sensor) {
            return Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: _getSensorColor(sensor),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 5),
                Text(sensor, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              ],
            );
          }).toList(),
        ),

        const SizedBox(height: 12), // ✅ Adds spacing before the graph

        // ✅ The Combined Graph
        SizedBox(
          height: 300, // ✅ Fixed height for Daily
          child: BarChart(
            BarChartData(
  barGroups: List.generate(timestamps.length, (index) {
    String timeLabel = timestamps[index];

    List<BarChartRodData> bars = [];

    for (var sensor in sensorTypes) {
      var sensorData = frequencyAnalysisData[sensor]
              ?.where((data) => data["Time"] == timeLabel)
              .toList() ??
          [];
      if (sensorData.isNotEmpty) {
        double sensorValue = double.tryParse(sensorData.first["Value"].toString()) ?? 0;

        bars.add(
          BarChartRodData(
            toY: sensorValue,
            color: _getSensorColor(sensor),
            width: 16,
          ),
        );
      }
    }

    return BarChartGroupData(x: index, barRods: bars);
  }),

  // ✅ Enable Touch Interaction
  barTouchData: BarTouchData(
  touchTooltipData: BarTouchTooltipData(
    getTooltipItem: (group, groupIndex, rod, rodIndex) {
      String formattedTime = "Unknown Time";

      try {
        DateTime parsedTime;
        if (timestamps[groupIndex].contains("AM") || timestamps[groupIndex].contains("PM")) {
          parsedTime = DateFormat("yyyy-MM-dd hh:mm a").parse(timestamps[groupIndex]);
        } else {
          parsedTime = DateFormat("yyyy-MM-dd HH:mm:ss").parse(timestamps[groupIndex]);
        }

        // Show Day + Time for Weekly, Only Time for Daily
        formattedTime = (selectedFilter == "Weekly")
            ? DateFormat("EEE hh:mm a").format(parsedTime) // Example: Mon 08:00 AM
            : DateFormat("hh:mm a").format(parsedTime); // Example: 08:00 AM
      } catch (e) {
        print("Error parsing timestamp: ${timestamps[groupIndex]} - $e");
      }

      return BarTooltipItem(
        "Sensor Value: ${rod.toY}\nTime: $formattedTime", // Tooltip Format
        const TextStyle(color: Colors.white, fontSize: 12),
      );
    },
    getTooltipColor: (group) => Colors.black87, // Tooltip background color
    tooltipRoundedRadius: 8, // Rounded corners
    tooltipPadding: const EdgeInsets.all(8), // Padding inside tooltip
    tooltipMargin: 10, // Space between bars & tooltip
  ),
),


  titlesData: _buildChartTitles(timestamps), // ✅ Keep existing title formatting
),

          ),
        ),
      ],
    );
  }

  // ✅ If "Weekly", show separate graphs per sensor type
  return Column(
    children: sensorTypes.map((sensor) {
      List<String> sensorTimestamps = [];
      for (var entry in frequencyAnalysisData[sensor] ?? []) {
        if (!sensorTimestamps.contains(entry["Time"])) {
          sensorTimestamps.add(entry["Time"]);
        }
      }

      return Column(
        children: [
          const SizedBox(height: 16), // ✅ Adds spacing between graphs

          // ✅ Sensor Title (Legend for Each Graph)
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: _getSensorColor(sensor),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 5),
              Text(sensor, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
            ],
          ),

          const SizedBox(height: 10),

          // ✅ The Separate Graph for this Sensor
          SizedBox(
            height: 300, // ✅ Consistent height per graph
            child: BarChart(
              BarChartData(
  barGroups: List.generate(timestamps.length, (index) {
    String timeLabel = timestamps[index];

    List<BarChartRodData> bars = [];

    for (var sensor in sensorTypes) {
      var sensorData = frequencyAnalysisData[sensor]
              ?.where((data) => data["Time"] == timeLabel)
              .toList() ??
          [];
      if (sensorData.isNotEmpty) {
        double sensorValue = double.tryParse(sensorData.first["Value"].toString()) ?? 0;

        bars.add(
          BarChartRodData(
            toY: sensorValue,
            color: _getSensorColor(sensor),
            width: 16,
          ),
        );
      }
    }

    return BarChartGroupData(x: index, barRods: bars);
  }),

  // ✅ Enable Touch Interaction
  barTouchData: BarTouchData(
  touchTooltipData: BarTouchTooltipData(
    getTooltipItem: (group, groupIndex, rod, rodIndex) {
      String formattedTime = "Unknown Time";

      try {
        DateTime parsedTime;
        if (timestamps[groupIndex].contains("AM") || timestamps[groupIndex].contains("PM")) {
          parsedTime = DateFormat("yyyy-MM-dd hh:mm a").parse(timestamps[groupIndex]);
        } else {
          parsedTime = DateFormat("yyyy-MM-dd HH:mm:ss").parse(timestamps[groupIndex]);
        }

        // Show Day + Time for Weekly, Only Time for Daily
        formattedTime = (selectedFilter == "Weekly")
            ? DateFormat("EEE hh:mm a").format(parsedTime) // Example: Mon 08:00 AM
            : DateFormat("hh:mm a").format(parsedTime); // Example: 08:00 AM
      } catch (e) {
        print("Error parsing timestamp: ${timestamps[groupIndex]} - $e");
      }

      return BarTooltipItem(
        "Sensor Value: ${rod.toY}\nTime: $formattedTime", // Tooltip Format
        const TextStyle(color: Colors.white, fontSize: 12),
      );
    },
    getTooltipColor: (group) => Colors.black87, // Tooltip background color
    tooltipRoundedRadius: 8, // Rounded corners
    tooltipPadding: const EdgeInsets.all(8), // Padding inside tooltip
    tooltipMargin: 10, // Space between bars & tooltip
  ),
),


  titlesData: _buildChartTitles(timestamps), // ✅ Keep existing title formatting
),

            ),
          ),
        ],
      );
    }).toList(),
  );
}



}