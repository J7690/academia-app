import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';

import '../../../../config/supabase_config.dart';

/// La capsule 3D JOUÉE par le téléphone, au lieu d'attendre la vidéo du serveur.
///
/// Le lecteur est une page web (`academia_bobodo_backend/studio_visuel/lecteur/`,
/// publiée avec l'application web sous `/lecteur/`). Mesures qui ont décidé
/// (28/10/2026, TECNO Mali-G52) : 58,6 i/s en palier léger ; voix de la scène 1
/// en 2,5 s depuis `studio-voix` ; première image parlée en ≈ 3 s, contre 2 à
/// 5 minutes pour la vidéo fabriquée sur machine GPU.
///
/// LA VIDÉO DU SERVEUR RESTE LE REPLI. Cet écran rend `CapsuleLecteurIssue.repli`
/// dès que le lecteur ne peut pas jouer (pas de WebGL2, page injoignable,
/// capsule illisible) : l'écran d'aperçu reprend alors l'attente du MP4, que la
/// chaîne GPU fabrique toujours en parallèle. Dégradation gracieuse, et dite.
enum CapsuleLecteurIssue { terminee, fermee, repli }

class CapsuleLecteurScreen extends StatefulWidget {
  const CapsuleLecteurScreen({super.key, required this.jobId});

  /// L'identifiant du travail studio (`app.studio_jobs.id`).
  final String jobId;

  /// Adresse du lecteur. Surchargée en essai par
  /// `--dart-define=LECTEUR_URL=http://127.0.0.1:8766/lecteur/index.html`
  /// (serveur du poste relié par `adb reverse`).
  static const String adresse = String.fromEnvironment(
    'LECTEUR_URL',
    defaultValue: 'https://app.academiea.com/lecteur/index.html',
  );

  /// Ouvre le lecteur. Sur le web, pas de lecteur intégré pour l'instant :
  /// repli immédiat sur la vidéo.
  static Future<CapsuleLecteurIssue> ouvrir(BuildContext context, String jobId) async {
    if (kIsWeb) return CapsuleLecteurIssue.repli;
    final issue = await Navigator.of(context).push<CapsuleLecteurIssue>(
      MaterialPageRoute(builder: (_) => CapsuleLecteurScreen(jobId: jobId)),
    );
    return issue ?? CapsuleLecteurIssue.fermee;
  }

  @override
  State<CapsuleLecteurScreen> createState() => _CapsuleLecteurScreenState();
}

class _CapsuleLecteurScreenState extends State<CapsuleLecteurScreen> {
  late final WebViewController _controleur;
  Timer? _delaiPret;
  bool _pret = false;
  bool _fini = false;

  @override
  void initState() {
    super.initState();
    _controleur = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.black)
      ..addJavaScriptChannel('Academia', onMessageReceived: (m) => _message(m.message))
      ..setNavigationDelegate(NavigationDelegate(
        onPageFinished: (_) => _configurer(),
        onWebResourceError: (e) {
          // Seule la page elle-même compte : une ressource secondaire en échec
          // (un objet 3D, par exemple) est déjà gérée et dite par le lecteur.
          if (e.isForMainFrame ?? true) _quitter(CapsuleLecteurIssue.repli, 'page : ${e.description}');
        },
      ));
    // Le son démarre sans appui : l'étudiant a déjà touché « Générer ».
    final plateforme = _controleur.platform;
    if (plateforme is AndroidWebViewController) {
      plateforme.setMediaPlaybackRequiresUserGesture(false);
    }
    _controleur.loadRequest(Uri.parse('${CapsuleLecteurScreen.adresse}?app=1'));
    // Sans « prêt » en 25 s, on n'insiste pas : la vidéo du serveur prend le relais.
    _delaiPret = Timer(const Duration(seconds: 25), () {
      if (!_pret) _quitter(CapsuleLecteurIssue.repli, 'lecteur muet après 25 s');
    });
  }

  /// Le jeton passe par un appel JavaScript, JAMAIS par l'adresse : une URL
  /// finit dans un historique, un journal de serveur, une capture d'écran.
  Future<void> _configurer() async {
    final jeton = Supabase.instance.client.auth.currentSession?.accessToken;
    if (jeton == null) {
      _quitter(CapsuleLecteurIssue.repli, 'session absente');
      return;
    }
    final config = jsonEncode({
      'job': widget.jobId,
      'jeton': jeton,
      'supabaseUrl': SupabaseConfig.url,
      'cleAnon': SupabaseConfig.anonKey,
    });
    await _controleur.runJavaScript('window.__academia = $config;');
  }

  void _message(String brut) {
    Map<String, dynamic> m;
    try {
      m = jsonDecode(brut) as Map<String, dynamic>;
    } catch (_) {
      return;
    }
    switch (m['type']) {
      case 'pret':
        _pret = true;
        debugPrint('[LECTEUR-3D] prêt : ${m['gpu']} · ${m['webgl']} · ${m['scenes']} scènes');
        break;
      case 'premiere_image_parlee':
        debugPrint('[LECTEUR-3D] première image parlée : ${m['ms']} ms après le lancement');
        break;
      case 'fin':
        _quitter(CapsuleLecteurIssue.terminee, 'fin');
        break;
      case 'erreur':
        _quitter(CapsuleLecteurIssue.repli, '${m['code']} : ${m['message']}');
        break;
    }
  }

  void _quitter(CapsuleLecteurIssue issue, String motif) {
    if (_fini || !mounted) return;
    _fini = true;
    _delaiPret?.cancel();
    debugPrint('[LECTEUR-3D] sortie ${issue.name} — $motif');
    Navigator.of(context).pop(issue);
  }

  @override
  void dispose() {
    _delaiPret?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            Positioned.fill(child: WebViewWidget(controller: _controleur)),
            Positioned(
              top: 4,
              left: 4,
              child: IconButton(
                tooltip: 'Fermer',
                icon: const Icon(Icons.close, color: Colors.white70),
                onPressed: () => _quitter(CapsuleLecteurIssue.fermee, 'fermé par l\'étudiant'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
