import 'package:e_repairkit/models/appuser.dart';
import 'package:e_repairkit/view/create_post.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/repair_suggestion.dart';
import '../viewmodels/chat_viewmodel.dart';

class SuggestionCard extends StatefulWidget {
  final RepairSuggestion suggestion;
  const SuggestionCard({super.key, required this.suggestion});

  @override
  State<SuggestionCard> createState() => _SuggestionCardState();
}

class _SuggestionCardState extends State<SuggestionCard> {
  bool _isSaved = false;
  bool _isTried = false;
  int _rating = 0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;

    // Get the real user ID from the provider
    final userId = context.read<AppUser?>()?.uid ?? 'anonymous';

    return Card(
      margin: const EdgeInsets.only(top: 12.0),
      elevation: 2.0,
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.suggestion.title,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            if (widget.suggestion.query.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Text(
                  'Saved from: "${widget.suggestion.query}"',
                  style: textTheme.bodyMedium?.copyWith(
                    fontStyle: FontStyle.italic,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            const Divider(),
            ...widget.suggestion.steps.map(
              (step) => ListTile(
                leading: CircleAvatar(
                  radius: 15,
                  backgroundColor: theme.colorScheme.primaryContainer,
                  child: Text(
                    '${widget.suggestion.steps.indexOf(step) + 1}',
                    style: TextStyle(
                      color: theme.colorScheme.onPrimaryContainer,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                title: Text(step),
              ),
            ),
            const SizedBox(height: 8),
            if (widget.suggestion.tools.isNotEmpty)
              Text(
                'Tools: ${widget.suggestion.tools.join(", ")}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            Text(
              'Time: ${widget.suggestion.estimatedTimeMinutes} mins',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 8),
            if (widget.suggestion.safetyNotes.isNotEmpty)
              Text(
                '⚠️ Safety Note: ${widget.suggestion.safetyNotes}',
                style: const TextStyle(
                  color: Colors.red,
                  fontWeight: FontWeight.bold,
                ),
              ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                // --- "SAVE" BUTTON (BOOKMARK) ---
                IconButton(
                  icon: Icon(_isSaved ? Icons.bookmark : Icons.bookmark_border),
                  color: _isSaved ? theme.colorScheme.secondary : null,
                  tooltip: 'Save idea',
                  onPressed: () async {
                    try {
                      await context.read<ChatViewModel>().saveFeedback(
                            suggestionId: widget.suggestion.id,
                            userId: userId, // Use real ID
                            rating: _rating,
                            tried: _isTried,
                            saved: !_isSaved,
                          );
                      setState(() {
                        _isSaved = !_isSaved;
                      });
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                            content:
                                Text(_isSaved ? 'Saved idea' : 'Unsaved idea')),
                      );
                    } catch (e) {
                      ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Failed to save')));
                    }
                  },
                ),

                // --- "TRIED" BUTTON (CHECK) ---
                IconButton(
                  icon: Icon(_isTried
                      ? Icons.check_circle
                      : Icons.check_circle_outline),
                  color: _isTried ? theme.colorScheme.primary : null,
                  tooltip: 'I tried this',
                  onPressed: () async {
                    try {
                      await context.read<ChatViewModel>().saveFeedback(
                            suggestionId: widget.suggestion.id,
                            userId: userId, // Use real ID
                            rating: _rating,
                            tried: !_isTried,
                            saved: _isSaved,
                          );
                      setState(() {
                        _isTried = !_isTried;
                      });
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                            content: Text(_isTried
                                ? 'Marked as tried'
                                : 'Un-marked as tried')),
                      );
                    } catch (e) {
                      ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Failed to mark')));
                    }
                  },
                ),

                // --- "RATING" BUTTON (STAR) ---
                PopupMenuButton<int>(
                  tooltip: 'Rate this suggestion',
                  onSelected: (val) async {
                    try {
                      await context.read<ChatViewModel>().saveFeedback(
                            suggestionId: widget.suggestion.id,
                            userId: userId, // Use real ID
                            rating: val,
                            tried: _isTried,
                            saved: _isSaved,
                          );
                      setState(() {
                        _rating = val;
                      });
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Thanks for rating $val ⭐')),
                      );
                    } catch (e) {
                      ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Failed to rate')));
                    }
                  },
                  itemBuilder: (_) => List.generate(
                      5,
                      (i) => PopupMenuItem(
                          value: i + 1, child: Text('${i + 1} ⭐'))),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12.0),
                    child: Icon(
                      _rating > 0 ? Icons.star : Icons.star_border,
                      color: _rating > 0 ? theme.colorScheme.secondary : null,
                    ),
                  ),
                ),

                // --- "SHARE" BUTTON ---
                // This button only appears if `_isTried` is true
                if (_isTried)
                  IconButton(
                    icon: const Icon(Icons.share),
                    color: theme.colorScheme.primary,
                    tooltip: 'Share your experience',
                    onPressed: () {
                      // This navigation will now work
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => CreatePostView(
                            suggestion: widget.suggestion,
                          ),
                        ),
                      );
                    },
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

