import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:qr_scanner_overlay/qr_scanner_overlay.dart';

class ScannerPage extends StatefulWidget {
  @override
  _ScannerPageState createState() => _ScannerPageState();
}

class _ScannerPageState extends State<ScannerPage> {
  final SupabaseClient supabase = Supabase.instance.client;
  bool _isScanning = true; // Flag to prevent multiple scans

  void _handleScannedData(String scannedData) async {
    if (!_isScanning) return;
    setState(() => _isScanning = false); // Disable further scans

    try {
      final qrResponse = await supabase
          .from('Containers_test')
          .select(
              'container_id, hardware_id, Hardware_Sensors_Test!Containers_test_hardware_id_fkey(qr_value)') // Use dot notation with !inner for join
          .eq('Hardware_Sensors_Test.qr_value',
              scannedData); // Apply WHERE condition

      if (qrResponse.isNotEmpty) {
        // Handle the data, e.g., navigate to a details page
        print(qrResponse);
      } else {
        print("No data found.");
      }
    } catch (e) {
      print("Error fetching data: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(title: Text("QR Scanner")),
        body: Stack(children: [
          MobileScanner(
            scanWindow: Rect.fromCenter(
            center: MediaQuery.of(context).size.center(Offset.zero),
            width: 250,
            height: 250,
          ),
            onDetect: (capture) {
              if (_isScanning && capture.barcodes.isNotEmpty) {
                final barcode = capture.barcodes.first;
                if (barcode.rawValue != null) {
                  _handleScannedData(barcode.rawValue!);
                  Navigator.pop(context); // Close scanner after scanning
                }
              }
            },
          ),
          QRScannerOverlay(
            overlayColor: Colors.black.withOpacity(0.5),
          )
        ]
      )
    );
  }
}
