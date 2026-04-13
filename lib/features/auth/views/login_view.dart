import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:nfc_manager/nfc_manager.dart';
import 'package:provider/provider.dart';
import '../viewmodels/auth_viewmodel.dart';
import '../../navigation/main_screen.dart';
import 'register_view.dart';

class LoginView extends StatefulWidget {
  const LoginView({super.key});

  @override
  State<LoginView> createState() => _LoginViewState();
}

class _LoginViewState extends State<LoginView> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _isNfcAvailable = false;
  late AuthViewModel _authViewModel;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _authViewModel = context.read<AuthViewModel>();
      _authViewModel.addListener(_onAuthChanged);
    });
    _initNfc();
  }

  Future<void> _initNfc() async {
    try {
      final available = await NfcManager.instance.isAvailable();
      if (!mounted) return;
      setState(() => _isNfcAvailable = available);
      if (available) _startNfcSession();
    } catch (_) {
    }
  }

  void _startNfcSession() {
    NfcManager.instance.startSession(
      onDiscovered: (NfcTag tag) async {
        await NfcManager.instance.stopSession();
        if (!mounted) return;
        context.read<AuthViewModel>().login(
          'prueba@uniandes.edu.co',
          'MyPass123',
          loginType: 'NFC',
        );
      },
    );
  }

  void _onAuthChanged() {
    if (!mounted) return;
    if (_authViewModel.status == AuthStatus.authenticated) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const MainScreen()),
        (route) => false,
      );
    }
  }

  @override
  void dispose() {
    _authViewModel.removeListener(_onAuthChanged);
    _emailController.dispose();
    _passwordController.dispose();
    if (_isNfcAvailable) NfcManager.instance.stopSession();
    super.dispose();
  }

  void _handleLogin() {
    if (_formKey.currentState!.validate()) {
      context.read<AuthViewModel>().login(
            _emailController.text.trim(),
            _passwordController.text,
            loginType: 'email-password',
          );
    }
  }

  void _navigateToRegister() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const RegisterView()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Consumer<AuthViewModel>(
          builder: (context, authVm, _) {
            return SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 40),
                    // Title
                    Center(
                      child: Text(
                        'AndesHub',
                        style: Theme.of(context)
                            .textTheme
                            .headlineMedium
                            ?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                    ),
                    const SizedBox(height: 48),

                    // NFC section
                    Column(
                      children: [
                        const SizedBox(height: 12),
                        Text(
                          'Tap your uniandes physical id in your cellphone for automatic login via NFC',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 13,
                            color: Theme.of(context)
                                .colorScheme
                                .onSurface
                                .withValues(alpha: 0.65),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 28),

                    // Separator
                    Row(
                      children: [
                        const Expanded(child: Divider()),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Text(
                            'or',
                            style: TextStyle(
                              fontSize: 13,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurface
                                  .withValues(alpha: 0.45),
                            ),
                          ),
                        ),
                        const Expanded(child: Divider()),
                      ],
                    ),
                    const SizedBox(height: 28),

                    // Email label
                    Text(
                      'Email',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      maxLength: 100,
                      inputFormatters: [
                        FilteringTextInputFormatter.deny(
                            RegExp(r'[\$!#%^&*()+=\[\]{}|\\;:"<>,?/~`]')),
                      ],
                      decoration: const InputDecoration(
                        hintText: 'Enter your email',
                        counterText: '',
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Email is required';
                        }
                        if (!value.trim().endsWith('@uniandes.edu.co')) {
                          return 'Must be a @uniandes.edu.co email';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 24),

                    // Password label
                    Text(
                      'Password',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _passwordController,
                      obscureText: _obscurePassword,
                      maxLength: 100,
                      decoration: InputDecoration(
                        hintText: 'Enter your password',
                        counterText: '',
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscurePassword
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                            color: Colors.grey,
                          ),
                          onPressed: () {
                            setState(() {
                              _obscurePassword = !_obscurePassword;
                            });
                          },
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Password is required';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 8),
                    const SizedBox(height: 32),

                    // Login button
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed:
                            authVm.status == AuthStatus.loading
                                ? null
                                : _handleLogin,
                        child: authVm.status == AuthStatus.loading
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.black87,
                                ),
                              )
                            : const Text('Login'),
                      ),
                    ),

                    // Error message
                    if (authVm.errorMessage != null) ...[
                      const SizedBox(height: 16),
                      Center(
                        child: Text(
                          authVm.errorMessage!,
                          style: const TextStyle(
                            color: Colors.red,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],

                    const SizedBox(height: 24),

                    // Sign up link
                    Center(
                      child: GestureDetector(
                        onTap: _navigateToRegister,
                        child: RichText(
                          text: TextSpan(
                            text: "Don't have an account? ",
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                              fontSize: 13,
                            ),
                            children: const [
                              TextSpan(
                                text: 'Sign Up',
                                style: TextStyle(
                                  color: Color(0xFF8B7E3B),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
