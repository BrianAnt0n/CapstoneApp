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

  String comparisonSummary = "";
  String frequencySummary = "";

  final GlobalKey comparisonGraphKey = GlobalKey();
  final GlobalKey frequencyGraphKey = GlobalKey();

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
  Widget _buildDataCard(
    String title,
    Map<String, String> data,
    bool isFirstDate,
  ) {
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
                      entry.value,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color:
                            isFirstDate
                                ? Colors.blue
                                : Colors
                                    .green, // ✅ Dynamic Color Matching Graph
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
      return _defaultData("N/A");
    }

    Map<String, String> parsedData = {
      "Temperature": "${response['temperature'] ?? 'N/A'}°C",
      "Moisture Level": "${response['moisture'] ?? 'N/A'}%",
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
        print(
          "🚨 No notifications found for hardware_id: $hardwareId in the selected range",
        );
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
    double parsedValue =
        double.tryParse(value.toString()) ?? 0; // ✅ Ensure it's a number

    if (sensorType.toLowerCase() == "moisture" ||
        sensorType.toLowerCase() == "humidity") {
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
                print("⚠️ Error parsing timestamp: ${timestamps[index]} - $e");
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
  print("📄 Exporting PDF...");

  await Future.delayed(const Duration(milliseconds: 1000)); // ✅ Ensure time for UI updates
  print("🔍 Checking comparisonGraphKey BEFORE capturing images: ${comparisonGraphKey.currentContext != null}");


print("🔍 comparisonGraphKey exists in UI: ${comparisonGraphKey.currentContext != null}");

 // ✅ Wait for the graphs to finish rendering
  await _waitForGraphRender(comparisonGraphKey, "comparisonGraphKey");
  await _waitForGraphRender(frequencyGraphKey, "frequencyGraphKey");


  final pdf = pw.Document();

   // ✅ Ensure selectedFilter is set correctly before generating summaries
  print("🔄 Current selectedFilter: $selectedFilter");

  // ✅ Regenerate summaries with the latest data before exporting
  _buildConclusionWidget();  // 🔄 Forces latest frequencySummary update
  _generateFrequencySummary(); // 🔄 Forces update before PDF export

    // ✅ Load Custom Font
  final fontData = await rootBundle.load("assets/fonts/Roboto-Regular.ttf");
  final customFont = pw.Font.ttf(fontData);

  // ✅ Ensure summaries are set before exporting
  if (comparisonSummary.trim().isEmpty) {
    print("❌ No data for comparisonSummary! Regenerating...");
    _generateComparisonSummary();
  }

  if (frequencySummary.trim().isEmpty) {
    print("❌ No data for frequencySummary! Regenerating...");
    _generateFrequencySummary();
  }

    // ✅ Fix: Remove time from the dates
  String firstDateFormatted = DateFormat('yyyy-MM-dd').format(firstSelectedDate);
  String secondDateFormatted = DateFormat('yyyy-MM-dd').format(secondSelectedDate);

  // ✅ Replace full timestamp with formatted date in the summary text
  comparisonSummary = comparisonSummary
      .replaceAll(firstSelectedDate.toString(), firstDateFormatted)
      .replaceAll(secondSelectedDate.toString(), secondDateFormatted);



  print("📌 Final comparisonSummary: $comparisonSummary");
  print("📌 Final frequencySummary: $frequencySummary");

  // ✅ Title Page
  pdf.addPage(
    pw.Page(
      build: (pw.Context context) => pw.Center(
        child: pw.Column(
          mainAxisAlignment: pw.MainAxisAlignment.center,
          children: [
            pw.Text(
              "Data Report Summary",
              style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold, font: customFont),

            ),
            pw.SizedBox(height: 8),
            pw.Text("Generated on ${DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now())}"),
          ],
        ),
      ),
    ),
  );

  // ✅ Add Data Comparison Summary (if available)
  if (comparisonSummary.trim().isNotEmpty) {
    pdf.addPage(
      pw.Page(
        build: (pw.Context context) => pw.Padding(
          padding: const pw.EdgeInsets.all(16),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                "Data Comparison Summary",
               style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold, font: customFont),

              ),
              pw.SizedBox(height: 8),
              pw.Text(comparisonSummary, style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold, font: customFont)),
            ],
          ),
        ),
      ),
    );
  } else {
    print("❌ Still no data for comparisonSummary!");
  }

  // ✅ Add Time-Based Frequency Summary (if available)
  if (frequencySummary.trim().isNotEmpty) {
    pdf.addPage(
      pw.Page(
        build: (pw.Context context) => pw.Padding(
          padding: const pw.EdgeInsets.all(16),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                "Time-Based Frequency Summary",
                style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold, font: customFont),

              ),
              pw.SizedBox(height: 8),
              pw.Text(frequencySummary, style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold, font: customFont)),
            ],
          ),
        ),
      ),
    );
  } else {
    print("❌ Still no data for frequencySummary!");
  }

  setState(() {}); // ✅ Force UI rebuild first
