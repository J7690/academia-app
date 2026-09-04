import 'dart:typed_data';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart'
    show TargetPlatform, debugPrint, defaultTargetPlatform, kIsWeb;
import 'package:flutter/services.dart'
    show MethodChannel, MissingPluginException, PlatformException;
import 'package:permission_handler/permission_handler.dart';
import 'package:printing/printing.dart';

/// Enregistre un document là où l'utilisateur ira le chercher : le dossier
/// « Téléchargements » de son appareil, ou le téléchargement du navigateur.
///
/// Ce que remplace ce service : l'application appelait `Printing.layoutPdf`,
/// qui ouvre **l'aperçu d'impression**. L'étudiant croyait télécharger et
/// tombait sur une boîte de dialogue d'impression, à charge pour lui de
/// trouver « Enregistrer au format PDF » puis un dossier. Le fichier
/// n'atterrissait nulle part de prévisible.
///
/// Trois chemins, un seul résultat attendu :
///
///   — **Web** : `Printing.sharePdf` construit un Blob et clique un
///     `<a download>` (vérifié dans `printing-5.14.3/lib/printing_web.dart`,
///     lignes 291-308). C'est un vrai téléchargement navigateur : le fichier
///     part dans le dossier de téléchargement configuré. Rien à ajouter.
///   — **Android** : canal natif `com.academia.app/fichiers` → MediaStore.
///     Aucune permission depuis Android 10 ; en deçà, WRITE_EXTERNAL_STORAGE
///     est demandée ici, avant l'appel.
///   — **Ailleurs** (iOS, bureau) : `Printing.sharePdf`, qui ouvre la feuille
///     de partage — l'idiome de ces plateformes, où il n'existe pas de dossier
///     « Téléchargements » public.
const MethodChannel _canalFichiers = MethodChannel('com.academia.app/fichiers');

/// Ce qu'il est advenu du document. [nomFichier] est le nom **réellement**
/// retenu par le système : MediaStore ajoute « (1) » en cas d'homonyme, et
/// annoncer l'ancien nom enverrait l'étudiant chercher un fichier inexistant.
class ResultatEnregistrement {
  const ResultatEnregistrement._({
    required this.reussi,
    required this.enregistreSurLAppareil,
    this.nomFichier,
    this.erreur,
  });

  /// Le document est arrivé dans le dossier « Téléchargements ».
  factory ResultatEnregistrement.enregistre(String nomFichier) =>
      ResultatEnregistrement._(
        reussi: true,
        enregistreSurLAppareil: true,
        nomFichier: nomFichier,
      );

  /// Le document est parti par le téléchargement du navigateur ou la feuille
  /// de partage : on ne peut pas nommer sa destination finale.
  factory ResultatEnregistrement.remis() => const ResultatEnregistrement._(
        reussi: true,
        enregistreSurLAppareil: false,
      );

  factory ResultatEnregistrement.echec(String erreur) =>
      ResultatEnregistrement._(
        reussi: false,
        enregistreSurLAppareil: false,
        erreur: erreur,
      );

  final bool reussi;
  final bool enregistreSurLAppareil;
  final String? nomFichier;
  final String? erreur;
}

/// Écrit [octets] sous le nom [nom] dans les téléchargements de l'appareil.
///
/// Ne lance pas : renvoie toujours un [ResultatEnregistrement]. Un échec
/// silencieux ferait croire à l'étudiant qu'il détient son reçu — c'est
/// exactement le défaut que le dépôt traque (cf. `CLAUDE.md`, §11).
Future<ResultatEnregistrement> enregistrerDansTelechargements({
  required Uint8List octets,
  required String nom,
  String type = 'application/pdf',
}) async {
  if (kIsWeb) {
    try {
      await Printing.sharePdf(bytes: octets, filename: nom);
      return ResultatEnregistrement.remis();
    } catch (e) {
      debugPrint('Téléchargement web impossible : $e');
      return ResultatEnregistrement.echec('$e');
    }
  }

  if (defaultTargetPlatform == TargetPlatform.android) {
    try {
      if (!await _permissionAccordeeSiNecessaire()) {
        return ResultatEnregistrement.echec(
          "L'autorisation d'écrire dans les fichiers a été refusée.",
        );
      }
      final nomRetenu = await _canalFichiers.invokeMethod<String>(
        'enregistrerDansTelechargements',
        <String, dynamic>{'octets': octets, 'nom': nom, 'type': type},
      );
      return ResultatEnregistrement.enregistre(nomRetenu ?? nom);
    } on PlatformException catch (e) {
      debugPrint('Enregistrement Android impossible : ${e.code} ${e.message}');
      return ResultatEnregistrement.echec(e.message ?? e.code);
    } on MissingPluginException {
      // Le canal natif n'existe pas dans cette version installée : on remet
      // le document par le partage plutôt que de ne rien donner du tout.
      return _remettreParPartage(octets, nom);
    } catch (e) {
      debugPrint('Enregistrement Android impossible : $e');
      return ResultatEnregistrement.echec('$e');
    }
  }

  return _remettreParPartage(octets, nom);
}

Future<ResultatEnregistrement> _remettreParPartage(
  Uint8List octets,
  String nom,
) async {
  try {
    await Printing.sharePdf(bytes: octets, filename: nom);
    return ResultatEnregistrement.remis();
  } catch (e) {
    debugPrint('Partage impossible : $e');
    return ResultatEnregistrement.echec('$e');
  }
}

/// Depuis Android 10 (API 29), écrire dans « Téléchargements » via MediaStore
/// ne demande **aucune** permission. En deçà, il faut WRITE_EXTERNAL_STORAGE.
/// On interroge la version réelle de l'appareil au lieu de demander une
/// permission qui, sur un téléphone récent, serait refusée d'office par le
/// système et bloquerait un enregistrement pourtant permis.
Future<bool> _permissionAccordeeSiNecessaire() async {
  try {
    final infos = await DeviceInfoPlugin().androidInfo;
    if (infos.version.sdkInt >= 29) return true;
  } catch (e) {
    debugPrint('Version Android indéterminée ($e) — on demande la permission.');
  }
  final statut = await Permission.storage.request();
  return statut.isGranted;
}
