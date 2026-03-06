import 'package:flutter/material.dart';

/// Vista de Onboarding
class OnboardingView extends StatelessWidget {
  const OnboardingView({super.key});
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Onboarding'),
      ),
      body: const Center(
        child: Text(
          'Hello World - Onboarding',
          style: TextStyle(fontSize: 24),
        ),
      ),
    );
  }
}