await Future.delayed(const Duration(milliseconds: 500)); // ✅ Allow UI to update
print("🔍 Checking comparisonGraphKey BEFORE capturing images: ${comparisonGraphKey.currentContext != null}");

  // ✅ Capture and Add Graphs
  List<Uint8List> images = await _captureGraphsAsImages();
  if (images.isEmpty) {
    print("❌ No images captured, skipping graphs in PDF.");
  } else {
    for (var image in images) {
      pdf.addPage(
        pw.Page(
          build: (pw.Context context) => pw.Center(
            child: pw.Image(pw.MemoryImage(image), width: 400, height: 300),
          ),
        ),
      );
    }
  }

  // ✅ Save and Open the PDF
  final output = await getTemporaryDirectory();
  final file = File("${output.path}/data_report.pdf");
  await file.writeAsBytes(await pdf.save());

  print("✅ PDF Saved at: ${file.path}");
  await Printing.layoutPdf(
    onLayout: (PdfPageFormat format) async => pdf.save(),
  );
}






//////////////////////////////////////////////////////////////////////////////////////////

// ✅ Helper Functions to Recalculate Summaries
void _generateComparisonSummary() {
  comparisonSummary = ""; // Clear old data
  if (firstDateData.isNotEmpty && secondDateData.isNotEmpty) {
    List<String> labels = ["Temperature", "Moisture Level", "pH Level 1", "pH Level 2", "Humidity"];
    
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
  print("🔄 Regenerating Frequency Summary...");
  frequencySummary = ""; // ✅ Clear old data

  print("🔍 selectedFilter: $selectedFilter"); // ✅ Debugging line

  if (frequencyAnalysisData.isNotEmpty) {
    List<String> summaries = [];

    frequencyAnalysisData.forEach((sensorType, sensorData) {
      if (sensorData.isNotEmpty) {
        if (selectedFilter == "Weekly") {
          double highestWeeklyValue = 0;
          String highestWeeklyTimestamp = "";

          for (var entry in sensorData) {
            double sensorValue = double.tryParse(entry["Value"].toString()) ?? 0;
            if (sensorValue > highestWeeklyValue) {
              highestWeeklyValue = sensorValue;
              highestWeeklyTimestamp = entry["Time"];
            }
          }

          // ✅ Format timestamp correctly for Weekly mode
          String formattedTimestamp = "Unknown Time";
          try {
            DateTime parsedTime = DateFormat("yyyy-MM-dd hh:mm a").parse(highestWeeklyTimestamp);
            formattedTimestamp = DateFormat("EEE, yyyy-MM-dd hh:mm a").format(parsedTime);
          } catch (e) {
            print("⚠️ Error parsing timestamp: $highestWeeklyTimestamp - $e");
          }

          summaries.add("• The highest recorded value this week for **$sensorType** was at **$formattedTimestamp** with a value of **${highestWeeklyValue.toStringAsFixed(2)}**.");
        } else { // ✅ Daily Mode
          var highestRecord = (sensorData as List<Map<String, dynamic>>).reduce(
            (a, b) => (double.tryParse(a["Value"].toString()) ?? 0) >
                       (double.tryParse(b["Value"].toString()) ?? 0) ? a : b,
          );

          double highestValue = double.tryParse(highestRecord["Value"].toString()) ?? 0;
          String rawTimestamp = highestRecord["Time"];
          String formattedTimestamp = "Unknown Time";

          try {
            DateTime parsedTime = DateFormat("yyyy-MM-dd hh:mm a").parse(rawTimestamp);
            formattedTimestamp = DateFormat("hh:mm a").format(parsedTime);
          } catch (e) {
            print("⚠️ Error parsing timestamp: $rawTimestamp - $e");
          }

          summaries.add("• The highest recorded value today for **$sensorType** was at **$formattedTimestamp** with a value of **${highestValue.toStringAsFixed(2)}**.");
        }
      }
    });

    // ✅ Combine summaries for all sensor types
    frequencySummary = summaries.join("\n\n");
  }

  print("📌 Final frequencySummary: $frequencySummary");
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

   // ✅ Ensure both graphs are fully rendered before capturing
   await _waitForGraphRender(comparisonGraphKey, "comparisonGraphKey");
   await _waitForGraphRender(frequencyGraphKey, "frequencyGraphKey");

   // ✅ Retry capturing if `comparisonGraphKey.currentContext` is still null
   int retries = 5;
   while (comparisonGraphKey.currentContext == null && retries > 0) {
       print("🔄 Retrying capturing _buildComparisonGraph()... ($retries retries left)");
       await Future.delayed(const Duration(milliseconds: 500));
       retries--;
   }

   // ✅ Capture _buildComparisonGraph()
   if (comparisonGraphKey.currentContext != null) {
      RenderRepaintBoundary boundary =
           comparisonGraphKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
      ui.Image image = await boundary.toImage(pixelRatio: 3.0);
      ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData != null) images.add(byteData.buffer.asUint8List());
      print("✅ Successfully captured _buildComparisonGraph()");
   } else {
      print("❌ comparisonGraphKey is STILL NULL after waiting!");
   }

   // ✅ Capture _buildTimeBasedFrequencyGraph()
   if (frequencyGraphKey.currentContext != null) {
      RenderRepaintBoundary boundary =
           frequencyGraphKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
      ui.Image image = await boundary.toImage(pixelRatio: 3.0);
      ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData != null) images.add(byteData.buffer.asUint8List());
      print("✅ Successfully captured _buildTimeBasedFrequencyGraph()");
   } else {
      print("❌ frequencyGraphKey is STILL NULL after waiting!");
   }

   print("📸 Total images captured: ${images.length}");
   return images;
}


