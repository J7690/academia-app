import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../services/hero_video_encoder_service.dart';

class AdminHeroVideoEncoderScreen extends StatefulWidget {
  const AdminHeroVideoEncoderScreen({super.key});

  @override
  State<AdminHeroVideoEncoderScreen> createState() =>
      _AdminHeroVideoEncoderScreenState();
}

class _AdminHeroVideoEncoderScreenState
    extends State<AdminHeroVideoEncoderScreen> {
  bool _isLoading = false;
  String? _error;
  String? _success;

  bool _encoderOnline = false;
  bool _encoderStatusLoading = false;

  Uint8List? _selectedBytes;
  String? _selectedFileName;

  String? _selectedContextCode; // 'landing', 'student_home', 'minisite'

  HeroVideoEncoderJob? _lastJob;
  HeroVideoEncoderJobStatus? _lastStatus;

  List<HeroVideoRecord> _videos = const <HeroVideoRecord>[];
  bool _videosLoading = false;
  String? _videosError;

  @override
  void initState() {
    super.initState();
    _refreshEncoderStatus();
    _loadVideos();
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _refreshEncoderStatus() async {
    if (!HeroVideoEncoderService.isConfigured) {
      setState(() {
        _encoderOnline = false;
        _encoderStatusLoading = false;
      });
      return;
    }

    setState(() {
      _encoderStatusLoading = true;
    });

    try {
      final online = await HeroVideoEncoderService.isEncoderReachable();
      if (!mounted) return;
      setState(() {
        _encoderOnline = online;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _encoderOnline = false;
      });
    } finally {
      if (!mounted) return;
      setState(() {
        _encoderStatusLoading = false;
      });
    }
  }

  Future<void> _loadVideos() async {
    setState(() {
      _videosLoading = true;
      _videosError = null;
    });

    try {
      final records = await HeroVideoEncoderService.listHeroVideos();
      if (!mounted) return;
      setState(() {
        _videos = records;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _videosError = e.toString();
      });
    } finally {
      if (!mounted) return;
      setState(() {
        _videosLoading = false;
      });
    }
  }

  Future<void> _pickFile() async {
    setState(() {
      _error = null;
      _success = null;
    });

    final result = await FilePicker.platform.pickFiles(
      allowMultiple: false,
      withData: true,
      type: FileType.custom,
      allowedExtensions: const ['mp4', 'mov', 'm4v', 'webm'],
    );

    if (result == null || result.files.isEmpty) {
      return;
    }

    final file = result.files.first;
    final bytes = file.bytes;
    if (bytes == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Impossible de lire le contenu du fichier vidéo.'),
        ),
      );
      return;
    }

    setState(() {
      _selectedBytes = Uint8List.fromList(bytes);
      _selectedFileName = file.name;
    });
  }

  Future<void> _startEncoding() async {
    final bytes = _selectedBytes;
    final fileName = _selectedFileName;
    final contextCode = _selectedContextCode;

    if (bytes == null || fileName == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Sélectionne d\'abord une vidéo à transcoder.'),
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
      _success = null;
      _lastStatus = null;
    });

    try {
      final job = await HeroVideoEncoderService.startJob(
        bytes: bytes,
        fileName: fileName,
        context: contextCode,
      );

      setState(() {
        _lastJob = job;
        if (job.heroVideoId != null && job.heroVideoId!.isNotEmpty) {
          _success =
              'Transcodage terminé. Vidéo Hero créée (id=${job.heroVideoId}).';
        } else {
          _success = 'Transcodage terminé avec statut: ${job.status}.';
        }
      });
      await _loadVideos();
    } catch (e) {
      setState(() {
        _error = e.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _refreshJobStatus() async {
    final job = _lastJob;
    if (job == null) {
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
      _success = null;
    });

    try {
      final status = await HeroVideoEncoderService.getJobStatus(job.jobId);
      setState(() {
        _lastStatus = status;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Widget _buildSelectedFileInfo() {
    final fileName = _selectedFileName;
    final bytes = _selectedBytes;

    if (fileName == null || bytes == null) {
      return const Text(
        'Aucune vidéo sélectionnée. Sélectionne un fichier MP4/MOV/WEBM à transcoder.',
        style: TextStyle(fontSize: 12),
      );
    }

    final sizeMb = bytes.lengthInBytes / (1024 * 1024);
    return Text(
      'Vidéo sélectionnée : $fileName (${sizeMb.toStringAsFixed(1)} Mo)',
      style: const TextStyle(fontSize: 12),
    );
  }

  Widget _buildLastJobSummary() {
    final job = _lastJob;
    if (job == null) {
      return const SizedBox.shrink();
    }

    return Card(
      margin: const EdgeInsets.only(top: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Dernier job Hero Video Studio',
              style: TextStyle(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            SelectableText('Job ID : ${job.jobId}'),
            if (job.heroVideoId != null && job.heroVideoId!.isNotEmpty) ...[
              const SizedBox(height: 4),
              SelectableText('Hero video ID : ${job.heroVideoId}'),
            ],
            const SizedBox(height: 4),
            Text('Statut : ${job.status}'),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: ElevatedButton.icon(
                onPressed:
                    _isLoading || !HeroVideoEncoderService.isConfigured
                        ? null
                        : _refreshJobStatus,
                icon: const Icon(Icons.refresh),
                label: const Text('Recharger le statut'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLastStatusDetails() {
    final status = _lastStatus;
    if (status == null) {
      return const SizedBox.shrink();
    }

    return Card(
      margin: const EdgeInsets.only(top: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Détails du job',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            SelectableText('ID : ${status.id}'),
            const SizedBox(height: 4),
            Text('Contexte : ${status.context}'),
            const SizedBox(height: 4),
            Text('Statut : ${status.status}'),
            if (status.sourceFilename != null) ...[
              const SizedBox(height: 4),
              Text('Fichier source : ${status.sourceFilename}'),
            ],
            if (status.sourceSizeBytes != null) ...[
              const SizedBox(height: 4),
              Text('Taille source : ${status.sourceSizeBytes} octets'),
            ],
            if (status.heroVideoId != null && status.heroVideoId!.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text('Hero video ID : ${status.heroVideoId}'),
            ],
            if (status.createdAt != null) ...[
              const SizedBox(height: 4),
              Text('Créé le : ${status.createdAt}'),
            ],
            if (status.updatedAt != null) ...[
              const SizedBox(height: 4),
              Text('Mis à jour le : ${status.updatedAt}'),
            ],
            if (status.log != null && status.log!.isNotEmpty) ...[
              const SizedBox(height: 12),
              const Text(
                'Journal du job',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Container(
                width: double.infinity,
                constraints: const BoxConstraints(maxHeight: 240),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: SingleChildScrollView(
                  child: SelectableText(
                    status.log!,
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final encoderConfigured = HeroVideoEncoderService.isConfigured;
    final encoderBaseUrl = HeroVideoEncoderService.baseUrl.trim();

    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F6),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: const [
                      Icon(Icons.movie_filter, size: 24),
                      SizedBox(width: 8),
                      Text(
                        'Hero Video Studio',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Encodage local de vidéos Hero universelles (MP4 H.264/AAC, 720p max) '
                    'segmentées et stockées dans le bucket hero_videos.',
                    style: TextStyle(fontSize: 14),
                  ),
                  const SizedBox(height: 16),
                  _buildSystemStatusBlock(encoderConfigured, encoderBaseUrl),
                  const SizedBox(height: 16),
                  _buildSourceVideoBlock(),
                  const SizedBox(height: 16),
                  _buildEncodingProfileBlock(),
                  const SizedBox(height: 16),
                  _buildLaunchEncodingBlock(encoderConfigured),
                  _buildLastJobSummary(),
                  _buildLastStatusDetails(),
                  const SizedBox(height: 16),
                  _buildVideosOutputBlock(),
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      _error!,
                      style: const TextStyle(
                        color: Colors.red,
                        fontSize: 13,
                      ),
                    ),
                  ],
                  if (_success != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      _success!,
                      style: const TextStyle(
                        color: Colors.green,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSystemStatusBlock(bool encoderConfigured, String encoderBaseUrl) {
    if (!encoderConfigured) {
      return Card(
        color: const Color(0xFFFFE5E5),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              Text(
                'Encoder local non configuré',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.red,
                ),
              ),
              SizedBox(height: 8),
              Text(
                'Ce studio nécessite un serveur d\'encodage local (FastAPI + ffmpeg).',
                style: TextStyle(fontSize: 13),
              ),
              SizedBox(height: 4),
              Text(
                'Lance l\'application avec :\n'
                '--dart-define=HERO_ENCODER_BASE_URL=http://localhost:8010',
                style: TextStyle(fontSize: 13),
              ),
              SizedBox(height: 8),
              Text(
                'Les endpoints /services/hero_video_encoder/... ne doivent JAMAIS être appelés '
                'sur le domaine Supabase. C\'est un service LOCAL sur localhost.',
                style: TextStyle(fontSize: 13),
              ),
            ],
          ),
        ),
      );
    }

    if (!_encoderOnline) {
      return Card(
        color: const Color(0xFFFEF3C7),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Encoder local non détecté',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF92400E),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Base URL : $encoderBaseUrl',
                style: const TextStyle(fontSize: 13),
              ),
              const SizedBox(height: 4),
              const Text(
                'Lance le serveur :\n'
                'uvicorn main:app --host 0.0.0.0 --port 8010',
                style: TextStyle(fontSize: 13),
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: _encoderStatusLoading ? null : _refreshEncoderStatus,
                  icon: _encoderStatusLoading
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.refresh, size: 16),
                  label: const Text(
                    'Rafraîchir l\'état de l\'encoder',
                    style: TextStyle(fontSize: 13),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Card(
      color: const Color(0xFFDCFCE7),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Encoder local actif',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Color(0xFF166534),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Base URL : $encoderBaseUrl',
              style: const TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 4),
            const Text(
              'Le serveur FastAPI Hero Video Encoder est joignable sur ta machine.',
              style: TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: _encoderStatusLoading ? null : _refreshEncoderStatus,
                icon: _encoderStatusLoading
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.refresh, size: 16),
                label: const Text(
                  'Rafraîchir l\'état de l\'encoder',
                  style: TextStyle(fontSize: 13),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSourceVideoBlock() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Source vidéo (input)',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                ElevatedButton.icon(
                  onPressed: _isLoading ? null : _pickFile,
                  icon: const Icon(Icons.upload_file),
                  label: const Text('Sélectionner une vidéo'),
                ),
                const SizedBox(width: 12),
                if (_isLoading)
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            _buildSelectedFileInfo(),
          ],
        ),
      ),
    );
  }

  Widget _buildEncodingProfileBlock() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Text(
              'Profil Hero standard (lecture seule)',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Text(
              '🎞 Codec vidéo : H.264 (baseline)\n'
              '🎨 Pixel format : yuv420p\n'
              '📐 Résolution max : 1280×720\n'
              '⏱ FPS : 24 / 30\n'
              '🔊 Audio : AAC\n'
              '📦 Découpe : segments ~45–50 Mo\n'
              '🗂 Stockage : Supabase / bucket hero_videos',
              style: TextStyle(fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLaunchEncodingBlock(bool encoderConfigured) {
    final hasFile = _selectedBytes != null && _selectedFileName != null;
    final canStart = !_isLoading &&
        encoderConfigured &&
        _encoderOnline &&
        hasFile &&
        _selectedContextCode != null &&
        _selectedContextCode!.isNotEmpty;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Lancer l\'encodage (job Hero Video Studio)',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Text('Contexte d\'usage : '),
                const SizedBox(width: 8),
                DropdownButton<String>(
                  value: _selectedContextCode,
                  hint: const Text('Sélectionner un contexte'),
                  items: const [
                    DropdownMenuItem(
                      value: 'landing',
                      child: Text('Landing Hero'),
                    ),
                    DropdownMenuItem(
                      value: 'student_home',
                      child: Text('Accueil étudiant'),
                    ),
                    DropdownMenuItem(
                      value: 'minisite',
                      child: Text('Mini-site'),
                    ),
                  ],
                  onChanged: (value) {
                    setState(() {
                      _selectedContextCode = value;
                    });
                  },
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'Le contexte sert uniquement à classer les vidéos Hero (landing / étudiant / minisite).',
              style: TextStyle(fontSize: 12),
            ),
            const SizedBox(height: 16),
            Align(
              alignment: Alignment.centerLeft,
              child: ElevatedButton.icon(
                onPressed: canStart ? _startEncoding : null,
                icon: const Icon(Icons.play_arrow),
                label: const Text('Lancer l\'encodage'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVideosOutputBlock() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Vidéos Hero produites (output)',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                TextButton.icon(
                  onPressed: _videosLoading ? null : _loadVideos,
                  icon: _videosLoading
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.refresh, size: 16),
                  label: const Text(
                    'Rafraîchir',
                    style: TextStyle(fontSize: 13),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (_videosError != null) ...[
              Text(
                _videosError!,
                style: const TextStyle(color: Colors.red, fontSize: 12),
              ),
              const SizedBox(height: 8),
            ],
            if (_videosLoading && _videos.isEmpty)
              const Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              )
            else if (_videos.isEmpty)
              const Text(
                'Aucune vidéo Hero produite pour le moment.',
                style: TextStyle(fontSize: 12),
              )
            else
              Column(
                children: _videos.map((v) => _buildVideoRow(v)).toList(),
              ),
          ],
        ),
      ),
    );
  }

  String _formatContextLabel(String context) {
    switch (context) {
      case 'landing':
        return 'Landing Hero';
      case 'student_home':
        return 'Accueil étudiant';
      case 'minisite':
        return 'Mini-site';
      default:
        return context;
    }
  }

  String _formatDuration(double? seconds) {
    if (seconds == null) {
      return '-';
    }
    if (seconds < 1) {
      return '${seconds.toStringAsFixed(2)} s';
    }
    return '${seconds.toStringAsFixed(1)} s';
  }

  String _formatSize(int? bytes) {
    if (bytes == null || bytes <= 0) {
      return '-';
    }
    final mb = bytes / (1024 * 1024);
    return '${mb.toStringAsFixed(1)} Mo';
  }

  String _formatDate(DateTime? dt) {
    if (dt == null) return '-';
    return dt.toLocal().toString().split('.').first;
  }

  Widget _buildVideoRow(HeroVideoRecord v) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SelectableText(
            'ID : ${v.id}',
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            'Contexte : ${_formatContextLabel(v.context)}',
            style: const TextStyle(fontSize: 12),
          ),
          const SizedBox(height: 2),
          Text(
            'Durée : ${_formatDuration(v.duration)} | Résolution : ${v.resolution ?? '-'} | Segments : ${v.partsCount}',
            style: const TextStyle(fontSize: 12),
          ),
          const SizedBox(height: 2),
          Text(
            'Taille totale : ${_formatSize(v.totalSizeBytes)} | Créée le : ${_formatDate(v.createdAt)}',
            style: const TextStyle(fontSize: 12),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              TextButton.icon(
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: v.id));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('ID de la vidéo Hero copié.')),
                  );
                },
                icon: const Icon(Icons.copy, size: 16),
                label: const Text('Copier l\'ID'),
              ),
              if (v.partsUrls.isNotEmpty)
                TextButton.icon(
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: v.partsUrls.first));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('URL du premier segment copiée.'),
                      ),
                    );
                  },
                  icon: const Icon(Icons.link, size: 16),
                  label: const Text('Copier l\'URL du premier segment'),
                ),
              if (v.partsUrls.isNotEmpty)
                TextButton.icon(
                  onPressed: () {
                    _showSegmentsDialog(v);
                  },
                  icon: const Icon(Icons.list, size: 16),
                  label: const Text('Voir les segments'),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _showSegmentsDialog(HeroVideoRecord v) async {
    await showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Segments de la vidéo Hero'),
          content: SizedBox(
            width: 600,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (var i = 0; i < v.partsUrls.length; i++)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('${i + 1}. ', style: const TextStyle(fontSize: 12)),
                          Expanded(
                            child: SelectableText(
                              v.partsUrls[i],
                              style: const TextStyle(fontSize: 12),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.copy, size: 16),
                            tooltip: 'Copier',
                            onPressed: () {
                              Clipboard.setData(ClipboardData(text: v.partsUrls[i]));
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Segment ${i + 1} copié.'),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('Fermer'),
            ),
          ],
        );
      },
    );
  }
}
