import 'package:flutter/material.dart';

/// Vista de Login
class LoginView extends StatelessWidget {
  const LoginView({super.key});
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Login'),
      ),
      body: const Center(
        child: Text(
          'Hello World - Login',
          style: TextStyle(fontSize: 24),
        ),
      ),
    );
  }
}
