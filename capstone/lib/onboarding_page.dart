import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';
import 'login_page.dart';

class OnboardingPage extends StatefulWidget {
  @override
  _OnboardingPageState createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  final PageController _controller = PageController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          PageView(
            controller: _controller,
            children: [
              OnboardingScreen(
                image: 'assets/feature1.png',
                title: 'Feature 1',
                description: 'Description of Feature 1',
              ),
              OnboardingScreen(
                image: 'assets/feature2.png',
                title: 'Feature 2',
                description: 'Description of Feature 2',
              ),
              OnboardingScreen(
                image: 'assets/feature3.png',
                title: 'Feature 3',
                description: 'Description of Feature 3',
              ),
            ],
          ),
          Positioned(
            bottom: 80, // Position above the bottom sheet
            left: 0,
            right: 0,
            child: Center(
              child: SmoothPageIndicator(
                controller: _controller, // PageController
                count: 3, // Number of pages
                effect: WormEffect(
                  dotWidth: 10.0,
                  dotHeight: 10.0,
                  spacing: 16.0,
                  activeDotColor: Colors.blue,
                  dotColor: Colors.grey,
                ),
              ),
            ),
          ),
        ],
      ),
      bottomSheet: Container(
        height: 60,
        width: double.infinity,
        color: Colors.white,
        child: Center(
          child: ElevatedButton(
            onPressed: () async {
              final prefs = await SharedPreferences.getInstance();
              await prefs.setBool('seenOnboarding', true);

              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => LoginPage()),
              );
            },
            child: Text('Get Started'),
          ),
        ),
      ),
    );
  }
}

class OnboardingScreen extends StatelessWidget {
  final String image;
  final String title;
  final String description;

  OnboardingScreen({
    required this.image,
    required this.title,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Image.asset(image),
          SizedBox(height: 20),
          Text(
            title,
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 10),
          Text(
            description,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 16),
          ),
        ],
      ),
    );
  }
}
