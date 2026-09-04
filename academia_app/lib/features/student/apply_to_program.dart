import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/student_application_payments_provider.dart';
import '../../providers/student_applications_provider.dart';
import '../../providers/student_profile_provider.dart';
import '../../services/analytics_tracking_service.dart';
import 'application_outcome_dialog.dart';
import 'application_request_dialog.dart';
import 'dossier_completion_sheet.dart';
import 'dossier_fields.dart';
import 'student_application_detail_screen.dart';
import 'student_dashboard_nav_controller.dart';

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
///
/// Depuis le 14/08/2026, chaque issue du parcours est annoncée par une boîte
/// de dialogue explicite (cf. `application_outcome_dialog.dart`) au lieu d'un
/// SnackBar furtif, chaque attente réseau est visible, et une candidature
/// déjà déposée est signalée AVANT toute saisie.
Future<void> applyToProgram(
  BuildContext context, {
  required String programId,
  String? programTitle,
  String? initialDegreeLevel,
  String? initialStudyMode,
}) async {
  final profileProvider = context.read<StudentProfileProvider>();
  final applicationsProvider = context.read<StudentApplicationsProvider>();

  // TUNNEL DE CANDIDATURE — instrumenté le 04/09/2026.
  //
  // Mesure du 03/09 : 279 étudiants, 9 dossiers complets, 7 candidats. On
  // savait donc que 97 % n'arrivaient pas au bout, mais pas OÙ ils s'arrêtent.
  // Ce parcours étant le point de passage unique des trois boutons
  // « Candidater » (accueil, mini-site, partenaires), le mesurer ici les couvre
  // tous les trois — et chaque étape abandonnée est nommée, pour qu'on sache
  // quoi simplifier au lieu de le deviner.
  void trace(String action, {Map<String, dynamic>? details}) {
    AnalyticsTrackingService.instance.trackAction(
      'program_apply',
      action,
      entityType: 'program',
      entityId: programId,
      properties: {
        if (programTitle != null) 'program_title': programTitle,
        ...?details,
      },
    );
  }

  trace('click');

  // 0. Garde « déjà candidaté ». L'app connaît les candidatures de
  //    l'étudiant : inutile de le laisser tout re-saisir pour un doublon.
  //    Si la liste ne peut pas être chargée (réseau), on laisse passer :
  //    ce garde-fou est un confort, pas un verrou.
  if (applicationsProvider.applications.isEmpty) {
    await _withProgress(
      context,
      'Vérification de tes candidatures…',
      applicationsProvider.loadApplications(),
    );
    if (!context.mounted) return;
  }
  final existing = _applicationFor(applicationsProvider, programId);
  if (existing != null) {
    final status = existing['status']?.toString();
    final closed = status == 'rejected' || status == 'canceled';
    trace('deja_candidate', details: {'statut': status});
    final reapply = await showAlreadyAppliedDialog(
      context,
      statusLabel: applicationStatusLabel(status),
      programTitle: programTitle,
      allowReapply: closed,
      onFollow: () => _openApplication(context, existing),
    );
    if (!context.mounted) return;
    if (!reapply) return;
  }

  // 1. Contrôle du dossier en amont. Une vérification qui n'aboutit pas
  //    (réseau, RPC) ne bloque pas : le serveur reste l'arbitre à l'envoi,
  //    et le filet de l'étape 4 rattrape le refus sans rien perdre.
  final status = await _withProgress(
    context,
    'Vérification de ton dossier…',
    profileProvider.checkDossier(),
  );
  if (!context.mounted) return;

  if (status != null && status.verified && !status.isComplete) {
    // LE POINT DE FUITE PRÉSUMÉ. Le dossier exige 12 champs ; au 03/09, la
    // moyenne remplie était de 1,4. On enregistre combien il en manque au
    // moment où l'étudiant voit le formulaire, puis s'il le referme.
    final manquants = status.missingFields.length;
    trace('dossier_requis', details: {'champs_manquants': manquants});

    final ready = await showDossierCompletionSheet(
      context,
      profileProvider: profileProvider,
      missingFields: status.missingFields,
    );
    if (!context.mounted) return;
    if (!ready) {
      // l'étudiant a refermé le formulaire
      trace('abandon_dossier', details: {'champs_manquants': manquants});
      return;
    }
    trace('dossier_complete', details: {'champs_saisis': manquants});
  }

  // 2. La candidature elle-même.
  final request = await showApplicationRequestDialog(
    context,
    programTitle: programTitle,
    initialDegreeLevel: initialDegreeLevel,
    initialStudyMode: initialStudyMode,
  );
  if (!context.mounted) return;
  if (request == null) {
    trace('abandon_formulaire');
    return;
  }

  // 3. Envoi.
  var success = await _sendWithProgress(
    context,
    applicationsProvider,
    programId,
    request,
  );
  if (success == null || !context.mounted) return;

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
      final retried = await _sendWithProgress(
        context,
        applicationsProvider,
        programId,
        request,
      );
      if (retried == null || !context.mounted) return;
      success = retried;
    }
  }

  // 5. L'issue, annoncée en clair : ce qui s'est passé, pourquoi, quoi faire.
  if (success) {
    trace('deposee', details: {
      'reduction_demandee': request.discountRequested,
    });
    final created = _applicationFor(applicationsProvider, programId);
    await showApplicationSuccessDialog(
      context,
      programTitle: programTitle,
      onFollow: () => created != null
          ? _openApplication(context, created)
          : _openApplicationsTab(context),
    );
    return;
  }

  final failure = _describeFailure(applicationsProvider);
  final retry = await showApplicationProblemDialog(
    context,
    title: failure.title,
    problem: failure.problem,
    advice: failure.advice,
    technicalDetail: failure.technicalDetail,
    actionLabel: failure.retryable ? 'Réessayer' : null,
  );
  if (!context.mounted) return;
  if (retry) {
    final retried = await _sendWithProgress(
      context,
      applicationsProvider,
      programId,
      request,
    );
    if (retried == null || !context.mounted) return;
    if (retried) {
      final created = _applicationFor(applicationsProvider, programId);
      await showApplicationSuccessDialog(
        context,
        programTitle: programTitle,
        onFollow: () => created != null
            ? _openApplication(context, created)
            : _openApplicationsTab(context),
      );
    } else {
      final again = _describeFailure(applicationsProvider);
      await showApplicationProblemDialog(
        context,
        title: again.title,
        problem: again.problem,
        advice: again.advice,
        technicalDetail: again.technicalDetail,
      );
    }
  }
}

