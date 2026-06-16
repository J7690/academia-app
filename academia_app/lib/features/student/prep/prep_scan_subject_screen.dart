import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../config/supabase_config.dart';
import 'package:http/http.dart' as http;

/// Écran étudiant : scanner un sujet d'examen et obtenir des réponses IA.
class PrepScanSubjectScreen extends StatefulWidget {
  const PrepScanSubjectScreen({super.key});

  @override
  State<PrepScanSubjectScreen> createState() => _PrepScanSubjectScreenState();
}

class _PrepScanSubjectScreenState extends State<PrepScanSubjectScreen> {
  final ImagePicker _picker = ImagePicker();

  Uint8List? _imageBytes;
  String? _imageName;
  String? _imageMimeType;
  bool _isProcessing = false;
  String? _extractedText;
  String? _answers;
  String? _error;
  String _selectedConcours = '';
  double _progress = 0;
  String _statusMessage = '';

  final _concoursOptions = [
    ('', 'Détection auto'),
    ('ENAREF', 'ENAREF — Régies financières'),
    ('ADMIN_CIVIL', 'Administration civile'),
    ('DOUANE', 'Douane'),
    ('GREFFIERS', 'Greffiers — Justice'),
    ('SANTE', 'Santé'),
    ('EDUCATION', 'Éducation'),
  ];

  // ─── Capture / Galerie ────────────────────────────────────────────

  Future<void> _pickImage(ImageSource source) async {
    try {
      final xFile = await _picker.pickImage(
        source: source,
        maxWidth: 2048,
        maxHeight: 2048,
        imageQuality: 85,
      );
      if (xFile == null) return;

      final bytes = await xFile.readAsBytes();
      final ext = xFile.name.split('.').last.toLowerCase();

      setState(() {
        _imageBytes = bytes;
        _imageName = xFile.name;
        _imageMimeType = ext == 'png' ? 'image/png' : 'image/jpeg';
        _extractedText = null;
        _answers = null;
        _error = null;
      });
    } catch (e) {
      setState(() => _error = 'Erreur lors de la sélection: $e');
    }
  }

  // ─── Envoi à l'Edge Function ──────────────────────────────────────

  Future<void> _analyzeImage() async {
    if (_imageBytes == null) return;

    setState(() {
      _isProcessing = true;
      _error = null;
      _extractedText = null;
      _answers = null;
      _progress = 0.1;
      _statusMessage = 'Lecture de l\'image...';
    });

    try {
      final base64Image = base64Encode(_imageBytes!);
      final mimeType = _imageMimeType ?? 'image/jpeg';

      setState(() {
        _progress = 0.3;
        _statusMessage = 'Extraction du texte (OCR)...';
      });

      // Call Edge Function
      final session = Supabase.instance.client.auth.currentSession;
      if (session == null) {
        throw Exception('Non authentifié. Veuillez vous reconnecter.');
      }

      final uri = Uri.parse('${SupabaseConfig.url}/functions/v1/prep-scan-subject');
      final response = await http.post(
        uri,
        headers: {
          'Authorization': 'Bearer ${session.accessToken}',
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'apikey': SupabaseConfig.anonKey,
        },
        body: jsonEncode({
          'image_base64': base64Image,
          'mime_type': mimeType,
          'mode': 'full',
          if (_selectedConcours.isNotEmpty) 'concours_type': _selectedConcours,
        }),
      );

      setState(() {
        _progress = 0.7;
        _statusMessage = 'Génération des réponses...';
      });

      final responseBody = response.body;
      Map<String, dynamic>? data;
      try {
        data = jsonDecode(responseBody) as Map<String, dynamic>?;
      } catch (_) {
        data = null;
      }

      if (response.statusCode == 200 && data != null) {
        if (data['success'] == true) {
          setState(() {
            _extractedText = data!['extracted_text']?.toString();
            _answers = data['answers']?.toString();
            _progress = 1.0;
            _statusMessage = 'Terminé !';
          });
        } else {
          setState(() {
            _error = data!['message']?.toString() ?? data['error']?.toString() ?? 'Erreur inconnue';
          });
        }
      } else if (response.statusCode == 402 && data != null) {
        setState(() {
          _error = data!['message']?.toString() ?? 'Crédits insuffisants';
        });
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

  // ─── Build ────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text('Scanner un sujet'),
        foregroundColor: Colors.white,
        elevation: 0,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF8B5CF6), Color(0xFF7C3AED)],
            ),
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ─── Instructions ─────────────────────────────────────
            if (_imageBytes == null && _answers == null)
              _buildInstructionCard(),

            // ─── Image preview ────────────────────────────────────
            if (_imageBytes != null && _answers == null)
              _buildImagePreview(),

            // ─── Concours selector ────────────────────────────────
            if (_imageBytes != null && _answers == null) ...[
              const SizedBox(height: 12),
              _buildConcoursSelector(),
            ],

            // ─── Action buttons ───────────────────────────────────
            if (_answers == null) ...[
              const SizedBox(height: 16),
              _buildActionButtons(),
            ],

            // ─── Processing indicator ─────────────────────────────
            if (_isProcessing) ...[
              const SizedBox(height: 16),
              _buildProcessingCard(),
            ],

            // ─── Error message ────────────────────────────────────
            if (_error != null) ...[
              const SizedBox(height: 16),
              _buildErrorCard(),
            ],

