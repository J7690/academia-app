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
          return const LoadingWidget(message: 'Bobodo prépare son espace de discussion...');
        }

        if (provider.error != null) {
          return CustomErrorWidget(
            error: provider.error!,
            onRetry: () => provider.loadMessages(),
          );
        }

        return Column(
          children: [
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: messages.length,
                itemBuilder: (context, index) {
                  final msg = messages[index];
                  final isUser = msg['sender'] == 'student';
                  return Align(
                    alignment:
                        isUser ? Alignment.centerRight : Alignment.centerLeft,
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isUser
                            ? Theme.of(context).colorScheme.primaryContainer
                            : Theme.of(context).colorScheme.surfaceVariant,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(msg['content']?.toString() ?? ''),
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
                    child: TextField(
                      controller: _controller,
                      decoration: const InputDecoration(
                        hintText:
                            'Pose une question à Bobodo sur Academia ou Nexiom...',
                      ),
                      onSubmitted: (_) => _send(context),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.send),
                    onPressed: () => _send(context),
                  ),
                ],
              ),
            ),
          ],
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
