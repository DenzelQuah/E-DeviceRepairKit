import 'package:e_repairkit/viewmodels/chat_viewmodel.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

class ChatOverflowMenu extends StatelessWidget {
  const ChatOverflowMenu({super.key});

  @override
  Widget build(BuildContext context) {
    final vm = context.read<ChatViewModel>();

    return PopupMenuButton<String>(
      icon: const Icon(Icons.more_vert),
      onSelected: (value) async {
        if (value == 'attach') {
          final picker = ImagePicker();
          final picked = await picker.pickImage(
            source: ImageSource.camera,
            imageQuality: 75,
          );
          if (picked != null) {
            vm.setAttachedImagePath(picked.path);
          }
        } else if (value == 'practical') {
          vm.setMode('practical');
        } else if (value == 'experimental') {
          vm.setMode('experimental');
        } else if (value == 'creativity') {
          // show a small dialog with slider
          double temp = vm.temperature;
          await showDialog<void>(
            context: context,
            builder:
                (ctx) => AlertDialog(
                  title: const Text('Creativity'),
                  content: StatefulBuilder(
                    builder:
                        (c, setState) => Column(
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
      itemBuilder:
          (context) => [
            const PopupMenuItem(value: 'attach', child: Text('Attach photo')),
            const PopupMenuDivider(),
            const PopupMenuItem(
              value: 'practical',
              child: Text('Mode: Practical'),
            ),
            const PopupMenuItem(
              value: 'experimental',
              child: Text('Mode: Experimental'),
            ),
            const PopupMenuDivider(),
            const PopupMenuItem(
              value: 'creativity',
              child: Text('Creativeness'),
            ),
          ],
    );
  }
}
