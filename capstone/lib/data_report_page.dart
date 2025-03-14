import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'shared_prefs_helper.dart';
import 'package:fl_chart/fl_chart.dart';
import 'dart:io';
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'dart:ui' as ui;
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart'; // ✅ Fixes rootBundle issue
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;


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
  bool isExportingPDF = false;

  String comparisonSummary = "";
  String frequencySummary = "";

  final GlobalKey comparisonGraphKey = GlobalKey();
final GlobalKey frequencyGraphKey = GlobalKey();


  final GlobalKey<_ComparisonGraphWidgetState> comparisonGraphWidgetKey = GlobalKey<_ComparisonGraphWidgetState>();
 final GlobalKey<_FrequencyGraphWidgetState> frequencyGraphWidgetKey = GlobalKey<_FrequencyGraphWidgetState>();


  @override
  void initState() {
    super.initState();

    firstSelectedDate = DateTime.now().subtract(const Duration(days: 1)); // ✅ Default to Yesterday
  secondSelectedDate = DateTime.now().subtract(const Duration(days: 2)); // ✅ Default to 2 days ago


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
    secondDateData = await _fetchHistoricalData(secondSelectedDate, hardwareId!); // ✅ Fetch second date data
    frequencyAnalysisData = await _fetchFrequencyAnalysis(hardwareId!) ??
        {}; // ✅ Fetch data for the graph

    setState(() {
      print("🔄 UI Updated with fetched data for User: $storedEmail");
    });
  }

  

  // Date Picker Tile Widget
  Widget _buildDatePickerTile(
    String title,
    DateTime selectedDate,
    Function(DateTime?) onDatePicked,
  ) {
    return ListTile(
      title: Text(
        title,
        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
      ),
      subtitle: Text(
        DateFormat('yyyy-MM-dd').format(selectedDate),
        style: const TextStyle(fontSize: 16),
      ),
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
          Text(
            title,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
          ),
          const Divider(color: Colors.black45),
          ...data.entries.map((entry) {
            String formattedValue = _formatSensorValue(entry.key, entry.value); // ✅ Format the value
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    entry.key,
                    style: const TextStyle(
                      fontSize: 16,
                      color: Colors.black54,
                    ),
                  ),
                  Text(
                    formattedValue, // ✅ Use formatted value
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: isFirstDate ? Colors.blue : Colors.green, 
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

// Helper function to format sensor values in Data Card
String _formatSensorValue(String sensor, dynamic value) {
  double? parsedValue;

  // ✅ If value is already a double, use it directly
  if (value is double) {
    parsedValue = value;
  } else if (value is String) {
    parsedValue = double.tryParse(value.replaceAll("°C", "").replaceAll("%", ""));
  }

  if (parsedValue == null) return value.toString(); // Return original value if parsing fails

  switch (sensor.toLowerCase()) {
    case "temperature":
      return "${parsedValue.toStringAsFixed(1)}°C"; // 1 decimal place
    case "dryness level":
      return "${parsedValue.toInt()}%"; // Whole number
    case "ph level 1":
    case "ph level 2":
      return parsedValue.toStringAsFixed(2); // 2 decimal places
    case "humidity":
      return "${parsedValue.toInt()}%"; // Whole number
    default:
      return value.toString(); // Fallback case
  }
}



  String selectedFilter = "Daily"; // Default filter

  Future<Map<String, String>> _fetchHistoricalData(
    DateTime date,
    int hardwareId,
  ) async {
    
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
      print("🟢 API Response: $response");

      return _defaultData("N/A");
    }

    Map<String, String> parsedData = {
      "Temperature": "${response['temperature'] ?? 'N/A'}°C",
      "Dryness Level": "${response['moisture'] ?? 'N/A'}%",
      "pH Level 1": "${response['ph_level1'] ?? 'N/A'}",
      "pH Level 2": "${response['ph_level2'] ?? 'N/A'}",
      "Humidity": "${response['humidity'] ?? 'N/A'}%",
    };

    print("✅ Parsed Data for $date: $parsedData");
    return parsedData;
  } catch (e) {
    print("❌ Error fetching historical data: $e");
    return _defaultData("Error");
  }
}


  Future<Map<String, List<Map<String, dynamic>>>> _fetchFrequencyAnalysis(
    int hardwareId,
  ) async {
    print(
      "🔍 Fetching frequency analysis data for hardware_id: $hardwareId with filter: $selectedFilter",
    );

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
        if (kDebugMode) {
          print("🟢 Frequency Data Response: $response");
        }
        if (kDebugMode) {
          print("🟢 API Response from Supabase: $response");
        }

        if (kDebugMode) {
          print(
          "🚨 No notifications found for hardware_id: $hardwareId in the selected range",
        );
        }
        return {};
      }

      // ✅ Process and group notifications by sensor type
      Map<String, List<Map<String, dynamic>>> groupedData = {};
      for (var entry in response) {
        String sensor = entry['sensor_type'] ?? "Unknown Sensor";

        // ✅ Remove non-numeric characters (°C, %)
        String cleanValue = entry['sensor_value'].toString().replaceAll(
          RegExp('[^0-9.]'),
          '',
        );
        double value = double.tryParse(cleanValue) ?? 0;

        // ✅ Filter out 0.0 values (only show alerts)
        if (value == 0) continue;

        // ✅ Format timestamp as "YYYY-MM-DD HH:MM AM/PM"
        String formattedTime = "Unknown";
        if (entry['timestamp'] != null) {
          try {
            formattedTime = DateFormat(
              "yyyy-MM-dd hh:mm a",
            ).format(DateTime.parse(entry['timestamp'].toString()));
          } catch (e) {
            if (kDebugMode) {
              print("⚠️ Error parsing timestamp: ${entry['timestamp']} - $e");
            }
          }
        }

        if (!groupedData.containsKey(sensor)) {
          groupedData[sensor] = [];
        }

        groupedData[sensor]!.add({"Value": value, "Time": formattedTime});
      }

      return groupedData;
    } catch (e) {
      if (kDebugMode) {
        print("❌ Error fetching notification data: $e");
      }
      return {};
    }
  }

  Map<String, String> _defaultData(String message) {
    return {
      "Temperature": message,
      "Dryness Level": message,
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
    print("🟢 _buildComparisonGraph() is rebuilding. comparisonGraphKey exists: ${comparisonGraphKey.currentContext != null}");

if (firstDateData.isEmpty || secondDateData.isEmpty) {
   return const SizedBox(height: 300); // ✅ Maintain layout
}

  List<String> labels = [

    "Temperature",
    "Moisture Level",
    "pH Level 1",
    "pH Level 2",
    "Humidity",
  ];

  List<double> firstValues = labels.map((label) {
  String rawValue = firstDateData[label]?.toString() ?? "0"; // ✅ Ensure it's a String
  return double.tryParse(rawValue) ?? 0; // ✅ Convert String to double safely
}).toList();

List<double> secondValues = labels.map((label) {
  String rawValue = secondDateData[label]?.toString() ?? "0"; // ✅ Ensure it's a String
  return double.tryParse(rawValue) ?? 0; // ✅ Convert String to double safely
}).toList();



  return Column(
    children: [
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
      const SizedBox(height: 13),
      
      SizedBox(
        height: 300,
        child: BarChart(
          BarChartData(
            barGroups: List.generate(labels.length, (index) {
              return BarChartGroupData(
                x: index,
                barRods: [
                  BarChartRodData(
                    toY: firstValues[index],
                    color: firstDateData.isNotEmpty ? Colors.blue : Colors.grey.withOpacity(0.3),
                    width: 16,
                  ),
                  BarChartRodData(
                    toY: secondValues[index],
                    color: secondDateData.isNotEmpty ? Colors.green : Colors.grey.withOpacity(0.3),
                    width: 16,
                  ),
                ],
              );
            }),
            titlesData: FlTitlesData(
              topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
              leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 40)),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  getTitlesWidget: (value, _) {
                    return Icon(_getSensorIcon(labels[value.toInt()]), size: 24, color: Colors.black54);
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
      case "dryness level":
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

  // String _formatSensorValue(String sensorType, dynamic value) {
  //   double parsedValue =
  //       double.tryParse(value.toString()) ?? 0; // ✅ Ensure it's a number

  //   if (sensorType.toLowerCase() == "moisture" ||
  //       sensorType.toLowerCase() == "humidity") {
  //     return "${parsedValue.round()}%"; // ✅ Round to whole number
  //   } else if (sensorType.toLowerCase() == "temperature") {
  //     return "${parsedValue.toStringAsFixed(1)}°C"; // ✅ Keep 1 decimal place
  //   }

  //   return value.toString(); // ✅ Keep pH values as-is
  // }

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
                if (timestamps[index].contains("AM") ||
                    timestamps[index].contains("PM")) {
                  parsedTime = DateFormat(
                    "yyyy-MM-dd hh:mm a",
                  ).parse(timestamps[index]);
                } else {
                  parsedTime = DateFormat(
                    "yyyy-MM-dd HH:mm:ss",
                  ).parse(timestamps[index]);
                }

                // ✅ Show Day + Time for Weekly, Only Time for Daily
                formattedTime =
                    (selectedFilter == "Weekly")
                        ? DateFormat("EEE hh:mm a").format(
                          parsedTime,
                        ) // Mon 08:00 AM
                        : DateFormat("hh:mm a").format(parsedTime); // 08:00 AM
              } catch (e) {
                if (kDebugMode) {
                  print("⚠️ Error parsing timestamp: ${timestamps[index]} - $e");
                }
              }

              // ✅ Adaptive Label Spacing
              bool showLabel =
                  timestamps.length <= 4 ||
                  index % 2 == 0; // Show every other label if > 4

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



 Future<void> _exportToPDF() async {
  setState(() {
    isExportingPDF = true; // 🔄 Show Loading Indicator
  });

    // ✅ Delete old PDFs before generating a new one
  final output = await getTemporaryDirectory();
  final List<FileSystemEntity> files = output.listSync();

  for (var file in files) {
    if (file is File && file.path.contains("data_report_")) {
      try {
        await file.delete(); // 🚨 Delete previous PDFs
        if (kDebugMode) print("🗑️ Deleted old PDF: ${file.path}");
      } catch (e) {
        if (kDebugMode) print("⚠️ Error deleting old PDF: $e");
      }
    }
  }

  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (context) {
      return AlertDialog(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text("Generating PDF, please wait..."),
          ],
        ),
      );
    },
  );

  try {
    if (kDebugMode) {
      print("📄 Exporting PDF...");
    }

    await Future.delayed(const Duration(milliseconds: 1000)); // Ensure UI updates

    // 📂 Load Fonts
    final regularFont = pw.Font.ttf(await rootBundle.load("assets/fonts/Roboto-Regular.ttf"));
    final blackFont = pw.Font.ttf(await rootBundle.load("assets/fonts/Roboto-Black.ttf"));
    final boldFont = pw.Font.ttf(await rootBundle.load("assets/fonts/Roboto-Bold.ttf"));
    final lightFont = pw.Font.ttf(await rootBundle.load("assets/fonts/Roboto-Light.ttf"));
    final italicFont = pw.Font.ttf(await rootBundle.load("assets/fonts/Roboto-Italic.ttf"));

    final generatedDate = DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now());

    // ✅ Ensure summaries are generated
    if (comparisonSummary.trim().isEmpty) {
      if (kDebugMode) {
        print("❌ No data for comparisonSummary! Regenerating...");
      }
      _generateComparisonSummary();
    }

    if (frequencySummary.trim().isEmpty) {
      if (kDebugMode) {
        print("❌ No data for frequencySummary! Regenerating...");
        print("🔍 selectedFilter before generating: $selectedFilter"); // ✅ Debugging
      }
      _generateFrequencySummary();
    }

    // ✅ Format dates correctly
    String firstDateFormatted = DateFormat('yyyy-MM-dd').format(firstSelectedDate);
    String secondDateFormatted = DateFormat('yyyy-MM-dd').format(secondSelectedDate);

    comparisonSummary = comparisonSummary
        .replaceAll(firstSelectedDate.toString(), firstDateFormatted)
        .replaceAll(secondSelectedDate.toString(), secondDateFormatted);

    final pdf = pw.Document();

    /// ✅ Page 1: Title Page
    pdf.addPage(
      pw.Page(
        build: (pw.Context context) => pw.Center(
          child: pw.Column(
            mainAxisAlignment: pw.MainAxisAlignment.center,
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              pw.Text("DATA REPORT SUMMARY", style: pw.TextStyle(fontSize: 32, font: blackFont, letterSpacing: 1.5)),
              pw.SizedBox(height: 16),
              pw.Text("Generated on $generatedDate", style: pw.TextStyle(font: italicFont, fontSize: 12, color: PdfColors.grey)),
              pw.SizedBox(height: 24),
              pw.Text("Confidential Document", style: pw.TextStyle(font: lightFont, fontSize: 10, color: PdfColors.grey500)),
            ],
          ),
        ),
      ),
    );

    /// ✅ Helper for Bullet Points with Bold Formatting for Frequency Summary
   pw.Widget _buildBulletPoints(String summary) {
  List<String> lines = summary.split("\n").where((line) => line.isNotEmpty).toList();

  return pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: lines.map((line) {
      pw.Widget bulletPoint;

      // ✅ Remove ** formatting completely before parsing
      String cleanLine = line.replaceAll("**", "");

      // ✅ Detect "Daily" format
      final dailyMatch = RegExp(r"The highest recorded value today for (.+?) was at (.+?) with a value of (.+?)\.").firstMatch(cleanLine);

      // ✅ Detect "Weekly" format
      final weeklyMatch = RegExp(r"The highest recorded (.+?) this week was (.+?) at (.+?)\.").firstMatch(cleanLine);

      if (dailyMatch != null) {
        final sensorType = dailyMatch.group(1)!;
        final timestamp = dailyMatch.group(2)!;
        final value = dailyMatch.group(3)!;

        bulletPoint = pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text("• ", style: pw.TextStyle(font: boldFont, fontSize: 17)),
            pw.Expanded(
              child: pw.RichText(
                text: pw.TextSpan(
                  style: pw.TextStyle(font: regularFont, fontSize: 16),
                  children: [
                    const pw.TextSpan(text: "The highest recorded value today for "),
                    pw.TextSpan(text: sensorType, style: pw.TextStyle(font: boldFont)), 
                    const pw.TextSpan(text: " was at "),
                    pw.TextSpan(text: timestamp, style: pw.TextStyle(font: boldFont)),
                    const pw.TextSpan(text: " with a value of "),
                    pw.TextSpan(text: value, style: pw.TextStyle(font: boldFont)),
                    const pw.TextSpan(text: "."),
                  ],
                ),
              ),
            ),
          ],
        );
      } 
      else if (weeklyMatch != null) {
        final sensorType = weeklyMatch.group(1)!;
        final value = weeklyMatch.group(2)!;
        final timestamp = weeklyMatch.group(3)!;

        bulletPoint = pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text("• ", style: pw.TextStyle(font: boldFont, fontSize: 17)),
            pw.Expanded(
              child: pw.RichText(
                text: pw.TextSpan(
                  style: pw.TextStyle(font: regularFont, fontSize: 16),
                  children: [
                    const pw.TextSpan(text: "The highest recorded "),
                    pw.TextSpan(text: sensorType, style: pw.TextStyle(font: boldFont)), 
                    const pw.TextSpan(text: " this week was "),
                    pw.TextSpan(text: value, style: pw.TextStyle(font: boldFont)),
                    const pw.TextSpan(text: " at "),
                    pw.TextSpan(text: timestamp, style: pw.TextStyle(font: boldFont)),
                    const pw.TextSpan(text: "."),
                  ],
                ),
              ),
            ),
          ],
        );
      } 
      else {
        bulletPoint = pw.Text(cleanLine, style: pw.TextStyle(font: regularFont, fontSize: 16));
      }

      // ✅ Add spacing after each bullet point
      return pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          bulletPoint,
          pw.SizedBox(height: 10), // Adjust for more or less spacing
        ],
      );
    }).toList(),
  );
}



    /// ✅ Helper for Comparison Summary with Rich Formatting
    pw.Widget _buildComparisonBulletPoints(String summary) {
  List<String> lines = summary.split("\n").where((line) => line.isNotEmpty).toList();

  return pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: lines.map((line) {
      final match = RegExp(r"• (.+?) on (.+?) \((.+?)\) was higher than (.+?) \((.+?)\) by (.+?)\.").firstMatch(line) ??
          RegExp(r"• (.+?) was the same on both dates \((.+?): (.+?), (.+?): (.+?)\)\.").firstMatch(line);

      pw.Widget bulletPoint;

      if (match != null && match.groupCount == 6) {
        bulletPoint = pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text("• ", style: pw.TextStyle(font: boldFont, fontSize: 17)),
            pw.Expanded(
              child: pw.RichText(
                text: pw.TextSpan(
                  style: pw.TextStyle(font: regularFont, fontSize: 16),
                  children: [
                    pw.TextSpan(text: match.group(1)!, style: pw.TextStyle(font: boldFont)),
                    const pw.TextSpan(text: " on "),
                    pw.TextSpan(text: match.group(2)!, style: pw.TextStyle(font: italicFont)),
                    const pw.TextSpan(text: " ("),
                    pw.TextSpan(text: match.group(3)!, style: pw.TextStyle(font: boldFont)),
                    const pw.TextSpan(text: ") was higher than "),
                    pw.TextSpan(text: match.group(4)!, style: pw.TextStyle(font: italicFont)),
                    const pw.TextSpan(text: " ("),
                    pw.TextSpan(text: match.group(5)!, style: pw.TextStyle(font: boldFont)),
                    const pw.TextSpan(text: ") by "),
                    pw.TextSpan(text: match.group(6)!, style: pw.TextStyle(font: boldFont)),
                    const pw.TextSpan(text: "."),
                  ],
                ),
              ),
            ),
          ],
        );
      } else if (match != null && match.groupCount == 5) {
        bulletPoint = pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text("• ", style: pw.TextStyle(font: boldFont, fontSize: 17)),
            pw.Expanded(
              child: pw.RichText(
                text: pw.TextSpan(
                  style: pw.TextStyle(font: regularFont, fontSize: 16),
                  children: [
                    pw.TextSpan(text: match.group(1)!, style: pw.TextStyle(font: boldFont)),
                    const pw.TextSpan(text: " was the same on both dates ("),
                    pw.TextSpan(text: match.group(2)!, style: pw.TextStyle(font: italicFont)),
                    const pw.TextSpan(text: ": "),
                    pw.TextSpan(text: match.group(3)!, style: pw.TextStyle(font: boldFont)),
                    const pw.TextSpan(text: ", "),
                    pw.TextSpan(text: match.group(4)!, style: pw.TextStyle(font: italicFont)),
                    const pw.TextSpan(text: ": "),
                    pw.TextSpan(text: match.group(5)!, style: pw.TextStyle(font: boldFont)),
                    const pw.TextSpan(text: ")."),
                  ],
                ),
              ),
            ),
          ],
        );
      } else {
        bulletPoint = pw.Text(line, style: pw.TextStyle(font: regularFont, fontSize: 16));
      }

      // Add spacing after each bullet
      return pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          bulletPoint,
          pw.SizedBox(height: 10), // Adjust this for more or less spacing
        ],
      );
    }).toList(),
  );
}


     /// ✅ Page 2: Data Comparison Summary
    if (comparisonSummary.trim().isNotEmpty) {
      pdf.addPage(
        pw.Page(
          build: (pw.Context context) => pw.Padding(
            padding: const pw.EdgeInsets.all(24),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text("Data Comparison Summary", style: pw.TextStyle(fontSize: 24, font: boldFont, color: PdfColors.blue900)),
                pw.SizedBox(height: 12),
                pw.Divider(),
                pw.SizedBox(height: 12),
                _buildComparisonBulletPoints(comparisonSummary),
              ],
            ),
          ),
        ),
      );
    }

    /// ✅ Page 3: Time-Based Frequency Summary
    if (frequencySummary.trim().isNotEmpty) {
      pdf.addPage(
        pw.Page(
          build: (pw.Context context) => pw.Padding(
            padding: const pw.EdgeInsets.all(24),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text("Time-Based Frequency Summary", style: pw.TextStyle(fontSize: 24, font: boldFont, color: PdfColors.blue900)),
                pw.SizedBox(height: 12),
                pw.Divider(),
                pw.SizedBox(height: 12),
                _buildBulletPoints(frequencySummary),
              ],
            ),
          ),
        ),
      );
    }

    // ✅ Capture Graphs
    List<Uint8List> images = await _captureGraphsAsImages();

    // ✅ Page 4: Comparison Graph
    if (images.isNotEmpty) {
      pdf.addPage(
        pw.Page(
          build: (pw.Context context) => pw.Center(
            child: pw.Column(
              children: [
                pw.Text("Comparison Graph", style: pw.TextStyle(fontSize: 20, font: boldFont)),
                pw.SizedBox(height: 10),
                pw.Image(pw.MemoryImage(images[0]), width: 400, height: 300),
              ],
            ),
          ),
        ),
      );
    }
