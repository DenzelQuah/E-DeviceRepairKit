import 'package:e_repairkit/models/comment_forum.dart';
import 'package:e_repairkit/models/repair_suggestion.dart';
import 'package:e_repairkit/services/forum_service.dart';
import 'package:e_repairkit/widget/suggestion_card.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class PostDetailView extends StatefulWidget {
  final RepairSuggestion suggestion;
  const PostDetailView({super.key, required this.suggestion});

  @override
  State<PostDetailView> createState() => _PostDetailViewState();
}

class _PostDetailViewState extends State<PostDetailView> {
  late Stream<List<Comment>> _commentsStream;
  final _commentController = TextEditingController();
  bool _isCommenting = false;

  @override
  void initState() {
    super.initState();
    _commentsStream =
        context.read<ForumService>().getComments(widget.suggestion.id);
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _postComment() async {
    if (_commentController.text.isEmpty) {
      return;
    }
    setState(() {
      _isCommenting = true;
    });

    try {
      await context.read<ForumService>().addComment(
            solutionId: widget.suggestion.id,
            text: _commentController.text,
          );
      _commentController.clear();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to post comment: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isCommenting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.suggestion.query,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              children: [
                // 1. The full, interactive Solution Card
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: SuggestionCard(suggestion: widget.suggestion),
                ),
                // 2. The Comment Section
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text(
                    'Community Comments',
                    style: theme.textTheme.titleLarge
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                ),
                _buildCommentsList(),
              ],
            ),
          ),
          // 3. The "Add Comment" text field
          _buildCommentInputField(context),
        ],
      ),
    );
  }

  Widget _buildCommentsList() {
    return StreamBuilder<List<Comment>>(
      stream: _commentsStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(24.0),
              child: Text('Be the first to comment!'),
            ),
          );
        }

        final comments = snapshot.data!;
        return ListView.builder(
          itemCount: comments.length,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemBuilder: (context, index) {
            final comment = comments[index];
            return ListTile(
              title: Text(comment.username,
                  style: Theme.of(context).textTheme.titleSmall),
              subtitle: Text(comment.text,
                  style: Theme.of(context).textTheme.bodyMedium),
            );
          },
        );
      },
    );
  }

  Widget _buildCommentInputField(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(8.0),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 5,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _commentController,
              decoration: const InputDecoration(
                hintText: 'Add your thoughts...',
                border: OutlineInputBorder(),
              ),
              minLines: 1,
              maxLines: 4,
            ),
          ),
          const SizedBox(width: 8),
          _isCommenting
              ? const CircularProgressIndicator()
              : IconButton(
                  icon: const Icon(Icons.send),
                  onPressed: _postComment,
                  color: Theme.of(context).colorScheme.primary,
                ),
        ],
      ),
    );
  }
}
