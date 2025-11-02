import 'package:e_repairkit/models/appuser.dart';
import 'package:e_repairkit/services/auth_service.dart';
import 'package:e_repairkit/view/homeview.dart';
import 'package:e_repairkit/view/loginview.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    // Get the auth service
    final authService = context.watch<AuthService>();

    // Listen to the stream of auth changes
    return StreamBuilder<AppUser?>(
      stream: authService.onAuthStateChanged,
      builder: (context, snapshot) {
        // 1. If the stream is still loading, show a spinner
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        // 2. If the stream has data (a user), show the HomeView
        if (snapshot.hasData) {
          return const HomeView();
        }

        // 3. If the stream has no data (user is null), show the LoginView
        return const LoginView();
      },
    );
  }
}
