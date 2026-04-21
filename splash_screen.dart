// lib/screens/splash_screen.dart

import 'package:flutter/material.dart';
import 'home_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  bool _showChoice = false;
  late AnimationController _controller;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 600));
    _fadeAnim = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _controller.forward();

    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _showChoice = true);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _enter(String mode) {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => HomeScreen(mode: mode)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FA),
      body: Center(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 400),
          child: _showChoice ? _choiceView(cs) : _logoView(cs),
        ),
      ),
    );
  }

  Widget _logoView(ColorScheme cs) {
    return FadeTransition(
      opacity: _fadeAnim,
      child: Column(
        key: const ValueKey('logo'),
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // App Logo
          Container(
            width: 110, height: 110,
            decoration: BoxDecoration(
              color: cs.primary,
              borderRadius: BorderRadius.circular(28),
              boxShadow: [
                BoxShadow(
                  color: cs.primary.withOpacity(0.3),
                  blurRadius: 32, spreadRadius: 4,
                ),
              ],
            ),
            child: Stack(alignment: Alignment.center, children: [
              Positioned.fill(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(28),
                  child: CustomPaint(painter: _GridPainter(color: Colors.white)),
                ),
              ),
              const Icon(Icons.calendar_month_rounded,
                  size: 48, color: Colors.white),
            ]),
          ),
          const SizedBox(height: 24),
          const Text('TimeTable',
            style: TextStyle(
              fontSize: 32, fontWeight: FontWeight.w900,
              color: Color(0xFF1A56DB), letterSpacing: 0.5,
            )),
          const SizedBox(height: 6),
          const Text('Smart Schedule Generator',
            style: TextStyle(fontSize: 13, color: Color(0xFF6B7280))),
          const SizedBox(height: 40),
          SizedBox(
            width: 32, height: 32,
            child: CircularProgressIndicator(
              color: cs.primary, strokeWidth: 2.5),
          ),
        ],
      ),
    );
  }

  Widget _choiceView(ColorScheme cs) {
    return Padding(
      key: const ValueKey('choice'),
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Mini logo
          Container(
            width: 72, height: 72,
            decoration: BoxDecoration(
              color: cs.primary,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(color: cs.primary.withOpacity(0.25), blurRadius: 20)],
            ),
            child: Stack(alignment: Alignment.center, children: [
              Positioned.fill(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: CustomPaint(painter: _GridPainter(color: Colors.white)),
                ),
              ),
              const Icon(Icons.calendar_month_rounded,
                  size: 32, color: Colors.white),
            ]),
          ),
          const SizedBox(height: 20),
          const Text('Choose Institution Type',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800,
                color: Color(0xFF1A1F36))),
          const SizedBox(height: 6),
          const Text('Setup adapts based on your institution',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: Color(0xFF6B7280))),
          const SizedBox(height: 36),

          _modeCard(
            cs: cs,
            icon: Icons.school_rounded,
            title: 'School',
            subtitle: 'Manage classes, sections & teachers',
            color: const Color(0xFF1A56DB),
            onTap: () => _enter('school'),
          ),
          const SizedBox(height: 14),
          _modeCard(
            cs: cs,
            icon: Icons.account_balance_rounded,
            title: 'College',
            subtitle: 'Manage departments, semesters & faculty',
            color: const Color(0xFF0E9F6E),
            onTap: () => _enter('college'),
          ),
        ],
      ),
    );
  }

  Widget _modeCard({
    required ColorScheme cs,
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.25), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.08),
              blurRadius: 12, offset: const Offset(0, 4)),
          ],
        ),
        child: Row(children: [
          Container(
            width: 52, height: 52,
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Center(child: Icon(icon, color: color, size: 26)),
          ),
          const SizedBox(width: 16),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title,
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold,
                  color: color)),
            const SizedBox(height: 3),
            Text(subtitle,
              style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
          ])),
          Icon(Icons.arrow_forward_ios_rounded,
              size: 14, color: color.withOpacity(0.5)),
        ]),
      ),
    );
  }
}

// Subtle timetable grid lines for the logo background
class _GridPainter extends CustomPainter {
  final Color color;
  const _GridPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withOpacity(0.12)
      ..strokeWidth = 1;
    for (int i = 1; i <= 3; i++) {
      final x = size.width * i / 4;
      canvas.drawLine(
          Offset(x, size.height * 0.15), Offset(x, size.height * 0.85), paint);
    }
    for (int i = 1; i <= 3; i++) {
      final y = size.height * i / 4;
      canvas.drawLine(
          Offset(size.width * 0.15, y), Offset(size.width * 0.85, y), paint);
    }
  }

  @override
  bool shouldRepaint(_) => false;
}
