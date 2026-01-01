// OnboardingScreen (Updated with shared_preferences)
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'onboarding_page.dart';
import 'login_page.dart';
import 'package:famity/utills/animated_route.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _controller = PageController();
  int _currentIndex = 0;

  final List<Widget> pages = const [
    OnboardingPage(
      imagePath: 'assets/images/firstimage.png',
      title: 'Preserve Family Memories',
      description:
          "Capture the voices of your loved ones before time fades them. Memory Chain lets you record and archive precious stories, advice, and greetings — keeping them safe for future generations to listen, learn, and remember.",
    ),
    OnboardingPage(
      imagePath: 'assets/images/secondimage.png',
      title: 'Record and Archive Voice Stories',
      description:
          "Easily capture the voices of your loved ones—whether it’s a heartfelt message, life advice, or a cherished memory. Store them securely, so their stories live on through generations.",
    ),
    OnboardingPage(
      imagePath: 'assets/images/thirdimage.png',
      title: 'Playback on Family Tree Timeline',
      description:
          "Experience your family’s stories as they unfold across generations. Navigate through a visual family tree and listen to voice memories connected to each loved one, organized beautifully in time.",
    ),
  ];

  void nextPage() async {
    if (_currentIndex < pages.length - 1) {
      _controller.nextPage(
          duration: const Duration(milliseconds: 300), curve: Curves.easeIn);
    } else {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool("onboarding_seen", true); // ✅ Save completion
      Navigator.pushReplacement(
        context,
        SlidePageRoute(page: const LoginPage()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFE8D6FA),
      body: SafeArea(
        child: Stack(
          children: [
            PageView(
              controller: _controller,
              onPageChanged: (index) {
                setState(() {
                  _currentIndex = index;
                });
              },
              children: pages,
            ),
            Positioned(
              left: 20,
              bottom: 20,
              child: TextButton(
                onPressed: () async {
                  final prefs = await SharedPreferences.getInstance();
                  await prefs.setBool(
                      "onboarding_seen", true); // ✅ Save completion
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (_) => const LoginPage()),
                  );
                },
                child: const Text(
                  "Skip",
                  style: TextStyle(color: Colors.black),
                ),
              ),
            ),
            Positioned(
              right: 20,
              bottom: 20,
              child: ElevatedButton(
                onPressed: nextPage,
                style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30))),
                child: const Text("Next"),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