// ✅ Helper Function: Waits for a widget to render
Future<void> _waitForGraphRender(GlobalKey key, String graphName) async {
  int retries = 15; // ✅ Increased retries
  while (retries > 0) {
    await Future.delayed(const Duration(milliseconds: 700)); // ✅ Increased delay

    if (key.currentContext != null) {
      RenderRepaintBoundary? boundary = key.currentContext!.findRenderObject() as RenderRepaintBoundary?;
      if (boundary != null && !boundary.debugNeedsPaint) {
        print("✅ $graphName is fully rendered and painted.");
        return; // ✅ Exit once rendering is complete
      }
    }

    print("⏳ Waiting for $graphName to finish rendering... ($retries retries left)");
    retries--;
  }

  print("❌ $graphName is STILL NULL or not painted after waiting!");
}




//////////////////////////////////////////////////////////////////////////////////////////

  @override
  Widget build(BuildContext context) {

      print("🔍 BUILDING PAGE - comparisonGraphKey exists: ${comparisonGraphKey.currentContext != null}");

    // 🔍 Debugging Log
      print("🔍 comparisonGraphKey exists in UI: ${comparisonGraphKey.currentContext != null}");

       // 🔍 Check if first and second date data are updating
    print("🔍 First Date Data: $firstDateData");
    print("🔍 Second Date Data: $secondDateData");



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

    print("🔍 Fetching data for second date: $pickedDate");
    
    secondDateData = await _fetchHistoricalData(secondSelectedDate, hardwareId!);
    
    print("🔍 Updated secondDateData: $secondDateData");
    
    setState(() {}); // 🔄 Ensure UI updates
  }
}),


            

            Expanded(
              child: ListView(
                children: [
                  _buildDataCard("First Date Data", firstDateData, true),
                  _buildDataCard("Second Date Data", secondDateData, true),
                  const SizedBox(height: 16),

                  ComparisonGraphWidget(
                    repaintKey: comparisonGraphKey,
                    firstDateData: firstDateData,
                    secondDateData: secondDateData,
                  ),


                  const SizedBox(height: 12),




                  const Divider(
                    thickness: 2,
                    color: Colors.black26,
                  ), // ✅ Adds a Visual Separator
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

                  const SizedBox(height: 16), // ✅ Adds spacing before the graph
                  if (frequencyAnalysisData.isNotEmpty)
                    RepaintBoundary(
                      key: frequencyGraphKey,
                      child: _buildTimeBasedFrequencyGraph(),
                    ),
                  const SizedBox(
                    height: 16,
                  ), // Adds spacing before the conclusion
                  _buildConclusionWidget(),

                  // ✅ Export PDF Button
                  const SizedBox(height: 16),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.picture_as_pdf),
                      label: const Text("Export as PDF"),
                      onPressed: () async {
                        await _exportToPDF(); // ✅ Calls the function to generate PDF
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green[700], // ✅ Green theme
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
              String sensorType = entry.key;
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
                    print("⚠️ Error parsing timestamp: ${data["Time"]} - $e");
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
            children:
                sensorTypes.map((sensor) {
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
                      Text(
                        sensor,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
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
                    var sensorData =
                        frequencyAnalysisData[sensor]
                            ?.where((data) => data["Time"] == timeLabel)
                            .toList() ??
                        [];
                    if (sensorData.isNotEmpty) {
                      double sensorValue =
                          double.tryParse(
                            sensorData.first["Value"].toString(),
                          ) ??
                          0;

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
                        if (timestamps[groupIndex].contains("AM") ||
                            timestamps[groupIndex].contains("PM")) {
                          parsedTime = DateFormat(
                            "yyyy-MM-dd hh:mm a",
                          ).parse(timestamps[groupIndex]);
                        } else {
                          parsedTime = DateFormat(
                            "yyyy-MM-dd HH:mm:ss",
                          ).parse(timestamps[groupIndex]);
                        }

                        // Show Day + Time for Weekly, Only Time for Daily
                        formattedTime =
                            (selectedFilter == "Weekly")
                                ? DateFormat("EEE hh:mm a").format(
                                  parsedTime,
                                ) // Example: Mon 08:00 AM
                                : DateFormat(
                                  "hh:mm a",
                                ).format(parsedTime); // Example: 08:00 AM
                      } catch (e) {
                        print(
                          "Error parsing timestamp: ${timestamps[groupIndex]} - $e",
                        );
                      }

                      return BarTooltipItem(
                        "Sensor Value: ${rod.toY}\nTime: $formattedTime", // Tooltip Format
                        const TextStyle(color: Colors.white, fontSize: 12),
                      );
                    },
                    getTooltipColor:
                        (group) => Colors.black87, // Tooltip background color
                    tooltipRoundedRadius: 8, // Rounded corners
                    tooltipPadding: const EdgeInsets.all(
                      8,
                    ), // Padding inside tooltip
                    tooltipMargin: 10, // Space between bars & tooltip
                  ),
                ),

                titlesData: _buildChartTitles(
                  timestamps,
                ), // ✅ Keep existing title formatting
              ),
            ),
          ),
        ],
      );
    }

    // ✅ If "Weekly", show separate graphs per sensor type
    return Column(
      children:
          sensorTypes.map((sensor) {
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
                    Text(
                      sensor,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
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

                        
                          var sensorData =
                              frequencyAnalysisData[sensor]
                                  ?.where((data) => data["Time"] == timeLabel)
                                  .toList() ??
                              [];
                          if (sensorData.isNotEmpty) {
                            double sensorValue =
                                double.tryParse(
                                  sensorData.first["Value"].toString(),
                                ) ??
                                0;

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

                      // ✅ Enable Touch Interaction
                      barTouchData: BarTouchData(
                        touchTooltipData: BarTouchTooltipData(
                          getTooltipItem: (group, groupIndex, rod, rodIndex) {
                            String formattedTime = "Unknown Time";

                            try {
                              DateTime parsedTime;
                              if (timestamps[groupIndex].contains("AM") ||
                                  timestamps[groupIndex].contains("PM")) {
                                parsedTime = DateFormat(
                                  "yyyy-MM-dd hh:mm a",
                                ).parse(timestamps[groupIndex]);
                              } else {
                                parsedTime = DateFormat(
                                  "yyyy-MM-dd HH:mm:ss",
                                ).parse(timestamps[groupIndex]);
                              }

                              // Show Day + Time for Weekly, Only Time for Daily
                              formattedTime =
                                  (selectedFilter == "Weekly")
                                      ? DateFormat("EEE hh:mm a").format(
                                        parsedTime,
                                      ) // Example: Mon 08:00 AM
                                      : DateFormat(
                                        "hh:mm a",
                                      ).format(parsedTime); // Example: 08:00 AM
                            } catch (e) {
                              print(
                                "Error parsing timestamp: ${timestamps[groupIndex]} - $e",
                              );
                            }

                            return BarTooltipItem(
                              "Sensor Value: ${rod.toY}\nTime: $formattedTime", // Tooltip Format
                              const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                              ),
                            );
                          },
                          getTooltipColor:
                              (group) =>
                                  Colors.black87, // Tooltip background color
                          tooltipRoundedRadius: 8, // Rounded corners
                          tooltipPadding: const EdgeInsets.all(
                            8,
                          ), // Padding inside tooltip
                          tooltipMargin: 10, // Space between bars & tooltip
                        ),
                      ),

                      titlesData: _buildChartTitles(
                        timestamps,
                      ), // ✅ Keep existing title formatting
                    ),
                  ),
                ),
              ],
            );
          }).toList(),
    );
  }

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
      "Moisture Level",
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
  print("📝 Frequency Summary: $frequencySummary");
  List<InlineSpan> frequencySpans = [];

  if (frequencyAnalysisData.isNotEmpty) {
    frequencyAnalysisData.forEach((sensorType, sensorData) {
      if (sensorData.isNotEmpty) {
        var highestRecord = (sensorData as List<Map<String, dynamic>>).reduce(
          (a, b) =>
              (double.tryParse(a["Value"].toString()) ?? 0) >
                      (double.tryParse(b["Value"].toString()) ?? 0)
                  ? a
                  : b,
        );

        double highestValue =
            double.tryParse(highestRecord["Value"].toString()) ?? 0;
        String highestValueStr = formatSensorValue(sensorType, highestValue);
        String rawTimestamp = highestRecord["Time"];
        String formattedTimestamp = "Unknown Time";

        try {
          DateTime parsedTime = DateFormat("yyyy-MM-dd hh:mm a").parse(rawTimestamp);
          formattedTimestamp = (selectedFilter == "Weekly")
              ? DateFormat("EEE hh:mm a").format(parsedTime) // Example: Mon 08:00 AM
              : DateFormat("hh:mm a").format(parsedTime); // Example: 08:00 AM
        } catch (e) {
          print("⚠️ Error parsing timestamp: $rawTimestamp - $e");
        }

        frequencySpans.add(_buildBulletSpan(
          sensorType,
          "was highest at $formattedTimestamp with a value of ",
          highestValueStr,
        ));
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
  final GlobalKey repaintKey;
  final Map<String, String> firstDateData;
  final Map<String, String> secondDateData;

  const ComparisonGraphWidget({
    Key? key,
    required this.repaintKey,
    required this.firstDateData,
    required this.secondDateData,
  }) : super(key: key);

  @override
  _ComparisonGraphWidgetState createState() => _ComparisonGraphWidgetState();
}

class _ComparisonGraphWidgetState extends State<ComparisonGraphWidget> {
  @override
  Widget build(BuildContext context) {
    print("🟢 _buildComparisonGraph() is rebuilding. comparisonGraphKey exists: ${widget.repaintKey.currentContext != null}");

    return RepaintBoundary(
      key: widget.repaintKey,
      child: _buildComparisonGraph(), // Now defined inside this widget
    );
  }

  Widget _buildComparisonGraph() {
    if (widget.firstDateData.isEmpty || widget.secondDateData.isEmpty) {
      return const SizedBox(height: 300); // Maintain layout
    }

    List<String> labels = [
      "Temperature",
      "Moisture Level",
      "pH Level 1",
      "pH Level 2",
      "Humidity",
    ];

    List<double> firstValues = labels.map((label) {
      String rawValue = widget.firstDateData[label]?.toString() ?? "0";
      return double.tryParse(rawValue) ?? 0;
    }).toList();

    List<double> secondValues = labels.map((label) {
      String rawValue = widget.secondDateData[label]?.toString() ?? "0";
      return double.tryParse(rawValue) ?? 0;
    }).toList();

    return Column(
      children: [
        Wrap(
          spacing: 12,
          children: labels.map((sensor) {
            return Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.circle, size: 12, color: Colors.black),
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
                      return Icon(Icons.circle, size: 24, color: Colors.black54);
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
}
