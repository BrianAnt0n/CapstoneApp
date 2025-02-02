import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:qr_scanner_overlay/qr_scanner_overlay.dart';

class ScannerPage extends StatefulWidget {

  @override
  _ScannerPageState createState() => _ScannerPageState();
}

class _ScannerPageState extends State<ScannerPage> {
  final MobileScannerController cameraController = MobileScannerController();

  void initState() {
    super.initState();
    cameraController.start();
  }

  @override
  void dispose() {
    cameraController.dispose(); // Release camera when exiting
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Scan QR Code')),
      body: MobileScanner(
              controller: cameraController,
              onDetect: (BarcodeCapture barcodeCapture) {  // ✅ Updated callback
          final List<Barcode> barcodes = barcodeCapture.barcodes;
          
          if (barcodes.isNotEmpty) {
            final String scannedValue = barcodes.first.rawValue ?? "Unknown QR Code";
            // Navigator.pop(context, scannedValue); // Return value to the previous page
            ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(scannedValue),
                    ),
                  );
          }
        },
              // onDetect: (barcode, args) {
              //     // String qrCode = capture.barcodes.first.rawValue.toString();
              //     if (barcode.rawValue != null) {
              //     final String qrCode = barcode.rawValue!;
              //     Navigator.pop(context, qrCode);
              //     }
              //     else {
              //       ScaffoldMessenger.of(context).showSnackBar(
              //       SnackBar(
              //         content: Text('No QR detected!'),
              //       ),
              //     );
              //     }
              //     // ScaffoldMessenger.of(context).showSnackBar(
              //     //   SnackBar(
              //     //     content: Text(qrScanned.toString()),
              //     //   ),
              //     // );
              // }
              ),
      );
  }
}
