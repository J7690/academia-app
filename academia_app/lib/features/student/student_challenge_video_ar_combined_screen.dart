import 'package:ar_flutter_plugin/ar_flutter_plugin.dart';
import 'package:ar_flutter_plugin/managers/ar_session_manager.dart';
import 'package:ar_flutter_plugin/managers/ar_object_manager.dart';
import 'package:ar_flutter_plugin/managers/ar_anchor_manager.dart';
import 'package:ar_flutter_plugin/managers/ar_location_manager.dart';
import 'package:ar_flutter_plugin/models/ar_hittest_result.dart';
import 'package:ar_flutter_plugin/models/ar_node.dart';
import 'package:ar_flutter_plugin/datatypes/node_types.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:vector_math/vector_math_64.dart' as vector;

import '../../widgets/student_video_player.dart';

class StudentChallengeVideoArCombinedScreen extends StatefulWidget {
  final String videoUrl;
  final Map<String, dynamic>? overlays;

  const StudentChallengeVideoArCombinedScreen({
    super.key,
    required this.videoUrl,
    this.overlays,
  });

  @override
  State<StudentChallengeVideoArCombinedScreen> createState() =>
      _StudentChallengeVideoArCombinedScreenState();
}

class _StudentChallengeVideoArCombinedScreenState
    extends State<StudentChallengeVideoArCombinedScreen> {
  VideoPlayerController? _videoController;
  bool _videoInitialized = false;

  ARSessionManager? _sessionManager;
  ARObjectManager? _objectManager;

  @override
  void initState() {
    super.initState();
    _initVideo();
  }

  Future<void> _initVideo() async {
    final url = widget.videoUrl.trim();
    if (url.isEmpty) {
      return;
    }
    final controller = VideoPlayerController.networkUrl(Uri.parse(url));
    _videoController = controller;
    try {
      await controller.initialize();
      if (!mounted) return;
      controller.setLooping(true);
      controller.play();
      setState(() {
        _videoInitialized = true;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _videoInitialized = false;
      });
    }
  }

  @override
  void dispose() {
    _videoController?.dispose();
    _sessionManager?.dispose();
    super.dispose();
  }

  void _onARViewCreated(
    ARSessionManager sessionManager,
    ARObjectManager objectManager,
    ARAnchorManager anchorManager,
    ARLocationManager locationManager,
  ) {
    _sessionManager = sessionManager;
    _objectManager = objectManager;

    _sessionManager?.onInitialize(
      showFeaturePoints: false,
      showPlanes: true,
      customPlaneTexturePath: null,
      showWorldOrigin: false,
      handleTaps: true,
    );

    _objectManager?.onInitialize();
    _objectManager?.onNodeTap = (nodes) {};
    _sessionManager?.onPlaneOrPointTap = _onPlaneTap;
  }

  Future<void> _onPlaneTap(List<ARHitTestResult> hits) async {
    if (hits.isEmpty || _objectManager == null) {
      return;
    }

    final hit = hits.first;
    final position = hit.worldTransform.getTranslation();
    final rotationMatrix = hit.worldTransform.getRotation();
    final quaternion = vector.Quaternion.fromRotation(rotationMatrix);

    final node = ARNode(
      type: NodeType.webGLB,
      uri:
          'https://github.com/KhronosGroup/glTF-Sample-Models/raw/master/2.0/Duck/glTF-Binary/Duck.glb',
      scale: vector.Vector3(0.2, 0.2, 0.2),
      position: position,
    );
    node.rotationFromQuaternion = quaternion;

    await _objectManager!.addNode(node);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Vidéo + AR live'),
      ),
      body: Column(
        children: [
          Expanded(
            child: Container(
              color: Colors.black,
              padding: const EdgeInsets.all(12.0),
              child: Center(
                child: _videoController != null && _videoInitialized
                    ? StudentVideoPlayer(
                        controller: _videoController!,
                        overlays: widget.overlays,
                      )
                    : const CircularProgressIndicator(),
              ),
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: ARView(
              onARViewCreated: _onARViewCreated,
            ),
          ),
        ],
      ),
    );
  }
}
