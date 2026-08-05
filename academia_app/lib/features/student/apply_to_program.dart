import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/student_applications_provider.dart';
import '../../providers/student_profile_provider.dart';
import 'application_request_dialog.dart';
import 'dossier_completion_sheet.dart';
import 'dossier_fields.dart';

/// Parcours complet « Candidater », appelable depuis n'importe quel écran.
///
/// Écrit ici une seule fois : le mini-site université et l'accueil étudiant
/// portaient jusqu'ici deux copies du même bloc, qu'il fallait corriger deux
/// fois — et qui avaient commencé à diverger.
///
/// Ordre retenu : on vérifie le dossier AVANT d'ouvrir le formulaire de
/// candidature, pour que l'étudiant ne saisisse jamais pour rien. Le contrôle
/// après envoi reste en filet, parce que c'est le serveur qui tranche : dans
/// ce cas la candidature déjà saisie est renvoyée telle quelle, sans re-saisie.
Future<void> applyToProgram(
  BuildContext context, {
  required String programId,
  String? programTitle,
  String? initialDegreeLevel,
  String? initialStudyMode,
}) async {
  final profileProvider = context.read<StudentProfileProvider>();
  final applicationsProvider = context.read<StudentApplicationsProvider>();
  final messenger = ScaffoldMessenger.of(context);

  // 1. Contrôle en amont. Une vérification qui n'aboutit pas (réseau, RPC)
  //    ne bloque pas : le serveur reste l'arbitre à l'envoi, et le filet de
  //    l'étape 4 rattrape le refus sans rien perdre.
  final status = await profileProvider.checkDossier();
  if (!context.mounted) return;

  if (status.verified && !status.isComplete) {
    final ready = await showDossierCompletionSheet(
      context,
      profileProvider: profileProvider,
      missingFields: status.missingFields,
    );
    if (!context.mounted) return;
    if (!ready) return; // l'étudiant a refermé le formulaire
  }

  // 2. La candidature elle-même.
  final request = await showApplicationRequestDialog(
    context,
    programTitle: programTitle,
    initialDegreeLevel: initialDegreeLevel,
    initialStudyMode: initialStudyMode,
  );
  if (!context.mounted) return;
  if (request == null) return;

  // 3. Envoi.
  var success = await _send(applicationsProvider, programId, request);
  if (!context.mounted) return;

  // 4. Filet : le serveur refuse encore. On complète, puis on renvoie la
  //    candidature DÉJÀ saisie. Une seule reprise — au-delà, on affiche
  //    l'erreur plutôt que de boucler.
  if (!success && applicationsProvider.dossierIncomplete) {
    final ready = await showDossierCompletionSheet(
      context,
      profileProvider: profileProvider,
      missingFields: applicationsProvider.missingFields,
    );
    if (!context.mounted) return;
    if (ready) {
      success = await _send(applicationsProvider, programId, request);
      if (!context.mounted) return;
    }
  }

  messenger.showSnackBar(
    SnackBar(
      content: Text(
        success
            ? 'Candidature créée avec succès.'
            : _failureMessage(applicationsProvider),
      ),
    ),
  );
}

Future<bool> _send(
  StudentApplicationsProvider provider,
  String programId,
  ApplicationRequestData request,
) {
  return provider.createApplication(
    programId: programId,
    requestedDegreeLevel: request.requestedDegreeLevel,
    requestedStudyMode: request.requestedStudyMode,
    requestedSchedule: request.requestedSchedule,
    discountRequested: request.discountRequested,
    discountDetails: request.discountDetails,
    studentComment: request.studentComment,
  );
}

/// Le serveur renvoie des noms de colonnes ; l'étudiant lit des libellés.
String _failureMessage(StudentApplicationsProvider provider) {
  if (provider.dossierIncomplete) {
    final labels = provider.missingFields.map(dossierFieldLabel).toList();
    if (labels.isNotEmpty) {
      return 'Il manque encore : ${labels.join(', ')}.';
    }
  }
  return provider.error ?? 'Erreur lors de la création de la candidature.';
}
