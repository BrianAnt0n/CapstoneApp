import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

class ContainerDetails extends StatefulWidget {
  final int hardwareId; // Pass hardware ID when opening this page

  const ContainerDetails({super.key, required this.hardwareId});

  @override
  _ContainerDetailsState createState() => _ContainerDetailsState();
}

class _ContainerDetailsState extends State<ContainerDetails> {
  late Future<List<Map<String, dynamic>>> pastCompost;

  @override
  void initState() {
    super.initState();
    pastCompost = _fetchPastCompost(widget.hardwareId); // Fetch compost data
  }

  Future<List<Map<String, dynamic>>> _fetchPastCompost(int hardwareId) async {
    try {
      final response = await Supabase.instance.client
          .from('Compost_Data')
          .select()
          .eq('hardware_id', hardwareId)
          .order('end_date', ascending: false);

      print("Fetched ${response.length} past compost records.");
      return response;
    } catch (e) {
      print("Error fetching past compost: $e");
      return [];
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Container Details")),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Past Compost History",
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: FutureBuilder<List<Map<String, dynamic>>>(
                future: pastCompost,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    return const Center(
                        child: Text("Error loading compost history."));
                  }
                  if (!snapshot.hasData || snapshot.data!.isEmpty) {
                    return const Center(
                        child: Text("No past compost records found."));
                  }

                  return ListView.builder(
                    itemCount: snapshot.data!.length,
                    itemBuilder: (context, index) {
                      final compost = snapshot.data![index];
                      final startDate = compost['start_date'] != null
                          ? DateFormat.yMMMd()
                              .format(DateTime.parse(compost['start_date']))
                          : "N/A";
                      final endDate = compost['end_date'] != null
                          ? DateFormat.yMMMd()
                              .format(DateTime.parse(compost['end_date']))
                          : "N/A";

                      return Card(
                        margin: const EdgeInsets.symmetric(vertical: 8),
                        elevation: 3,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        child: ListTile(
                          title: Text("Start Date: $startDate"),
                          subtitle: Text("End Date: $endDate"),
                          leading:
                              const Icon(Icons.history, color: Colors.green),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
