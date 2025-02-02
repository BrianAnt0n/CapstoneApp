import 'package:flutter/material.dart';

class ESPConnectionPage extends StatelessWidget {
  const ESPConnectionPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ESP Connection'),
      ),
      body: const Center(
        child: Text('ESP Connection Settings Here'),
      ),
    );
  }
}
