import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

class SplashScreen extends StatefulWidget {
  final VoidCallback onComplete;
  const SplashScreen({super.key, required this.onComplete});
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with TickerProviderStateMixin {
  late AnimationController _logoCtrl;
  late AnimationController _textCtrl;
  late AnimationController _pulseCtrl;
  late Animation<double> _logoScale;
  late Animation<double> _logoRotate;
  late Animation<double> _textFade;
  late Animation<Offset> _textSlide;
  late Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();

    // Logo animation
    _logoCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200));
    _logoScale = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _logoCtrl, curve: Curves.elasticOut));
    _logoRotate = Tween<double>(begin: -0.5, end: 0).animate(
      CurvedAnimation(parent: _logoCtrl, curve: Curves.easeOutCubic));

    // Text animation
    _textCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 800));
    _textFade = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _textCtrl, curve: Curves.easeOut));
    _textSlide = Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero).animate(
      CurvedAnimation(parent: _textCtrl, curve: Curves.easeOutCubic));

    // Pulse animation
    _pulseCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1500))
      ..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.7, end: 1.0).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));

    // Start sequence
    _logoCtrl.forward();
    Future.delayed(const Duration(milliseconds: 600), () {
      if (mounted) _textCtrl.forward();
    });

    // Auto-proceed after 2.5 seconds
    Future.delayed(const Duration(milliseconds: 2500), () {
      if (mounted) widget.onComplete();
    });
  }

  @override
  void dispose() {
    _logoCtrl.dispose();
    _textCtrl.dispose();
    _pulseCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft, end: Alignment.bottomRight,
            colors: [Color(0xFF0F0F23), Color(0xFF1A1A3E), Color(0xFF0D0D2B)],
          ),
        ),
        child: Stack(children: [
          // Animated background circles
          Positioned(top: -80, right: -80, child: AnimatedBuilder(
            animation: _pulseAnim,
            builder: (_, __) => Container(
              width: 300, height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(colors: [
                  AppColors.primary.withValues(alpha: 0.08 * _pulseAnim.value),
                  Colors.transparent]),
              ),
            ),
          )),
          Positioned(bottom: -120, left: -60, child: AnimatedBuilder(
            animation: _pulseAnim,
            builder: (_, __) => Container(
              width: 350, height: 350,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(colors: [
                  AppColors.accent.withValues(alpha: 0.06 * _pulseAnim.value),
                  Colors.transparent]),
              ),
            ),
          )),

          // Main content
          Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
            // Animated Logo
            ScaleTransition(
              scale: _logoScale,
              child: RotationTransition(
                turns: _logoRotate,
                child: Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    gradient: AppColors.primaryGradient,
                    borderRadius: BorderRadius.circular(28),
                    boxShadow: [
                      BoxShadow(color: AppColors.primary.withValues(alpha: 0.4),
                        blurRadius: 30, spreadRadius: 5),
                    ],
                  ),
                  child: const Icon(Icons.receipt_long, color: Colors.white, size: 56),
                ),
              ),
            ),
            const SizedBox(height: 32),

            // App Name
            SlideTransition(
              position: _textSlide,
              child: FadeTransition(
                opacity: _textFade,
                child: ShaderMask(
                  shaderCallback: (bounds) => const LinearGradient(
                    colors: [Color(0xFF00F5A0), Color(0xFF00D9F5), Color(0xFFA855F7)],
                  ).createShader(bounds),
                  child: const Text('My Billu', style: TextStyle(
                    fontSize: 42, fontWeight: FontWeight.w900,
                    color: Colors.white, letterSpacing: -1)),
                ),
              ),
            ),
            const SizedBox(height: 8),

            // Tagline
            FadeTransition(
              opacity: _textFade,
              child: Text('Smart Billing Software', style: TextStyle(
                fontSize: 14, fontWeight: FontWeight.w500,
                color: Colors.white.withValues(alpha: 0.5), letterSpacing: 2)),
            ),
            const SizedBox(height: 48),

            // Loading indicator
            FadeTransition(
              opacity: _textFade,
              child: SizedBox(
                width: 28, height: 28,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  valueColor: AlwaysStoppedAnimation(
                    AppColors.primary.withValues(alpha: 0.6)),
                ),
              ),
            ),
          ])),

          // Footer
          Positioned(
            bottom: 30, left: 0, right: 0,
            child: FadeTransition(
              opacity: _textFade,
              child: Text('Sumukha Tech Solutions',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 11, color: Colors.white.withValues(alpha: 0.2),
                  fontWeight: FontWeight.w500, letterSpacing: 1)),
            ),
          ),
        ]),
      ),
    );
  }
}
