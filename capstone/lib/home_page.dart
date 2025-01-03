import 'package:flutter/material.dart';

class HomePage extends StatefulWidget {
  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _currentIndex = 0; // Tracks the selected tab index

  // List of pages for each menu
  final List<Widget> _pages = [
    DashboardPage(),
    ContainerPage(),
    OthersPage(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('E-ComposThink Home'), // AppBar title
      ),
      body: _pages[_currentIndex], // Show the selected page
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index; // Update the selected tab
          });
        },
        items: [
          BottomNavigationBarItem(
            icon: Icon(Icons.dashboard),
            label: 'Dashboard',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.inbox),
            label: 'Container',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.more_horiz),
            label: 'Others',
          ),
        ],
      ),
    );
  }
}

// Placeholder for Dashboard page
class DashboardPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text('Dashboard Content'),
    );
  }
}

// Placeholder for Container page
class ContainerPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text('Container Content'),
    );
  }
}

// Placeholder for Others page
class OthersPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text('Others Content'),
    );
  }
}
