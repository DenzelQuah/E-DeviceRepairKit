import 'package:e_repairkit/models/message.dart';
import 'package:e_repairkit/viewmodels/chat_viewmodel.dart';
import 'package:e_repairkit/widget/shop_card.dart';
import 'package:e_repairkit/widget/suggestion_card.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

// 1. --- ADD MISSING IMPORTS ---
import 'package:e_repairkit/models/shop.dart';



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
      Future.delayed(const Duration(milliseconds: 50), () => _scrollToBottom());
    }
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<ChatViewModel>();
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());

    return Scaffold(
      appBar: AppBar(
        title: const Text('AI Repair Assistant'),
      ),
      body: Column(
        children: [
          // --- Message List ---
          Expanded(
            child: StreamBuilder<List<Message>>(
              stream: viewModel.messagesStream,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return const Center(child: Text("No messages yet."));
                }

                final messages = snapshot.data!;
                final items = [
                  ...messages,
                  ...viewModel.shops,
                ];

                return ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(8.0),
                  itemCount: items.length,
                  itemBuilder: (context, index) {
                    final item = items[index];

                    if (item is Message) {
                      // This will now work
                      return _MessageBubble(message: item);
                    } else if (item is Shop) {
                      // This will now work
                      return ShopCard(shop: item);
                    }
                    return const SizedBox.shrink();
                  },
                );
              },
            ),
          ),

          // --- Loading Indicator ---
          if (viewModel.isLoading)
            const Padding(
              padding: EdgeInsets.all(8.0),
              child: LinearProgressIndicator(),
            ),

          // --- Text Input ---
          // 2. --- USE THE HELPER WIDGET ---
          _MessageInputBar(
            controller: _textController,
            onSend: _sendMessage,
          ),
        ],
      ),
    );
  }
}

// 3. --- ADD THE MISSING WIDGETS AT THE BOTTOM ---

// --- WIDGET FOR THE TEXT INPUT BAR ---
class _MessageInputBar extends StatelessWidget {
  final TextEditingController controller;
  final VoidCallback onSend;

  const _MessageInputBar({required this.controller, required this.onSend});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 16),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              onSubmitted: (_) => onSend(),
              decoration: InputDecoration(
                hintText: 'Describe your problem...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.send),
            onPressed: onSend,
          ),
        ],
      ),
    );
  }
}

// --- WIDGET FOR THE CHAT BUBBLE ---
class _MessageBubble extends StatelessWidget {
  final Message message;
  const _MessageBubble({required this.message});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isUser = message.isFromUser;

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isUser
              ? theme.primaryColor
              : theme.colorScheme.secondaryContainer,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: isUser ? const Radius.circular(16) : const Radius.circular(0),
            bottomRight: isUser ? const Radius.circular(0) : const Radius.circular(16),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              message.text,
              style: TextStyle(
                color: isUser
                    ? Colors.white
                    : theme.colorScheme.onSecondaryContainer,
              ),
            ),
            // --- Show Suggestions ---
            if (message.suggestions != null && message.suggestions!.isNotEmpty)
              ...message.suggestions!.map(
                // This import was missing too
                (suggestion) => SuggestionCard(suggestion: suggestion),
              ),
            // --- Show "Find Shops" Button on AI messages ---
            if (!isUser)
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: TextButton(
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: const Text("This didn't work. Find shops near me?"),
                  onPressed: () {
                    context.read<ChatViewModel>().findRepairShops();
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}