/// Affiche une attente visible pendant [future]. Sans elle, un tap sur
/// « Candidater » avec un réseau lent ne montre RIEN pendant plusieurs
/// secondes, et l'étudiant tape à répétition en croyant le bouton cassé.
///
/// Rend `null` si le contexte a été démonté pendant l'attente.
Future<T?> _withProgress<T>(
  BuildContext context,
  String message,
  Future<T> future,
) async {
  final navigator = Navigator.of(context, rootNavigator: true);
  var dialogVisible = true;
  showDialog<void>(
    context: context,
    barrierDismissible: false,
    useRootNavigator: true,
    builder: (_) => PopScope(
      canPop: false,
      child: Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2.5),
              ),
              const SizedBox(width: 16),
              Flexible(
                child: Text(message, style: const TextStyle(fontSize: 14)),
              ),
            ],
          ),
        ),
      ),
    ),
  ).whenComplete(() => dialogVisible = false);

  try {
    return await future;
  } finally {
    if (dialogVisible && navigator.mounted) {
      navigator.pop();
    }
  }
}

Future<bool?> _sendWithProgress(
  BuildContext context,
  StudentApplicationsProvider provider,
  String programId,
  ApplicationRequestData request,
) {
  return _withProgress(
    context,
    'Envoi de ta candidature…',
    provider.createApplication(
      programId: programId,
      requestedDegreeLevel: request.requestedDegreeLevel,
      requestedStudyMode: request.requestedStudyMode,
      requestedSchedule: request.requestedSchedule,
      discountRequested: request.discountRequested,
      discountDetails: request.discountDetails,
      studentComment: request.studentComment,
    ),
  );
}

