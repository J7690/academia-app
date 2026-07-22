import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../services/content_media_service.dart';

/// Onglet « Médiathèque » (M4) — le manager/admin met à disposition des
/// visuels, affiches et vidéos, diffusés à l'équipe (ou à tous pour l'admin).
/// Les commerciaux les consultent depuis leur espace ; chaque accès est
/// journalisé (traçabilité des visuels partenaires).
class ManagerMediaTab extends StatefulWidget {
  final bool isAdmin;
  const ManagerMediaTab({super.key, this.isAdmin = false});

  @override
  State<ManagerMediaTab> createState() => _ManagerMediaTabState();
}

class _ManagerMediaTabState extends State<ManagerMediaTab> {
  bool _loading = true;
  List<Map<String, dynamic>> _assets = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      // Le manager/admin voit ce qu'il a créé (RLS creator/admin) — on récupère
      // via la liste commerciale pour l'aperçu de diffusion.
      final r = await Supabase.instance.client
          .rpc('app_commercial_list_content_assets');
      if (r is Map && r['success'] == true) {
        _assets = (r['assets'] as List? ?? [])
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
      }
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _openAddSheet() async {
    final titleCtrl = TextEditingController();
    final urlCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    String type = 'image';
    String audience = widget.isAdmin ? 'all_commercials' : 'team';
    Uint8List? pickedBytes;
    String? pickedName;
    bool busy = false;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.9,
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          left: 16, right: 16, top: 16,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
        ),
        child: StatefulBuilder(
          builder: (ctx, setSheet) => SingleChildScrollView(
            child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Ajouter un média',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              TextField(controller: titleCtrl, decoration: const InputDecoration(labelText: 'Titre')),
              const SizedBox(height: 8),
              // Option 1 : importer un fichier (téléchargeable/partageable par les commerciaux)
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: busy
                          ? null
                          : () async {
                              // Pattern éprouvé de l'app : FileType.custom +
                              // extensions (FileType.media est peu fiable sur Android).
                              final res = await FilePicker.platform.pickFiles(
                                allowMultiple: false,
                                withData: true,
                                type: FileType.custom,
                                allowedExtensions: const [
                                  'jpg', 'jpeg', 'png', 'webp', 'gif',
                                  'mp4', 'mov', 'webm', 'm4v',
                                  'pdf',
                                ],
                              );
                              if (res == null || res.files.isEmpty) return;
                              final picked = res.files.first;
                              if (picked.bytes == null) {
                                if (ctx.mounted) {
                                  ScaffoldMessenger.of(ctx).showSnackBar(
                                      const SnackBar(
                                          content: Text(
                                              'Impossible de lire ce fichier. Réessayez ou choisissez-en un autre.')));
                                }
                                return;
                              }
                              if (picked.size > 200 * 1024 * 1024) {
                                if (ctx.mounted) {
                                  ScaffoldMessenger.of(ctx).showSnackBar(
                                      const SnackBar(
                                          content: Text(
                                              'Fichier trop volumineux (max 200 Mo).')));
                                }
                                return;
                              }
                              // Détection auto du type selon l'extension.
                              final ext = picked.extension?.toLowerCase() ?? '';
                              final detected = ['mp4', 'mov', 'webm', 'm4v']
                                      .contains(ext)
                                  ? 'video'
                                  : (ext == 'pdf' ? 'document' : 'image');
                              setSheet(() {
                                pickedBytes = picked.bytes;
                                pickedName = picked.name;
                                type = detected;
                                urlCtrl.clear();
                              });
                            },
                      icon: const Icon(Icons.upload_file),
                      label: Text(pickedName == null
                          ? 'Importer un fichier'
                          : 'Fichier : ${pickedName!}'),
                    ),
                  ),
                ],
              ),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 4),
                child: Text('— ou —', style: TextStyle(color: Colors.grey)),
              ),
              TextField(controller: urlCtrl, decoration: const InputDecoration(labelText: 'Coller un lien (URL du visuel / vidéo)')),
              TextField(controller: descCtrl, decoration: const InputDecoration(labelText: 'Description')),
              const SizedBox(height: 8),
              Row(children: [
                const Text('Type : '),
                DropdownButton<String>(
                  value: type,
                  items: const [
                    DropdownMenuItem(value: 'image', child: Text('Affiche / image')),
                    DropdownMenuItem(value: 'video', child: Text('Vidéo')),
                    DropdownMenuItem(value: 'document', child: Text('Document')),
                  ],
                  onChanged: (v) => setSheet(() => type = v ?? 'image'),
                ),
              ]),
              if (widget.isAdmin)
                Row(children: [
                  const Text('Diffusion : '),
                  DropdownButton<String>(
                    value: audience,
                    items: const [
                      DropdownMenuItem(value: 'all_commercials', child: Text('Tous les commerciaux')),
                      DropdownMenuItem(value: 'team', child: Text('Mon équipe')),
                    ],
                    onChanged: (v) => setSheet(() => audience = v ?? 'all_commercials'),
                  ),
                ]),
              const SizedBox(height: 8),
              FilledButton(
                onPressed: busy
                    ? null
                    : () async {
                        if (titleCtrl.text.trim().isEmpty) return;
                        if (pickedBytes == null && urlCtrl.text.trim().isEmpty) return;
                        setSheet(() => busy = true);
                        try {
                          String? storagePath;
                          String? externalUrl;
                          String? thumbUrl;
                          if (pickedBytes != null) {
                            if (type == 'image') {
                              // Image => bucket privé, filigrané à la demande.
                              storagePath = await ContentMediaService.instance
                                  .uploadToPartnerMedia(
                                      bytes: pickedBytes!, originalName: pickedName!);
                            } else {
                              // Vidéo / document => bucket public.
                              externalUrl = await ContentMediaService.instance
                                  .uploadToMarketing(
                                      bytes: pickedBytes!, originalName: pickedName!);
                            }
                          } else {
                            externalUrl = urlCtrl.text.trim();
                            if (type == 'image') thumbUrl = externalUrl;
                          }
                          await Supabase.instance.client
                              .rpc('app_manager_add_content_asset', params: {
                            'p_title': titleCtrl.text.trim(),
                            'p_asset_type': type,
                            'p_storage_path': storagePath,
                            'p_external_url': externalUrl,
                            'p_thumbnail_url': thumbUrl,
                            'p_description': descCtrl.text.trim(),
                            'p_audience_type': audience,
                          });
                          if (ctx.mounted) Navigator.pop(ctx);
                        } catch (e) {
                          if (ctx.mounted) {
                            ScaffoldMessenger.of(ctx).showSnackBar(
                                SnackBar(content: Text('Publication échouée : $e')));
                          }
                          setSheet(() => busy = false);
                        }
                      },
                child: busy
                    ? const Text('Publication…')
                    : const Text('Publier dans la médiathèque'),
              ),
              const SizedBox(height: 8),
            ],
          ),
          ),
        ),
      ),
    );
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _assets.isEmpty
              ? const Center(child: Text('Aucun média publié'))
              : RefreshIndicator(
                  onRefresh: _load,
                  child: GridView.count(
                    crossAxisCount: 2,
                    padding: const EdgeInsets.all(12),
                    childAspectRatio: 0.85,
                    children: _assets.map(_card).toList(),
                  ),
                ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openAddSheet,
        icon: const Icon(Icons.add),
        label: const Text('Média'),
      ),
    );
  }

  Widget _card(Map<String, dynamic> a) {
    final thumb = a['thumbnail_url']?.toString();
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: thumb != null && thumb.isNotEmpty
                ? Image.network(thumb, fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const Icon(Icons.image, size: 40))
                : Container(
                    color: Colors.indigo.shade50,
                    child: Icon(
                        a['asset_type'] == 'video' ? Icons.play_circle : Icons.description,
                        size: 40)),
          ),
          Padding(
            padding: const EdgeInsets.all(8),
            child: Text(a['title']?.toString() ?? '—',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
          ),
        ],
      ),
    );
  }
}
