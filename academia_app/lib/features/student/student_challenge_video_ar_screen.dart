import 'package:ar_flutter_plugin/ar_flutter_plugin.dart';
import 'package:flutter/material.dart';
import 'package:vector_math/vector_math_64.dart' as vector;

class StudentChallengeVideoArScreen extends StatefulWidget {
  final List<Map<String, dynamic>> initialObjects;

  const StudentChallengeVideoArScreen({
    super.key,
    required this.initialObjects,
  });

  @override
  State<StudentChallengeVideoArScreen> createState() => _StudentChallengeVideoArScreenState();
}

class _StudentChallengeVideoArScreenState extends State<StudentChallengeVideoArScreen> {
  ARSessionManager? _sessionManager;
  ARObjectManager? _objectManager;
  final List<ARNode> _nodes = [];
  final List<Map<String, dynamic>> _objectsJson = [];

  @override
  void initState() {
    super.initState();
    _objectsJson.addAll(
      widget.initialObjects
          .map((e) => Map<String, dynamic>.from(e))
          .toList(growable: false),
    );
  }

  @override
  void dispose() {
    _sessionManager?.dispose();
    super.dispose();
  }

  void _onARViewCreated(ARSessionManager sessionManager, ARObjectManager objectManager, ARAnchorManager anchorManager, ARLocationManager locationManager) {
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
    final rotation = hit.worldTransform.getRotation();

    final node = ARNode(
      type: NodeType.webGLB,
      uri:
          'https://github.com/KhronosGroup/glTF-Sample-Models/raw/master/2.0/Duck/glTF-Binary/Duck.glb',
      scale: vector.Vector3(0.2, 0.2, 0.2),
      position: position,
      rotation: vector.Vector4(rotation.x, rotation.y, rotation.z, rotation.w),
    );

    final added = await _objectManager!.addNode(node, planeAnchor: hit.anchor);
    if (added == true) {
      _nodes.add(node);
      _objectsJson.add({
        'type': 'webGLB',
        'uri': node.uri,
        'anchor_type': 'plane',
        'position': {
          'x': node.position.x,
          'y': node.position.y,
          'z': node.position.z,
        },
        'rotation': {
          'x': rotation.x,
          'y': rotation.y,
          'z': rotation.z,
          'w': rotation.w,
        },
        'scale': {
          'x': node.scale.x,
          'y': node.scale.y,
          'z': node.scale.z,
        },
      });
      setState(() {});
    }
  }

  void _onValidate() {
    Navigator.of(context).pop<List<Map<String, dynamic>>>(_objectsJson);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Studio AR 3D'),
      ),
      body: Column(
        children: [
          Expanded(
            child: ARView(
              onARViewCreated: _onARViewCreated,
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _onValidate,
                icon: const Icon(Icons.check_circle_outline),
                label: const Text('Valider les objets AR'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
