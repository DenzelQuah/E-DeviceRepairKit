import 'package:flutter/material.dart';
import '../../models/repair_suggestion.dart';

class SuggestionCard extends StatelessWidget {
  final RepairSuggestion suggestion;
  const SuggestionCard({super.key, required this.suggestion});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(top: 12.0),
      elevation: 2.0,
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              suggestion.title,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const Divider(),
            // Iterates over the steps and creates a numbered list
            ...suggestion.steps.map(
              (step) => ListTile(
                leading: CircleAvatar(
                  radius: 15,
                  child: Text('${suggestion.steps.indexOf(step) + 1}'),
                ),
                title: Text(step),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Tools: ${suggestion.tools.join(", ")}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            Text(
              'Time: ${suggestion.estimatedTimeMinutes} mins',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 8),
            if (suggestion.safetyNotes.isNotEmpty)
              Text(
                '⚠️ Safety Note: ${suggestion.safetyNotes}',
                style: const TextStyle(
                  color: Colors.red,
                  fontWeight: FontWeight.bold,
                ),
              ),
          ],
        ),
      ),
    );
  }
}