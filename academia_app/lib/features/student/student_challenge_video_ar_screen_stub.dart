import 'package:flutter/material.dart';

class StudentChallengeVideoArScreen extends StatelessWidget {
  final List<Map<String, dynamic>> initialObjects;

  const StudentChallengeVideoArScreen({
    super.key,
    required this.initialObjects,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Studio AR 3D'),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: const [
              Icon(Icons.phone_android_outlined, size: 32),
              SizedBox(height: 16),
              Text(
                'Le Studio AR 3D n’est pas disponible sur cette plateforme. Utilise l’app mobile pour placer des objets AR.',
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