List<Uint8List> imagesfrequency = await _captureGraphsAsImages();
    // ✅ Page 5: Frequency Graph
    if (imagesfrequency.length > 1) {
      pdf.addPage(
        pw.Page(
          build: (pw.Context context) => pw.Center(
            child: pw.Column(
              children: [
                pw.Text("Frequency Graph", style: pw.TextStyle(fontSize: 20, font: boldFont)),
                pw.SizedBox(height: 10),
                pw.Image(pw.MemoryImage(imagesfrequency[1]), width: 400, height: 300),
              ],
            ),
          ),
        ),
      );
    }

    // ✅ Save and Open the PDF
    final output = await getTemporaryDirectory();
final String timestamp = DateTime.now().millisecondsSinceEpoch.toString();
final file = File("${output.path}/data_report_$timestamp.pdf"); // Unique filename
await file.writeAsBytes(await pdf.save());

    print("✅ PDF Saved at: ${file.path}");
    await Printing.layoutPdf(onLayout: (PdfPageFormat format) async => pdf.save());

  } finally {
    setState(() {
      isExportingPDF = false;
    });
    Navigator.of(context).pop();
  }
}




//////////////////////////////////////////////////////////////////////////////////////////

// ✅ Helper Functions to Recalculate Summaries
void _generateComparisonSummary() {
  comparisonSummary = ""; // Clear old data
  if (firstDateData.isNotEmpty && secondDateData.isNotEmpty) {
    List<String> labels = ["Temperature", "Dryness Level", "pH Level 1", "pH Level 2", "Humidity"];
    
    for (String label in labels) {
      double firstValue = double.tryParse(firstDateData[label]?.replaceAll(RegExp('[^0-9.]'), '') ?? "0") ?? 0;
      double secondValue = double.tryParse(secondDateData[label]?.replaceAll(RegExp('[^0-9.]'), '') ?? "0") ?? 0;

      //   // ✅ Format Dates Correctly (Removes Time)
      // String firstDateFormatted = DateFormat('yyyy-MM-dd').format(firstSelectedDate);
      // String secondDateFormatted = DateFormat('yyyy-MM-dd').format(secondSelectedDate);

      if (firstValue > secondValue) {
        double diff = (firstValue - secondValue);
        comparisonSummary += "• $label on $firstSelectedDate (${firstValue.toStringAsFixed(2)}) was higher than $secondSelectedDate (${secondValue.toStringAsFixed(2)}) by ${diff.toStringAsFixed(2)}.\n\n";
      } else if (firstValue < secondValue) {
        double diff = (secondValue - firstValue);
        comparisonSummary += "• $label on $secondSelectedDate (${secondValue.toStringAsFixed(2)}) was higher than $firstSelectedDate (${firstValue.toStringAsFixed(2)}) by ${diff.toStringAsFixed(2)}.\n\n";
      } else {
        comparisonSummary += "• $label was the same on both dates ($firstSelectedDate: ${firstValue.toStringAsFixed(2)}, $secondSelectedDate: ${secondValue.toStringAsFixed(2)}).\n\n";
      }
    }
  }
}

