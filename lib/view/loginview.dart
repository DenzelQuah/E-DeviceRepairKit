import 'package:e_repairkit/view/forgotpassword.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:e_repairkit/services/auth_service.dart';

class LoginView extends StatefulWidget {
  const LoginView({super.key});

  @override
  State<LoginView> createState() => _LoginViewState();
}

class _LoginViewState extends State<LoginView> {
  // --- STATE VARIABLES ---
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _usernameController = TextEditingController();

  bool _isLoginView = true; // Toggles between Login and Sign Up
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _usernameController.dispose();
    super.dispose();
  }

  /// Toggles the view between Login and Sign Up
  void _toggleView() {
    setState(() {
      _isLoginView = !_isLoginView;
      _formKey.currentState?.reset(); // Clear validation errors
    });
  }

  /// --- SUBMIT FOR LOGIN OR SIGN UP ---
  Future<void> _submitForm() async {
    // First, validate the form
    if (!(_formKey.currentState?.validate() ?? false)) {
      return; // Invalid form
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final authService = context.read<AuthService>();
      if (_isLoginView) {
        // --- LOGIN LOGIC ---
        await authService.signInWithEmailAndPassword(
          email: _emailController.text,
          password: _passwordController.text,
        );
      } else {
        // --- SIGN UP LOGIC ---
        await authService.signUpWithEmailAndPassword(
          email: _emailController.text,
          password: _passwordController.text,
          username: _usernameController.text,
        );
        // On successful sign up, toggle back to login view
        _toggleView();
        if (mounted) {
           ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Account created! Please log in.')),
          );
        }
      }
      // AuthWrapper will handle navigation
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString()),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  /// --- GOOGLE SIGN IN ---
  Future<void> _signInWithGoogle() async {
     setState(() {
      _isLoading = true;
    });
    try {
      await context.read<AuthService>().signInWithGoogle();
      // AuthWrapper will handle navigation
    } catch (e) {
       if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString()),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } finally {
       if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // --- Your App Icon ---
                CircleAvatar(
                  radius: 50,
                  backgroundColor: theme.colorScheme.primaryContainer,
                  child: Icon(
                    Icons.build_circle_outlined, // Placeholder
                    size: 50,
                    color: theme.colorScheme.onPrimaryContainer,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  _isLoginView ? 'Welcome Back!' : 'Create Account',
                  textAlign: TextAlign.center,
                  style: textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 32),

                // --- USERNAME FIELD (Sign Up Only) ---
                if (!_isLoginView)
                  TextFormField(
                    controller: _usernameController,
                    decoration: const InputDecoration(
                      labelText: 'Username',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.person),
                    ),
                    validator: (value) => (value?.isEmpty ?? true)
                        ? 'Please enter a username'
                        : null,
                  ),
                if (!_isLoginView) const SizedBox(height: 16),

                // --- EMAIL FIELD ---
                TextFormField(
                  controller: _emailController,
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.email),
                  ),
                  keyboardType: TextInputType.emailAddress,
                  validator: (value) => (value?.isEmpty ?? true)
                      ? 'Please enter an email'
                      : null,
                ),
                const SizedBox(height: 16),

                // --- PASSWORD FIELD ---
                TextFormField(
                  controller: _passwordController,
                  decoration: const InputDecoration(
                    labelText: 'Password',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.lock),
                  ),
                  obscureText: true,
                  validator: (value) {
                    if (value?.isEmpty ?? true) {
                      return 'Please enter a password';
                    }
                    if (!_isLoginView && value!.length < 6) {
                      return 'Password must be at least 6 characters';
                    }
                    return null;
                  },
                ),

                // --- FORGOT PASSWORD BUTTON (Login Only) ---
                if (_isLoginView)
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: _isLoading
                          ? null
                          : () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (context) =>
                                        const ForgotPasswordView()),
                              );
                            },
                      child: const Text('Forgot Password?'),
                    ),
                  ),
                const SizedBox(height: 16),

                // --- LOADING INDICATOR OR BUTTONS ---
                if (_isLoading)
                  const Center(child: CircularProgressIndicator())
                else ...[
                  // --- Main Action Button ---
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    onPressed: _submitForm,
                    child: Text(_isLoginView ? 'Login' : 'Create Account'),
                  ),
                  const SizedBox(height: 16),
                  const Row(
                    children: [
                      Expanded(child: Divider()),
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 8.0),
                        child: Text('OR'),
                      ),
                      Expanded(child: Divider()),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // --- Google Sign-In Button ---
                  ElevatedButton.icon(
                    icon: Image.asset(
                      'lib/assets/google_logo.png',
                      height: 24.0,
                      width: 24.0,
                    ),
                    label: const Text('Sign in with Google'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      textStyle: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    onPressed: _signInWithGoogle,
                  ),
                ],
                const SizedBox(height: 24),

                // --- TOGGLE BUTTON ---
                TextButton(
                  onPressed: _isLoading ? null : _toggleView,
                  child: Text(
                    _isLoginView
                        ? 'Don\'t have an account? Sign Up'
                        : 'Already have an account? Login',
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

