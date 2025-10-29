import 'package:flutter/material.dart';
import 'package:e_repairkit/widget/appbar.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[200],
      extendBodyBehindAppBar: true, // To allow body to extend behind the AppBar
      appBar: const AppBarWidget(
      title: 'E-Repair Kit Home Page',

      ),


      body: const Center(
        child: Text(
          'Welcome to the Home Page!',
          style: TextStyle(fontSize: 24),
        ),
      ),
    );
  }
  
  
}
