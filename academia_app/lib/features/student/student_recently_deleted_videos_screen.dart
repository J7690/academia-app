import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/student_challenges_provider.dart';

class StudentRecentlyDeletedVideosScreen extends StatefulWidget {
  const StudentRecentlyDeletedVideosScreen({super.key});

  @override
  State<StudentRecentlyDeletedVideosScreen> createState() =>
      _StudentRecentlyDeletedVideosScreenState();
}

class _StudentRecentlyDeletedVideosScreenState
    extends State<StudentRecentlyDeletedVideosScreen> {
  bool _isLoading = false;
  String? _error;
  List<Map<String, dynamic>> _videos = [];
  bool _didRestore = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _load();
    });
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });

    final provider = context.read<StudentChallengesProvider>();
    final items = await provider.listRecentlyDeletedVideos(limit: 50);

    if (!mounted) return;
    setState(() {
      _videos = items;
      _error = provider.error;
      _isLoading = false;
    });
  }

  Future<void> _restore(Map<String, dynamic> item) async {
    final provider = context.read<StudentChallengesProvider>();

    final videoType = item['video_type']?.toString() ?? '';
    final videoId = item['video_id']?.toString() ?? '';

    if (videoType.isEmpty || videoId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Impossible d\'identifier cette vidéo.')),
      );
      return;
    }

    final ok = await provider.restoreVideo(videoType: videoType, videoId: videoId);
    if (!mounted) return;

    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(provider.error ?? 'Erreur lors de la restauration.')),
      );
      return;
    }

    setState(() {
      _videos = _videos
          .where((v) =>
              v['video_type']?.toString() != videoType ||
              v['video_id']?.toString() != videoId)
          .toList(growable: false);
      _didRestore = true;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Vidéo restaurée')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        Navigator.of(context).pop(_didRestore);
        return false;
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Récemment supprimées'),
        ),
        body: RefreshIndicator(
          onRefresh: _load,
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
                  ? ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.all(16),
                      children: [
                        Text(
                          _error!,
                          style: const TextStyle(color: Colors.redAccent),
                        ),
                        const SizedBox(height: 12),
                        ElevatedButton(
                          onPressed: _load,
                          child: const Text('Réessayer'),
                        ),
                      ],
                    )
                  : _videos.isEmpty
                      ? ListView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.all(24),
                          children: const [
                            SizedBox(height: 80),
                            Icon(Icons.delete_outline, size: 56, color: Colors.black45),
                            SizedBox(height: 16),
                            Text(
                              'Aucune vidéo supprimée récemment.',
                              textAlign: TextAlign.center,
                              style: TextStyle(fontSize: 15, color: Colors.black54),
                            ),
                          ],
                        )
                      : ListView.separated(
                          physics: const AlwaysScrollableScrollPhysics(),
                          itemCount: _videos.length,
                          separatorBuilder: (_, __) => const Divider(height: 1),
                          itemBuilder: (context, index) {
                            final v = _videos[index];
                            final videoType = v['video_type']?.toString() ?? '';
                            final title =
                                (v['challenge_title']?.toString().trim().isNotEmpty == true)
                                    ? v['challenge_title']?.toString() ?? ''
                                    : (videoType == 'free'
                                        ? 'Vidéo libre'
                                        : 'Vidéo de challenge');
                            final deletedAt = v['deleted_at']?.toString() ?? '';

                            return ListTile(
                              leading: const Icon(Icons.play_circle_outline),
                              title: Text(title),
                              subtitle: deletedAt.isEmpty
                                  ? null
                                  : Text('Supprimée le $deletedAt'),
                              trailing: TextButton(
                                onPressed: () => _restore(v),
                                child: const Text('Restaurer'),
                              ),
                            );
                          },
                        ),
        ),
      ),
    );
  }
}
