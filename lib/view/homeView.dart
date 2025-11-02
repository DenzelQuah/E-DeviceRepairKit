import 'package:e_repairkit/models/push_service.dart';
import 'package:e_repairkit/models/repair_suggestion.dart';
import 'package:e_repairkit/services/offline_search_service.dart';
import 'package:e_repairkit/view/forum.dart';
import 'package:e_repairkit/view/modeselection.dart';
import 'package:e_repairkit/view/offline_search_view.dart';
import 'package:e_repairkit/view/profile.dart';
import 'package:e_repairkit/widget/suggestion_card.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';


class HomeView extends StatefulWidget {
  const HomeView({super.key});

  @override
  State<HomeView> createState() => _HomeViewState();
}

class _HomeViewState extends State<HomeView> {
  final int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;

    // --- 1. DEFINE YOUR RESPONSIVE VARIABLES ---
    final screenWidth = MediaQuery.of(context).size.width;
    // We use clamp() to make sure font is not too big or too small
    final double titleFont = (screenWidth * 0.065).clamp(22.0, 28.0);
    final double bodyFont = (screenWidth * 0.04).clamp(14.0, 16.0);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // --- 1. TOP ACTION CARD ---
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
                      backgroundColor:
                          theme.colorScheme.primaryContainer.withOpacity(0.5),
                          
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

                    
                    
                    // --- 2. UPDATED AESTHETIC TEXT ---
                Container(
  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
  decoration: BoxDecoration(
    color: theme.colorScheme.primary.withOpacity(1),
    borderRadius: BorderRadius.circular(20),
  ),
  child:
  Text(
  'Your pocket repair expert.\n'
  'Get instant AI help or browse your offline library.',
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
                    // --- END OF CHANGE ---

                    SizedBox(height: screenWidth * 0.07),
                  Padding(
  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
  child: Column(
    // We use a Column instead of a Row
    children: [
      // --- Card 1 (AI Chat) ---
      // This is the primary action, so it's more colorful
      Card(
        elevation: 4,
        shadowColor: theme.colorScheme.primary.withOpacity(0.3),
        color: theme.colorScheme.primaryContainer,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16)),
        child: InkWell(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (cxt) => const ModeSelectionView(),
              ),
            );
          },
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Icon(Icons.smart_toy_outlined,
                    size: 30,
                    color: theme.colorScheme.onPrimaryContainer),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Diagnose Your Device',
                          style: textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color:
                                  theme.colorScheme.onPrimaryContainer)),
                      const SizedBox(height: 2),
                      Text('Chat with our AI assistant for help.',
                          style: textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onPrimaryContainer
                                  .withOpacity(0.8))),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right,
                    color: theme.colorScheme.onPrimaryContainer
                        .withOpacity(0.8))
              ],
            ),
          ),
        ),
      ),

      const SizedBox(height: 12), // Spacer

      // --- Card 2 (Offline) ---
      // This is the secondary action, so it's more subtle
      Card(
        elevation: 0,
        color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.7),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16)),
        child: InkWell(
          onTap: () {
            _searchOfflineSolutions(context);
          },
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Icon(Icons.handyman_outlined,
                    size: 30,
                    color: theme.colorScheme.onSurfaceVariant),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Diagnose Device Offline',
                          style: textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: theme.colorScheme.onSurfaceVariant)),
                      const SizedBox(height: 2),
                      Text('Browse your saved solution library.',
                          style: textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant
                                  .withOpacity(0.8))),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right,
                    color:
                        theme.colorScheme.onSurfaceVariant.withOpacity(0.8))
              ],
            ),
          ),
        ),
      ),
    ],
  ),
)
                  ],
                ),
              ),

              // --- 3. LIST HEADER ---
              Padding(
                padding: const EdgeInsets.fromLTRB(16.0, 16.0, 8.0, 16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Recent Solutions',
                      style: textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    TextButton(
                      onPressed: () => _searchOfflineSolutions(context),
                      child: const Text('View All'),
                    ),
                  ],
                ),
              ),

              // --- 4. LIST VIEW ---
              FutureBuilder<List<RepairSuggestion>>(
                future: context.read<OfflineSearchService>().getAllSuggestions(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: Padding(
                        padding: EdgeInsets.all(32.0),
                        child: CircularProgressIndicator(),
                      ),
                    );
                  }
                  if (snapshot.hasError) {
                    return Center(
                        child: Text('Error: ${snapshot.error}',
                            textAlign: TextAlign.center));
                  }

                  // --- 3. UPDATED EMPTY STATE WIDGET ---
                  if (!snapshot.hasData || snapshot.data!.isEmpty) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24.0, vertical: 48.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.bookmark_outline,
                            size: 60,
                            color: theme.colorScheme.onSurfaceVariant.withOpacity(0.5),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Your Library is Empty',
                            style: textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Start an AI chat to save your first repair solution. Every fix you find builds your personal offline guide.',
                            textAlign: TextAlign.center,
                            style: textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant
                            ),
                          ),
                        ],
                      ),
                    );
                  }
                  // --- END OF CHANGE ---

                  final solutions = snapshot.data!;
                  final recentSolutions = solutions.take(3).toList();

                  return ListView.builder(
                    itemCount: recentSolutions.length,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    itemBuilder: (context, index) {
                      return SuggestionCard(suggestion: recentSolutions[index]);
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
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.forum_outlined),
            label: 'Forum',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.bookmark_outline),
            label: 'Offline',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline),
            label: 'Profile',
          ),
        ],
        onTap: (index) {
          switch (index) {
            case 0:
              break;
            case 1:
            Navigator.push(
            context,
            MaterialPageRoute(builder: (cxt) => const ForumView()),
            );
              break;
            case 2:
              _searchOfflineSolutions(context);
              break;
            case 3:
              Navigator.push(
                context,
                MaterialPageRoute(builder: (cxt) => const ProfileView()),
              );
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

  // lib/view/homeview.dart (excerpt)

@override
void initState() {
  super.initState();
  // Call initialization after the build phase is complete, ensuring context is ready
  WidgetsBinding.instance.addPostFrameCallback((_) {
    // Read the PushService and initialize it
    context.read<PushService>().initialize();

    print("Huawei Push Service initialization triggered from HomeView.");
  });
}

  
}
