import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/student_communities_provider.dart';
import '../theme/prep_theme.dart';

/// Media gallery tab showing all shared images in a community
class CommunityMediaGallery extends StatelessWidget {
  final String communityId;

  const CommunityMediaGallery({super.key, required this.communityId});

  @override
  Widget build(BuildContext context) {
    return Consumer<StudentCommunitiesProvider>(
      builder: (context, provider, _) {
        final images = provider.imagePosts;

        if (images.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.photo_library_outlined, size: 48, color: Colors.grey.shade300),
                  const SizedBox(height: 12),
                  Text(
                    'Aucune image partagée',
                    style: TextStyle(fontSize: 15, color: Colors.grey.shade500),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Les images envoyées dans le chat apparaîtront ici.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 13, color: Colors.grey.shade400),
                  ),
                ],
              ),
            ),
          );
        }

        return GridView.builder(
          padding: const EdgeInsets.all(4),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: 2,
            mainAxisSpacing: 2,
          ),
          itemCount: images.length,
          itemBuilder: (context, index) {
            final post = images[index];
            final url = post['media_url']?.toString() ?? '';
            return GestureDetector(
              onTap: () => _openFullScreen(context, images, index),
              child: CachedNetworkImage(
                imageUrl: url,
                fit: BoxFit.cover,
                placeholder: (_, __) => Container(color: Colors.grey.shade200),
                errorWidget: (_, __, ___) => Container(
                  color: Colors.grey.shade200,
                  child: const Icon(Icons.broken_image, color: Colors.grey),
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _openFullScreen(BuildContext context, List<Map<String, dynamic>> images, int initialIndex) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _FullScreenGallery(images: images, initialIndex: initialIndex),
      ),
    );
  }
}

class _FullScreenGallery extends StatefulWidget {
  final List<Map<String, dynamic>> images;
  final int initialIndex;

  const _FullScreenGallery({required this.images, required this.initialIndex});

  @override
  State<_FullScreenGallery> createState() => _FullScreenGalleryState();
}

class _FullScreenGalleryState extends State<_FullScreenGallery> {
  late PageController _controller;
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _controller = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(
          '${_currentIndex + 1} / ${widget.images.length}',
          style: const TextStyle(fontSize: 16),
        ),
      ),
      body: PageView.builder(
        controller: _controller,
        itemCount: widget.images.length,
        onPageChanged: (i) => setState(() => _currentIndex = i),
        itemBuilder: (context, index) {
          final url = widget.images[index]['media_url']?.toString() ?? '';
          return InteractiveViewer(
            minScale: 0.5,
            maxScale: 4.0,
            child: Center(
              child: CachedNetworkImage(
                imageUrl: url,
                fit: BoxFit.contain,
                placeholder: (_, __) => const CircularProgressIndicator(color: PrepTheme.primary),
                errorWidget: (_, __, ___) => const Icon(Icons.broken_image, color: Colors.white, size: 48),
              ),
            ),
          );
        },
      ),
    );
  }
}
