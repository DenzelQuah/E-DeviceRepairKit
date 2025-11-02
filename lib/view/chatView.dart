import 'dart:io';

import 'package:e_repairkit/models/message.dart';
// 1. --- ADD MISSING IMPORTS ---
import 'package:e_repairkit/models/shop.dart';
import 'package:e_repairkit/viewmodels/chat_viewmodel.dart';
import 'package:e_repairkit/widget/chat_overflow_menu.dart';
import 'package:e_repairkit/widget/shop_card.dart';
import 'package:e_repairkit/widget/suggestion_card.dart';
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
      viewModel.sendMessage(
        _textController.text,
        imagePath: viewModel.attachedImagePath,
        temperature: viewModel.temperature,
        mode: viewModel.mode,
      );
      _textController.clear();
      viewModel.setAttachedImagePath(null);
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
        actions: [
          // Overflow menu encapsulated in widget
          const Padding(
            padding: EdgeInsets.only(right: 8.0),
            child: ChatOverflowMenu(),
          ),
        ],
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
                final items = [...messages, ...viewModel.shops];

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
          // The controls (mode, creativity, attach) are now in the AppBar overflow menu
          _MessageInputBar(
            controller: _textController,
            onSend: _sendMessage,
            attachedImagePath: viewModel.attachedImagePath,
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
  final String? attachedImagePath;

  const _MessageInputBar({
    required this.controller,
    required this.onSend,
    this.attachedImagePath,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 16),
      child: Row(
        children: [
          if (attachedImagePath != null) ...[
            Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.file(
                  File(attachedImagePath!),
                  width: 56,
                  height: 56,
                  fit: BoxFit.cover,
                ),
              ),
            ),
          ],
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
          IconButton(icon: const Icon(Icons.send), onPressed: onSend),
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
      child: GestureDetector(
        onLongPress:
            isUser
                ? () async {
                  final editCtrl = TextEditingController(text: message.text);
                  final result = await showDialog<String?>(
                    context: context,
                    builder:
                        (ctx) => AlertDialog(
                          title: const Text('Edit message'),
                          content: TextField(
                            controller: editCtrl,
                            maxLines: null,
                            decoration: const InputDecoration(
                              hintText: 'Edit your message',
                            ),
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(ctx),
                              child: const Text('Cancel'),
                            ),
                            TextButton(
                              onPressed:
                                  () => Navigator.pop(ctx, editCtrl.text),
                              child: const Text('Save'),
                            ),
                          ],
                        ),
                  );

                  if (result != null &&
                      result.trim().isNotEmpty &&
                      result.trim() != message.text) {
                    // call viewmodel to edit
                    context.read<ChatViewModel>().editMessage(
                      messageId: message.id,
                      newText: result.trim(),
                    );
                  }
                }
                : null,
        child: Container(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.75,
          ),
          margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color:
                isUser
                    ? theme.primaryColor
                    : theme.colorScheme.secondaryContainer,
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(16),
              topRight: const Radius.circular(16),
              bottomLeft:
                  isUser ? const Radius.circular(16) : const Radius.circular(0),
              bottomRight:
                  isUser ? const Radius.circular(0) : const Radius.circular(16),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                message.text,
                style: TextStyle(
                  color:
                      isUser
                          ? Colors.white
                          : theme.colorScheme.onSecondaryContainer,
                ),
              ),
              if (message.edited)
                Padding(
                  padding: const EdgeInsets.only(top: 6.0),
                  child: Text(
                    'edited',
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
              // --- Show Suggestions ---
              if (message.suggestions != null &&
                  message.suggestions!.isNotEmpty)
                ...message.suggestions!.map(
                  // This import was missing too
                  (suggestion) => SuggestionCard(suggestion: suggestion),
                ),
              // --- Show "Find Shops" Button on AI messages ---
              if (!isUser)
                Padding(
                  padding: const EdgeInsets.only(top: 8.0),
          child: ElevatedButton.icon(
  style: ElevatedButton.styleFrom(
    backgroundColor: Colors.orangeAccent,
    foregroundColor: Colors.white,
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
  ),
  icon: const Icon(Icons.location_on),
  label: const Text(
    "Find shops near me",
    style: TextStyle(fontWeight: FontWeight.bold),
  ),
  onPressed: () {
    context.read<ChatViewModel>().findRepairShops();
  },
),


                ),
            ],
          ),
        ),
      ),
    );
  }
}
