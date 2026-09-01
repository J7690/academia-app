import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/smart_whiteboard_provider.dart';
import '../../../student/video_publish_screen.dart';
import '../../../../video/academia_playback_view.dart';

/// Écran de prévisualisation de la vidéo Smart Whiteboard
/// 
/// Permet de visualiser la vidéo MP4 générée par Kamatera,
/// de la partager, de la télécharger et de la publier dans le Challenge Feed.
class SmartWhiteboardPreviewScreen extends StatefulWidget {
  final String? projectId;
  final String? renderId;
  final String? videoUrl;

  const SmartWhiteboardPreviewScreen({
    super.key,
    this.projectId,
    this.renderId,
    this.videoUrl,
  });

  @override
  State<SmartWhiteboardPreviewScreen> createState() => _SmartWhiteboardPreviewScreenState();
}

class _SmartWhiteboardPreviewScreenState extends State<SmartWhiteboardPreviewScreen> {
  bool _isPolling = false;
  String? _resolvedVideoUrl;

  /// Ce qui a échoué, en clair. Tant qu'il est nul, on fabrique encore.
  String? _erreur;

  @override
  void initState() {
    super.initState();
    debugPrint('[WB-PREVIEW] initState — projectId=${widget.projectId} renderId=${widget.renderId} videoUrl=${widget.videoUrl}');
    WidgetsBinding.instance.addPostFrameCallback((_) => _start());
  }

  Future<void> _start() async {
    final provider = context.read<SmartWhiteboardProvider>();
    debugPrint('[WB-PREVIEW] _start — provider.renderVideoUrl=${provider.renderVideoUrl} provider.currentRenderJobId=${provider.currentRenderJobId}');

    // 1. Prendre l'URL déjà connue — MAIS SEULEMENT SI ELLE EST BIEN CELLE DE
    //    CE COURS-LÀ.
    //
    // `provider.renderVideoUrl` est un champ unique, partagé par tous les cours.
    // L'écran le lisait sans vérifier à quel projet il appartenait : après avoir
    // regardé un cours, en ouvrir un AUTRE affichait le PRÉCÉDENT.
    //
    // Mesuré sur le téléphone de Jocelyn le 20/08 à 14:04:22 : ouverture de
    // « les nuages » (projet 518ca1e4), et l'application a monté le lecteur sur
    // `capsules/capsule/1787233422/capsule.mp4` — la capsule de « la date ».
    // Rien ne le signalait : une vidéo s'affichait, simplement pas la bonne.
    //
    // On ne se fie donc à la mémoire que si le provider parle du MÊME projet.
    final memoireUtilisable = provider.currentProjectId != null &&
        widget.projectId != null &&
        provider.currentProjectId == widget.projectId;
    final url = widget.videoUrl ??
        (memoireUtilisable || widget.projectId == null
            ? provider.renderVideoUrl
            : null);
    if (url != null) {
      debugPrint('[WB-PREVIEW] URL already known, skipping poll → $url');
      _setVideoUrl(url);
      return;
    }

    // 2. Sinon, lancer le suivi si on a un travail en cours
    if (provider.currentRenderJobId != null && !_isPolling) {
      debugPrint('[WB-PREVIEW] Starting poll for renderJobId=${provider.currentRenderJobId}');
      setState(() {
        _isPolling = true;
        _erreur = null;
      });

      // Les deux fabrications ne se suivent pas de la même façon : le tableau
      // interroge `whiteboard_renders`, l'animation `studio_etat_travail`.
      if (provider.estAnimation3d) {
        await provider.suivreCapsule3d();
      } else {
        await provider.pollRenderJob();
      }
      if (!mounted) return;

      final polledUrl = provider.renderVideoUrl;
      debugPrint('[WB-PREVIEW] Poll done — polledUrl=$polledUrl state=${provider.state}');
      setState(() => _isPolling = false);

      if (polledUrl != null) {
        _setVideoUrl(polledUrl);
        return;
      }

      // NE PLUS LAISSER TOURNER UNE ROUE SUR UN RENDU MORT.
      // Le provider recevait bien le message d'erreur du serveur, mais cet
      // écran ne le lisait jamais : l'étudiant restait devant un sablier
      // éternel pour un rendu déjà échoué en base. C'est le défaut mesuré le
      // 07/08, et c'est ici qu'il se corrige.
      setState(() {
        _erreur = provider.errorMessage ??
            "La vidéo n'a pas pu être fabriquée. Ton cours reste enregistré.";
      });
    } else if (widget.projectId != null) {
      // RATTRAPER UNE CAPSULE DONT ON A PERDU L'IDENTIFIANT.
      //
      // `currentRenderJobId` ne vit qu'en mémoire : l'application relancée, il
      // est nul, et une capsule PAYÉE devenait injoignable — « Mes cours » ne
      // joint que `whiteboard_renders`, où la chaîne 3D n'écrit jamais.
      //
      // La RPC `studio_creer_travail_etudiant` est idempotente et le sait : elle
      // rend le travail déjà en cours, ou la capsule déjà prête, plutôt que d'en
      // refabriquer une. C'est donc elle, et pas une nouvelle table, qui répare
      // la perte de fil.
      debugPrint('[WB-PREVIEW] pas de travail en memoire — on rattache le projet');
      setState(() {
        _isPolling = true;
        _erreur = null;
      });
      final provider = context.read<SmartWhiteboardProvider>();
      await provider.createRenderJob();
      if (!mounted) return;
      if (provider.currentRenderJobId == null) {
        setState(() {
          _isPolling = false;
          _erreur = provider.errorMessage ??
              "Ce cours n'a pas encore de vidéo.";
        });
        return;
      }
      setState(() => _isPolling = false);
      await _start();
    } else {
      debugPrint('[WB-PREVIEW] ⚠️ No URL and no renderJobId — nothing to play');
      setState(() {
        _erreur = "Aucune fabrication en cours pour ce cours.";
      });
    }
  }

