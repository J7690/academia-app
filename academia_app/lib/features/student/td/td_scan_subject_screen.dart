import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:http/http.dart' as http;

import '../../../config/supabase_config.dart';

/// Écran étudiant TD : scanner un exercice/sujet et obtenir la correction IA.
class TdScanSubjectScreen extends StatefulWidget {
  const TdScanSubjectScreen({super.key});

  @override
  State<TdScanSubjectScreen> createState() => _TdScanSubjectScreenState();
}

class _TdScanSubjectScreenState extends State<TdScanSubjectScreen> {
  final ImagePicker _picker = ImagePicker();

  Uint8List? _imageBytes;
  String? _imageName;
  String? _imageMimeType;
  bool _isProcessing = false;
  String? _extractedText;
  String? _solutions;
  String? _error;
  String? _selectedField;
  String? _selectedLevel;
  double _progress = 0;
  String _statusMessage = '';

  final _fieldOptions = [
    'Mathématiques', 'Physique', 'Chimie', 'Biologie', 'Informatique',
    'Économie', 'Droit', 'Comptabilité', 'Gestion', 'Français', 'Anglais',
    'Philosophie', 'Histoire-Géo',
  ];

  final _levelOptions = ['Licence 1', 'Licence 2', 'Licence 3', 'Master 1', 'Master 2', 'BTS', 'Terminale'];

  Future<void> _pickImage(ImageSource source) async {
    try {
      final xFile = await _picker.pickImage(
        source: source, maxWidth: 2048, maxHeight: 2048, imageQuality: 85,
      );
      if (xFile == null) return;
      final bytes = await xFile.readAsBytes();
      final ext = xFile.name.split('.').last.toLowerCase();
      setState(() {
        _imageBytes = bytes;
        _imageName = xFile.name;
        _imageMimeType = ext == 'png' ? 'image/png' : 'image/jpeg';
        _extractedText = null;
        _solutions = null;
        _error = null;
      });
    } catch (e) {
      setState(() => _error = 'Erreur: $e');
    }
  }

