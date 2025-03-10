import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ContainerDetails extends StatefulWidget {
  final int hardwareId;

  const ContainerDetails({super.key, required this.hardwareId});

  @override
  _ContainerDetailsState createState() => _ContainerDetailsState();
}

class _ContainerDetailsState extends State<ContainerDetails> {
  late Future<List<Map<String, dynamic>>> _pastCompostFuture;

  @override
  void initState() {
    super.initState();
    _pastCompostFuture = _fetchPastCompost(widget.hardwareId);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Compost History"),
        backgroundColor: Colors.blueAccent,
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: FutureBuilder<List<Map<String, dynamic>>>(
          future: _pastCompostFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
              return _buildEmptyState();
            }

            final pastCompostList = snapshot.data!;
            return ListView.builder(
              itemCount: pastCompostList.length,
              itemBuilder: (context, index) {
                final compost = pastCompostList[index];
                return _buildCompostCard(compost);
              },
            );
          },
        ),
      ),
    );
  }

  // 📌 Fetch Past Compost Records
  Future<List<Map<String, dynamic>>> _fetchPastCompost(int hardwareId) async {
    final response = await Supabase.instance.client
        .from('Compost_Data')
        .select()
        .eq('hardware_id', hardwareId)
        .order('end_date', ascending: false);
    return response ?? [];
  }

// 📌 Build a compost card with compost status and weeks before retrieval
  Widget _buildCompostCard(Map<String, dynamic> compost) {
    DateTime startDate = DateTime.parse(compost['start_date']);
    DateTime? endDate = compost['end_date'] != null
        ? DateTime.parse(compost['end_date'])
        : null;
    int weeksBeforeRetrieval =
        _calculateWeeksBeforeRetrieval(startDate, endDate);
    String status = _getCompostStatus(weeksBeforeRetrieval);
    Color statusColor = _getStatusColor(weeksBeforeRetrieval);

    return Card(
      elevation: 5,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.symmetric(vertical: 10),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            // 📌 Compost Icon
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: statusColor.withOpacity(0.1),
              ),
              child: Icon(Icons.recycling, size: 30, color: statusColor),
            ),
            const SizedBox(width: 16),

            // 📌 Compost Date Details & Status
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Compost Cycle",
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.blueAccent.shade700),
                  ),
                  const SizedBox(height: 5),
                  Row(
                    children: [
                      const Icon(Icons.calendar_today,
                          size: 16, color: Colors.blueAccent),
                      const SizedBox(width: 8),
                      Text("Start: ${_formatDate(compost['start_date'])}",
                          style:
                              TextStyle(fontSize: 14, color: Colors.grey[700])),
                    ],
                  ),
                  Row(
                    children: [
                      const Icon(Icons.event,
                          size: 16, color: Colors.redAccent),
                      const SizedBox(width: 8),
                      Text("End: ${_formatDate(compost['end_date'])}",
                          style:
                              TextStyle(fontSize: 14, color: Colors.grey[700])),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // 📌 Display Weeks Before Retrieval
                  Text(
                    "Week Duration: $weeksBeforeRetrieval weeks",
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w500),
                  ),

                  const SizedBox(height: 8),

                  // 📌 Compost Status
                  Container(
                    padding:
                        const EdgeInsets.symmetric(vertical: 4, horizontal: 10),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      status,
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: statusColor),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

// 📌 Calculate Weeks Before Retrieval
  int _calculateWeeksBeforeRetrieval(DateTime startDate, DateTime? endDate) {
    final today = DateTime.now();
    return endDate == null
        ? today.difference(startDate).inDays ~/ 7
        : endDate.difference(startDate).inDays ~/ 7;
  }

// 📌 Determine Compost Status Based on Weeks Before Retrieval
  String _getCompostStatus(int weeks) {
    if (weeks >= 1 && weeks <= 7) {
      return "Retrieved Early: Not Ready"; // 🔴 Too soon
    } else if (weeks >= 8 && weeks <= 11) {
      return "Premature Compost Retrieval"; // 🟠 Taken before optimal composting
    } else if (weeks >= 12 && weeks <= 15) {
      return "Compost Fully Matured"; // 🟢 Perfect time
    } else {
      return "Overcomposted"; // ⚫ Left too long
    }
  }

// 📌 Assign Status Colors Based on Weeks Before Retrieval
  Color _getStatusColor(int weeks) {
    if (weeks >= 1 && weeks <= 7) {
      return Colors.redAccent; // 🔴 Not Ready
    } else if (weeks >= 8 && weeks <= 11) {
      return Colors.orangeAccent; // 🟠 Premature
    } else if (weeks >= 12 && weeks <= 15) {
      return Colors.green; // 🟢 Fully Matured
    } else {
      return Colors.grey; // ⚫ Overcomposted
    }
  }


// 📌 Calculate Compost Status Based on `_calculateContainerAge` logic
  String _calculateCompostStatus(DateTime startDate, DateTime? endDate) {
    final today = DateTime.now();
    final int ageWeeks = endDate == null
        ? today.difference(startDate).inDays ~/ 7
        : endDate.difference(startDate).inDays ~/ 7;

    if (ageWeeks < 4) {
      return "Retrieved Early: Not Ready"; // 🔴 Too soon
    } else if (ageWeeks >= 4 && ageWeeks < 7) {
      return "Premature Retrieval"; // 🟠 Taken before optimal composting
    } else if (ageWeeks >= 7 && ageWeeks < 12) {
      // ✅ Fix: `<=` changed to `<` for better accuracy
      return "Compost Fully Matured"; // 🟢 Perfect time
    } else {
      return "Overcomposted"; // 🔴 Left too long
    }
  }

  // 📌 Empty state UI when no compost records exist
  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.history, size: 80, color: Colors.grey),
          const SizedBox(height: 12),
          const Text(
            "No past compost records found",
            textAlign: TextAlign.center,
            style: TextStyle(
                fontSize: 18, fontWeight: FontWeight.w500, color: Colors.grey),
          ),
        ],
      ),
    );
  }

  // 📌 Format Date
  String _formatDate(String? date) {
    if (date == null || date.isEmpty) return "N/A";
    return DateFormat.yMMMMd().format(DateTime.parse(date));
  }
}
