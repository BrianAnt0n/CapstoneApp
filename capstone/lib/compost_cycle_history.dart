import 'package:flutter/material.dart';

class CompostCycleHistory extends StatelessWidget {
  final Map<String, dynamic> compost;

  const CompostCycleHistory({Key? key, required this.compost}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Compost Cycle History"),
        backgroundColor: Colors.blueAccent,
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Compost Cycle Details",
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.blueAccent.shade700,
              ),
            ),
            const SizedBox(height: 12),
            _buildDetailRow(Icons.calendar_today, "Start Date", compost['start_date']),
            _buildDetailRow(Icons.event, "End Date", compost['end_date'] ?? "Ongoing"),
            _buildDetailRow(Icons.person, "Started by", compost['started_by'] ?? "Unknown"),
            _buildDetailRow(Icons.person_outline, "Retrieved by", compost['retrieved_by'] ?? "Unknown"),
            const SizedBox(height: 20),
            Text(
              "Additional Information:",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            Text(
              compost['additional_info'] ?? "No additional details available.",
              style: const TextStyle(fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.blueAccent),
          const SizedBox(width: 12),
          Text(
            "$label: ",
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 16),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
