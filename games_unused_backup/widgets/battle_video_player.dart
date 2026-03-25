import 'dart:async';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

/// Lecteur vidéo stylisé pour les battles
class BattleVideoPlayer extends StatefulWidget {
  final VideoPlayerController controller;
  final bool autoPlay;
  final bool showControls;
  final double? width;
  final double? height;
  
  const BattleVideoPlayer({
    Key? key,
    required this.controller,
    this.autoPlay = true,
    this.showControls = true,
    this.width,
    this.height,
  }) : super(key: key);
  
  @override
  _BattleVideoPlayerState createState() => _BattleVideoPlayerState();
}

class _BattleVideoPlayerState extends State<BattleVideoPlayer> {
  bool _isPlaying = false;
  bool _showControlsOverlay = false;
  Timer? _hideControlsTimer;
  
  @override
  void initState() {
    super.initState();
    _initializeVideo();
  }
  
  @override
  void dispose() {
    _hideControlsTimer?.cancel();
    super.dispose();
  }
  
  Future<void> _initializeVideo() async {
    try {
      await widget.controller.initialize();
      
      if (widget.autoPlay) {
        await widget.controller.play();
        setState(() {
          _isPlaying = true;
        });
      }
      
      widget.controller.addListener(_videoListener);
      
      if (mounted) {
        setState(() {});
      }
    } catch (e) {
      print('Erreur initialisation vidéo: $e');
    }
  }
  
  void _videoListener() {
    if (mounted) {
      setState(() {
        _isPlaying = widget.controller.value.isPlaying;
      });
    }
  }
  
  void _togglePlayPause() {
    if (_isPlaying) {
      widget.controller.pause();
    } else {
      widget.controller.play();
    }
    setState(() {
      _isPlaying = !_isPlaying;
    });
    
    if (widget.showControls) {
      _showControlsTemporarily();
    }
  }
  
  void _showControlsTemporarily() {
    setState(() {
      _showControlsOverlay = true;
    });
    
    _hideControlsTimer?.cancel();
    _hideControlsTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() {
          _showControlsOverlay = false;
        });
      }
    });
  }
  
  @override
  Widget build(BuildContext context) {
    if (!widget.controller.value.isInitialized) {
      return Container(
        width: widget.width,
        height: widget.height,
        color: Colors.black,
        child: const Center(
          child: CircularProgressIndicator(
            color: Color(0xFF00D4FF),
          ),
        ),
      );
    }
    
    return GestureDetector(
      onTap: widget.showControls ? _showControlsTemporarily : null,
      child: Stack(
        children: [
          // Video
          SizedBox(
            width: widget.width,
            height: widget.height,
            child: AspectRatio(
              aspectRatio: widget.controller.value.aspectRatio,
              child: VideoPlayer(widget.controller),
            ),
          ),
          
          // Controls overlay
          if (widget.showControls && _showControlsOverlay)
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withOpacity(0.7),
                      Colors.transparent,
                      Colors.transparent,
                      Colors.black.withOpacity(0.7),
                    ],
                  ),
                ),
                child: Center(
                  child: GestureDetector(
                    onTap: _togglePlayPause,
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.5),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        _isPlaying ? Icons.pause : Icons.play_arrow,
                        color: Colors.white,
                        size: 48,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          
          // Play/Pause button (always visible if autoPlay is false)
          if (!widget.autoPlay)
            Positioned.fill(
              child: Center(
                child: GestureDetector(
                  onTap: _togglePlayPause,
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.7),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      _isPlaying ? Icons.pause : Icons.play_arrow,
                      color: Colors.white,
                      size: 56,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
