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

  // 📌 Build a compost card with inline details
  Widget _buildCompostCard(Map<String, dynamic> compost) {
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
                color: Colors.blueAccent.withOpacity(0.1),
              ),
              child: const Icon(Icons.recycling,
                  size: 30, color: Colors.blueAccent),
            ),
            const SizedBox(width: 16),

            // 📌 Compost Date Details
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
                      Text(
                        "Start: ${_formatDate(compost['start_date'])}",
                        style: TextStyle(fontSize: 14, color: Colors.grey[700]),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      const Icon(Icons.event,
                          size: 16, color: Colors.redAccent),
                      const SizedBox(width: 8),
                      Text(
                        "End: ${_formatDate(compost['end_date'])}",
                        style: TextStyle(fontSize: 14, color: Colors.grey[700]),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
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