void _generateFrequencySummary() {
  if (kDebugMode) {
    print("🔄 Regenerating Frequency Summary...");
  }
  frequencySummary = ""; // ✅ Clear old data

  if (kDebugMode) {
    print("🔍 selectedFilter: $selectedFilter");
  } 

  if (frequencyAnalysisData.isNotEmpty) {
    List<String> summaries = [];

    frequencyAnalysisData.forEach((sensorType, sensorData) {
      String displaySensorType = sensorType == "moisture" ? "Dryness" : sensorType; // ✅ Change Moisture to Dryness

      if (sensorData.isNotEmpty) {
        if (selectedFilter == "Weekly") {
          double highestWeeklyValue = 0, lowestWeeklyValue = double.infinity;
          String highestWeeklyTimestamp = "", lowestWeeklyTimestamp = "";

          for (var entry in sensorData) {
            double sensorValue = double.tryParse(entry["Value"].toString()) ?? 0;
            
            // ✅ Check for highest
            if (sensorValue > highestWeeklyValue) {
              highestWeeklyValue = sensorValue;
              highestWeeklyTimestamp = entry["Time"];
            }

            // ✅ Check for lowest
            if (sensorValue < lowestWeeklyValue) {
              lowestWeeklyValue = sensorValue;
              lowestWeeklyTimestamp = entry["Time"];
            }
          }

          // ✅ Format timestamps correctly for Weekly mode
          String highestFormattedTimestamp = "Unknown Time";
          String lowestFormattedTimestamp = "Unknown Time";
          
          try {
            DateTime parsedTime = DateFormat("yyyy-MM-dd hh:mm a").parse(highestWeeklyTimestamp);
            highestFormattedTimestamp = DateFormat("EEE, yyyy-MM-dd hh:mm a").format(parsedTime);
          } catch (e) {
            if (kDebugMode) {
              print("⚠️ Error parsing highest timestamp: $highestWeeklyTimestamp - $e");
            }
          }

          try {
            DateTime parsedTime = DateFormat("yyyy-MM-dd hh:mm a").parse(lowestWeeklyTimestamp);
            lowestFormattedTimestamp = DateFormat("EEE, yyyy-MM-dd hh:mm a").format(parsedTime);
          } catch (e) {
            if (kDebugMode) {
              print("⚠️ Error parsing lowest timestamp: $lowestWeeklyTimestamp - $e");
            }
          }

          // ✅ Apply proper units
          String highestFormattedValue = _formatSensorValue(displaySensorType, highestWeeklyValue);
          String lowestFormattedValue = _formatSensorValue(displaySensorType, lowestWeeklyValue);

          // ✅ Improved Weekly Formatting
          summaries.add(
            "• The **$displaySensorType** was **highest** at **$highestFormattedTimestamp** with a value of **$highestFormattedValue**, "
            "while it was **lowest** at **$lowestFormattedTimestamp** with a value of **$lowestFormattedValue** this week."
          );

        } else { // ✅ Daily Mode
          var highestRecord = (sensorData as List<Map<String, dynamic>>).reduce(
            (a, b) => (double.tryParse(a["Value"].toString()) ?? 0) >
                       (double.tryParse(b["Value"].toString()) ?? 0) ? a : b,
          );

          var lowestRecord = (sensorData as List<Map<String, dynamic>>).reduce(
            (a, b) => (double.tryParse(a["Value"].toString()) ?? double.infinity) <
                       (double.tryParse(b["Value"].toString()) ?? double.infinity) ? a : b,
          );

          double highestValue = double.tryParse(highestRecord["Value"].toString()) ?? 0;
          double lowestValue = double.tryParse(lowestRecord["Value"].toString()) ?? 0;

          String highestRawTimestamp = highestRecord["Time"];
          String lowestRawTimestamp = lowestRecord["Time"];

          String highestFormattedTimestamp = "Unknown Time";
          String lowestFormattedTimestamp = "Unknown Time";

          try {
            DateTime parsedTime = DateFormat("yyyy-MM-dd hh:mm a").parse(highestRawTimestamp);
            highestFormattedTimestamp = DateFormat("hh:mm a").format(parsedTime);
          } catch (e) {
            if (kDebugMode) {
              print("⚠️ Error parsing highest timestamp: $highestRawTimestamp - $e");
            }
          }

          try {
            DateTime parsedTime = DateFormat("yyyy-MM-dd hh:mm a").parse(lowestRawTimestamp);
            lowestFormattedTimestamp = DateFormat("hh:mm a").format(parsedTime);
          } catch (e) {
            if (kDebugMode) {
              print("⚠️ Error parsing lowest timestamp: $lowestRawTimestamp - $e");
            }
          }

          // ✅ Apply proper units
          String highestFormattedValue = _formatSensorValue(displaySensorType, highestValue);
          String lowestFormattedValue = _formatSensorValue(displaySensorType, lowestValue);

          // ✅ Improved Daily Formatting
          summaries.add(
            "• The **$displaySensorType** was **highest** at **$highestFormattedTimestamp** with a value of **$highestFormattedValue**, "
            "while it was **lowest** at **$lowestFormattedTimestamp** with a value of **$lowestFormattedValue** today."
          );
        }
      }
    });

    // ✅ Combine summaries for all sensor types
    frequencySummary = summaries.join("\n\n"); 
  }

  if (kDebugMode) {
    print("📌 Final frequencySummary: $frequencySummary");
  }
}


