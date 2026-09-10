import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Vérifier un bon de courtage présenté au guichet.
///
/// C'EST ICI, ET NULLE PART AILLEURS, QU'UN BON SE CLÔT. L'onglet « Mes
/// documents » montre des copies d'annonce sans code ; seul le papier du
/// candidat porte le secret. La procédure voulue par Jocelyn tient à cela :
/// le candidat se déplace, l'agent scanne, l'école décide.
///
/// LE SCAN SE FAIT DANS L'APPLICATION, ET C'EST LE POINT. Un lecteur externe
/// ouvrirait un navigateur où l'agent n'est peut-être pas connecté ; le serveur
/// ne saurait alors pas QUI vérifie, et ne pourrait pas répondre « ce bon n'est
/// pas adressé à votre établissement ». Toute la garantie repose sur l'identité
/// de l'appelant.
///
/// Le QR encode une adresse `…/v/<numéro>/<jeton>`. On n'ouvre pas cette
/// adresse : on en extrait les deux morceaux et on interroge le serveur. Le
/// papier ne prouve rien, c'est l'enregistrement qui répond.
class UniversityScanBonScreen extends StatefulWidget {
  const UniversityScanBonScreen({super.key});

  @override
  State<UniversityScanBonScreen> createState() => _UniversityScanBonScreenState();
}

class _UniversityScanBonScreenState extends State<UniversityScanBonScreen> {
  final MobileScannerController _controleur = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
    formats: const [BarcodeFormat.qrCode],
  );

  bool _enCours = false;
  Map<String, dynamic>? _resultat;
  String? _numeroLu;
  String? _codeLu;

  @override
  void dispose() {
    _controleur.dispose();
    super.dispose();
  }

  /// Extrait le numéro et le secret d'une adresse `…/v/<numéro>/<jeton>`.
  ///
  /// Tolère aussi un texte brut « BC-2026-000147 7K4M-92XQ », au cas où
  /// quelqu'un colle le contenu d'un QR lu ailleurs.
  static (String, String)? _lire(String? brut) {
    final t = (brut ?? '').trim();
    if (t.isEmpty) return null;

    final uri = Uri.tryParse(t);
    if (uri != null && uri.pathSegments.length >= 3) {
      final s = uri.pathSegments;
      final i = s.indexOf('v');
      if (i >= 0 && s.length > i + 2) return (s[i + 1], s[i + 2]);
    }

    final m = RegExp(r'(BC-\d{4}-\d{6})\D+([0-9A-Za-z-]{6,})').firstMatch(t);
    if (m != null) return (m.group(1)!, m.group(2)!);
    return null;
  }

  Future<void> _verifier(String numero, String code) async {
    setState(() {
      _enCours = true;
      _numeroLu = numero;
      _codeLu = code;
    });
    try {
      final r = await Supabase.instance.client.rpc(
        'app_verifier_bon_de_courtage',
        params: {'p_numero': numero, 'p_code': code},
      );
      if (!mounted) return;
      setState(() => _resultat =
          r is Map<String, dynamic> ? r : {'resultat': 'reponse_inattendue'});
    } catch (e) {
      if (!mounted) return;
      setState(() => _resultat = {
            'resultat': 'erreur_reseau',
            'message': 'La vérification n\'a pas abouti : $e',
          });
    } finally {
      if (mounted) setState(() => _enCours = false);
    }
  }

  Future<void> _clore() async {
    final messager = ScaffoldMessenger.of(context);
    setState(() => _enCours = true);
    try {
      final r = await Supabase.instance.client.rpc(
        'app_consommer_bon_de_courtage',
        params: {'p_numero': _numeroLu, 'p_code': _codeLu},
      );
      if (!mounted) return;
      final m = r is Map<String, dynamic> ? r : <String, dynamic>{};
      messager.showSnackBar(SnackBar(
          content: Text((m['message'] ?? 'Opération terminée.').toString())));
      // On relit plutôt que de supposer : l'écran doit montrer l'état RÉEL du
      // bon après l'opération, pas celui qu'on espérait.
      if (_numeroLu != null && _codeLu != null) {
        await _verifier(_numeroLu!, _codeLu!);
      }
    } catch (e) {
      if (!mounted) return;
      messager.showSnackBar(
          SnackBar(content: Text('La clôture n\'a pas abouti : $e')));
    } finally {
      if (mounted) setState(() => _enCours = false);
    }
  }

  void _recommencer() {
    setState(() {
      _resultat = null;
      _numeroLu = null;
      _codeLu = null;
    });
    _controleur.start();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Vérifier un bon de courtage'),
        actions: [
          IconButton(
            tooltip: 'Saisir le code à la main',
            onPressed: _ouvrirSaisie,
            icon: const Icon(Icons.keyboard_alt_outlined),
          ),
        ],
      ),
      body: _resultat != null
          ? _Resultat(
              donnees: _resultat!,
              enCours: _enCours,
              onClore: _clore,
              onRecommencer: _recommencer,
            )
          : Column(
              children: [
                Expanded(
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      MobileScanner(
                        controller: _controleur,
                        onDetect: (capture) {
                          if (_enCours || _resultat != null) return;
                          for (final b in capture.barcodes) {
                            final lu = _lire(b.rawValue);
                            if (lu != null) {
                              _controleur.stop();
                              _verifier(lu.$1, lu.$2);
                              return;
                            }
                          }
                        },
                        errorBuilder: (context, erreur) => _CameraIndisponible(
                          erreur: erreur.errorDetails?.message ??
                              erreur.errorCode.name,
                          onSaisir: _ouvrirSaisie,
                        ),
                      ),
                      const _Viseur(),
                      if (_enCours)
                        Container(
                          color: Colors.black54,
                          child: const Center(
                              child: CircularProgressIndicator(
                                  color: Colors.white)),
                        ),
                    ],
                  ),
                ),
                Container(
                  width: double.infinity,
                  color: const Color(0xFF14251D),
                  padding: const EdgeInsets.fromLTRB(18, 14, 18, 18),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'Vise le code carré imprimé sur le bon du candidat.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.white, fontSize: 13.5),
                      ),
                      const SizedBox(height: 8),
                      TextButton.icon(
                        onPressed: _ouvrirSaisie,
                        icon: const Icon(Icons.keyboard_alt_outlined, size: 17),
                        label: const Text('Le code ne se lit pas ? Saisir à la main'),
                        style: TextButton.styleFrom(
                            foregroundColor: const Color(0xFF9AD6AE)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  /// LA SAISIE À LA MAIN N'EST PAS UN REPLI DE CONFORT. Un papier froissé, un
  /// écran fissuré, un QR imprimé trop petit : le code à huit caractères se lit
  /// et se dicte. Sans cette porte, une école bloquée n'a aucun recours.
  Future<void> _ouvrirSaisie() async {
    final champNumero = TextEditingController(text: _numeroLu ?? 'BC-2026-');
    final champCode = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Saisir le bon à la main'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: champNumero,
              autofocus: true,
              textCapitalization: TextCapitalization.characters,
              decoration: const InputDecoration(
                labelText: 'Numéro du bon',
                hintText: 'BC-2026-000147',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: champCode,
              textCapitalization: TextCapitalization.characters,
              decoration: const InputDecoration(
                labelText: 'Clé à 8 caractères',
                hintText: '7K4M-92XQ',
                border: OutlineInputBorder(),
                helperText: 'Les tirets et la casse n\'ont pas d\'importance',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text('Annuler')),
          FilledButton(
              onPressed: () => Navigator.pop(c, true),
              child: const Text('Vérifier')),
        ],
      ),
    );
    final numero = champNumero.text.trim();
    final code = champCode.text.trim();
    champNumero.dispose();
    champCode.dispose();
    if (ok == true && numero.isNotEmpty && code.isNotEmpty) {
      await _controleur.stop();
      await _verifier(numero, code);
    }
  }
}

