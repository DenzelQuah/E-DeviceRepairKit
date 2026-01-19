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

  /// Helper to handle API calls and reduce code duplication
  Future<void> _handleFeedback({
    required BuildContext context,
    required String userId,
    int? newRating,
    bool? newTried,
    bool? newSaved,
    required String successMessage,
  }) async {
    try {
      await context.read<ChatViewModel>().saveFeedback(
            suggestionId: widget.suggestion.id,
            userId: userId,
            rating: newRating ?? _rating,
            tried: newTried ?? _isTried,
            saved: newSaved ?? _isSaved,
          );

      if (mounted) {
        setState(() {
          if (newRating != null) _rating = newRating;
          if (newTried != null) _isTried = newTried;
          if (newSaved != null) _isSaved = newSaved;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(successMessage), duration: const Duration(seconds: 1)),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Action failed. Please check connection.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final userId = context.read<AppUser?>()?.uid ?? 'anonymous';

    return Card(
      margin: const EdgeInsets.only(top: 12.0),
      elevation: 2.0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Header (Problem & Solution)
            _buildHeader(context, theme),
            
            const SizedBox(height: 12),
            const Divider(),
            
            // 2. Steps List
            _buildSteps(theme),

            const SizedBox(height: 16),

            // 3. Metadata (Tools, Time, Safety)
            _buildMetaInfo(context, theme),

            const SizedBox(height: 8),

            // 4. Action Buttons
            _buildActionButtons(context, theme, userId),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Main Title: The User's Problem
        Text(
          widget.suggestion.query.isNotEmpty
              ? widget.suggestion.query
              : "General Repair Issue",
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        // Subtitle: The Suggested Fix
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: theme.colorScheme.primaryContainer.withOpacity(0.4),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: theme.colorScheme.primary.withOpacity(0.2)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.lightbulb_outline, size: 18, color: theme.colorScheme.primary),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  "Suggested Fix: ${widget.suggestion.title}",
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSteps(ThemeData theme) {
    return Column(
      children: widget.suggestion.steps.map((step) {
        int index = widget.suggestion.steps.indexOf(step) + 1;
        return Padding(
          padding: const EdgeInsets.only(bottom: 8.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 12,
                backgroundColor: theme.colorScheme.primaryContainer,
                child: Text(
                  '$index',
                  style: TextStyle(
                    fontSize: 12,
                    color: theme.colorScheme.onPrimaryContainer,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(step, style: const TextStyle(height: 1.4)),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildMetaInfo(BuildContext context, ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Tools & Time
        Row(
         children: [
            if (widget.suggestion.tools.isNotEmpty) ...[
              Icon(Icons.handyman_outlined, size: 16, color: theme.colorScheme.secondary),
              const SizedBox(width: 4),
              // --- FIX: Use Flexible to prevent overflow ---
              Flexible(
                child: Text(
                  widget.suggestion.tools.join(", "),
                  style: theme.textTheme.bodySmall,
                  overflow: TextOverflow.ellipsis, // Cut off with "..."
                  maxLines: 1, // Keep on one line
                ),
              ),
              const SizedBox(width: 16),
            ],
            
            // This will now stay visible even if the tool list is long
            Icon(Icons.timer_outlined, size: 16, color: theme.colorScheme.secondary),
            const SizedBox(width: 4),
            Text(
              '${widget.suggestion.estimatedTimeMinutes} mins',
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
        
        // Safety Note (Highlighted)
        if (widget.suggestion.safetyNotes.isNotEmpty) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.red.withOpacity(0.08),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.red.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.warning_amber_rounded, color: Colors.red, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    widget.suggestion.safetyNotes,
                    style: const TextStyle(
                      color: Colors.red,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildActionButtons(BuildContext context, ThemeData theme, String userId) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        // SAVE
        IconButton(
          icon: Icon(_isSaved ? Icons.bookmark : Icons.bookmark_border),
          color: _isSaved ? theme.colorScheme.secondary : null,
          tooltip: 'Save idea',
          onPressed: () => _handleFeedback(
            context: context,
            userId: userId,
            newSaved: !_isSaved,
            successMessage: _isSaved ? 'Unsaved' : 'Saved to Library',
          ),
        ),

        // TRIED
        IconButton(
          icon: Icon(_isTried ? Icons.check_circle : Icons.check_circle_outline),
          color: _isTried ? theme.colorScheme.primary : null,
          tooltip: 'I tried this',
          onPressed: () => _handleFeedback(
            context: context,
            userId: userId,
            newTried: !_isTried,
            successMessage: _isTried ? 'Marked as untried' : 'Marked as Tried',
          ),
        ),

        // RATE
        PopupMenuButton<int>(
          tooltip: 'Rate suggestion',
          onSelected: (val) => _handleFeedback(
            context: context,
            userId: userId,
            newRating: val,
            successMessage: 'Rated $val stars',
          ),
          itemBuilder: (_) => List.generate(
            5,
            (i) => PopupMenuItem(value: i + 1, child: Text('${i + 1} ⭐')),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12.0),
            child: Icon(
              _rating > 0 ? Icons.star : Icons.star_border,
              color: _rating > 0 ? theme.colorScheme.secondary : null,
            ),
          ),
        ),

        // SHARE (Only if tried)
        if (_isTried)
          IconButton(
            icon: const Icon(Icons.share),
            color: theme.colorScheme.primary,
            tooltip: 'Share experience',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => CreatePostView(suggestion: widget.suggestion),
                ),
              );
            },
          ),
      ],
    );
  }
}