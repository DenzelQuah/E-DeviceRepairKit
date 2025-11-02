import 'package:e_repairkit/models/repair_suggestion.dart'; // <-- 1. CHANGED IMPORT
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
  // --- 3. STREAM IS NOW List<RepairSuggestion> ---
  late Stream<List<RepairSuggestion>> _postsStream;

  @override
  void initState() {
    super.initState();
    // 4. CALL THE NEW SERVICE METHOD
    _postsStream = context.read<ForumService>().getPublishedSolutions();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Community Forum'),
        // 5. REMOVED FAB (Users don't create posts, they publish them)
      ),
      body: StreamBuilder<List<RepairSuggestion>>( // <-- 6. CHANGED MODEL
        stream: _postsStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
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

          // --- Success State (Show the list of solutions) ---
          final solutions = snapshot.data!;

          return ListView.builder(
            padding: const EdgeInsets.all(8.0),
            itemCount: solutions.length,
            itemBuilder: (context, index) {
              final solution = solutions[index];
              // --- 7. USE THE NEW POST CARD ---
              return _buildSolutionPostCard(context, solution);
            },
          );
        },
      ),
    );
  }

  /// A helper widget to build the card for each solution
  Widget _buildSolutionPostCard(BuildContext context, RepairSuggestion solution) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: InkWell(
        onTap: () {
          // --- 8. NAVIGATE TO THE NEW DETAIL PAGE ---
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
              // 1. The Post Title (from the problem)
              Text(
                solution.query, // This is the "Problem"
                style: theme.textTheme.titleLarge
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              // 2. The Solution Title
              Text(
                solution.title, // This is the solution title
                style: theme.textTheme.titleMedium?.copyWith(
                  color: theme.colorScheme.primary,
                ),
              ),
              const SizedBox(height: 12),

              // 3. Post Stats (Tries, Rating, Comments)
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
                    // Format rating to one decimal place
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

  // Helper for the stat chips
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
