import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../providers/student_communities_provider.dart';

class StudentCommunityDetailScreen extends StatefulWidget {
  final String communityId;
  final String initialName;
  final String initialDescription;

  const StudentCommunityDetailScreen({
    super.key,
    required this.communityId,
    required this.initialName,
    required this.initialDescription,
  });

  @override
  State<StudentCommunityDetailScreen> createState() => _StudentCommunityDetailScreenState();
}

class _StudentCommunityDetailScreenState extends State<StudentCommunityDetailScreen> {
  final TextEditingController _messageController = TextEditingController();
  bool _loadingPosts = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final provider = context.read<StudentCommunitiesProvider>();
      await _loadPosts();
      provider.subscribeToCommunityPosts(widget.communityId);
      await provider.markCommunityRead(widget.communityId);
    });
  }

  @override
  void dispose() {
    final provider = context.read<StudentCommunitiesProvider>();
    provider.unsubscribeFromCommunityPosts();
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _loadPosts() async {
    setState(() {
      _loadingPosts = true;
    });
    final provider = context.read<StudentCommunitiesProvider>();
    await provider.loadCommunityPosts(widget.communityId);
    if (!mounted) return;
    setState(() {
      _loadingPosts = false;
    });
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;
    final provider = context.read<StudentCommunitiesProvider>();
    final ok = await provider.addPost(
      communityId: widget.communityId,
      content: text,
    );
    if (!mounted) return;
    if (!ok && provider.error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(provider.error!)),
      );
      return;
    }
    _messageController.clear();
  }

  Widget _buildPostContent(Map<String, dynamic> p) {
    final type = (p['type'] ?? 'text').toString();
    final content = (p['content'] ?? '').toString();
    final mediaUrl = (p['media_url'] ?? '').toString();

    // Cas texte simple (comportement existant)
    if (type == 'text' || mediaUrl.isEmpty) {
      return Text(
        content,
        style: const TextStyle(fontSize: 14),
      );
    }

    // Cas image
    if (type == 'image' && mediaUrl.isNotEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.network(
              mediaUrl,
              fit: BoxFit.cover,
            ),
          ),
          if (content.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              content,
              style: const TextStyle(fontSize: 14),
            ),
          ],
        ],
      );
    }

    // Autres types (audio, fichier, etc.) : afficher comme pièce jointe cliquable
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: () async {
            final uri = Uri.tryParse(mediaUrl);
            if (uri != null) {
              await launchUrl(uri);
            }
          },
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.attach_file, size: 18),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  mediaUrl,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    decoration: TextDecoration.underline,
                    color: Colors.blue,
                  ),
                ),
              ),
            ],
          ),
        ),
        if (content.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            content,
            style: const TextStyle(fontSize: 14),
          ),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<StudentCommunitiesProvider>(
      builder: (context, provider, child) {
        final posts = provider.posts;

        return Scaffold(
          backgroundColor: const Color(0xFFF3F4F6),
          appBar: AppBar(
            elevation: 0,
            centerTitle: false,
            title: Text(widget.initialName),
            foregroundColor: Colors.white,
            flexibleSpace: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFFA3D65C), Color(0xFF1EA75C)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
            ),
          ),
          body: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.initialName,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (widget.initialDescription.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        widget.initialDescription,
                        style: const TextStyle(fontSize: 14),
                      ),
                    ],
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: _loadingPosts
                    ? const Center(child: CircularProgressIndicator())
                    : posts.isEmpty
                        ? const Center(
                            child: Padding(
                              padding: EdgeInsets.all(16.0),
                              child: Text(
                                'Aucun message pour cette communauté pour le moment. Sois le premier à écrire !',
                                textAlign: TextAlign.center,
                              ),
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                            itemCount: posts.length,
                            itemBuilder: (context, index) {
                              final p = posts[index];
                              final createdAt = (p['created_at'] ?? '').toString();
                              return Container(
                                margin: const EdgeInsets.only(bottom: 8),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _buildPostContent(p),
                                    if (createdAt.isNotEmpty) ...[
                                      const SizedBox(height: 4),
                                      Text(
                                        createdAt,
                                        style: const TextStyle(
                                          fontSize: 11,
                                          color: Colors.grey,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              );
                            },
                          ),
              ),
              const Divider(height: 1),
              Padding(
                padding: EdgeInsets.only(
                  left: 12,
                  right: 12,
                  bottom: MediaQuery.of(context).padding.bottom + 8,
                  top: 8,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _messageController,
                        minLines: 1,
                        maxLines: 4,
                        decoration: const InputDecoration(
                          hintText: 'Écrire un message...',
                          filled: true,
                          fillColor: Colors.white,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.all(Radius.circular(24)),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.send),
                      onPressed: provider.isSaving ? null : _sendMessage,
                    ),
                  ],
                ),
              ),
            ],
          ),
          bottomNavigationBar: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1EA75C),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                  child: const Text('Retour'),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
