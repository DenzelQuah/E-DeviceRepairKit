import 'dart:io';
import 'package:e_repairkit/models/message.dart';
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
          const Padding(
            padding: EdgeInsets.only(right: 8.0),
            child: ChatOverflowMenu(),
          ),
        ],
      ),
      body: Column(
        children: [
          // --- Message List with Diagnostic Status Bar ---
          Expanded(
            child: StreamBuilder<List<Message>>(
              stream: viewModel.messagesStream,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                
                final messages = snapshot.data ?? [];
                
                if (messages.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.build_circle, size: 64, color: Colors.grey[400]),
                        const SizedBox(height: 16),
                        Text(
                          "Hi! I'm your repair assistant",
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          "Describe your device problem and I'll help diagnose it",
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Colors.grey[600],
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  );
                }

                final items = [...messages, ...viewModel.shops];

                return Column(
                  children: [
                    // Diagnostic Status Bar
                    _DiagnosticStatusBar(
                      hasProvidedSolution: _hasSuggestions(messages),
                    ),
                    
                    // Message List
                    Expanded(
                      child: ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.all(8.0),
                        itemCount: items.length,
                        itemBuilder: (context, index) {
                          final item = items[index];

                          if (item is Message) {
                            return _MessageBubble(message: item);
                          } else if (item is Shop) {
                            return ShopCard(shop: item);
                          }
                          return const SizedBox.shrink();
                        },
                      ),
                    ),
                  ],
                );
              },
            ),
          ),

          // --- Solution Verification Indicator ---
          StreamBuilder<List<Message>>(
            stream: viewModel.messagesStream,
            builder: (context, snapshot) {
              final messages = snapshot.data ?? [];
              final hasSuggestions = _hasSuggestions(messages);
              
              if (viewModel.waitingForFixConfirmation && hasSuggestions) {
                return FollowUpIndicator(
                  onYes: () => _sendQuickReply('Yes, it worked! The problem is fixed.'),
                  onNo: () => _sendQuickReply('No, it didn\'t work. Still having the same issue.'),
                );
              }
              return const SizedBox.shrink();
            },
          ),

          // --- Loading Indicator ---
          if (viewModel.isLoading)
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Analyzing...',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),

          // --- Text Input ---
          StreamBuilder<List<Message>>(
            stream: viewModel.messagesStream,
            builder: (context, snapshot) {
              final messages = snapshot.data ?? [];
              return _MessageInputBar(
                controller: _textController,
                onSend: _sendMessage,
                attachedImagePath: viewModel.attachedImagePath,
                isFollowUpMode: viewModel.waitingForFixConfirmation,
                hasSolution: _hasSuggestions(messages),
              );
            },
          ),
        ],
      ),
    );
  }

  bool _hasSuggestions(List<Message> messages) {
    return messages.any((msg) => 
      msg.suggestions != null && msg.suggestions!.isNotEmpty
    );
  }

  void _sendQuickReply(String text) {
    final viewModel = context.read<ChatViewModel>();
    viewModel.sendMessage(
      text,
      temperature: viewModel.temperature,
      mode: viewModel.mode,
    );
    Future.delayed(const Duration(milliseconds: 50), () => _scrollToBottom());
  }
}

// --- DIAGNOSTIC STATUS BAR ---
class _DiagnosticStatusBar extends StatelessWidget {
  final bool hasProvidedSolution;

  const _DiagnosticStatusBar({
    required this.hasProvidedSolution,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: hasProvidedSolution ? Colors.green.shade50 : Colors.blue.shade50,
        border: Border(
          bottom: BorderSide(
            color: hasProvidedSolution ? Colors.green.shade200 : Colors.blue.shade200,
          ),
        ),
      ),
      child: Row(
        children: [
          Icon(
            hasProvidedSolution ? Icons.check_circle : Icons.psychology,
            size: 16,
            color: hasProvidedSolution ? Colors.green.shade700 : Colors.blue.shade700,
          ),
          const SizedBox(width: 8),
          Text(
            hasProvidedSolution ? 'Solution Provided' : 'Diagnosing...',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: hasProvidedSolution ? Colors.green.shade700 : Colors.blue.shade700,
            ),
          ),
        ],
      ),
    );
  }
}

