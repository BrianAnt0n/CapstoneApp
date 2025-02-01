import 'package:flutter/material.dart';

class AppGuidePage extends StatelessWidget {
  const AppGuidePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('App Guide'),
      ),
      body: ListView(
        children: [
          ListTile(
            leading: const Icon(Icons.dashboard),
            title: const Text('Application Dashboard'),
            onTap: () {
              // Navigate to Application Dashboard page
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ApplicationDashboardPage(),
                ),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.storage),
            title: const Text('Container Management'),
            onTap: () {
              // Navigate to Container Management page
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ContainerManagementPage(),
                ),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.device_hub),
            title: const Text('ESP32 Connection'),
            onTap: () {
              // Navigate to ESP32 Connection page
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ESP32ConnectionPage(),
                ),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.qr_code),
            title: const Text('QR Code Scan'),
            onTap: () {
              // Navigate to QR Code Scan page
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => QRCodeScanPage(),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

// Placeholder pages for the menu items
class ApplicationDashboardPage extends StatelessWidget {
  const ApplicationDashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Application Dashboard')),
      body: const Center(child: Text('Application Dashboard Content')),
    );
  }
}

class ContainerManagementPage extends StatelessWidget {
  const ContainerManagementPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Container Management')),
      body: const Center(child: Text('Container Management Content')),
    );
  }
}

class ESP32ConnectionPage extends StatelessWidget {
  const ESP32ConnectionPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('ESP32 Connection')),
      body: const Center(child: Text('ESP32 Connection Content')),
    );
  }
}

class QRCodeScanPage extends StatelessWidget {
  const QRCodeScanPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('QR Code Scan')),
      body: const Center(child: Text('QR Code Scan Content')),
    );
  }
}