  Future<void> _analyzeImage() async {
    if (_imageBytes == null) return;

    setState(() {
      _isProcessing = true;
      _error = null;
      _extractedText = null;
      _solutions = null;
      _progress = 0.1;
      _statusMessage = 'Lecture de l\'image...';
    });

    try {
      final base64Image = base64Encode(_imageBytes!);
      final mimeType = _imageMimeType ?? 'image/jpeg';

      setState(() { _progress = 0.3; _statusMessage = 'Extraction du texte (OCR)...'; });

      final session = Supabase.instance.client.auth.currentSession;
      if (session == null) throw Exception('Non authentifié.');

      final uri = Uri.parse('${SupabaseConfig.url}/functions/v1/td-scan-subject');
      final response = await http.post(uri, headers: {
        'Authorization': 'Bearer ${session.accessToken}',
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        'apikey': SupabaseConfig.anonKey,
      }, body: jsonEncode({
        'image_base64': base64Image,
        'mime_type': mimeType,
        'mode': 'full',
        if (_selectedField != null) 'field_name': _selectedField,
        if (_selectedLevel != null) 'level': _selectedLevel,
      }));

      setState(() { _progress = 0.7; _statusMessage = 'Résolution des exercices...'; });

      Map<String, dynamic>? data;
      try {
        data = jsonDecode(response.body) as Map<String, dynamic>?;
      } catch (_) {
        data = null;
      }

      if (response.statusCode == 200 && data != null) {
        if (data['success'] == true) {
          setState(() {
            _extractedText = data!['extracted_text']?.toString();
            _solutions = data['solutions']?.toString();
            _progress = 1.0;
            _statusMessage = 'Terminé !';
          });
        } else {
          setState(() => _error = data!['message']?.toString() ?? data['error']?.toString() ?? 'Erreur inconnue');
        }
      } else if (response.statusCode == 402 && data != null) {
        setState(() => _error = data!['message']?.toString() ?? 'Crédits insuffisants');
      } else {
        final msg = data?['message']?.toString() ?? data?['error']?.toString();
        final detail = data?['detail']?.toString();
        setState(() {
          _error = msg ?? 'Erreur serveur (${response.statusCode})';
          if (detail != null && detail.isNotEmpty) _error = '$_error\n$detail';
        });
      }
    } catch (e) {
      setState(() => _error = 'Erreur de connexion: $e');
    } finally {
      setState(() => _isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    const primaryColor = Color(0xFF7C3AED);

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text('Scanner un exercice TD'),
        foregroundColor: Colors.white,
        elevation: 0,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(colors: [Color(0xFF7C3AED), Color(0xFF6D28D9)]),
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_imageBytes == null && _solutions == null) _buildInstructions(primaryColor),
            if (_imageBytes != null && _solutions == null) _buildImagePreview(),
            if (_imageBytes != null && _solutions == null) ...[
              const SizedBox(height: 12),
              _buildFilters(primaryColor),
            ],
            if (_solutions == null) ...[
              const SizedBox(height: 16),
              _buildActionButtons(primaryColor),
            ],
            if (_isProcessing) ...[const SizedBox(height: 16), _buildProcessing(primaryColor)],
            if (_error != null) ...[const SizedBox(height: 16), _buildError()],
            if (_solutions != null) _buildResults(primaryColor),
          ],
        ),
      ),
    );
  }

  Widget _buildInstructions(Color c) => Card(
    elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    child: Padding(padding: const EdgeInsets.all(20), child: Column(children: [
      Container(width: 80, height: 80, decoration: BoxDecoration(
        color: c.withAlpha(25), borderRadius: BorderRadius.circular(20),
      ), child: Icon(Icons.document_scanner, size: 40, color: c)),
      const SizedBox(height: 16),
      const Text('Scanner un exercice', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
      const SizedBox(height: 8),
      Text('Prenez en photo un exercice de TD.\nL\'IA le résoudra étape par étape.',
        textAlign: TextAlign.center, style: TextStyle(fontSize: 14, color: Colors.grey[600])),
    ])),
  );

  Widget _buildImagePreview() => Card(
    elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    clipBehavior: Clip.antiAlias,
    child: Column(children: [
      ConstrainedBox(constraints: const BoxConstraints(maxHeight: 300),
        child: Image.memory(_imageBytes!, fit: BoxFit.contain, width: double.infinity)),
      Padding(padding: const EdgeInsets.all(12), child: Row(children: [
        const Icon(Icons.image, size: 16, color: Colors.grey),
        const SizedBox(width: 8),
        Expanded(child: Text(_imageName ?? 'image',
          style: const TextStyle(fontSize: 12, color: Colors.grey), overflow: TextOverflow.ellipsis)),
        TextButton(onPressed: () => setState(() { _imageBytes = null; _error = null; }),
          child: const Text('Changer', style: TextStyle(color: Color(0xFF7C3AED)))),
      ])),
    ]),
  );

  Widget _buildFilters(Color c) => Card(
    elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          DropdownButtonFormField<String>(
            value: _selectedField,
            isDense: true,
            isExpanded: true,
            decoration: InputDecoration(
              labelText: 'Matière',
              border: const OutlineInputBorder(),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              prefixIcon: Icon(Icons.school, color: c, size: 20),
            ),
            items: _fieldOptions.map((f) => DropdownMenuItem(value: f, child: Text(f, style: const TextStyle(fontSize: 13), overflow: TextOverflow.ellipsis))).toList(),
            onChanged: (v) => setState(() => _selectedField = v),
          ),
          const SizedBox(height: 10),
          DropdownButtonFormField<String>(
            value: _selectedLevel,
            isDense: true,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'Niveau',
              border: OutlineInputBorder(),
              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              prefixIcon: Icon(Icons.signal_cellular_alt, size: 20),
            ),
            items: _levelOptions.map((l) => DropdownMenuItem(value: l, child: Text(l, style: const TextStyle(fontSize: 13), overflow: TextOverflow.ellipsis))).toList(),
            onChanged: (v) => setState(() => _selectedLevel = v),
          ),
        ],
      ),
    ),
  );

  Widget _buildActionButtons(Color c) {
    if (_imageBytes != null) {
      return ElevatedButton.icon(
        onPressed: _isProcessing ? null : _analyzeImage,
        icon: const Icon(Icons.auto_awesome),
        label: const Text('Résoudre cet exercice'),
        style: ElevatedButton.styleFrom(
          backgroundColor: c, foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
      );
    }
    return Row(children: [
      Expanded(child: _ActionCard(icon: Icons.camera_alt, label: 'Caméra', color: c,
        onTap: () => _pickImage(ImageSource.camera))),
      const SizedBox(width: 12),
      Expanded(child: _ActionCard(icon: Icons.photo_library, label: 'Galerie', color: const Color(0xFF0891B2),
        onTap: () => _pickImage(ImageSource.gallery))),
    ]);
  }

  Widget _buildProcessing(Color c) => Card(
    elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    child: Padding(padding: const EdgeInsets.all(20), child: Column(children: [
      ClipRRect(borderRadius: BorderRadius.circular(8),
        child: LinearProgressIndicator(value: _progress, backgroundColor: Colors.grey[200],
          valueColor: AlwaysStoppedAnimation<Color>(c), minHeight: 6)),
      const SizedBox(height: 12),
      Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(c))),
        const SizedBox(width: 12),
        Text(_statusMessage, style: TextStyle(fontSize: 14, color: Colors.grey[700])),
      ]),
    ])),
  );

  Widget _buildError() => Card(
    elevation: 0, color: Colors.red[50],
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    child: Padding(padding: const EdgeInsets.all(16), child: Row(children: [
      const Icon(Icons.error_outline, color: Colors.red),
      const SizedBox(width: 12),
      Expanded(child: Text(_error!, style: const TextStyle(color: Colors.red, fontSize: 13))),
    ])),
  );

  Widget _buildResults(Color c) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(
        gradient: LinearGradient(colors: [c, const Color(0xFF6D28D9)]),
        borderRadius: BorderRadius.circular(16)),
        child: const Row(children: [
          Icon(Icons.check_circle, color: Colors.white, size: 28),
          SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Correction terminée', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
            SizedBox(height: 2),
            Text('Voici la solution détaillée', style: TextStyle(color: Colors.white70, fontSize: 12)),
          ])),
        ])),
      const SizedBox(height: 12),
      if (_extractedText != null) _CollapsibleSection(
        title: 'Texte extrait', icon: Icons.text_snippet, color: const Color(0xFF0891B2),
        child: SelectableText(_extractedText!, style: const TextStyle(fontSize: 13, height: 1.5))),
      const SizedBox(height: 12),
      Card(elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(padding: const EdgeInsets.all(16), child: Column(
          crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(
                color: c.withAlpha(25), borderRadius: BorderRadius.circular(10)),
                child: Icon(Icons.auto_awesome, color: c, size: 20)),
              const SizedBox(width: 12),
              const Text('Solution détaillée', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ]),
            const SizedBox(height: 16),
            MarkdownBody(data: _solutions ?? '', selectable: true, styleSheet: MarkdownStyleSheet(
              p: const TextStyle(fontSize: 14, height: 1.6),
              h1: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              h2: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              h3: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              strong: TextStyle(fontWeight: FontWeight.bold, color: c),
            )),
          ]))),
      const SizedBox(height: 16),
      OutlinedButton.icon(
        onPressed: () => setState(() { _imageBytes = null; _extractedText = null; _solutions = null; _error = null; }),
        icon: const Icon(Icons.camera_alt),
        label: const Text('Scanner un autre exercice'),
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          side: BorderSide(color: c), foregroundColor: c)),
      const SizedBox(height: 24),
    ],
  );
}

