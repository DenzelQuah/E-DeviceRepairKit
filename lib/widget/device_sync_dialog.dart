import 'package:e_repairkit/services/forum_service.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/repair_suggestion.dart';
import '../services/offline_search_service.dart';

class DeviceSyncDialog extends StatefulWidget {
  final List<RepairSuggestion> forumData;

  const DeviceSyncDialog({super.key, required this.forumData});

  @override
  State<DeviceSyncDialog> createState() => _DeviceSyncDialogState();
}

class _DeviceSyncDialogState extends State<DeviceSyncDialog> {
  // 1. CHANGE: Use a List instead of a single String
  List<String> _selectedDevices = [];
  bool _isLoading = false;

  final List<String> _availableDevices = [
    'Smartphone',
    'Laptop',
    'Tablet',
    'Console',
    'Other',
    'All',
  ];

  @override
  void initState() {
    super.initState();
    _loadSavedDevices();
  }

  Future<void> _loadSavedDevices() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _selectedDevices = prefs.getStringList('user_device_types') ?? [];
    });
  }

Future<void> _startSync() async {
    if (_selectedDevices.isEmpty) return;

    setState(() => _isLoading = true);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('user_device_types', _selectedDevices);

    print("--- SYNC STARTED ---"); // DEBUG LOG
    
    // 1. Fetch ALL data
    final allSolutions = await context.read<ForumService>().getPublishedSolutions().first;
    
    print("Firestore found: ${allSolutions.length} total posts."); // DEBUG LOG: Tells you if DB fetch worked

    int count = 0;
    if (allSolutions.isNotEmpty) {
       List<String> typesToDownload = [];
       
       if (_selectedDevices.contains('All')) {
         typesToDownload = ['Smartphone', 'Laptop', 'Tablet', 'Console', 'Other'];
       } else {
         typesToDownload = List.from(_selectedDevices);
       }
       
       print("Downloading categories: $typesToDownload"); // DEBUG LOG

       // 2. Download
       // Note: We removed the .take(50) limit to try and get everything
       count = await context
          .read<OfflineSearchService>()
          .downloadTargetedSolutions(allSolutions, typesToDownload);
          
       print("Download finished. Saved: $count items."); // DEBUG LOG
    } else {
       print("Download skipped: No posts found in database."); // DEBUG LOG
    }

    setState(() => _isLoading = false);

    if (!mounted) return;
    Navigator.pop(context);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(count == 0 
            ? 'Sync complete but found 0 matching items.' 
            : 'Successfully saved $count solutions offline!'), 
        backgroundColor: count > 0 ? Colors.green : Colors.orange
      ),
    );
  }

  void _toggleDevice(String device) {
    setState(() {
      if (_selectedDevices.contains(device)) {
        _selectedDevices.remove(device);
      } else {
        _selectedDevices.add(device);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AlertDialog(
      title: const Text('Personalize Your Kit'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('Select devices to save fixes offline:'),
          const SizedBox(height: 16),
          if (_isLoading)
            const SizedBox(
              height: 50,
              child: Center(child: CircularProgressIndicator()),
            )
          else
            Wrap(
              spacing: 8.0,
              runSpacing: 4.0,
              children:
                  _availableDevices.map((device) {
                    final isSelected = _selectedDevices.contains(device);
                    // Special styling for "All"
                    final isAllTag = device == 'All';

                    return FilterChip(
                      label: Text(device),
                      selected: isSelected,
                      selectedColor:
                          isAllTag
                              ? theme.colorScheme.primary
                              : theme.colorScheme.primaryContainer,
                      labelStyle: TextStyle(
                        color:
                            (isAllTag && isSelected)
                                ? theme.colorScheme.onPrimary
                                : null,
                      ),
                      checkmarkColor:
                          (isAllTag && isSelected)
                              ? theme.colorScheme.onPrimary
                              : theme.colorScheme.primary,
                      onSelected: (_) => _toggleDevice(device),
                    );
                  }).toList(),
            ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton.icon(
          onPressed:
              (_selectedDevices.isNotEmpty && !_isLoading) ? _startSync : null,
          icon: const Icon(Icons.download_rounded),
          label: const Text('Sync Now'),
        ),
      ],
    );
  }
}
