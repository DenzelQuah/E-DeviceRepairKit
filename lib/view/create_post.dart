import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:e_repairkit/models/repair_suggestion.dart';
import 'package:e_repairkit/services/forum_service.dart';
import 'package:e_repairkit/widget/suggestion_card.dart';

class CreatePostView extends StatefulWidget {
  // This page accepts the suggestion the user wants to share
  final RepairSuggestion suggestion;

  const CreatePostView({super.key, required this.suggestion});

  @override
  State<CreatePostView> createState() => _CreatePostViewState();
}

class _CreatePostViewState extends State<CreatePostView> {
  final _contentController = TextEditingController();
  final _titleController = TextEditingController();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    // Pre-fill the title with the user's original problem
    _titleController.text = widget.suggestion.query;
  }

  @override
  void dispose() {
    _contentController.dispose();
    _titleController.dispose();
    super.dispose();
  }

  Future<void> _submitPost() async {
    if (_titleController.text.isEmpty || _contentController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill out a title and your review.')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // Call the service to create the post
      await context.read<ForumService>().createPost(
            title: _titleController.text,
            content: _contentController.text,
            suggestion: widget.suggestion,
          );
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Post shared successfully!')),
        );
        Navigator.pop(context); // Go back to the previous screen
      }

    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to share post: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

@override
Widget build(BuildContext context) {
  final theme = Theme.of(context);
  final colorScheme = theme.colorScheme;

  return Scaffold(
    backgroundColor: colorScheme.surface,
    appBar: AppBar(
      elevation: 0,
      title: const Text('Share Your Experience'),
      centerTitle: true,
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: 12.0),
          child: _isLoading
              ? const Padding(
                  padding: EdgeInsets.all(10.0),
                  child: SizedBox(
                    height: 22,
                    width: 22,
                    child: CircularProgressIndicator(strokeWidth: 2.5),
                  ),
                )
              : TextButton(
                  onPressed: _submitPost,
                  style: TextButton.styleFrom(
                    foregroundColor: colorScheme.primary,
                    textStyle: const TextStyle(
                        fontWeight: FontWeight.bold, letterSpacing: 1.0),
                  ),
                  child: const Text('SHARE'),
                ),
        ),
      ],
    ),
    body: SingleChildScrollView(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1️⃣ Title Field
          Text(
            'Problem / Title',
            style: theme.textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: colorScheme.surface,
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  offset: const Offset(3, 3),
                  blurRadius: 6,
                ),
                BoxShadow(
                  color: Colors.white.withOpacity(0.8),
                  offset: const Offset(-2, -2),
                  blurRadius: 6,
                ),
              ],
            ),
            child: TextField(
              controller: _titleController,
              decoration: InputDecoration(
                hintText: 'e.g., My phone screen was cracked',
                hintStyle: theme.textTheme.bodyMedium
                    ?.copyWith(color: colorScheme.onSurface.withOpacity(0.5)),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                border: InputBorder.none,
              ),
            ),
          ),

          const SizedBox(height: 28),

          // 2️⃣ Review Field
          Text(
            'Your Review / Thoughts',
            style: theme.textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: colorScheme.surface,
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  offset: const Offset(3, 3),
                  blurRadius: 6,
                ),
                BoxShadow(
                  color: Colors.white.withOpacity(0.8),
                  offset: const Offset(-2, -2),
                  blurRadius: 6,
                ),
              ],
            ),
            child: TextField(
              controller: _contentController,
              minLines: 5,
              maxLines: 10,
              decoration: InputDecoration(
                hintText:
                    'e.g., “This solution worked great, but be careful with step 2…”',
                hintStyle: theme.textTheme.bodyMedium
                    ?.copyWith(color: colorScheme.onSurface.withOpacity(0.5)),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                border: InputBorder.none,
              ),
            ),
          ),

          const SizedBox(height: 32),

          // 3️⃣ Read-only Shared Solution
          Text(
            'You are sharing this solution:',
            style: theme.textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
          AbsorbPointer(
            child: Container(
              decoration: BoxDecoration(
                color: colorScheme.surface,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    offset: const Offset(3, 3),
                    blurRadius: 6,
                  ),
                  BoxShadow(
                    color: Colors.white.withOpacity(0.8),
                    offset: const Offset(-2, -2),
                    blurRadius: 6,
                  ),
                ],
              ),
              child: SuggestionCard(suggestion: widget.suggestion),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    ),
  );
}

}

