import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:qr_scanner_overlay/qr_scanner_overlay.dart';

class ScannerPage extends StatefulWidget {
  final Function(String) onScanned; // Callback to return scanned data

  const ScannerPage({Key? key, required this.onScanned}) : super(key: key);

  @override
  _ScannerPageState createState() => _ScannerPageState();
}

class _ScannerPageState extends State<ScannerPage> {
  bool isScanning = true; // Ensures it only scans once
  MobileScannerController controller = MobileScannerController();

  @override
  void dispose() {
    controller.dispose(); // Clean up the scanner when closing the page
    super.dispose();
  }



  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Scan QR Code")),
      body: Stack(
        children: [MobileScanner(
          scanWindow: Rect.fromCenter(
            center: MediaQuery.of(context).size.center(Offset.zero),
            width: 250,
            height: 250,),
        controller: controller,
        onDetect: (capture) {
          if (!isScanning) return; // Ignore multiple scans

          final List<Barcode> barcodes = capture.barcodes;
          for (final barcode in barcodes) {
            if (barcode.rawValue != null) {
              setState(() => isScanning = false); // Stop scanning
              widget.onScanned(barcode.rawValue!);
              Navigator.pop(context); // Close scanner & go back
              break;
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