// ✅ Helper Function: Formats Bullet Points for PDF
pw.Widget _buildPDFBulletPoints(String summary, pw.Font customFont) {
  List<String> lines = summary.split("\n").where((line) => line.isNotEmpty).toList();

  return pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: lines.map((line) {
      List<String> parts = line.split("by");
      String firstPart = parts.isNotEmpty ? parts[0].trim() : "";
      String secondPart = parts.length > 1 ? "by ${parts[1].trim()}" : "";

      return pw.Padding(
        padding: const pw.EdgeInsets.only(bottom: 4),
        child: pw.RichText(
          text: pw.TextSpan(
            children: [
              pw.TextSpan(
                text: "• ", // ✅ Bullet point (now works with custom font!)
                style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold, font: customFont),
              ),
              pw.TextSpan(
                text: firstPart, // ✅ First part of the sentence
                style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold, font: customFont),
              ),
              if (secondPart.isNotEmpty)
                pw.TextSpan(
                  text: " $secondPart", // ✅ Bold the difference value
                  style: pw.TextStyle(
                    font: customFont,
                    fontSize: 14,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.blue,
                  ),
                ),
            ],
          ),
        ),
      );
    }).toList(),
  );
}




  Future<List<Uint8List>> _captureGraphsAsImages() async {
  List<Uint8List> images = [];

  // ✅ Ensure UI updates before capturing graphs
  setState(() {});  
  await Future.delayed(const Duration(milliseconds: 500)); // Allow UI to settle

  // ✅ Wait for graphs to render
  await _waitForGraphRender(comparisonGraphKey, "comparisonGraphKey");
  await _waitForGraphRender(frequencyGraphKey, "frequencyGraphKey");

  // ✅ Capture and Compress _buildComparisonGraph()
  Uint8List? comparisonGraphImage = await _captureGraphWithCompression(comparisonGraphKey, "comparisonGraphKey");
  if (comparisonGraphImage != null) images.add(comparisonGraphImage);

  // ✅ Capture and Compress _buildTimeBasedFrequencyGraph()
  Uint8List? frequencyGraphImage = await _captureGraphWithCompression(frequencyGraphKey, "frequencyGraphKey");
  if (frequencyGraphImage != null) images.add(frequencyGraphImage);

  if (kDebugMode) {
    print("📸 Total images captured: ${images.length}");
  }
  return images;
}


// Future<Uint8List?> _captureFrequencyGraphAsImage() async {
//   // ✅ Capture only the Frequency Graph
//   Uint8List? frequencyGraphImage = await _captureGraphWithCompression(
//     frequencyGraphKey,
//     "frequencyGraphKey",
//     // () => setState(() {}), // 🔄 Forces a rebuild!
//   );

//   if (frequencyGraphImage != null && kDebugMode) {
//     print("📸 Captured Frequency Graph Image!");
//   }

//   return frequencyGraphImage;
// }

Future<Uint8List?> _captureGraphWithCompression(GlobalKey repaintKey, String graphName) async {
  if (kDebugMode) {
    print("🔍 Attempting to capture $graphName...");
  }

  if (repaintKey.currentContext == null) {
    if (kDebugMode) print("⚠ $graphName context is NULL! Skipping capture.");
    return null;
  }

  // ✅ Ensure widget is fully rendered before capturing
  await Future.delayed(const Duration(milliseconds: 700)); // Added delay
  await _waitForGraphRender(repaintKey, graphName);

  // ✅ Get the repaint boundary
  final boundary = repaintKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
  if (boundary == null || boundary.debugNeedsPaint) {
    if (kDebugMode) print("⚠ $graphName is not ready! Skipping...");
    return null;
  }

  try {
    // ✅ Capture at 2x resolution
    ui.Image image = await boundary.toImage(pixelRatio: 2.0);
    ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    Uint8List? pngBytes = byteData?.buffer.asUint8List();

    if (pngBytes == null) {
      if (kDebugMode) print("❌ Failed to convert $graphName to PNG.");
      return null;
    }

    // ✅ Apply optimized compression
    Uint8List compressedBytes = await _compressImage(pngBytes);

    if (kDebugMode) {
      print("✅ Captured & Compressed $graphName - Original: ${pngBytes.length ~/ 1024} KB → Compressed: ${compressedBytes.length ~/ 1024} KB");
    }

    return compressedBytes;
  } catch (e) {
    if (kDebugMode) print("❌ Error capturing $graphName: $e");
    return null;
  }
}




// // ✅ Helper Function: Captures a widget as an image
// Future<Uint8List?> _captureGraph(GlobalKey key, String graphName, VoidCallback forceRebuild) async {

//   if (kDebugMode) {
//     print("🔍 Attempting to capture $graphName...");
//   }

//   if (kDebugMode) {
//     print("🔍 Checking $graphName BEFORE capturing images: ${key.currentContext != null}");
//   }

//   // ✅ Force rebuild if widget is null
//   if (key.currentContext == null) {
//     if (kDebugMode) {
//       print("⚠ $graphName context is NULL! Forcing rebuild...");
//     }
//     forceRebuild();  // 🔄 Calls setState() to trigger a rebuild
//     await Future.delayed(Duration(milliseconds: 500)); // Allow rebuild time
//   }

//   // ✅ Double-check after rebuild attempt
//   if (key.currentContext == null) {
//     if (kDebugMode) {
//       print("⚠ $graphName context is STILL NULL after rebuild attempt. Skipping capture.");
//     }
//     return null;
//   }

//   // ✅ Ensure widget is fully rendered before proceeding
//   await _waitForGraphRender(key, graphName);

//   if (key.currentContext == null || key.currentContext!.findRenderObject() == null) {
//     if (kDebugMode) {
//       print("⚠ $graphName is still NULL, skipping capture.");
//     }
//     return null;
//   }

//   RenderRepaintBoundary? boundary = key.currentContext!.findRenderObject() as RenderRepaintBoundary?;

//   if (boundary == null || boundary.debugNeedsPaint) {
//   if (kDebugMode) {
//     print("⚠ $graphName is not fully painted! Retrying...");
//   }

//   // ✅ Force UI rebuild and delay again
//   forceRebuild();
//   await Future.delayed(Duration(milliseconds: 700));

//   boundary = key.currentContext?.findRenderObject() as RenderRepaintBoundary?;
//   if (boundary == null || boundary.debugNeedsPaint) {
//     if (kDebugMode) {
//       print("❌ $graphName is STILL NOT READY after waiting! Skipping...");
//     }
//     return null;
//   }
// }

//   if (kDebugMode) {
//     print("✅ $graphName is fully rendered and painted.");
//   }
//   ui.Image image = await boundary.toImage(pixelRatio: 3.0);
//   ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);
//   return byteData?.buffer.asUint8List();
// }


// ✅ Moved `_waitForGraphRender()` inside `_captureGraph()`
Future<void> _waitForGraphRender(GlobalKey key, String graphName) async {
  int retries = 5; // ✅ Increased retries slightly for reliability
  while (retries > 0) {
    await Future.delayed(const Duration(milliseconds: 700)); // ✅ Slightly increased delay

    final boundary = key.currentContext?.findRenderObject() as RenderRepaintBoundary?;
    if (boundary != null && !boundary.debugNeedsPaint) {
      if (kDebugMode) print("✅ $graphName is fully rendered.");
      return;
    }

    retries--;
    if (kDebugMode) print("⏳ Waiting for $graphName to render... ($retries retries left)");
  }

  if (kDebugMode) print("❌ $graphName never finished rendering.");
}


Future<Uint8List> _compressImage(Uint8List imageBytes) async {
  img.Image? image = img.decodeImage(imageBytes);
  if (image == null) return imageBytes; // ✅ Return original if decoding fails

  // ✅ Dynamic Resizing - Only resize if image width is > 800px
  if (image.width > 1000) {
    image = img.copyResize(image, width: 800);
  }

  return Uint8List.fromList(img.encodeJpg(image, quality: 75)); // ✅ Slightly lower quality for better compression
}




// // ✅ Helper Function: Waits for a widget to render
// Future<void> _waitForGraphRender(GlobalKey key, String graphName) async {
//   int retries = 15; // ✅ Increased retries
//   while (retries > 0) {
//     await Future.delayed(const Duration(milliseconds: 700)); // ✅ Increased delay

//     if (key.currentContext != null) {
//       RenderRepaintBoundary? boundary = key.currentContext!.findRenderObject() as RenderRepaintBoundary?;
//       if (boundary != null && !boundary.debugNeedsPaint) {
//         print("✅ $graphName is fully rendered and painted.");
//         return; // ✅ Exit once rendering is complete
//       }
//     }

//     print("⏳ Waiting for $graphName to finish rendering... ($retries retries left)");
//     retries--;
//   }

//   print("❌ $graphName is STILL NULL or not painted after waiting!");
// }