  Future<void> _reessayer() async {
    final provider = context.read<SmartWhiteboardProvider>();
    setState(() {
      _erreur = null;
      _resolvedVideoUrl = null;
    });
    await provider.createRenderJob();
    if (!mounted) return;
    if (provider.state == SmartWhiteboardState.error) {
      setState(() => _erreur = provider.errorMessage);
      return;
    }
    await _start();
  }

  void _setVideoUrl(String url) {
    debugPrint('[WB-PREVIEW] ✅ _setVideoUrl → ${url.length > 80 ? '${url.substring(0, 80)}...' : url}');
    setState(() { _resolvedVideoUrl = url; });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Prévisualisation'),
        backgroundColor: const Color(0xFF1EA75C),
        actions: [
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: _handleShare,
          ),
          IconButton(
            icon: const Icon(Icons.download),
            onPressed: _handleDownload,
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: Center(
              child: _buildVideoPlayer(),
            ),
          ),
          _buildActionButtons(),
        ],
      ),
    );
  }

  Widget _buildVideoPlayer() {
    // URL résolue → AcademiaPlaybackView (natif Android avec safeCodecSelector)
    if (_resolvedVideoUrl != null) {
      debugPrint('[WB-PREVIEW] Building AcademiaPlaybackView for url=${_resolvedVideoUrl!.substring(0, _resolvedVideoUrl!.length.clamp(0, 60))}...');
      return _player(_resolvedVideoUrl!);
    }

    // Pas encore de vidéo complète : si le worker a déjà déposé l'aperçu court,
    // on le joue pour que l'étudiant voie son cours démarrer sans attendre.
    final previewUrl = context.watch<SmartWhiteboardProvider>().previewVideoUrl;
    if (previewUrl != null) {
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Expanded(child: _player(previewUrl)),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            color: const Color(0xFF1EA75C).withValues(alpha: 0.12),
            child: const Row(
              children: [
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Aperçu des premières secondes — la vidéo complète finit de se préparer.',
                    style: TextStyle(fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    }

    // ÉCHEC : on le dit, et on propose de réessayer.
    if (_erreur != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 46, color: Color(0xFFB45309)),
              const SizedBox(height: 14),
              const Text(
                "La vidéo n'a pas pu être fabriquée",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              Text(
                _erreur!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 13, height: 1.45, color: Color(0xFF6B7280)),
              ),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: _reessayer,
                icon: const Icon(Icons.refresh),
                label: const Text('Réessayer'),
              ),
            ],
          ),
        ),
      );
    }

    // EN COURS : on dit à quelle étape on en est, pas seulement qu'on attend.
    final provider = context.watch<SmartWhiteboardProvider>();
    final etape = provider.etapeEnCours ??
        (_isPolling ? 'Fabrication en cours' : 'Chargement de la vidéo');
    // L'ATTENTE ANNONCÉE DOIT ÊTRE CELLE QU'ON A MESURÉE.
    // « une dizaine de minutes » datait de la chaîne Blender. Le moteur
    // navigateur rend dix fois plus vite : mesure du 19/08 sur capsule réelle,
    // 2 min 40 de la commande à la vidéo. Annoncer quatre fois trop pousse
    // l'étudiant à quitter l'écran — le geste qui, précisément, lui fait perdre
    // le suivi de sa capsule.
    final attente = provider.estAnimation3d
        ? "L'animation demande une machine dédiée : compte trois à quatre minutes."
        : "Ton cours s'écrit au tableau : deux à trois minutes.";

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 18),
            Text(etape,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Text(attente,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 12.5, height: 1.45, color: Color(0xFF6B7280))),
          ],
        ),
      ),
    );
  }

  /// Lecteur natif. La clé force la recréation lors du passage aperçu → complet.
  Widget _player(String url) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: AcademiaPlaybackView(
        key: ValueKey(url),
        url: url,
        autoplay: true,
        looping: true,
        muted: false,
        showControls: true,
        fit: BoxFit.contain,
        showErrorText: true,
      ),
    );
  }

  /// URL de la vidéo effectivement disponible (widget, résolue ou provider).
  String? get _effectiveVideoUrl {
    final provider = context.read<SmartWhiteboardProvider>();
    return _resolvedVideoUrl ?? widget.videoUrl ?? provider.renderVideoUrl;
  }

  Future<void> _handlePublish() async {
    final url = _effectiveVideoUrl;
    if (url == null || url.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('La vidéo n\'est pas encore prête.')),
      );
      return;
    }

    // Réutilise le flux de publication existant du Challenge (caption, cover,
    // visibilité...). La vidéo est déjà uploadée : on passe l'URL rendue.
    final published = await Navigator.of(context).push<bool?>(
      MaterialPageRoute(
        builder: (_) => VideoPublishScreen(
          videoUrl: url,
          videoType: 'free',
        ),
      ),
    );

    if (!mounted) return;
    if (published == true) {
      // Ferme le studio Smart Whiteboard et remonte vers le feed.
      Navigator.of(context).pop(true);
    }
  }

  Widget _buildActionButtons() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Action principale : publier dans le Challenge
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _resolvedVideoUrl != null ? _handlePublish : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1EA75C),
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              icon: const Icon(Icons.upload),
              label: const Text(
                'Publier dans le Challenge',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.edit),
                  label: const Text('Modifier le storyboard'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                  label: const Text('Fermer'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _handleShare() {
    if (widget.videoUrl == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Aucune vidéo à partager')),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Partage - Fonctionnalité à implémenter')),
    );
  }

  void _handleDownload() {
    if (widget.videoUrl == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Aucune vidéo à télécharger')),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Téléchargement - Fonctionnalité à implémenter')),
    );
  }
}
