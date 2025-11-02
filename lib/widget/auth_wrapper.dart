import 'package:e_repairkit/models/appuser.dart';
import 'package:e_repairkit/view/homeview.dart';
import 'package:e_repairkit/view/loginview.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';


class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    // Listen to the AppUser stream from your StreamProvider
    final appUser = context.watch<AppUser?>();

    if (appUser != null) {
      // If user is logged in, show the HomeView
      return const HomeView();
    } else {
      // If user is not logged in, show the LoginView
      // TODO: Create LoginView.dart
      // For now, let's just show a placeholder
      return const LoginView(); 
    }
  }
}
