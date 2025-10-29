import 'package:e_repairkit/viewmodels/chat_viewmodel.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class ChatView extends StatefulWidget {
  const ChatView({super.key});

  @override
  State<ChatView> createState() => _ChatViewState();
}

class _ChatViewState extends State<ChatView> {
  final _textController = TextEditingController();
  final _scrollController = ScrollController();

  void _sendMessage() {
    final viewModel = context.read<ChatViewModel>();
    if (_textController.text.isNotEmpty) {
      viewModel.sendMessage(_textController.text);
      _textController.clear();
      // Scroll to bottom after message sends
      Future.delayed(Duration(milliseconds: 50), () => _scrollToBottom());
    }
  }

  void _scrollToBottom() {
    _scrollController.animateTo(
      _scrollController.position.maxScrollExtent,
      duration: Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    // "watch" rebuilds this widget when notifyListeners() is called
    final viewModel = context.watch<ChatViewModel>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('AI Repair Assistant'),
      ),


      // UI Structure
      body: Column(
        children: [
          // --- Message List ---
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              itemCount: viewModel.messages.length,
              itemBuilder: (context, index) {
                final message = viewModel.messages[index];
                return ListTile(
                  title: Text(message.text),
                  leading: message.isFromUser ? null : Icon(Icons.smart_toy),
                  trailing: message.isFromUser ? Icon(Icons.person) : null,
                );
                // We'll make this look nicer later
              },
            ),
          ),

          // --- Loading Indicator ---
          if (viewModel.isLoading)
            const Padding(
              padding: EdgeInsets.all(8.0),
              child: CircularProgressIndicator(),
            ),

          // --- Text Input ---
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _textController,
                    onSubmitted: (_) => _sendMessage(),
                    decoration: InputDecoration(
                      hintText: 'Describe your problem...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.send),
                  onPressed: _sendMessage,
                ),
              ],
            ),
          ),
        ],
      ),

      //End of Scaffold
    );
  }
}