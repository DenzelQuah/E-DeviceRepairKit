import 'package:flutter/material.dart';

//If i want to call this AppBar in any file just import this file and use AppBarWidget()
class AppBarWidget extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  const AppBarWidget({super.key,required this.title});

  @override
  Widget build(BuildContext context) {
    // Returns the AppBar with all the properties from your original file.
    return AppBar(
      // The title text that appears in the app bar.
      title:
      Text
        (
          title,
          style: TextStyle
          (
            fontFamily: 'Roboto',
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        
      // Sets the default color for icons and text within the app bar.
      foregroundColor: const Color.fromARGB(255, 0, 0, 0),
      backgroundColor: const Color.fromARGB(255, 255, 255, 255),
      centerTitle: true,
      elevation: 4.0,

      //Menu Bar Icon Button
      leading: IconButton(
          icon: const Icon(Icons.menu),
          onPressed: () {
            print('Menu button pressed');
            // Action to be performed when the settings icon is pressed.
          },
        ),

    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}