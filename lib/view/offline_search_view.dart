import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/repair_suggestion.dart';
import '../services/offline_search_service.dart';
import '../widget/suggestion_card.dart';

class OfflineSearchView extends StatefulWidget {
  const OfflineSearchView({super.key});

  @override
  State<OfflineSearchView> createState() => _OfflineSearchViewState();
}

class _OfflineSearchViewState extends State<OfflineSearchView> {
  final _searchController = TextEditingController();
  late Future<List<RepairSuggestion>> _resultsFuture;

  @override
  void initState() {
    super.initState();
    _resultsFuture = _performSearch('');
    // keep a listener to update UI of clear icon (does not change logic)
    _searchController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<List<RepairSuggestion>> _performSearch(String query) {
    return context.read<OfflineSearchService>().searchOffline(query);
  }

  void _refreshSearch() {
    setState(() {
      _resultsFuture = _performSearch(_searchController.text);
    });
  }

  Map<String, List<RepairSuggestion>> _groupResults(
      List<RepairSuggestion> results) {
    final Map<String, List<RepairSuggestion>> grouped = {};
    for (final suggestion in results) {
      final key = suggestion.query.isNotEmpty ? suggestion.query : "Other";
      if (!grouped.containsKey(key)) {
        grouped[key] = [];
      }
      grouped[key]!.add(suggestion);
    }
    return grouped;
  }

  // Neon palette (dual)
  static const Color _neonA = Color(0xFF00FFD1); // aqua
  static const Color _neonB = Color(0xFF7A00FF); // purple
  static const Color _bg0 = Color(0xFF05031A);
  static const Color _bg1 = Color(0xFF0B052F);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // subtle gradient app bar + dark neon background
      backgroundColor: _bg0,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        toolbarHeight: 80,
        centerTitle: false,
        title: Row(
          children: [
            // small neon badge
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const RadialGradient(
                  colors: [_neonA, _neonB],
                ),
                boxShadow: [
                  BoxShadow(color: _neonA.withOpacity(0.14), blurRadius: 16, spreadRadius: 1),
                  BoxShadow(color: _neonB.withOpacity(0.08), blurRadius: 30, spreadRadius: 2),
                ],
              ),
              child: const Icon(Icons.build_rounded, color: Colors.black87, size: 22),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Offline Solutions', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white.withOpacity(0.95))),
                Text('Tap a problem to explore saved solutions', style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.55))),
              ],
            )
          ],
        ),
      ),
      body: Container(
        // subtle background gradient
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [_bg0, _bg1],
          ),
        ),
        child: Column(
          children: [
            // Neon search bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12),
              child: _NeonSearchField(
                controller: _searchController,
                onSubmitted: (_) => _refreshSearch(),
                onClear: () {
                  _searchController.clear();
                  _refreshSearch();
                },
              ),
            ),

            // Results
            Expanded(
              child: RefreshIndicator(
                color: _neonA,
                backgroundColor: Colors.transparent,
                onRefresh: () async => _refreshSearch(),
                child: FutureBuilder<List<RepairSuggestion>>(
                  future: _resultsFuture,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator.adaptive());
                    }

                    if (snapshot.hasError) {
                      return _buildEmptyState('An error occurred: ${snapshot.error}');
                    }

                    if (!snapshot.hasData || snapshot.data!.isEmpty) {
                      return _buildEmptyState('No solutions found.\n\nAsk the AI to save new solutions!');
                    }

                    final results = snapshot.data!;
                    final groupedResults = _groupResults(results);
                    final problems = groupedResults.keys.toList();

                    return ListView.separated(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      itemCount: problems.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final problem = problems[index];
                        final solutions = groupedResults[problem]!;

                        return _NeonExpansionTile(
                          title: problem,
                          count: solutions.length,
                          accentA: _neonA,
                          accentB: _neonB,
                          child: Column(
                            children: solutions
                                .map((s) => Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 6),
                                      child: SuggestionCard(suggestion: s),
                                    ))
                                .toList(),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(String message) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        SizedBox(height: MediaQuery.of(context).size.height / 5),
        // neon icon row
        Center(
          child: Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const RadialGradient(colors: [Color(0xFF00FFD1), Color(0xFF7A00FF)]),
              boxShadow: [BoxShadow(color: _neonA.withOpacity(0.18), blurRadius: 24, spreadRadius: 6)],
            ),
            child: const Icon(Icons.search_off_rounded, size: 48, color: Colors.black87),
          ),
        ),
        const SizedBox(height: 26),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28.0),
          child: Text(
            message,
            style: TextStyle(color: Colors.white.withOpacity(0.72), fontSize: 14),
            textAlign: TextAlign.center,
          ),
        ),
      ],
    );
  }
}