//////////////////////////////////////////////////////////////////////////////////////////

  @override
  Widget build(BuildContext context) {

      if (kDebugMode) {
        print("🔍 BUILDING PAGE - comparisonGraphKey exists: ${comparisonGraphKey.currentContext != null}");
      }

    // 🔍 Debugging Log
      if (kDebugMode) {
        print("🔍 comparisonGraphKey exists in UI: ${comparisonGraphKey.currentContext != null}");
      }

       // 🔍 Check if first and second date data are updating
    if (kDebugMode) {
      print("🔍 First Date Data: $firstDateData");
    }
    if (kDebugMode) {
      print("🔍 Second Date Data: $secondDateData");
    }



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
            _buildDatePickerTile("Select First Date", firstSelectedDate, (
              pickedDate,
            ) async {
              if (pickedDate != null) {
                setState(() {
                  firstSelectedDate = pickedDate;
                });
                firstDateData = await _fetchHistoricalData(
                  firstSelectedDate,
                  hardwareId!,
                );
                setState(() {});
              }
            }),

            _buildDatePickerTile("Select Second Date", secondSelectedDate, (
              pickedDate,
            ) async {
              if (pickedDate != null) {
                setState(() {
                  secondSelectedDate = pickedDate;
                  hasSecondDate = true;
                });

    if (kDebugMode) {
      print("🔍 Fetching data for second date: $pickedDate");
    }
    
    secondDateData = await _fetchHistoricalData(secondSelectedDate, hardwareId!);
    
    if (kDebugMode) {
      print("🔍 Updated secondDateData: $secondDateData");
    }
    
    setState(() {}); // 🔄 Ensure UI updates
  }
}),

            Expanded(
              child: ListView(
                children: [
                  _buildDataCard("First Date Data", firstDateData, true),
                  _buildDataCard("Second Date Data", secondDateData, false),
                  const SizedBox(height: 16),

                 ComparisonGraphWidget(
                    key: comparisonGraphWidgetKey, // ✅ Add this line
                    repaintKey: comparisonGraphKey,
                    firstDateData: firstDateData,
                    secondDateData: secondDateData,
                    widgetKey: comparisonGraphWidgetKey, // ✅ Add this line
                  ),



                  const SizedBox(height: 12),




                  const Divider(thickness: 2,color: Colors.black26,), // ✅ Adds a Visual Separator

                  // ✅ Filter Dropdown for Daily/Weekly (AFTER Divider)
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: 10,
                      horizontal: 16,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          "Filter: ",
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        DropdownButton<String>(
                          value: selectedFilter,
                          items:
                              ["Daily", "Weekly"].map((String value) {
                                return DropdownMenuItem<String>(
                                  value: value,
                                  child: Text(
                                    value,
                                    style: const TextStyle(fontSize: 16),
                                  ),
                                );
                              }).toList(),
                          onChanged: (newValue) async {
                            if (newValue != null) {
                              setState(() {
                                selectedFilter = newValue;
                              });

                              // ✅ Fetch Updated Data Based on Filter
                              frequencyAnalysisData =
                                  await _fetchFrequencyAnalysis(hardwareId!);
                              setState(() {});
                            }
                          },
                        ),
                      ],
                    ),
                  ),

                  // Build Frequency Analysis Card
                  _buildFrequencyAnalysisCard(),

                  const SizedBox(height: 32), // ✅ Adds spacing before the graph

                  // Build Time Based Frequency Graph

                  // if (frequencyAnalysisData.isNotEmpty)
                  //   RepaintBoundary(
                  //     key: frequencyGraphKey,
                  //     child: _buildTimeBasedFrequencyGraph(),
                  //   ),


                // if (frequencyAnalysisData.isNotEmpty)
                    FrequencyGraphWidget(
                      key: frequencyGraphWidgetKey,
                      repaintKey: frequencyGraphKey,
                      frequencyData: frequencyAnalysisData,
                      selectedFilter: selectedFilter,
                    ),


                  const SizedBox(height: 16,), // Adds spacing before the conclusion
                   const Divider(thickness: 2, color: Colors.black26,), // ✅ Adds a Visual Separator

                  // ✅ Conclusion
                  _buildConclusionWidget(),

                  // ✅ Export PDF Button
                  const SizedBox(height: 16),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.picture_as_pdf),
                      label: Text(isExportingPDF
                          ? "Exporting..."
                          : "Export as PDF"), // 🔄 Update text while exporting
                      onPressed: isExportingPDF
                          ? null // ⛔ Disable button while exporting
                          : () async {
                              await _exportToPDF();
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green[700],
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          vertical: 12,
                          horizontal: 20,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 16), // ✅ Adds spacing after button
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
            const Text(
              "Time-Based Frequency Analysis",
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
            ),
            const Divider(color: Colors.black45),
            if (frequencyAnalysisData.isEmpty)
              const Text(
                "No alerts recorded.",
                style: TextStyle(fontSize: 16, color: Colors.black54),
              ),
            ...frequencyAnalysisData.entries.expand((entry) {
              String sensorType = entry.key == "moisture" ? "dryness" : entry.key;
              List<dynamic> sensorValues =
                  entry.value
                      .where(
                        (data) =>
                            (double.tryParse(data["Value"].toString()) ?? 0) >
                            0.0,
                      ) // ✅ Filters out 0.0 values
                      .toList();

              if (sensorValues.isEmpty) return []; // ✅ Skip empty categories

              return [
                Text(
                  sensorType,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
                ...sensorValues.map((data) {
                  // ✅ Format timestamp properly
                  String formattedTime = "Unknown Time";
                  try {
                    DateTime parsedTime = DateFormat(
                      "yyyy-MM-dd hh:mm a",
                    ).parse(data["Time"]);
                    if (selectedFilter == "Weekly") {
                      formattedTime = DateFormat(
                        "EEE hh:mm a",
                      ).format(parsedTime); // ✅ Show day (Mon, Tue, etc.)
                    } else {
                      formattedTime = DateFormat(
                        "hh:mm a",
                      ).format(parsedTime); // ✅ Keep time-only for "Daily"
                    }
                  } catch (e) {
                    if (kDebugMode) {
                      print("⚠️ Error parsing timestamp: ${data["Time"]} - $e");
                    }
                  }

                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          _formatSensorValue(
                            sensorType,
                            data["Value"],
                          ), // ✅ Apply formatting
                          style: const TextStyle(
                            fontSize: 16,
                            color: Colors.black54,
                          ),
                        ),
                        Text(
                          data["Time"] ??
                              "Unknown Time", // ✅ Use pre-formatted string
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.red,
                          ),
                        ),
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

  // Widget _buildTimeBasedFrequencyGraph() {
  //   if (frequencyAnalysisData.isEmpty) {
  //     return const Center(child: Text("No alerts recorded to display."));
  //   }

  //   List<String> sensorTypes = frequencyAnalysisData.keys.toList();
  //   List<String> timestamps = [];

  //   // ✅ Collect unique timestamps for X-axis labels
  //   for (var sensor in sensorTypes) {
  //     for (var entry in frequencyAnalysisData[sensor] ?? []) {
  //       if (!timestamps.contains(entry["Time"])) {
  //         timestamps.add(entry["Time"]);
  //       }
  //     }
  //   }

  //   // ✅ If "Daily", show a single combined graph
  //   if (selectedFilter == "Daily") {
  //     return Column(
  //       children: [
  //         // ✅ Add the Legend Row
  //         Wrap(
  //           spacing: 10,
  //           children:
  //               sensorTypes.map((sensor) {
  //                 return Row(
  //                   mainAxisSize: MainAxisSize.min,
  //                   children: [
  //                     Container(
  //                       width: 12,
  //                       height: 12,
  //                       decoration: BoxDecoration(
  //                         color: _getSensorColor(sensor),
  //                         shape: BoxShape.circle,
  //                       ),
  //                     ),
  //                     const SizedBox(width: 5),
  //                     Text(
  //                       sensor,
  //                       style: const TextStyle(
  //                         fontSize: 12,
  //                         fontWeight: FontWeight.bold,
  //                       ),
  //                     ),
  //                   ],
  //                 );
  //               }).toList(),
  //         ),

  //         const SizedBox(height: 12), // ✅ Adds spacing before the graph
  //         // ✅ The Combined Graph
  //         SizedBox(
  //           height: 300, // ✅ Fixed height for Daily
  //           child: BarChart(
  //             BarChartData(
  //               barGroups: List.generate(timestamps.length, (index) {
  //                 String timeLabel = timestamps[index];

  //                 List<BarChartRodData> bars = [];

  //                 for (var sensor in sensorTypes) {
  //                   var sensorData =
  //                       frequencyAnalysisData[sensor]
  //                           ?.where((data) => data["Time"] == timeLabel)
  //                           .toList() ??
  //                       [];
  //                   if (sensorData.isNotEmpty) {
  //                     double sensorValue =
  //                         double.tryParse(
  //                           sensorData.first["Value"].toString(),
  //                         ) ??
  //                         0;

  //                     bars.add(
  //                       BarChartRodData(
  //                         toY: sensorValue,
  //                         color: _getSensorColor(sensor),
  //                         width: 16,
  //                       ),
  //                     );
  //                   }
  //                 }

  //                 return BarChartGroupData(x: index, barRods: bars);
  //               }),

  //               // ✅ Enable Touch Interaction
  //               barTouchData: BarTouchData(
  //                 touchTooltipData: BarTouchTooltipData(

  //                   fitInsideHorizontally:true, // ✅ Prevents horizontal clipping
  //                   fitInsideVertically: true, // ✅ Prevents vertical clipping

  //                   getTooltipItem: (group, groupIndex, rod, rodIndex) {
  //                     String formattedTime = "Unknown Time";

  //                     try {
  //                       DateTime parsedTime;
  //                       if (timestamps[groupIndex].contains("AM") ||
  //                           timestamps[groupIndex].contains("PM")) {
  //                         parsedTime = DateFormat(
  //                           "yyyy-MM-dd hh:mm a",
  //                         ).parse(timestamps[groupIndex]);
  //                       } else {
  //                         parsedTime = DateFormat(
  //                           "yyyy-MM-dd HH:mm:ss",
  //                         ).parse(timestamps[groupIndex]);
  //                       }

  //                       // Show Day + Time for Weekly, Only Time for Daily
  //                       formattedTime =
  //                           (selectedFilter == "Weekly")
  //                               ? DateFormat("EEE hh:mm a").format(
  //                                 parsedTime,
  //                               ) // Example: Mon 08:00 AM
  //                               : DateFormat(
  //                                 "hh:mm a",
  //                               ).format(parsedTime); // Example: 08:00 AM
  //                     } catch (e) {
  //                       print(
  //                         "Error parsing timestamp: ${timestamps[groupIndex]} - $e",
  //                       );
  //                     }

  //                     return BarTooltipItem(
  //                       "Sensor Value: ${rod.toY}\nTime: $formattedTime", // Tooltip Format
  //                       const TextStyle(color: Colors.white, fontSize: 12),
  //                     );
  //                   },
  //                   getTooltipColor:
  //                       (group) => Colors.black87, // Tooltip background color
  //                   tooltipRoundedRadius: 8, // Rounded corners
  //                   tooltipPadding: const EdgeInsets.all(
  //                     8,
  //                   ), // Padding inside tooltip
  //                   tooltipMargin: 10, // Space between bars & tooltip
  //                 ),
  //               ),

  //               titlesData: _buildChartTitles(
  //                 timestamps,
  //               ), // ✅ Keep existing title formatting
  //             ),
  //           ),
  //         ),
  //       ],
  //     );
  //   }

  //   // ✅ If "Weekly", show separate graphs per sensor type
  //   return Column(
  //     children:
  //         sensorTypes.map((sensor) {
  //           List<String> sensorTimestamps = [];
  //           for (var entry in frequencyAnalysisData[sensor] ?? []) {
  //             if (!sensorTimestamps.contains(entry["Time"])) {
  //               sensorTimestamps.add(entry["Time"]);
  //             }
  //           }

  //           return Column(
  //             children: [
  //               const SizedBox(height: 16), // ✅ Adds spacing between graphs
  //               // ✅ Sensor Title (Legend for Each Graph)
  //               Row(
  //                 mainAxisAlignment: MainAxisAlignment.center,
  //                 children: [
  //                   Container(
  //                     width: 12,
  //                     height: 12,
  //                     decoration: BoxDecoration(
  //                       color: _getSensorColor(sensor),
  //                       shape: BoxShape.circle,
  //                     ),
  //                   ),
  //                   const SizedBox(width: 5),
  //                   Text(
  //                     sensor,
  //                     style: const TextStyle(
  //                       fontSize: 14,
  //                       fontWeight: FontWeight.bold,
  //                     ),
  //                   ),
  //                 ],
  //               ),

  //               const SizedBox(height: 10),

  //               // ✅ The Separate Graph for this Sensor

  //               Padding(
  // padding: const EdgeInsets.symmetric(vertical: 20),  // ✅ Adds space above & below
  //               child: SizedBox(
  //                 height: 300, // ✅ Consistent height per graph
  //                 child: BarChart(
  //                   BarChartData(
  //                     barGroups: List.generate(timestamps.length, (index) {
  //                       String timeLabel = timestamps[index];

  //                       List<BarChartRodData> bars = [];

                        
  //                         var sensorData =
  //                             frequencyAnalysisData[sensor]
  //                                 ?.where((data) => data["Time"] == timeLabel)
  //                                 .toList() ??
  //                             [];
  //                         if (sensorData.isNotEmpty) {
  //                           double sensorValue =
  //                               double.tryParse(
  //                                 sensorData.first["Value"].toString(),
  //                               ) ??
  //                               0;

  //                           bars.add(
  //                             BarChartRodData(
  //                               toY: sensorValue,
  //                               color: _getSensorColor(sensor),
  //                               width: 16,
  //                             ),
  //                           );
  //                         }
                        

  //                       return BarChartGroupData(x: index, barRods: bars);
  //                     }),

  //                     // ✅ Enable Touch Interaction
  //                     barTouchData: BarTouchData(
  //                       touchTooltipData: BarTouchTooltipData(

  //                         fitInsideHorizontally:true, // ✅ Prevents horizontal clipping
  //                          fitInsideVertically: true, // ✅ Prevents vertical clipping

  //                          tooltipMargin: 30,  // ✅ Pushes tooltip away from other widgets

  //                         getTooltipItem: (group, groupIndex, rod, rodIndex) {
  //                           String formattedTime = "Unknown Time";

  //                           try {
  //                             DateTime parsedTime;
  //                             if (timestamps[groupIndex].contains("AM") ||
  //                                 timestamps[groupIndex].contains("PM")) {
  //                               parsedTime = DateFormat(
  //                                 "yyyy-MM-dd hh:mm a",
  //                               ).parse(timestamps[groupIndex]);
  //                             } else {
  //                               parsedTime = DateFormat(
  //                                 "yyyy-MM-dd HH:mm:ss",
  //                               ).parse(timestamps[groupIndex]);
  //                             }

  //                             // Show Day + Time for Weekly, Only Time for Daily
  //                             formattedTime =
  //                                 (selectedFilter == "Weekly")
  //                                     ? DateFormat("EEE hh:mm a").format(
  //                                       parsedTime,
  //                                     ) // Example: Mon 08:00 AM
  //                                     : DateFormat(
  //                                       "hh:mm a",
  //                                     ).format(parsedTime); // Example: 08:00 AM
  //                           } catch (e) {
  //                             print(
  //                               "Error parsing timestamp: ${timestamps[groupIndex]} - $e",
  //                             );
  //                           }

  //                           return BarTooltipItem(
  //                             "Sensor Value: ${rod.toY}\nTime: $formattedTime", // Tooltip Format
  //                             const TextStyle(
  //                               color: Colors.white,
  //                               fontSize: 12,
  //                             ),
  //                           );
  //                         },
  //                         getTooltipColor:
  //                             (group) =>
  //                                 Colors.black87, // Tooltip background color
  //                         tooltipRoundedRadius: 8, // Rounded corners
  //                         tooltipPadding: const EdgeInsets.all(
  //                           8,
  //                         ), // Padding inside tooltip
  //                        // tooltipMargin: 10, // Space between bars & tooltip
  //                       ),
  //                     ),

  //                     titlesData: _buildChartTitles(
  //                       timestamps,
  //                     ), // ✅ Keep existing title formatting
  //                   ),
  //                 ),
  //                ),
  //               )
  //             ],
  //           );
  //         }).toList(),
  //   );
  // }

  String formatSensorValue(String sensor, double value) {
    if (sensor.toLowerCase().contains("moisture") ||
        sensor.toLowerCase().contains("humidity")) {
      return "${value.toInt()}%"; // Whole number + %
    } else if (sensor.toLowerCase().contains("temperature")) {
      return "${value.toStringAsFixed(1)}°C"; // 1 decimal place + °C
    } else if (sensor.toLowerCase().contains("ph")) {
      return value.toStringAsFixed(2); // 2 decimal places
    }
    return value.toString(); // Default case
  }

  Widget _buildConclusionWidget() {
  if (firstDateData.isEmpty &&
      secondDateData.isEmpty &&
      frequencyAnalysisData.isEmpty) {
    return const Center(child: Text("No data available for conclusion."));
  }

  String firstDateStr = DateFormat("yyyy-MM-dd").format(firstSelectedDate);
  String secondDateStr = DateFormat("yyyy-MM-dd").format(secondSelectedDate);

  // 📌 1️⃣ Comparison Summary
  print("📝 Comparison Summary: $comparisonSummary");
  List<InlineSpan> comparisonSpans = [];

  if (firstDateData.isNotEmpty && secondDateData.isNotEmpty) {
    List<String> labels = [
      "Temperature",
      "Dryness Level",
      "pH Level 1",
      "pH Level 2",
      "Humidity",
    ];

    String formatSensorValue(String sensor, double value) {
  if (sensor.contains("Temperature")) {
    return "${value.toStringAsFixed(1)}°C"; // ✅ 1 decimal + °C
  } else if (sensor.contains("Moisture") || sensor.contains("Humidity")) {
    return "${value.toStringAsFixed(0)}%"; // ✅ Whole number + %
  } else if (sensor.contains("pH")) {
    return value.toStringAsFixed(2); // ✅ 2 decimal places for pH
  }
  return value.toString(); // Default case (not expected)
}


    for (String label in labels) {
      double firstValue =
          double.tryParse(firstDateData[label]?.replaceAll(RegExp('[^0-9.]'), '') ?? "0") ?? 0;
      double secondValue =
          double.tryParse(secondDateData[label]?.replaceAll(RegExp('[^0-9.]'), '') ?? "0") ?? 0;

      if (firstValue > secondValue) {
          double diff = (firstValue - secondValue);
          comparisonSpans.add(_buildBulletSpan(
            label,
            "on $firstDateStr (${formatSensorValue(label, firstValue)}) was higher than $secondDateStr (${formatSensorValue(label, secondValue)}) by ",
            formatSensorValue(label, diff),
          ));
        } else if (firstValue < secondValue) {
          double diff = (secondValue - firstValue);
          comparisonSpans.add(_buildBulletSpan(
            label,
            "on $secondDateStr (${formatSensorValue(label, secondValue)}) was higher than $firstDateStr (${formatSensorValue(label, firstValue)}) by ",
            formatSensorValue(label, diff),
          ));
        } else {
          comparisonSpans.add(_buildBulletSpan(
            label,
            "was the same on both dates ($firstDateStr: ${formatSensorValue(label, firstValue)}, $secondDateStr: ${formatSensorValue(label, secondValue)}).",
            "",
          ));
        }


    }
  }

  
// 📌 2️⃣ Time-Based Frequency Summary
if (kDebugMode) {
  print("📝 Frequency Summary: $frequencySummary");
}
List<InlineSpan> frequencySpans = [];

if (frequencyAnalysisData.isNotEmpty) {
  frequencyAnalysisData.forEach((sensorType, sensorData) {
    if (sensorData.isNotEmpty) {
      // ✅ **Ensure `sensorData` is properly casted**
      List<Map<String, dynamic>> typedSensorData =
          List<Map<String, dynamic>>.from(sensorData);

      // ✅ Find the highest recorded value
      var highestRecord = typedSensorData.reduce(
        (a, b) =>
            (double.tryParse(a["Value"].toString()) ?? 0) >
                    (double.tryParse(b["Value"].toString()) ?? 0)
                ? a
                : b,
      );

      // ✅ Find the lowest recorded value
      var lowestRecord = typedSensorData.reduce(
        (a, b) =>
            (double.tryParse(a["Value"].toString()) ?? double.infinity) <
                    (double.tryParse(b["Value"].toString()) ?? double.infinity)
                ? a
                : b,
      );

      // ✅ Extract values & format them properly
      double highestValue = double.tryParse(highestRecord["Value"].toString()) ?? 0;
      double lowestValue = double.tryParse(lowestRecord["Value"].toString()) ?? 0;

      String highestValueStr = formatSensorValue(sensorType, highestValue);
      String lowestValueStr = formatSensorValue(sensorType, lowestValue);

      // ✅ Extract & format timestamps for highest and lowest
      String highestRawTimestamp = highestRecord["Time"];
      String lowestRawTimestamp = lowestRecord["Time"];
      String highestFormattedTimestamp = "Unknown Time";
      String lowestFormattedTimestamp = "Unknown Time";

      try {
        DateTime parsedTime = DateFormat("yyyy-MM-dd hh:mm a").parse(highestRawTimestamp);
        highestFormattedTimestamp = (selectedFilter == "Weekly")
            ? DateFormat("EEE hh:mm a").format(parsedTime) // Example: Mon 08:00 AM
            : DateFormat("hh:mm a").format(parsedTime); // Example: 08:00 AM
      } catch (e) {
        print("⚠️ Error parsing highest timestamp: $highestRawTimestamp - $e");
      }

      try {
        DateTime parsedTime = DateFormat("yyyy-MM-dd hh:mm a").parse(lowestRawTimestamp);
        lowestFormattedTimestamp = (selectedFilter == "Weekly")
            ? DateFormat("EEE hh:mm a").format(parsedTime) // Example: Mon 08:00 AM
            : DateFormat("hh:mm a").format(parsedTime); // Example: 08:00 AM
      } catch (e) {
        print("⚠️ Error parsing lowest timestamp: $lowestRawTimestamp - $e");
      }

      // ✅ ADD BULLET FOR EACH SENSOR TYPE WITH SPACING BETWEEN ENTRIES
      frequencySpans.add(
        TextSpan(
          children: [
            const TextSpan(
              text: "• ", // 🔹 Bullet Point
              style: TextStyle(fontWeight: FontWeight.bold),
            ),

            // 🔹 Sensor Name (Bold)
            TextSpan(
              text: (sensorType == "moisture" ? "Dryness" : sensorType),
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const TextSpan(text: " was "),

            // 🔹 Highest (Bold)
            const TextSpan(
              text: "highest",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const TextSpan(text: " at "),

            // 🔹 Highest Time (Bold)
            TextSpan(
              text: highestFormattedTimestamp,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const TextSpan(text: " with a value of "),

            // 🔹 Highest Value (Blue & Bold)
            TextSpan(
              text: highestValueStr,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.blue,
              ),
            ),
            const TextSpan(text: ", while it was "),

            // 🔹 Lowest (Bold)
            const TextSpan(
              text: "lowest",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const TextSpan(text: " at "),

            // 🔹 Lowest Time (Bold)
            TextSpan(
              text: lowestFormattedTimestamp,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const TextSpan(text: " with a value of "),

            // 🔹 Lowest Value (Blue & Bold)
            TextSpan(
              text: lowestValueStr,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.blue,
              ),
            ),
            const TextSpan(text: "."),

            // 🔹 ADD LINE BREAK AFTER EACH SENSOR ENTRY
            const TextSpan(text: "\n\n"), // 🔥 Ensures proper spacing
          ],
        ),
      );
    }
  });
}



  // 📌 UI Layout
  return Card(
    color: Colors.white,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    elevation: 3,
    margin: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
    child: Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ✅ Title
          const Text(
            "📌 Conclusion & Findings",
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.green,
            ),
          ),
          const Divider(color: Colors.black45),
          const SizedBox(height: 10),

          // ✅ Comparison Summary
          if (comparisonSpans.isNotEmpty) ...[
            Text(
              "📊 Date Comparison Summary ($firstDateStr vs. $secondDateStr)",
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            RichText(
              text: TextSpan(
                style: const TextStyle(fontSize: 16, color: Colors.black87),
                children: comparisonSpans,
              ),
            ),
            const SizedBox(height: 20),
          ],

          // ✅ Time-Based Frequency Summary
          if (frequencySpans.isNotEmpty) ...[
            const Text(
              "📈 Time-Based Frequency Summary",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            RichText(
              text: TextSpan(
                style: const TextStyle(fontSize: 16, color: Colors.black87),
                children: frequencySpans,
              ),
            ),
          ],
        ],
      ),
    ),
  );
}

// ✅ Helper Function: Formats text into bullet points with bold values
InlineSpan _buildBulletSpan(String label, String text, String boldValue) {
  return WidgetSpan(
    child: Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "• ", // Bullet point
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          Expanded(
            child: RichText(
              text: TextSpan(
                children: [
                  TextSpan(
                    text: "$label ", // Sensor name
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                  TextSpan(
                    text: text, // Regular text
                    style: const TextStyle(
                      fontSize: 16,
                      color: Colors.black87,
                    ),
                  ),
                  TextSpan(
                    text: boldValue, // Highlighted Value
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    ),
  );
}


}

class ComparisonGraphWidget extends StatefulWidget {
  final GlobalKey<_ComparisonGraphWidgetState> widgetKey; // ✅ Added GlobalKey
  final GlobalKey repaintKey;
  final Map<String, String> firstDateData;
  final Map<String, String> secondDateData;
  

  const ComparisonGraphWidget({
    Key? key,
    required this.widgetKey,  // ✅ Assign the key
    required this.repaintKey,
    required this.firstDateData,
    required this.secondDateData,
  }) : super(key: widgetKey); // ✅ Pass key to parent

  @override
  _ComparisonGraphWidgetState createState() => _ComparisonGraphWidgetState();
}

class _ComparisonGraphWidgetState extends State<ComparisonGraphWidget> with AutomaticKeepAliveClientMixin {
  
  // ✅ Ensures the widget stays in memory and doesn’t get disposed
  @override
  bool get wantKeepAlive => true;

  // ✅ Add this method to trigger a rebuild
  void forceRebuild() {
    setState(() {}); // 🔄 Triggers a rebuild when called
  }
  

  @override
  Widget build(BuildContext context) {
    super.build(context); // ✅ Required for AutomaticKeepAliveClientMixin

    print("🟢 _buildComparisonGraph() is rebuilding. comparisonGraphKey exists: ${widget.repaintKey.currentContext != null}");
    print("🔄 _buildComparisonGraph() is rebuilding. comparisonGraphKey is attached: ${widget.repaintKey.currentContext != null}");


    return Visibility( // ✅ Ensures widget is always built
      visible: true,
      maintainState: true,
      child: RepaintBoundary(
        key: widget.repaintKey,
        child: _buildComparisonGraph(),
      ),
    );
  }

  Widget _buildComparisonGraph() {
  print("🔍 comparisonGraph Data Check: First - ${widget.firstDateData}, Second - ${widget.secondDateData}");

  if (widget.firstDateData.isEmpty || widget.secondDateData.isEmpty) {
    return const SizedBox(height: 300); // Maintain layout
  }

  List<String> labels = [
    "Temperature",
    "Dryness Level",
    "pH Level 1",
    "pH Level 2",
    "Humidity",
  ];

  /// ✅ Improved Data Parsing (Fixed Casting Issue)
List<double> firstValues = labels.map((label) {
  String? rawValue = widget.firstDateData[label];

  if (rawValue == null || rawValue.toLowerCase() == "n/a") return 0.0; // Ensure double type

  rawValue = rawValue.replaceAll("°C", "").replaceAll("%", ""); // Remove units

  return double.tryParse(rawValue) ?? 0.0; // Explicitly return double
}).toList().cast<double>(); // ✅ Ensure it is a List<double>

List<double> secondValues = labels.map((label) {
  String? rawValue = widget.secondDateData[label];

  if (rawValue == null || rawValue.toLowerCase() == "n/a") return 0.0;

  rawValue = rawValue.replaceAll("°C", "").replaceAll("%", "");

  return double.tryParse(rawValue) ?? 0.0;
}).toList().cast<double>(); // ✅ Ensure it is a List<double>


  // ✅ Debugging: Print parsed values
  print("📊 First Values: $firstValues");
  print("📊 Second Values: $secondValues");

  return Column(
    children: [
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
      const SizedBox(height: 13),
      SizedBox(
        height: 300,
        child: BarChart(
          BarChartData(
            barGroups: List.generate(labels.length, (index) {
              return BarChartGroupData(
                x: index,
                barRods: [
                  BarChartRodData(
                    toY: firstValues[index],
                    color: Colors.blue,
                    width: 16,
                  ),
                  BarChartRodData(
                    toY: secondValues[index],
                    color: Colors.green,
                    width: 16,
                  ),
                ],
              );
            }),
            titlesData: FlTitlesData(
              leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 40)),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  getTitlesWidget: (value, _) {
                    return Icon(_getSensorIcon(labels[value.toInt()]), size: 24, color: Colors.black54);
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
      case "dryness level":
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
}


// Frequency Graph
class FrequencyGraphWidget extends StatefulWidget {
  final GlobalKey repaintKey;
  final Map<String, dynamic> frequencyData;
  final String selectedFilter;

  const FrequencyGraphWidget({
    Key? key,
    required this.repaintKey,
    required this.frequencyData,
    required this.selectedFilter,
  }) : super(key: key);

  @override
  _FrequencyGraphWidgetState createState() => _FrequencyGraphWidgetState();
}

class _FrequencyGraphWidgetState extends State<FrequencyGraphWidget> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true; // ✅ Keeps widget in memory

  @override
  Widget build(BuildContext context) {
    super.build(context); // ✅ Required for AutomaticKeepAliveClientMixin

    print("🟢 _buildTimeBasedFrequencyGraph() is rebuilding. frequencyGraphKey exists: ${widget.repaintKey.currentContext != null}");
    print("🟢 FrequencyGraphWidget is building. Attached to UI? ${widget.repaintKey.currentContext != null}");
    print("🔍 Frequency Data Check: ${widget.frequencyData}");



    return KeepAlive(
      keepAlive: true,
      child: SizedBox(
        height: 400,
        child: RepaintBoundary(
          key: widget.repaintKey,
          child: _buildTimeBasedFrequencyGraph(),
        ),
      ),
    );
}

Widget _buildTimeBasedFrequencyGraph() {
  if (widget.frequencyData.isEmpty) {
    return const Center(child: Text("No alerts recorded to display."));
  }

  List<String> sensorTypes = widget.frequencyData.keys.toList();
  List<String> timestamps = [];

  for (var sensor in sensorTypes) {
    for (var entry in widget.frequencyData[sensor] ?? []) {
      if (!timestamps.contains(entry["Time"])) {
        timestamps.add(entry["Time"]);
      }
    }
  }

// ✅ Daily Filter (Updated to work like Weekly)
if (widget.selectedFilter == "Daily") {
  return SingleChildScrollView(
    physics: const BouncingScrollPhysics(), // ✅ Retains vertical scrolling
    child: Column(
      children: sensorTypes.map((sensor) {
        String displaySensorType = sensor == "moisture" ? "Dryness" : sensor; // ✅ Replace moisture with Dryness

        List<String> sensorTimestamps = [];
        for (var entry in widget.frequencyData[sensor] ?? []) {
          if (!sensorTimestamps.contains(entry["Time"])) {
            sensorTimestamps.add(entry["Time"]);
          }
        }

        bool isScrollable = sensorTimestamps.length > 6; // ✅ Enable scrolling dynamically

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Column(
            children: [
              // ✅ Sensor Legend for Each Graph
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
                  Text(
                    displaySensorType, // ✅ Use updated sensor name
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                  ),
                ],
              ),

              const SizedBox(height: 10),

// ✅ Dynamic Scrolling - Horizontal for many timestamps, Vertical otherwise
SingleChildScrollView(
  scrollDirection: isScrollable ? Axis.horizontal : Axis.vertical,
  child: SizedBox(
    width: isScrollable ? sensorTimestamps.length * 50.0 : null, // ✅ Expand width dynamically
    height: 300,
    child: BarChart(
      BarChartData(
        barGroups: List.generate(sensorTimestamps.length, (index) {
          String timeLabel = sensorTimestamps[index];
          List<BarChartRodData> bars = [];

          var sensorData = widget.frequencyData[sensor]
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

          return BarChartGroupData(x: index, barRods: bars);
        }),

        // ✅ Tooltip for Better Data Viewing
        barTouchData: BarTouchData(
          touchTooltipData: BarTouchTooltipData(
            fitInsideVertically: true,
            fitInsideHorizontally: true,
            tooltipPadding: const EdgeInsets.all(8),
            tooltipRoundedRadius: 8,
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              String formattedTime = _formatTimestamp(sensorTimestamps[groupIndex]);
              return BarTooltipItem(
                "Sensor Value: ${rod.toY}\nTime: $formattedTime",
                const TextStyle(color: Colors.white, fontSize: 12),
              );
            },
            getTooltipColor: (group) => Colors.black87,
          ),
        ),

        // ✅ Properly format titlesData & remove only the highest Y-axis label
       titlesData: _buildChartTitles(sensorTimestamps), // ✅ Correct way to assign FlTitlesData

    ),
  ),
              ),
)
            ],
          ),
        );
      }).toList(),
    ),
  );
}


  // ✅ **Weekly Logic (Retains Vertical Scrolling for Multiple Sensors)**
 if (widget.selectedFilter == "Weekly") {
  return SingleChildScrollView(
    physics: const BouncingScrollPhysics(), // ✅ Retains vertical scrolling
    child: Column(
      children: sensorTypes.map((sensor) {
        String displaySensorType = sensor == "moisture" ? "Dryness" : sensor; // ✅ Replace moisture with Dryness

        List<String> sensorTimestamps = [];
        for (var entry in widget.frequencyData[sensor] ?? []) {
          if (!sensorTimestamps.contains(entry["Time"])) {
            sensorTimestamps.add(entry["Time"]);
          }
        }

        bool isScrollable = sensorTimestamps.length > 6; // ✅ Enable scrolling dynamically

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Column(
            children: [
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
                  Text(
                    displaySensorType, // ✅ Use updated sensor name
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                  ),
                ],
              ),

              const SizedBox(height: 10),

              SingleChildScrollView(
                scrollDirection: isScrollable ? Axis.horizontal : Axis.vertical, // ✅ Scroll dynamically
                child: SizedBox(
                  width: isScrollable ? sensorTimestamps.length * 50.0 : null, // ✅ Expand width dynamically
                  height: 300,
                  child: BarChart(
  BarChartData(
    // ✅ Find the highest value dynamically for padding
    maxY: (() {
      double highestSensorValue = widget.frequencyData[sensor]?.map((data) {
        return double.tryParse(data["Value"].toString()) ?? 0;
      }).reduce((a, b) => a > b ? a : b) ?? 0;

      return highestSensorValue + (highestSensorValue * 0.1); // ✅ Add 10% buffer
    })(),

    barGroups: List.generate(sensorTimestamps.length, (index) {
      String timeLabel = sensorTimestamps[index];
      List<BarChartRodData> bars = [];

      String displaySensorType = sensor == "moisture" ? "Dryness" : sensor; // ✅ Ensure correct naming in the graph

      var sensorData = widget.frequencyData[sensor]
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

      return BarChartGroupData(x: index, barRods: bars);
    }),

    barTouchData: BarTouchData(
      touchTooltipData: BarTouchTooltipData(
        fitInsideVertically: true,
        fitInsideHorizontally: true,
        tooltipPadding: const EdgeInsets.all(8),
        tooltipRoundedRadius: 8,
        getTooltipItem: (group, groupIndex, rod, rodIndex) {
          String formattedTime = _formatTimestamp(sensorTimestamps[groupIndex]);
          return BarTooltipItem(
            "Sensor Value: ${rod.toY}\nTime: $formattedTime",
            const TextStyle(color: Colors.white, fontSize: 12),
          );
        },
        getTooltipColor: (group) => Colors.black87,
      ),
    ),

    titlesData: _buildChartTitles(sensorTimestamps),
  ),
),

                ),
              ),
            ],
          ),
        );
      }).toList(),
    ),
  );
}


  return const SizedBox(); // Default fallback
}





  /// ✅ **Move `_buildChartTitles` inside `FrequencyGraphWidget`**
  FlTitlesData _buildChartTitles(List<String> timestamps) {
  return FlTitlesData(
    topTitles: AxisTitles(
      sideTitles: SideTitles(showTitles: false), // ✅ Hide top numbers
    ),
    leftTitles: AxisTitles(
      sideTitles: SideTitles(
        showTitles: true,
        reservedSize: 40,
        getTitlesWidget: (value, meta) {
          // ✅ Hide only the highest Y-axis label (LEFT SIDE)
          if (value >= meta.max) return Container();
          return Text(
            value.toInt().toString(),
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
          );
        },
      ),
    ),
    rightTitles: AxisTitles(
      sideTitles: SideTitles(
        showTitles: true,
        reservedSize: 40,
        getTitlesWidget: (value, meta) {
          // ✅ Hide only the highest Y-axis label (RIGHT SIDE)
          if (value >= meta.max) return Container();
          return Text(
            value.toInt().toString(),
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
          );
        },
      ),
    ),
    bottomTitles: AxisTitles(
      sideTitles: SideTitles(
        showTitles: true,
        reservedSize: 60,
        getTitlesWidget: (value, meta) {
          int index = value.toInt();
          if (index >= 0 && index < timestamps.length) {
            return _buildFormattedTimestampLabel(index, timestamps);
          }
          return const Text("");
        },
      ),
    ),
  );
}

  /// ✅ **Move `_formatTimestamp` inside `FrequencyGraphWidget`**
  String _formatTimestamp(String timestamp) {
    try {
      DateTime parsedTime;
      if (timestamp.contains("AM") || timestamp.contains("PM")) {
        parsedTime = DateFormat("yyyy-MM-dd hh:mm a").parse(timestamp);
      } else {
        parsedTime = DateFormat("yyyy-MM-dd HH:mm:ss").parse(timestamp);
      }

      return (widget.selectedFilter == "Weekly")
          ? DateFormat("EEE hh:mm a").format(parsedTime)
          : DateFormat("hh:mm a").format(parsedTime);
    } catch (e) {
      if (kDebugMode) {
        print("⚠️ Error parsing timestamp: $timestamp - $e");
      }
      return "Invalid Time";
    }
  }

  /// ✅ **Helper to show labels at correct intervals**
  Widget _buildFormattedTimestampLabel(int index, List<String> timestamps) {
    String formattedTime = _formatTimestamp(timestamps[index]);

    bool showLabel = timestamps.length <= 4 || index % 2 == 0;

    return showLabel
        ? Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              formattedTime,
              style: const TextStyle(fontSize: 10),
              textAlign: TextAlign.center,
            ),
          )
        : const SizedBox.shrink();
  }

  /// ✅ **Move `_getSensorColor` inside `FrequencyGraphWidget`**
  Color _getSensorColor(String sensor) {
  switch (sensor.toLowerCase()) {
    case "temperature":
      return Colors.red;
    case "moisture":
      return Colors.blue;
    case "ph_level":
    return const Color.fromARGB(255, 83, 255, 88);
    case "ph_level2":
      return Colors.green;
    case "humidity":
      return Colors.orange; // 🌤️ Set a distinct color for humidity
    default:
      return Colors.grey; // Fallback for unknown sensors
    }
  }
}
