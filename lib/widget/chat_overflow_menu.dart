import 'package:e_repairkit/viewmodels/chat_viewmodel.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart'; // Ensure this is imported
import 'package:provider/provider.dart';

class ChatOverflowMenu extends StatelessWidget {
  const ChatOverflowMenu({super.key});

  @override
  Widget build(BuildContext context) {
    final vm = context.read<ChatViewModel>();

    return PopupMenuButton<String>(
      icon: const Icon(Icons.more_vert),
      onSelected: (value) async {
        // --- 1. ATTACH PHOTO (RESTORED) ---
        if (value == 'attach') {
          final picker = ImagePicker();
          final picked = await picker.pickImage(
            source: ImageSource.camera,
            imageQuality: 75,
          );
          if (picked != null) {
            vm.setAttachedImagePath(picked.path);
          }
        } 
        
        // --- 2. NEW: OPEN HISTORY SLIDER ---
        else if (value == 'history') {
           Scaffold.of(context).openEndDrawer(); // This opens the drawer!
        }

        // --- 3. NEW: CLEAR CHAT ---
        else if (value == 'clear') {
           vm.resetSession();
        }

        // --- 4. MODES & CREATIVITY (EXISTING) ---
        else if (value == 'practical') {
          vm.setMode('practical');
        } else if (value == 'experimental') {
          vm.setMode('experimental');
        } else if (value == 'creativity') {
          // Show slider dialog
          double temp = vm.temperature;
          await showDialog<void>(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text('Creativity'),
              content: StatefulBuilder(
                builder: (c, setState) => Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Slider(
                      value: temp,
                      min: 0,
                      max: 1,
                      divisions: 10,
                      label: temp.toStringAsFixed(2),
                      onChanged: (v) => setState(() => temp = v),
                    ),
                    Text('Creativity: ${temp.toStringAsFixed(2)}'),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: () {
                    vm.setTemperature(temp);
                    Navigator.pop(ctx);
                  },
                  child: const Text('Save'),
                ),
              ],
            ),
          );
        }
      },
      itemBuilder: (context) => [
        // --- SECTION 1: ACTIONS ---
        const PopupMenuItem(
          value: 'clear',
          child: Row(
            children: [
              Icon(Icons.refresh, color: Colors.grey, size: 20),
              SizedBox(width: 12),
              Text('New Chat'),
            ],
          ),
        ),
        const PopupMenuItem(
          value: 'history',
          child: Row(
            children: [
              Icon(Icons.history, color: Colors.grey, size: 20),
              SizedBox(width: 12),
              Text('History'),
            ],
          ),
        ),
        const PopupMenuDivider(),
        
        // --- SECTION 2: TOOLS ---
        const PopupMenuItem(value: 'attach', child: Text('Attach photo')),
        const PopupMenuDivider(),
        
        // --- SECTION 3: MODES ---
        const PopupMenuItem(value: 'practical', child: Text('Mode: Practical')),
        const PopupMenuItem(value: 'experimental', child: Text('Mode: Experimental')),
        const PopupMenuItem(value: 'creativity', child: Text('Creativeness')),
      ],
    );
  }
}