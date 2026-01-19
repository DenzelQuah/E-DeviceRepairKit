import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:e_repairkit/models/push_service.dart';
import 'package:e_repairkit/models/repair_suggestion.dart'; // Import the Model
import 'package:e_repairkit/services/forum_service.dart';
import 'package:e_repairkit/services/offline_search_service.dart';
import 'package:e_repairkit/view/forum.dart';
import 'package:e_repairkit/view/modeselection.dart';
import 'package:e_repairkit/view/offline_search_view.dart';
import 'package:e_repairkit/view/post_detail.dart'; // Import the new Detail View
import 'package:e_repairkit/view/profile.dart';
import 'package:e_repairkit/widget/device_sync_dialog.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class HomeView extends StatefulWidget {
  const HomeView({super.key});

  @override
  State<HomeView> createState() => _HomeViewState();
}

class _HomeViewState extends State<HomeView> {
  final int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    
    // Initialize Push Notifications and Check Device Sync
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      context.read<PushService>().initialize();
      _triggerAutoOfflineSync();

      final prefs = await SharedPreferences.getInstance();
      final userDevices = prefs.getStringList('user_device_types');

      if (userDevices == null && mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => const DeviceSyncDialog(forumData: []), 
        );
      }
    });
  }
/// Silently checks for internet and downloads favorite categories
  Future<void> _triggerAutoOfflineSync() async {
    // A. Check if user is online (Optional but recommended)
    final connectivityResult = await Connectivity().checkConnectivity();
    if (connectivityResult == ConnectivityResult.none) {
      print("Offline: Skipping auto-sync.");
      return; 
    }

    // B. Get User's Category Preferences
    final prefs = await SharedPreferences.getInstance();
    final savedCategories = prefs.getStringList('user_device_types') ?? [];
    
    // If user hasn't set up preferences yet, do nothing
    if (savedCategories.isEmpty) return;

    print("Auto-Syncing for categories: $savedCategories");

    // C. Fetch latest data from Firestore (e.g., last 20 posts)
    // We use 'first' to get a single snapshot instead of a stream
    final recentPosts = await context.read<ForumService>()
        .getPublishedSolutions()
        .first; 

    if (!mounted) return;

    // D. Run the Downloader
    // We reuse the exact same logic you built for the Dialog!
    
    // Handle "All" logic if it exists in prefs
    List<String> typesToDownload = [];
    if (savedCategories.contains('All')) {
      typesToDownload = ['Smartphone', 'Laptop', 'Tablet', 'Console', 'Other'];
    } else {
      typesToDownload = List.from(savedCategories);
    }

    final count = await context.read<OfflineSearchService>()
        .downloadTargetedSolutions(recentPosts, typesToDownload);

    print("Auto-Sync Complete: Saved $count new solutions for offline mode.");
  }


  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;

    // Responsive variables
    final screenWidth = MediaQuery.of(context).size.width;
    final double titleFont = (screenWidth * 0.065).clamp(22.0, 28.0);
    final double bodyFont = (screenWidth * 0.04).clamp(14.0, 16.0);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // --- 1. TOP ACTION CARD (Welcome Area) ---
              Container(
                padding: const EdgeInsets.all(24.0),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      theme.colorScheme.primary.withOpacity(1),
                      theme.colorScheme.surface,
                    ],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
                child: Column(
                  children: [
                    CircleAvatar(
                      radius: 40,
                      backgroundColor: theme.colorScheme.primaryContainer.withOpacity(0.5),
                      child: Icon(
                        Icons.smart_toy_outlined,
                        size: 45,
                        color: theme.colorScheme.onPrimaryContainer,
                      ),
                    ),
                    SizedBox(height: screenWidth * 0.04),
                    Text(
                      'Welcome to E-RepairKit',
                      style: textTheme.headlineSmall?.copyWith(
                        fontSize: titleFont,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: screenWidth * 0.02),

                    // Aesthetic Text
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary.withOpacity(1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        'Your pocket repair expert.\nGet instant AI help or browse your offline library.',
                        style: textTheme.bodyMedium?.copyWith(
                          fontFamily: 'Comic Sans MS',
                          fontSize: bodyFont + 0.8,
                          height: 1.6,
                          fontWeight: FontWeight.w200,
                          color: Colors.white,
                          letterSpacing: 0.3,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),

                    SizedBox(height: screenWidth * 0.07),
                    
                    // --- Action Cards (AI & Offline) ---
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                      child: Column(
                        children: [
                          // AI Chat Card
                          Card(
                            elevation: 4,
                            shadowColor: theme.colorScheme.primary.withOpacity(0.3),
                            color: theme.colorScheme.primaryContainer,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            child: InkWell(
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (cxt) => const ModeSelectionView()),
                                );
                              },
                              borderRadius: BorderRadius.circular(16),
                              child: Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: Row(
                                  children: [
                                    Icon(Icons.smart_toy_outlined, size: 30, color: theme.colorScheme.onPrimaryContainer),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Diagnose Your Device',
                                            style: textTheme.titleMedium?.copyWith(
                                              fontWeight: FontWeight.bold,
                                              color: theme.colorScheme.onPrimaryContainer,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            'Chat with our AI assistant for help.',
                                            style: textTheme.bodyMedium?.copyWith(
                                              color: theme.colorScheme.onPrimaryContainer.withOpacity(0.8),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Icon(Icons.chevron_right, color: theme.colorScheme.onPrimaryContainer.withOpacity(0.8)),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          // Offline Card
                          Card(
                            elevation: 0,
                            color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.7),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            child: InkWell(
                              onTap: () => _searchOfflineSolutions(context),
                              borderRadius: BorderRadius.circular(16),
                              child: Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: Row(
                                  children: [
                                    Icon(Icons.handyman_outlined, size: 30, color: theme.colorScheme.onSurfaceVariant),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Diagnose Device Offline',
                                            style: textTheme.titleMedium?.copyWith(
                                              fontWeight: FontWeight.bold,
                                              color: theme.colorScheme.onSurfaceVariant,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            'Browse your saved solution library.',
                                            style: textTheme.bodyMedium?.copyWith(
                                              color: theme.colorScheme.onSurfaceVariant.withOpacity(0.8),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Icon(Icons.chevron_right, color: theme.colorScheme.onSurfaceVariant.withOpacity(0.8)),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // --- 3. RECENT SOLUTIONS HEADER ---
              Padding(
                padding: const EdgeInsets.fromLTRB(16.0, 16.0, 8.0, 16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Recent Solutions',
                      style: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                    ),
                   TextButton(
  onPressed: () {
    // Navigate to the online Community Forum
    Navigator.push(
      context, 
      MaterialPageRoute(builder: (context) => const ForumView()),
    );
  },
  child: const Text('View All'),
),
                  ],
                ),
              ),

              // --- 4. RECENT SOLUTIONS LIST (UPDATED TO USE MODEL) ---
              StreamBuilder<List<RepairSuggestion>>(
                // Use the Model-based stream
                stream: context.read<ForumService>().getPublishedSolutions(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: Padding(padding: EdgeInsets.all(32), child: CircularProgressIndicator()));
                  }
                  if (snapshot.hasError) {
                    return Center(child: Text('Error loading forum: ${snapshot.error}'));
                  }

                  // Empty State
                  if (!snapshot.hasData || snapshot.data!.isEmpty) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 48.0),
                      child: Column(
                        children: [
                          Icon(Icons.public, size: 60, color: theme.colorScheme.onSurfaceVariant.withOpacity(0.5)),
                          const SizedBox(height: 16),
                          const Text('No Community Solutions Yet'),
                        ],
                      ),
                    );
                  }

                  // Take only the top 5 for the home screen
                  final recentSolutions = snapshot.data!.take(5).toList();

                  return ListView.builder(
                    itemCount: recentSolutions.length,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    itemBuilder: (context, index) {
                      final suggestion = recentSolutions[index];

                      return Card(
                        elevation: 2,
                        margin: const EdgeInsets.symmetric(vertical: 8),
                        clipBehavior: Clip.antiAlias,
                        child: InkWell(
                          // Navigate to the ROBUST PostDetailView
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => PostDetailView(suggestion: suggestion),
                              ),
                            );
                          },
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  suggestion.query, // The Problem
                                  style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, fontSize: 16),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    Icon(Icons.check_circle_outline, size: 16, color: theme.colorScheme.primary),
                                    const SizedBox(width: 8),
                                    Text(
                                      suggestion.title, // The Solution Title
                                      style: textTheme.bodySmall,
                                      maxLines: 1, 
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),

      // --- BOTTOM NAVIGATION BAR ---
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        type: BottomNavigationBarType.fixed,
        selectedItemColor: theme.colorScheme.primary,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.forum_outlined), label: 'Forum'),
          BottomNavigationBarItem(icon: Icon(Icons.bookmark_outline), label: 'Offline'),
          BottomNavigationBarItem(icon: Icon(Icons.person_outline), label: 'Profile'),
        ],
        onTap: (index) {
          switch (index) {
            case 0: break;
            case 1:
              Navigator.push(context, MaterialPageRoute(builder: (cxt) => const ForumView()));
              break;
            case 2:
              _searchOfflineSolutions(context);
              break;
            case 3:
              Navigator.push(context, MaterialPageRoute(builder: (cxt) => const ProfileView()));
              break;
          }
        },
      ),
    );
  }

  void _searchOfflineSolutions(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (cxt) => const OfflineSearchView()),
    );
  }
}