class _ActionCard extends StatelessWidget {
  final IconData icon; final String label; final Color color; final VoidCallback onTap;
  const _ActionCard({required this.icon, required this.label, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(onTap: onTap, child: Card(
    elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    child: Padding(padding: const EdgeInsets.all(24), child: Column(children: [
      Container(width: 56, height: 56, decoration: BoxDecoration(
        color: color.withAlpha(25), borderRadius: BorderRadius.circular(16)),
        child: Icon(icon, color: color, size: 28)),
      const SizedBox(height: 12),
      Text(label, textAlign: TextAlign.center, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: color)),
    ]))));
}

class _CollapsibleSection extends StatefulWidget {
  final String title; final IconData icon; final Color color; final Widget child;
  const _CollapsibleSection({required this.title, required this.icon, required this.color, required this.child});
  @override State<_CollapsibleSection> createState() => _CollapsibleSectionState();
}

class _CollapsibleSectionState extends State<_CollapsibleSection> {
  bool _expanded = false;
  @override
  Widget build(BuildContext context) => Card(
    elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    child: Column(children: [
      ListTile(leading: Icon(widget.icon, color: widget.color),
        title: Text(widget.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
        trailing: Icon(_expanded ? Icons.expand_less : Icons.expand_more, color: Colors.grey),
        onTap: () => setState(() => _expanded = !_expanded)),
      if (_expanded) Padding(padding: const EdgeInsets.fromLTRB(16, 0, 16, 16), child: widget.child),
    ]));
}
