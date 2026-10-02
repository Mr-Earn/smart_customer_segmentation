import 'package:flutter/material.dart';

import '../app_theme.dart';

class SplashPage extends StatelessWidget {
  const SplashPage({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: forest,
    body: SafeArea(
      child: Center(
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0.82, end: 1),
          duration: const Duration(milliseconds: 700),
          curve: Curves.easeOutBack,
          builder: (context, scale, child) =>
              Transform.scale(scale: scale, child: child),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: lime,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(
                  Icons.scatter_plot_rounded,
                  color: forest,
                  size: 42,
                ),
              ),
              const SizedBox(height: 18),
              const Text(
                'MOSAIC',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 19,
                  letterSpacing: 2,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 5),
              const Text(
                'CUSTOMER INTELLIGENCE',
                style: TextStyle(
                  color: Color(0xFFB7C9BD),
                  fontSize: 10,
                  letterSpacing: 1,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 36),
              SizedBox(
                width: 90,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: const LinearProgressIndicator(
                    value: 0.72,
                    minHeight: 3,
                    backgroundColor: Color(0xFF49625A),
                    valueColor: AlwaysStoppedAnimation<Color>(lime),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
