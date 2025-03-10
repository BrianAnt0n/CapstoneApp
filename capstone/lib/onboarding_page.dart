import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';
import 'login_page.dart';

class OnboardingPage extends StatefulWidget {
  const OnboardingPage({super.key});

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
              const OnboardingScreen(
                image: 'assets/onboard_1.png',
                title: 'Purpose',
                description:
                    'E-ComposThink is a technologically advanced system that utilizes real-time monitoring and sensor technology to reduce food waste through composting.',
              ),
              const OnboardingScreen(
                image: 'assets/onboard_2.png',
                title: 'Significance',
                description:
                    'Having an Innovative Organic Waste Conversion can contribute to a better urban environment.',
              ),
              const OnboardingScreen(
                image: 'assets/onboard_3.png',
                title: 'Solution',
                description:
                    'E-ComposThink project offers a promising solution to address the growing issue of food waste and promote sustainable urban farming, it transforms how we approach food waste and urban farming.',
              ),
              OnboardingScreenWithButton(
                image: 'assets/onboard_4.png',
                title: '',
                description: '',
                onButtonPressed: () async {
                  final prefs = await SharedPreferences.getInstance();
                  await prefs.setBool('seenOnboarding', true);

                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (context) => const LoginPage()),
                  );
                },
              ),
            ],
          ),
          Positioned(
            bottom: 5, // Position above the bottom sheet
            left: 0,
            right: 0,
            child: Center(
              child: SmoothPageIndicator(
                controller: _controller, // PageController
                count: 4, // Number of pages
                effect: const WormEffect(
                  dotWidth: 10.0,
                  dotHeight: 10.0,
                  spacing: 16.0,
                  activeDotColor: Color.fromARGB(255, 81, 183, 2),
                  dotColor: Colors.grey,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class OnboardingScreen extends StatelessWidget {
  final String image;
  final String title;
  final String description;

  const OnboardingScreen({
    super.key,
    required this.image,
    required this.title,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Image.asset(
          image,
          fit: BoxFit.cover,
        ),
        Positioned(
          bottom: 85,
          left: 24,
          right: 24,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                description,
                textAlign: TextAlign.left,
                style: TextStyle(
                  fontSize: 20,
                  color: Colors.white.withOpacity(0.85), // ✅ Reduced opacity
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

//Placeholder for Button
class OnboardingScreenWithButton extends StatelessWidget {
  final String image;
  final String title;
  final String description;
  final VoidCallback onButtonPressed;

  const OnboardingScreenWithButton({
    super.key,
    required this.image,
    required this.title,
    required this.description,
    required this.onButtonPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Image.asset(
          image,
          fit: BoxFit.cover,
        ),
        Column(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    description,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 16,
                      color: Color.fromARGB(255, 255, 255, 255),
                    ),
                  ),
                  SizedBox(
                    width: double.infinity, // Button stretches to screen width
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                            vertical: 16.0), // Height of the button
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(
                              8.0), // Slightly rounded corners
                        ),
                        backgroundColor: const Color.fromARGB(
                            255, 9, 133, 0), // Button background color
                      ),
                      onPressed: onButtonPressed,
                      child: const Text(
                        'Get Started',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white, // Set text color to white
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }
}
