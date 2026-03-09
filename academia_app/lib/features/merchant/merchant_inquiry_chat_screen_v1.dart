import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class MerchantInquiryChatScreenV1 extends StatefulWidget {
  final String inquiryId;

  const MerchantInquiryChatScreenV1({
    super.key,
    required this.inquiryId,
  });

  @override
  State<MerchantInquiryChatScreenV1> createState() =>
      _MerchantInquiryChatScreenV1State();
}

class _MerchantInquiryChatScreenV1State
    extends State<MerchantInquiryChatScreenV1> {
  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => _MerchantInquiryChatProvider(inquiryId: widget.inquiryId),
      child: Consumer<_MerchantInquiryChatProvider>(
        builder: (context, provider, child) {
          return Scaffold(
            backgroundColor: const Color(0xFFF3F4F6),
            appBar: AppBar(
              title: const Text('Discussion client'),
              actions: [
                IconButton(
                  onPressed: provider.isLoading ? null : provider.load,
                  icon: const Icon(Icons.refresh),
                ),
              ],
            ),
            body: Column(
              children: [
                if (provider.error != null)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    color: Colors.red.withOpacity(0.08),
                    child: Text(
                      provider.error!,
                      style: const TextStyle(color: Colors.red),
                    ),
                  ),
                Expanded(
                  child: provider.isLoading && provider.messages.isEmpty
                      ? const Center(child: CircularProgressIndicator())
                      : ListView.builder(
                          padding: const EdgeInsets.all(12),
                          itemCount: provider.messages.length,
                          itemBuilder: (context, index) {
                            final m = provider.messages[index];
                            final content = m['content']?.toString() ?? '';
                            final senderId = m['sender_id']?.toString();
                            final isMine = senderId != null &&
                                senderId ==
                                    Supabase.instance.client.auth.currentUser?.id;
                            return Align(
                              alignment: isMine
                                  ? Alignment.centerRight
                                  : Alignment.centerLeft,
                              child: Container(
                                margin: const EdgeInsets.only(bottom: 10),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 10,
                                ),
                                constraints: const BoxConstraints(maxWidth: 320),
                                decoration: BoxDecoration(
                                  color: isMine
                                      ? const Color(0xFF4338CA)
                                      : Colors.white,
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: Text(
                                  content,
                                  style: TextStyle(
                                    color: isMine ? Colors.white : Colors.black87,
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                ),
                _Composer(
                  enabled: !provider.isLoading,
                  onSend: provider.send,
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _Composer extends StatefulWidget {
  final bool enabled;
  final Future<bool> Function(String message) onSend;

  const _Composer({
    required this.enabled,
    required this.onSend,
  });

  @override
  State<_Composer> createState() => _ComposerState();
}

class _ComposerState extends State<_Composer> {
  final _controller = TextEditingController();
  bool _sending = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
        color: Colors.white,
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _controller,
                enabled: widget.enabled && !_sending,
                decoration: const InputDecoration(
                  hintText: 'Écrire un message...',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
            ),
            const SizedBox(width: 10),
            IconButton(
              onPressed: (!widget.enabled || _sending)
                  ? null
                  : () async {
                      final msg = _controller.text.trim();
                      if (msg.isEmpty) return;
                      setState(() => _sending = true);
                      final ok = await widget.onSend(msg);
                      if (!mounted) return;
                      if (ok) {
                        _controller.clear();
                      }
                      setState(() => _sending = false);
                    },
              icon: _sending
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.send),
            ),
          ],
        ),
      ),
    );
  }
}

class _MerchantInquiryChatProvider extends ChangeNotifier {
  final SupabaseClient _client = Supabase.instance.client;
  final String inquiryId;

  bool _isLoading = false;
  String? _error;
  List<Map<String, dynamic>> _messages = [];

  bool get isLoading => _isLoading;
  String? get error => _error;
  List<Map<String, dynamic>> get messages => List.unmodifiable(_messages);

  _MerchantInquiryChatProvider({required this.inquiryId}) {
    load();
  }

  void _setLoading(bool v) {
    _isLoading = v;
    notifyListeners();
  }

  void _setError(String? v) {
    _error = v;
    notifyListeners();
  }

  Future<void> load() async {
    _setLoading(true);
    _setError(null);
    try {
      final response = await _client.rpc(
        'app_list_opportunity_inquiry_messages',
        params: {
          'p_inquiry_id': inquiryId,
          'p_limit': 80,
          'p_before': null,
        },
      );

      if (response is! Map<String, dynamic>) {
        _setError('Réponse invalide du serveur.');
        return;
      }
      if (response['success'] != true) {
        _setError(response['error']?.toString() ?? 'Erreur serveur.');
        return;
      }

      final data = response['messages'];
      if (data is List) {
        _messages = data
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList(growable: false);
      } else {
        _messages = [];
      }
      notifyListeners();
    } catch (e) {
      _setError(e.toString());
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> send(String message) async {
    _setError(null);
    try {
      final response = await _client.rpc(
        'app_merchant_reply_inquiry',
        params: {
          'p_inquiry_id': inquiryId,
          'p_message': message,
        },
      );

      if (response is! Map<String, dynamic>) {
        _setError('Réponse invalide du serveur.');
        return false;
      }
      if (response['success'] != true) {
        _setError(response['error']?.toString() ?? 'Erreur serveur.');
        return false;
      }

      await load();
      return true;
    } catch (e) {
      _setError(e.toString());
      return false;
    }
  }
}
