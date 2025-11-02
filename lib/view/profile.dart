import 'package:e_repairkit/models/appuser.dart';
import 'package:e_repairkit/models/comment_forum.dart';
import 'package:e_repairkit/models/repair_suggestion.dart';
import 'package:e_repairkit/services/auth_service.dart';
import 'package:e_repairkit/services/feedback_service.dart';
import 'package:e_repairkit/services/forum_service.dart';
import 'package:e_repairkit/widget/suggestion_card.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:rxdart/rxdart.dart';

class ProfileView extends StatefulWidget {
  const ProfileView({super.key});

  @override
  State<ProfileView> createState() => _ProfileViewState();
}

class _ProfileViewState extends State<ProfileView> {
  Stream<List<Comment>>? _myCommentsStream;
  Stream<List<RepairSuggestion>>? _mySavedSolutionsStream;
  AppUser? _user;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // We initialize the streams here, based on the user
    final user = context.watch<AppUser?>();

    if (user != null && user.uid != _user?.uid) {
      _user = user;
      final forumService = context.read<ForumService>();
      final feedbackService = context.read<FeedbackService>();

      // Stream 1: Get all my comments
      _myCommentsStream = forumService.getComments(user.uid);

      // Stream 2: Get all my saved feedback, then use those IDs
      // to get the actual solutions.
      _mySavedSolutionsStream = feedbackService
          .getMySavedFeedback(user.uid)
          .switchMap((feedbackList) {
        final ids =
            feedbackList.map((f) => f.suggestionId).toSet().toList();
        if (ids.isEmpty) {
          return Stream.value([]); // Return an empty stream
        }
        return forumService.getSolutionsByIds(ids);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    // This should not be null if navigated from HomeView,
    // but we check just in case.
    if (_user == null) {
      return const Scaffold(
        body: Center(
          child: Text('Not logged in.'),
        ),
      );
    }

    // Use a TabController to manage the two sections
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Profile'),
          actions: [
            IconButton(
              icon: const Icon(Icons.logout),
              tooltip: 'Sign Out',
              onPressed: () async {
                Navigator.of(context).pop(); // Pop this page
                await context.read<AuthService>().signOut();
                // AuthWrapper will handle the rest
              },
            ),
          ],
        ),
        body: NestedScrollView(
          headerSliverBuilder: (context, innerBoxIsScrolled) {
            return [
              SliverToBoxAdapter(
                child: _buildProfileHeader(context, _user!, theme),
              ),
              SliverPersistentHeader(
                delegate: _SliverTabBarDelegate(
                  const TabBar(
                    tabs: [
                      Tab(icon: Icon(Icons.bookmark), text: 'Saved Solutions'),
                      Tab(icon: Icon(Icons.comment), text: 'My Comments'),
                    ],
                  ),
                ),
                pinned: true,
              ),
            ];
          },
          body: TabBarView(
            children: [
              _buildSavedSolutionsList(),
              _buildMyCommentsList(),
            ],
          ),
        ),
      ),
    );
  }

  /// The header part with the user's avatar and name
  Widget _buildProfileHeader(
      BuildContext context, AppUser user, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        children: [
          CircleAvatar(
            radius: 50,
            backgroundColor: theme.colorScheme.primaryContainer,
            backgroundImage:
                user.photoUrl != null ? NetworkImage(user.photoUrl!) : null,
            child: user.photoUrl == null
                ? Icon(
                    Icons.person,
                    size: 50,
                    color: theme.colorScheme.onPrimaryContainer,
                  )
                : null,
          ),
          const SizedBox(height: 16),
          Text(
            user.displayName ?? 'Repair Hero',
            style: theme.textTheme.headlineSmall,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            user.email ?? 'No email associated',
            style: theme.textTheme.bodyLarge,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  /// The TabView for "My Saved Solutions"
  Widget _buildSavedSolutionsList() {
    if (_mySavedSolutionsStream == null) return const SizedBox.shrink();

    return StreamBuilder<List<RepairSuggestion>>(
      stream: _mySavedSolutionsStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const Center(
            child: Text('You haven\'t saved any solutions yet.'),
          );
        }

        final solutions = snapshot.data!;
        return ListView.builder(
          padding: const EdgeInsets.all(8.0),
          itemCount: solutions.length,
          itemBuilder: (context, index) {
            // We can re-use the same SuggestionCard!
            return SuggestionCard(suggestion: solutions[index]);
          },
        );
      },
    );
  }

  /// The TabView for "My Comments"
  Widget _buildMyCommentsList() {
    if (_myCommentsStream == null) return const SizedBox.shrink();
    final theme = Theme.of(context);

    return StreamBuilder<List<Comment>>(
      stream: _myCommentsStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const Center(
            child: Text('You haven\'t commented on any posts yet.'),
          );
        }

        final comments = snapshot.data!;
        return ListView.builder(
          padding: const EdgeInsets.all(8.0),
          itemCount: comments.length,
          itemBuilder: (context, index) {
            final comment = comments[index];
            return Card(
              margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
              child: ListTile(
                title: Text(comment.text),
                subtitle: Text(
                  'On post: "${comment.postId}"', // You might want to fetch the post title here
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: theme.colorScheme.primary),
                ),
                onTap: () {
                  // This is tricky, we don't have the full suggestion object.
                  // This is a "TODO" to fix later.
                  // For now, we can't navigate.
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text('Cannot navigate to post from here (TODO)')),
                  );
                },
              ),
            );
          },
        );
      },
    );
  }
}

/// A helper class to make the TabBar "sticky" at the top
class _SliverTabBarDelegate extends SliverPersistentHeaderDelegate {
  _SliverTabBarDelegate(this._tabBar);

  final TabBar _tabBar;

  @override
  double get minExtent => _tabBar.preferredSize.height;
  @override
  double get maxExtent => _tabBar.preferredSize.height;

  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: Theme.of(context).colorScheme.surface,
      child: _tabBar,
    );
  }

  @override
  bool shouldRebuild(_SliverTabBarDelegate oldDelegate) {
    return false;
  }
}
