import 'package:ar_flutter_plugin/ar_flutter_plugin.dart';
import 'package:ar_flutter_plugin/managers/ar_session_manager.dart';
import 'package:ar_flutter_plugin/managers/ar_object_manager.dart';
import 'package:ar_flutter_plugin/managers/ar_anchor_manager.dart';
import 'package:ar_flutter_plugin/managers/ar_location_manager.dart';
import 'package:ar_flutter_plugin/models/ar_hittest_result.dart';
import 'package:ar_flutter_plugin/models/ar_node.dart';
import 'package:ar_flutter_plugin/datatypes/node_types.dart';
import 'package:flutter/material.dart';
import 'package:vector_math/vector_math_64.dart' as vector;

import '../../video/academia_playback_engine.dart';
import '../../widgets/video_overlays_layer.dart';

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
  ARSessionManager? _sessionManager;
  ARObjectManager? _objectManager;

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
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
                child: widget.videoUrl.trim().isNotEmpty
                    ? Stack(
                        children: [
                          Positioned.fill(
                            child: AcademiaPlaybackEngine.view(
                              url: widget.videoUrl.trim(),
                              autoplay: true,
                              looping: true,
                              muted: false,
                              showControls: true,
                              fit: BoxFit.contain,
                            ),
                          ),
                          Positioned.fill(
                            child: IgnorePointer(
                              child: VideoOverlaysLayer(
                                overlays: widget.overlays,
                              ),
                            ),
                          ),
                        ],
                      )
                    : const Text(
                        'Vidéo indisponible.',
                        style: TextStyle(color: Colors.white),
                      ),
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
