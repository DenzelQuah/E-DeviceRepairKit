import 'package:e_repairkit/viewmodels/chat_viewmodel.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class ChatHistoryDrawer extends StatefulWidget {
  const ChatHistoryDrawer({super.key});

  @override
  State<ChatHistoryDrawer> createState() => _ChatHistoryDrawerState();
}

class _ChatHistoryDrawerState extends State<ChatHistoryDrawer> {
  @override
  void initState() {
    super.initState();
    // Fetch real data when the drawer opens
    Future.microtask(() => 
      context.read<ChatViewModel>().fetchChatSessions()
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Drawer(
      backgroundColor: const Color(0xFF1E1E1E),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 50, 20, 20),
            child: Text(
              "Your chats",
              style: theme.textTheme.titleMedium?.copyWith(
                color: Colors.white70,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          
          const Divider(color: Colors.white10),

          // Real List of Chats
          Expanded(
            child: Consumer<ChatViewModel>(
              builder: (context, vm, child) {
                if (vm.sessions.isEmpty) {
                  return const Center(
                    child: Text(
                      "No history yet",
                      style: TextStyle(color: Colors.white38),
                    ),
                  );
                }

                return ListView.builder(
                  padding: EdgeInsets.zero,
                  itemCount: vm.sessions.length,
                  itemBuilder: (context, index) {
                    final session = vm.sessions[index];
                    final isSelected = session.id == vm.sessionId; // Highlight current

                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                      tileColor: isSelected ? Colors.white.withOpacity(0.1) : null,
                      
                      // Title
                      title: Text(
                        session.title,
                        style: TextStyle(
                          color: isSelected ? Colors.white : Colors.white70, 
                          fontSize: 14,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      
                      // Date (Optional)
                      subtitle: Text(
                        _formatDate(session.lastActive),
                        style: const TextStyle(color: Colors.white24, fontSize: 11),
                      ),
                      
                      // Action
                      onTap: () {
                        vm.loadSession(session);
                        Navigator.pop(context); // Close drawer
                      },
                    );
                  },
                );
              },
            ),
          ),
          
          const Divider(color: Colors.white24),
          
          // Bottom Options
          ListTile(
            leading: const Icon(Icons.settings, color: Colors.white70),
            title: const Text('Settings', style: TextStyle(color: Colors.white70)),
            onTap: () {},
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    // Simple formatter, or use DateFormat from intl package
    return "${date.day}/${date.month} ${date.hour}:${date.minute.toString().padLeft(2, '0')}";
  }
}