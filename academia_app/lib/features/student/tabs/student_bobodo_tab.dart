import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../providers/bobodo_provider.dart';
import '../../../widgets/loading_widget.dart';
import '../../../widgets/error_widget.dart';

class StudentBobodoTab extends StatefulWidget {
  const StudentBobodoTab({super.key});

  @override
  State<StudentBobodoTab> createState() => _StudentBobodoTabState();
}

class _StudentBobodoTabState extends State<StudentBobodoTab> {
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<BobodoProvider>(
      builder: (context, provider, child) {
        final messages = provider.messages;

        if (provider.isLoading && messages.isEmpty) {
          return const LoadingWidget(
            message: 'Bobodo prépare son espace de discussion...',
          );
        }

        if (provider.error != null) {
          return CustomErrorWidget(
            error: provider.error!,
            onRetry: () => provider.loadMessages(),
          );
        }

        return Container(
          color: const Color(0xFFECE5DD),
          child: Column(
            children: [
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final msg = messages[index];
                    final isUser = msg['sender'] == 'student';
                    final messageId = msg['id']?.toString();
                    final content = msg['content']?.toString() ?? '';
                    final selectedFeedback = messageId != null
                        ? provider.feedbackForMessage(messageId)
                        : null;

                    final bubble = Container(
                      margin: const EdgeInsets.only(bottom: 6),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: isUser
                            ? const Color(0xFFDCF8C6)
                            : Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.03),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Text(content),
                    );

                    final feedbackRow = (!isUser && messageId != null)
                        ? Padding(
                            padding: const EdgeInsets.only(bottom: 8.0),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              mainAxisAlignment: isUser
                                  ? MainAxisAlignment.end
                                  : MainAxisAlignment.start,
                              children: [
                                IconButton(
                                  icon: Icon(
                                    selectedFeedback == 'up'
                                        ? Icons.thumb_up_alt
                                        : Icons.thumb_up_alt_outlined,
                                    size: 18,
                                  ),
                                  color: selectedFeedback == 'up'
                                      ? Theme.of(context).colorScheme.primary
                                      : null,
                                  tooltip: 'Réponse utile',
                                  onPressed: () {
                                    context
                                        .read<BobodoProvider>()
                                        .sendFeedback(messageId: messageId, rating: 'up');
                                  },
                                ),
                                IconButton(
                                  icon: Icon(
                                    selectedFeedback == 'down'
                                        ? Icons.thumb_down_alt
                                        : Icons.thumb_down_alt_outlined,
                                    size: 18,
                                  ),
                                  color: selectedFeedback == 'down'
                                      ? Theme.of(context).colorScheme.error
                                      : null,
                                  tooltip: 'Réponse peu utile',
                                  onPressed: () {
                                    context
                                        .read<BobodoProvider>()
                                        .sendFeedback(messageId: messageId, rating: 'down');
                                  },
                                ),
                              ],
                            ),
                          )
                        : const SizedBox.shrink();

                    return Align(
                      alignment:
                          isUser ? Alignment.centerRight : Alignment.centerLeft,
                      child: Column(
                        crossAxisAlignment: isUser
                            ? CrossAxisAlignment.end
                            : CrossAxisAlignment.start,
                        children: [
                          bubble,
                          feedbackRow,
                        ],
                      ),
                    );
                  },
                ),
              ),
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Row(
                  children: [
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(24),
                        ),
                        child: TextField(
                          controller: _controller,
                          decoration: const InputDecoration(
                            border: InputBorder.none,
                            hintText:
                                'Pose une question à Bobodo sur Academia ou Nexiom...',
                          ),
                          onSubmitted: (_) => _send(context),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.send),
                      color: const Color(0xFF1EA75C),
                      onPressed: () => _send(context),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _send(BuildContext context) async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    _controller.clear();
    final provider = context.read<BobodoProvider>();
    await provider.sendUserMessage(text);
  }
}