            // ─── Results ──────────────────────────────────────────
            if (_answers != null) ...[
              _buildResultsView(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInstructionCard() {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: const Color(0xFF8B5CF6).withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(Icons.document_scanner, size: 40, color: Color(0xFF8B5CF6)),
            ),
            const SizedBox(height: 16),
            const Text(
              'Scanner un sujet d\'examen',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Prenez en photo ou importez un sujet de concours.\nL\'IA va extraire les questions et vous fournir les réponses détaillées.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Colors.grey[600]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImagePreview() {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 300),
            child: Image.memory(
              _imageBytes!,
              fit: BoxFit.contain,
              width: double.infinity,
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                const Icon(Icons.image, size: 16, color: Colors.grey),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _imageName ?? 'image',
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                TextButton(
                  onPressed: () => setState(() {
                    _imageBytes = null;
                    _error = null;
                  }),
                  child: const Text('Changer', style: TextStyle(color: Color(0xFF8B5CF6))),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConcoursSelector() {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        child: DropdownButtonFormField<String>(
          value: _selectedConcours,
          decoration: const InputDecoration(
            labelText: 'Type de concours (optionnel)',
            border: InputBorder.none,
            icon: Icon(Icons.school, color: Color(0xFF8B5CF6)),
          ),
          items: _concoursOptions.map((c) => DropdownMenuItem(
            value: c.$1,
            child: Text(c.$2, style: const TextStyle(fontSize: 14)),
          )).toList(),
          onChanged: (v) => setState(() => _selectedConcours = v ?? ''),
        ),
      ),
    );
  }

  Widget _buildActionButtons() {
    if (_imageBytes != null) {
      return ElevatedButton.icon(
        onPressed: _isProcessing ? null : _analyzeImage,
        icon: const Icon(Icons.auto_awesome),
        label: const Text('Analyser et obtenir les réponses'),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF8B5CF6),
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }

    return Row(
      children: [
        Expanded(
          child: _ActionCard(
            icon: Icons.camera_alt,
            label: 'Prendre une photo',
            color: const Color(0xFF8B5CF6),
            onTap: () => _pickImage(ImageSource.camera),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _ActionCard(
            icon: Icons.photo_library,
            label: 'Galerie',
            color: const Color(0xFF0891B2),
            onTap: () => _pickImage(ImageSource.gallery),
          ),
        ),
      ],
    );
  }

  Widget _buildProcessingCard() {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: _progress,
                backgroundColor: Colors.grey[200],
                valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF8B5CF6)),
                minHeight: 6,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF8B5CF6)),
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  _statusMessage,
                  style: TextStyle(fontSize: 14, color: Colors.grey[700]),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorCard() {
    return Card(
      elevation: 0,
      color: Colors.red[50],
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.red),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                _error!,
                style: const TextStyle(color: Colors.red, fontSize: 13),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResultsView() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Success header
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF8B5CF6), Color(0xFF7C3AED)],
            ),
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Row(
            children: [
              Icon(Icons.check_circle, color: Colors.white, size: 28),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Correction terminée',
                      style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Voici les réponses détaillées à votre sujet',
                      style: TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Extracted text (collapsible)
        if (_extractedText != null)
          _CollapsibleCard(
            title: 'Texte extrait',
            icon: Icons.text_snippet,
            color: const Color(0xFF0891B2),
            child: SelectableText(
              _extractedText!,
              style: const TextStyle(fontSize: 13, height: 1.5),
            ),
          ),
        const SizedBox(height: 12),

        // Answers
        Card(
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF8B5CF6).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.auto_awesome, color: Color(0xFF8B5CF6), size: 20),
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      'Réponses & Corrections',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                MarkdownBody(
                  data: _answers ?? '',
                  selectable: true,
                  styleSheet: MarkdownStyleSheet(
                    p: const TextStyle(fontSize: 14, height: 1.6),
                    h1: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    h2: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    h3: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    strong: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF8B5CF6)),
                    listBullet: const TextStyle(fontSize: 14),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Action buttons
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => setState(() {
                  _imageBytes = null;
                  _extractedText = null;
                  _answers = null;
                  _error = null;
                }),
                icon: const Icon(Icons.camera_alt),
                label: const Text('Scanner un autre sujet'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  side: const BorderSide(color: Color(0xFF8B5CF6)),
                  foregroundColor: const Color(0xFF8B5CF6),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
// Reusable widgets
// ═══════════════════════════════════════════════════════════════════════

class _ActionCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ActionCard({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Card(
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(icon, color: color, size: 28),
              ),
              const SizedBox(height: 12),
              Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CollapsibleCard extends StatefulWidget {
  final String title;
  final IconData icon;
  final Color color;
  final Widget child;

  const _CollapsibleCard({
    required this.title,
    required this.icon,
    required this.color,
    required this.child,
  });

  @override
  State<_CollapsibleCard> createState() => _CollapsibleCardState();
}

class _CollapsibleCardState extends State<_CollapsibleCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Column(
        children: [
          ListTile(
            leading: Icon(widget.icon, color: widget.color),
            title: Text(
              widget.title,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
            ),
            trailing: Icon(
              _expanded ? Icons.expand_less : Icons.expand_more,
              color: Colors.grey,
            ),
            onTap: () => setState(() => _expanded = !_expanded),
          ),
          if (_expanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: widget.child,
            ),
        ],
      ),
    );
  }
}
