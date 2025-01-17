import 'package:flutter/material.dart';

class AppGuidePage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('App Guide'),
      ),
      body: ListView(
        children: [
          ListTile(
            leading: Icon(Icons.dashboard),
            title: Text('Application Dashboard'),
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
            leading: Icon(Icons.storage),
            title: Text('Container Management'),
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
            leading: Icon(Icons.device_hub),
            title: Text('ESP32 Connection'),
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
            leading: Icon(Icons.qr_code),
            title: Text('QR Code Scan'),
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
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Application Dashboard')),
      body: Center(child: Text('Application Dashboard Content')),
    );
  }
}

class ContainerManagementPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Container Management')),
      body: Center(child: Text('Container Management Content')),
    );
  }
}

class ESP32ConnectionPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('ESP32 Connection')),
      body: Center(child: Text('ESP32 Connection Content')),
    );
  }
}

class QRCodeScanPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('QR Code Scan')),
      body: Center(child: Text('QR Code Scan Content')),
    );
  }
}