// --- FOLLOW-UP INDICATOR (for solution verification) ---
class FollowUpIndicator extends StatelessWidget {
  final VoidCallback onYes;
  final VoidCallback onNo;

  const FollowUpIndicator({
    super.key,
    required this.onYes,
    required this.onNo,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.help_outline, color: Colors.orange.shade700, size: 20),
              const SizedBox(width: 8),
              Text(
                'Did the solution work?',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.orange.shade700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: onYes,
                  icon: const Icon(Icons.check_circle, size: 18),
                  label: const Text('Yes, it worked!'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onNo,
                  icon: const Icon(Icons.cancel, size: 18),
                  label: const Text('No, still broken'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red,
                    side: BorderSide(color: Colors.red.shade300),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// --- TEXT INPUT BAR ---
class _MessageInputBar extends StatelessWidget {
  final TextEditingController controller;
  final VoidCallback onSend;
  final String? attachedImagePath;
  final bool isFollowUpMode;
  final bool hasSolution;

  const _MessageInputBar({
    required this.controller,
    required this.onSend,
    this.attachedImagePath,
    this.isFollowUpMode = false,
    this.hasSolution = false,
  });

  @override
  Widget build(BuildContext context) {
    String hintText;
    if (hasSolution && isFollowUpMode) {
      hintText = 'Let me know if it worked...';
    } else if (isFollowUpMode) {
      hintText = 'Answer the questions above...';
    } else {
      hintText = 'Describe your device problem...';
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 16),
      child: Row(
        children: [
          if (attachedImagePath != null) ...[
            Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.file(
                      File(attachedImagePath!),
                      width: 56,
                      height: 56,
                      fit: BoxFit.cover,
                    ),
                  ),
                  Positioned(
                    top: -4,
                    right: -4,
                    child: IconButton(
                      icon: const Icon(Icons.cancel, color: Colors.red, size: 20),
                      onPressed: () {
                        context.read<ChatViewModel>().setAttachedImagePath(null);
                      },
                    ),
                  ),
                ],
              ),
            ),
          ],
          Expanded(
            child: TextField(
              controller: controller,
              onSubmitted: (_) => onSend(),
              maxLines: null,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                hintText: hintText,
                hintStyle: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[500],
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.send),
            onPressed: onSend,
            color: Theme.of(context).primaryColor,
          ),
        ],
      ),
    );
  }
}

// --- MESSAGE BUBBLE ---
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
        onLongPress: isUser
            ? () async {
                final editCtrl = TextEditingController(text: message.text);
                final result = await showDialog<String?>(
                  context: context,
                  builder: (ctx) => AlertDialog(
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
                        onPressed: () => Navigator.pop(ctx, editCtrl.text),
                        child: const Text('Save'),
                      ),
                    ],
                  ),
                );

                if (result != null &&
                    result.trim().isNotEmpty &&
                    result.trim() != message.text) {
                  context.read<ChatViewModel>().editMessage(
                        messageId: message.id,
                        newText: result.trim(),
                      );
                }
              }
            : null,
        child: Container(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.8,
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
              bottomLeft:
                  isUser ? const Radius.circular(16) : const Radius.circular(4),
              bottomRight:
                  isUser ? const Radius.circular(4) : const Radius.circular(16),
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
                  fontSize: 15,
                ),
              ),
              if (message.edited)
                Padding(
                  padding: const EdgeInsets.only(top: 6.0),
                  child: Text(
                    'edited',
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontStyle: FontStyle.italic,
                      color: isUser ? Colors.white70 : null,
                    ),
                  ),
                ),
              if (message.suggestions != null &&
                  message.suggestions!.isNotEmpty) ...[
                const SizedBox(height: 12),
                const Divider(height: 1),
                const SizedBox(height: 8),
                ...message.suggestions!.map(
                  (suggestion) => Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: SuggestionCard(suggestion: suggestion),
                  ),
                ),
              ],
              if (!isUser && message.suggestions != null && message.suggestions!.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 12.0),
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orangeAccent,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 10),
                    ),
                    icon: const Icon(Icons.location_on, size: 18),
                    label: const Text(
                      "Find shops near me",
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
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