/// Neon search field widget (visual only; keeps your controller)
class _NeonSearchField extends StatelessWidget {
  final TextEditingController controller;
  final void Function(String) onSubmitted;
  final VoidCallback onClear;

  const _NeonSearchField({
    required this.controller,
    required this.onSubmitted,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    const Color neonA = Color(0xFF00FFD1);
    const Color neonB = Color(0xFF7A00FF);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.white12, Colors.white10],
        ),
        boxShadow: [
          BoxShadow(color: neonA.withOpacity(0.06), blurRadius: 22, spreadRadius: 2),
          BoxShadow(color: neonB.withOpacity(0.03), blurRadius: 40, spreadRadius: 2),
        ],
        border: Border.all(color: Colors.white12),
      ),
      child: Row(
        children: [
          const SizedBox(width: 10),
          Icon(Icons.search, color: neonA.withOpacity(0.95)),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: controller,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Search problems or keywords...',
                hintStyle: TextStyle(color: Colors.white.withOpacity(0.45)),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 16),
              ),
              onSubmitted: onSubmitted,
            ),
          ),
          if (controller.text.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: GestureDetector(
                onTap: onClear,
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(colors: [neonA, neonB]),
                    boxShadow: [BoxShadow(color: neonA.withOpacity(0.18), blurRadius: 16, spreadRadius: 1)],
                  ),
                  child: const Icon(Icons.clear, size: 18, color: Colors.black87),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// A custom expansion tile with neon header and subtle animation.
/// It preserves the behaviour of a typical ExpansionTile but upgrades visuals.
class _NeonExpansionTile extends StatefulWidget {
  final String title;
  final int count;
  final Widget child;
  final Color accentA;
  final Color accentB;

  const _NeonExpansionTile({
    required this.title,
    required this.count,
    required this.child,
    required this.accentA,
    required this.accentB,
  });

  @override
  State<_NeonExpansionTile> createState() => _NeonExpansionTileState();
}

class _NeonExpansionTileState extends State<_NeonExpansionTile> with SingleTickerProviderStateMixin {
  bool _open = false;
  late final AnimationController _anim;

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(vsync: this, duration: const Duration(milliseconds: 280));
  }

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  void _toggle() {
    setState(() {
      _open = !_open;
      if (_open) {
        _anim.forward();
      } else {
        _anim.reverse();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final shadow = [
      BoxShadow(color: widget.accentA.withOpacity(0.12), blurRadius: 20, spreadRadius: 1),
      BoxShadow(color: widget.accentB.withOpacity(0.06), blurRadius: 36, spreadRadius: 1),
    ];

    return GestureDetector(
      onTap: _toggle,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          gradient: _open
              ? LinearGradient(colors: [widget.accentA.withOpacity(0.06), widget.accentB.withOpacity(0.03)])
              : null,
          border: Border.all(color: Colors.white10),
          boxShadow: _open ? shadow : null,
        ),
        child: Column(
          children: [
            // Header
            Row(
              children: [
                // neon marker
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(colors: [widget.accentA, widget.accentB]),
                    boxShadow: [BoxShadow(color: widget.accentA.withOpacity(0.18), blurRadius: 10)],
                  ),
                ),
                const SizedBox(width: 12),

                // Title & count
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(widget.title, style: TextStyle(color: Colors.white.withOpacity(0.95), fontSize: 16, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 2),
                      Text('${widget.count} solution(s)', style: TextStyle(color: Colors.white.withOpacity(0.45), fontSize: 12)),
                    ],
                  ),
                ),

                // chevron animated
                RotationTransition(
                  turns: Tween(begin: 0.0, end: 0.5).animate(CurvedAnimation(parent: _anim, curve: Curves.easeInOut)),
                  child: Icon(Icons.expand_more_rounded, color: Colors.white.withOpacity(0.9)),
                ),
              ],
            ),

            // Animated child area
            SizeTransition(
              sizeFactor: CurvedAnimation(parent: _anim, curve: Curves.easeInOut),
              axisAlignment: -1.0,
              child: Padding(
                padding: const EdgeInsets.only(top: 10, bottom: 6),
                child: widget.child,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