class _Viseur extends StatelessWidget {
  const _Viseur();

  @override
  Widget build(BuildContext context) => IgnorePointer(
        child: Center(
          child: Container(
            width: 230,
            height: 230,
            decoration: BoxDecoration(
              border: Border.all(color: Colors.white70, width: 2.5),
              borderRadius: BorderRadius.circular(18),
            ),
          ),
        ),
      );
}

class _CameraIndisponible extends StatelessWidget {
  const _CameraIndisponible({required this.erreur, required this.onSaisir});

  final String erreur;
  final VoidCallback onSaisir;

  @override
  Widget build(BuildContext context) => Container(
        color: const Color(0xFF14251D),
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.no_photography_outlined,
                size: 46, color: Colors.white70),
            const SizedBox(height: 14),
            const Text("L'appareil photo n'est pas disponible",
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            // On montre la cause. Un écran noir muet a déjà coûté une séance
            // entière de diagnostic sur ce dépôt.
            Text(erreur,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white70, fontSize: 12.5)),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onSaisir,
              icon: const Icon(Icons.keyboard_alt_outlined, size: 18),
              label: const Text('Saisir le code à la main'),
            ),
          ],
        ),
      );
}

/// Les six réponses du serveur, rendues telles quelles.
///
/// L'écran n'invente aucun message : il affiche celui que le serveur envoie.
/// C'est là-bas qu'ils ont été arrêtés avec Jocelyn, et les dupliquer ici
/// ferait vieillir les deux versions séparément.
class _Resultat extends StatelessWidget {
  const _Resultat({
    required this.donnees,
    required this.enCours,
    required this.onClore,
    required this.onRecommencer,
  });

  final Map<String, dynamic> donnees;
  final bool enCours;
  final VoidCallback onClore;
  final VoidCallback onRecommencer;

  static Map<String, dynamic> _objet(dynamic v) =>
      v is Map ? Map<String, dynamic>.from(v) : <String, dynamic>{};

