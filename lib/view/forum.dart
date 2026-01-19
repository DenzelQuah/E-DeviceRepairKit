import 'package:e_repairkit/models/repair_suggestion.dart';
import 'package:e_repairkit/services/forum_service.dart';
import 'package:e_repairkit/view/post_detail.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class ForumView extends StatefulWidget {
  const ForumView({super.key});

  @override
  State<ForumView> createState() => _ForumViewState();
}

class _ForumViewState extends State<ForumView> {
  // Stream of RepairSuggestion objects
  late Stream<List<RepairSuggestion>> _postsStream;

  @override
  void initState() {
    super.initState();
    // Initialize the stream here to avoid "LateInitializationError"
    _postsStream = context.read<ForumService>().getPublishedSolutions();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Community Forum'),
      ),
      body: StreamBuilder<List<RepairSuggestion>>(
        stream: _postsStream,
        builder: (context, snapshot) {
          // 1. Loading State
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          
          // 2. Error State
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  'Error loading solutions: ${snapshot.error}',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          // 3. Empty State
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Text(
                  'No solutions published yet.\nTry an AI search to find and share one!',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: Colors.grey[600],
                      ),
                ),
              ),
            );
          }

          // 4. Success State
          final solutions = snapshot.data!;

          return ListView.builder(
            padding: const EdgeInsets.all(8.0),
            itemCount: solutions.length,
            itemBuilder: (context, index) {
              final solution = solutions[index];
              return _buildSolutionPostCard(context, solution);
            },
          );
        },
      ),
    );
  }

  /// Helper widget to build the card for each solution
  Widget _buildSolutionPostCard(BuildContext context, RepairSuggestion solution) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: InkWell(
        onTap: () {
          // Navigate to the full Detail Page
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => PostDetailView(suggestion: solution),
            ),
          );
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Title (The Problem)
              Text(
                solution.query, 
                style: theme.textTheme.titleLarge
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              // Subtitle (The Solution)
              Text(
                solution.title,
                style: theme.textTheme.titleMedium?.copyWith(
                  color: theme.colorScheme.primary,
                ),
              ),
              const SizedBox(height: 12),

              // Stats Row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildStatChip(
                    context,
                    icon: Icons.check_circle_outline,
                    label: '${solution.tryCount} tried',
                    color: theme.colorScheme.primary,
                  ),
                  _buildStatChip(
                    context,
                    icon: Icons.star_outline,
                    label: '${solution.avgRating.toStringAsFixed(1)} stars (${solution.ratingCount})',
                    color: theme.colorScheme.secondary,
                  ),
                  _buildStatChip(
                    context,
                    icon: Icons.comment_outlined,
                    label: '${solution.commentCount} comments',
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Helper for the small icon+text chips
  Widget _buildStatChip(BuildContext context,
      {required IconData icon, required String label, required Color color}) {
    return Row(
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 4),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(color: color),
        ),
      ],
    );
  }
}