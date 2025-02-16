import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:image_picker/image_picker.dart';

class ScannerPage extends StatefulWidget {
  final Function(String) onScanned;

  const ScannerPage({Key? key, required this.onScanned}) : super(key: key);

  @override
  _ScannerPageState createState() => _ScannerPageState();
}

class _ScannerPageState extends State<ScannerPage> {
  bool isScanning = true;
  bool isProcessingImage = false;
  MobileScannerController controller = MobileScannerController();
  final ImagePicker _picker = ImagePicker();
  File? _selectedImage;

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  Future<void> scanImageFromGallery() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      setState(() {
        _selectedImage = File(image.path);
        isProcessingImage = true;
      });
      
      await Future.delayed(const Duration(seconds: 1));
      
      final BarcodeCapture? capture = await controller.analyzeImage(image.path);
      setState(() => isProcessingImage = false);
      
      if (capture != null && capture.barcodes.isNotEmpty) {
        final String? result = capture.barcodes.first.rawValue;
        if (result != null) {
          widget.onScanned(result);
          Navigator.pop(context);
          return;
        }
      }
      _showDialog("No QR code found in the image.");
    }
  }
  
  void _showDialog(String message) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text("Scan Result"),
          content: Text(message),
          actions: <Widget>[
            TextButton(
              child: const Text("OK", style: TextStyle(color: Colors.green)),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final scanWindowSize = 250.0;
    final screenSize = MediaQuery.of(context).size;
    final scanWindowRect = Rect.fromCenter(
      center: Offset(screenSize.width / 2, screenSize.height / 3),
      width: scanWindowSize,
      height: scanWindowSize,
    );

    return Scaffold(
      appBar: AppBar(title: const Text("Scan QR Code")),
      body: GestureDetector(
        onVerticalDragEnd: (details) {
          if (details.primaryVelocity != null && details.primaryVelocity! < -500) {
            scanImageFromGallery();
          }
        },
        child: Stack(
          children: [
            _selectedImage == null
                ? MobileScanner(
                    scanWindow: scanWindowRect,
                    controller: controller,
                    onDetect: (capture) {
                      if (!isScanning) return;
                      for (final barcode in capture.barcodes) {
                        if (barcode.rawValue != null) {
                          setState(() => isScanning = false);
                          widget.onScanned(barcode.rawValue!);
                          Navigator.pop(context);
                          break;
                        }
                      }
                    },
                  )
                : Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Image.file(
                          _selectedImage!,
                          width: screenSize.width * 0.8,
                          height: screenSize.width * 0.8,
                          fit: BoxFit.cover,
                        ),
                        const SizedBox(height: 20),
                        if (isProcessingImage)
                          const CircularProgressIndicator(),
                      ],
                    ),
                  ),
            if (_selectedImage == null)
              CustomPaint(
                size: screenSize,
                painter: ScanFramePainter(scanWindowRect),
              ),
            Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  "Swipe up to scan from gallery",
                  style: TextStyle(fontSize: 16, color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ScanFramePainter extends CustomPainter {
  final Rect scanWindow;
  final double strokeWidth = 4.0;
  final double cornerLength = 20.0;
  final Paint borderPaint = Paint()
    ..color = Colors.green
    ..strokeWidth = 4.0
    ..style = PaintingStyle.stroke;

  ScanFramePainter(this.scanWindow);

  @override
  void paint(Canvas canvas, Size size) {
    final Paint dimPaint = Paint()..color = Colors.black.withOpacity(0.5);

    Path dimPath = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height))
      ..addRect(scanWindow)
      ..fillType = PathFillType.evenOdd;
    canvas.drawPath(dimPath, dimPaint);

    Path path = Path();
    
    path.moveTo(scanWindow.left, scanWindow.top + cornerLength);
    path.lineTo(scanWindow.left, scanWindow.top);
    path.lineTo(scanWindow.left + cornerLength, scanWindow.top);

    path.moveTo(scanWindow.right - cornerLength, scanWindow.top);
    path.lineTo(scanWindow.right, scanWindow.top);
    path.lineTo(scanWindow.right, scanWindow.top + cornerLength);

    path.moveTo(scanWindow.left, scanWindow.bottom - cornerLength);
    path.lineTo(scanWindow.left, scanWindow.bottom);
    path.lineTo(scanWindow.left + cornerLength, scanWindow.bottom);

    path.moveTo(scanWindow.right - cornerLength, scanWindow.bottom);
    path.lineTo(scanWindow.right, scanWindow.bottom);
    path.lineTo(scanWindow.right, scanWindow.bottom - cornerLength);

    canvas.drawPath(path, borderPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}



// import 'package:flutter/material.dart';
// import 'package:intl/intl.dart';
// import 'package:mobile_scanner/mobile_scanner.dart';
// import 'package:shared_preferences/shared_preferences.dart';
// import 'package:supabase_flutter/supabase_flutter.dart';
// import 'package:qr_scanner_overlay/qr_scanner_overlay.dart';

// class ScannerPage extends StatefulWidget {
//   final Function(String) onScanned; // Callback to return scanned data

//   const ScannerPage({Key? key, required this.onScanned}) : super(key: key);

//   @override
//   _ScannerPageState createState() => _ScannerPageState();
// }

// class _ScannerPageState extends State<ScannerPage> {
//   bool isScanning = true; // Ensures it only scans once
//   MobileScannerController controller = MobileScannerController();

//   @override
//   void dispose() {
//     controller.dispose(); // Clean up the scanner when closing the page
//     super.dispose();
//   }



//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(title: const Text("Scan QR Code")),
//       body: Stack(
//         children: [MobileScanner(
//           scanWindow: Rect.fromCenter(
//             center: MediaQuery.of(context).size.center(Offset.zero),
//             width: 250,
//             height: 250,),
//         controller: controller,
//         onDetect: (capture) {
//           if (!isScanning) return; // Ignore multiple scans

//           final List<Barcode> barcodes = capture.barcodes;
//           for (final barcode in barcodes) {
//             if (barcode.rawValue != null) {
//               setState(() => isScanning = false); // Stop scanning
//               widget.onScanned(barcode.rawValue!);
//               Navigator.pop(context); // Close scanner & go back
//               break;
//             }
//           }
//         },
//       ),
//       QRScannerOverlay(
//             overlayColor: Colors.black.withOpacity(0.5),
//           )
//     ]
//     )
//     );
//   }
// }