Map<String, dynamic>? _applicationFor(
  StudentApplicationsProvider provider,
  String programId,
) {
  for (final app in provider.applications) {
    if (app['program_id']?.toString() == programId) return app;
  }
  return null;
}

void _openApplication(BuildContext context, Map<String, dynamic> application) {
  Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => ChangeNotifierProvider(
        create: (_) => StudentApplicationPaymentsProvider(),
        child: StudentApplicationDetailScreen(application: application),
      ),
    ),
  );
}

void _openApplicationsTab(BuildContext context) {
  StudentDashboardNavController.setIndex(1);
  Navigator.of(context).popUntil((route) => route.isFirst);
}

class _FailureDescription {
  final String title;
  final String problem;
  final String advice;
  final String? technicalDetail;
  final bool retryable;

  const _FailureDescription({
    required this.title,
    required this.problem,
    required this.advice,
    this.technicalDetail,
    this.retryable = true,
  });
}

/// Traduit l'erreur brute du provider en message que l'étudiant comprend.
///
/// Codes possibles côté serveur (lus dans la définition de
/// `app_create_application` en production le 14/08/2026) :
/// `dossier_incomplete`, `verification_failed`,
/// « Profil étudiant introuvable », ou tout SQLERRM brut. S'y ajoutent les
/// exceptions réseau côté Dart. Aucun de ces textes ne doit être le message
/// principal : ils partent en « détail technique ».
_FailureDescription _describeFailure(StudentApplicationsProvider provider) {
  final raw = provider.error ?? '';

  if (provider.dossierIncomplete) {
    final labels = provider.missingFields.map(dossierFieldLabel).toList();
    return _FailureDescription(
      title: 'Dossier incomplet',
      problem: labels.isNotEmpty
          ? 'Ta candidature n\'a pas été envoyée : il manque encore '
              '${labels.join(', ')}.'
          : 'Ta candidature n\'a pas été envoyée : ton dossier est incomplet.',
      advice: 'Complète ton dossier depuis « Mon profil », puis candidate à '
          'nouveau. Tes informations ne sont demandées qu\'une seule fois, '
          'pour toutes tes candidatures.',
      retryable: false,
    );
  }

  if (raw.contains('verification_failed')) {
    return const _FailureDescription(
      title: 'Vérification impossible',
      problem: 'Nous n\'avons pas pu vérifier ton dossier de candidature.',
      advice: 'Ce n\'est pas de ton fait. Réessaie dans un instant ; si le '
          'problème persiste, contacte le support Academia.',
      technicalDetail: 'verification_failed',
    );
  }

  if (raw.contains('Profil étudiant introuvable') ||
      raw.contains('student_profile_not_found') ||
      raw.contains('not_authenticated')) {
    return _FailureDescription(
      title: 'Compte étudiant introuvable',
      problem: 'Nous n\'avons pas retrouvé ton compte étudiant.',
      advice: 'Déconnecte-toi puis reconnecte-toi à l\'application. Si le '
          'problème persiste, contacte le support Academia.',
      technicalDetail: raw,
      retryable: false,
    );
  }

  final lower = raw.toLowerCase();
  if (lower.contains('socketexception') ||
      lower.contains('clientexception') ||
      lower.contains('timeoutexception') ||
      lower.contains('failed host lookup') ||
      lower.contains('connection')) {
    return _FailureDescription(
      title: 'Problème de connexion',
      problem: 'Ta candidature n\'a pas pu être envoyée : la connexion au '
          'serveur a échoué.',
      advice: 'Vérifie ta connexion internet, puis réessaie. Ta saisie est '
          'conservée.',
      technicalDetail: raw,
    );
  }

  return _FailureDescription(
    title: 'Envoi impossible',
    problem: 'Ta candidature n\'a pas pu être envoyée.',
    advice: 'Réessaie dans un instant. Si le problème persiste, contacte le '
        'support Academia en lui montrant le détail technique ci-dessous.',
    technicalDetail: raw.isEmpty ? null : raw,
  );
}