  @override
  Widget build(BuildContext context) {
    final resultat = (donnees['resultat'] ?? '').toString();
    final message = (donnees['message'] ?? '').toString();
    final bon = _objet(donnees['bon']);
    final valide = resultat == 'valide';
    final peutClore = valide && donnees['peut_consommer'] == true;

    final (IconData icone, Color couleur) = switch (resultat) {
      'valide' => (Icons.verified_outlined, const Color(0xFF14663A)),
      'deja_consomme' => (Icons.history_toggle_off, const Color(0xFF1B4F9C)),
      'expire' => (Icons.schedule_outlined, const Color(0xFFB45309)),
      'pas_le_destinataire' => (Icons.block_outlined, const Color(0xFFB3261E)),
      'introuvable' => (Icons.help_outline, const Color(0xFF5A6560)),
      _ => (Icons.error_outline, const Color(0xFFB3261E)),
    };

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(18, 20, 18, 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Icon(icone, size: 56, color: couleur),
          const SizedBox(height: 12),
          Text(
            switch (resultat) {
              'valide' => 'Bon authentique',
              'deja_consomme' => 'Bon déjà accepté',
              'expire' => 'Bon échu',
              'pas_le_destinataire' => 'Ce bon ne vous est pas adressé',
              'introuvable' => 'Aucun bon ne correspond',
              'trop_de_tentatives' => 'Trop de tentatives',
              'reserve_aux_universites' => 'Accès réservé',
              _ => 'Vérification impossible',
            },
            textAlign: TextAlign.center,
            style: TextStyle(
                fontSize: 20, fontWeight: FontWeight.w800, color: couleur),
          ),
          const SizedBox(height: 8),
          if (message.isNotEmpty)
            Text(message,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 13.5, height: 1.45, color: Color(0xFF3E4A44))),
          if (bon.isNotEmpty) ...[
            const SizedBox(height: 18),
            _Bloc(bon: bon),
          ],
          const SizedBox(height: 22),
          if (peutClore)
            FilledButton.icon(
              onPressed: enCours ? null : onClore,
              icon: const Icon(Icons.check_circle_outline),
              label: const Text('Accepter et clore ce bon'),
              style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF14663A),
                  padding: const EdgeInsets.symmetric(vertical: 14)),
            ),
          if (peutClore) const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: enCours ? null : onRecommencer,
            icon: const Icon(Icons.qr_code_scanner),
            label: const Text('Scanner un autre bon'),
          ),
        ],
      ),
    );
  }
}

/// Ce qui est ENREGISTRÉ, à comparer avec ce qui est IMPRIMÉ.
class _Bloc extends StatelessWidget {
  const _Bloc({required this.bon});

  final Map<String, dynamic> bon;

  static Map<String, dynamic> _o(dynamic v) =>
      v is Map ? Map<String, dynamic>.from(v) : <String, dynamic>{};

  static String _date(dynamic v) {
    final d = DateTime.tryParse((v ?? '').toString());
    return d == null ? '' : DateFormat('dd/MM/yyyy').format(d.toLocal());
  }

  @override
  Widget build(BuildContext context) {
    final candidat = _o(bon['candidat']);
    final formation = _o(bon['formation']);
    final reduction = _o(bon['reduction']);
    final taux = reduction['taux'];

    return Container(
      padding: const EdgeInsets.fromLTRB(15, 14, 15, 14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAF9),
        border: Border.all(color: const Color(0xFFE4E9E5)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('CE QUI EST ENREGISTRÉ',
              style: TextStyle(
                  fontSize: 10,
                  letterSpacing: 1.1,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF8A9490))),
          const SizedBox(height: 10),
          _L('Candidat', (candidat['nom'] ?? '').toString()),
          _L('Né(e) le', _date(candidat['date_de_naissance'])),
          _L('Téléphone', (candidat['telephone'] ?? '').toString()),
          _L('Formation', (formation['titre'] ?? '').toString()),
          _L('Niveau', (formation['niveau'] ?? '').toString()),
          _L('Réduction', taux == null ? '' : '$taux %', fort: true),
          _L('Émis le', _date(bon['emis_le'])),
          _L('Valable jusqu\'au', _date(bon['expire_le'])),
        ],
      ),
    );
  }
}

class _L extends StatelessWidget {
  const _L(this.etiquette, this.valeur, {this.fort = false});

  final String etiquette;
  final String valeur;
  final bool fort;

  @override
  Widget build(BuildContext context) {
    if (valeur.trim().isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 122,
            child: Text(etiquette,
                style:
                    const TextStyle(fontSize: 12, color: Color(0xFF8A9490))),
          ),
          Expanded(
            child: Text(valeur,
                style: TextStyle(
                    fontSize: fort ? 15 : 13,
                    fontWeight: fort ? FontWeight.w800 : FontWeight.w500,
                    color: fort
                        ? const Color(0xFF14663A)
                        : const Color(0xFF14251D))),
          ),
        ],
      ),
    );
  }
}
