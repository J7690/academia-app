import 'package:flutter/material.dart';

import '../../widgets/adaptive_dialog.dart';

/// Boîtes de dialogue de résultat du parcours « Candidater ».
///
/// Constat du 14/08/2026 : tous les retours du parcours passaient par des
/// SnackBars furtifs, et des codes bruts (`verification_failed`, messages
/// SQL) atteignaient l'écran. Chaque dialogue de ce fichier dit trois
/// choses, toujours dans cet ordre : **ce qui s'est passé, pourquoi, et ce
/// que l'étudiant doit faire.** Le détail technique reste disponible, mais
/// replié : il sert au support, pas à l'étudiant.

const Color _kInk = Color(0xFF0A2540);
const Color _kMuted = Color(0xFF6B7280);
const Color _kPrimary = Color(0xFF3275D0);

/// Libellé lisible d'un statut de candidature. Même vocabulaire que l'onglet
/// « Candidatures » : l'étudiant ne doit pas lire deux noms pour un même état.
String applicationStatusLabel(String? status) {
  switch (status) {
    case 'draft':
      return 'Brouillon';
    case 'submitted':
      return 'Soumise';
    case 'under_review':
      return 'En étude';
    case 'accepted':
      return 'Acceptée';
    case 'rejected':
      return 'Refusée';
    case 'canceled':
      return 'Annulée';
    default:
      return status ?? '';
  }
}

/// Succès : confirme, puis oriente vers la suite (suivi de la candidature).
Future<void> showApplicationSuccessDialog(
  BuildContext context, {
  String? programTitle,
  VoidCallback? onFollow,
}) {
  return showAdaptiveAppDialog<void>(
    context: context,
    title: const Row(
      children: [
        Icon(Icons.check_circle, color: Color(0xFF2E7D32)),
        SizedBox(width: 8),
        Expanded(child: Text('Candidature envoyée')),
      ],
    ),
    builder: (_) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          programTitle == null || programTitle.isEmpty
              ? 'Ta candidature a bien été transmise à l\'université.'
              : 'Ta candidature à « $programTitle » a bien été transmise à l\'université.',
          style: const TextStyle(fontSize: 15, color: _kInk, height: 1.4),
        ),
        const SizedBox(height: 8),
        const Text(
          'L\'université va l\'étudier. Tu peux suivre son avancement et '
          'échanger avec l\'université depuis l\'onglet « Candidatures ».',
          style: TextStyle(fontSize: 13, color: _kMuted, height: 1.4),
        ),
      ],
    ),
    actionsBuilder: (dialogContext) => [
      TextButton(
        onPressed: () => Navigator.of(dialogContext).pop(),
        child: const Text('Fermer'),
      ),
      if (onFollow != null)
        ElevatedButton.icon(
          onPressed: () {
            Navigator.of(dialogContext).pop();
            onFollow();
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: _kPrimary,
            foregroundColor: Colors.white,
          ),
          icon: const Icon(Icons.visibility_outlined),
          label: const Text('Suivre ma candidature'),
        ),
    ],
  );
}

/// L'étudiant a déjà une candidature pour cette formation.
///
/// Rend `true` si l'étudiant choisit de candidater à nouveau (proposé
/// uniquement quand [allowReapply] est vrai, c'est-à-dire pour une
/// candidature refusée ou annulée).
Future<bool> showAlreadyAppliedDialog(
  BuildContext context, {
  required String statusLabel,
  String? programTitle,
  bool allowReapply = false,
  VoidCallback? onFollow,
}) async {
  final result = await showAdaptiveAppDialog<bool>(
    context: context,
    title: const Row(
      children: [
        Icon(Icons.info_outline, color: _kPrimary),
        SizedBox(width: 8),
        Expanded(child: Text('Tu as déjà candidaté')),
      ],
    ),
    builder: (_) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          programTitle == null || programTitle.isEmpty
              ? 'Tu as déjà une candidature pour cette formation '
                  '(statut : $statusLabel).'
              : 'Tu as déjà une candidature pour « $programTitle » '
                  '(statut : $statusLabel).',
          style: const TextStyle(fontSize: 15, color: _kInk, height: 1.4),
        ),
        const SizedBox(height: 8),
        Text(
          allowReapply
              ? 'Tu peux la consulter, ou déposer une nouvelle candidature.'
              : 'Inutile d\'en déposer une nouvelle : suis son avancement '
                  'depuis l\'onglet « Candidatures ».',
          style: const TextStyle(fontSize: 13, color: _kMuted, height: 1.4),
        ),
      ],
    ),
    actionsBuilder: (dialogContext) => [
      if (allowReapply)
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: const Text('Candidater à nouveau'),
        ),
      if (onFollow != null)
        ElevatedButton.icon(
          onPressed: () {
            Navigator.of(dialogContext).pop(false);
            onFollow();
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: _kPrimary,
            foregroundColor: Colors.white,
          ),
          icon: const Icon(Icons.visibility_outlined),
          label: const Text('Voir ma candidature'),
        )
      else
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: const Text('Fermer'),
        ),
    ],
  );
  return result ?? false;
}

/// Problème : nomme le problème, explique quoi faire, et propose une action.
///
/// Rend `true` si l'étudiant presse le bouton d'action ([actionLabel]),
/// `false` s'il referme. [technicalDetail] reste replié : il sert au
/// support, jamais comme message principal.
Future<bool> showApplicationProblemDialog(
  BuildContext context, {
  required String title,
  required String problem,
  required String advice,
  String? technicalDetail,
  String? actionLabel,
}) async {
  final result = await showAdaptiveAppDialog<bool>(
    context: context,
    title: Row(
      children: [
        const Icon(Icons.error_outline, color: Color(0xFFDC2626)),
        const SizedBox(width: 8),
        Expanded(child: Text(title)),
      ],
    ),
    builder: (_) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          problem,
          style: const TextStyle(fontSize: 15, color: _kInk, height: 1.4),
        ),
        const SizedBox(height: 8),
        Text(
          advice,
          style: const TextStyle(fontSize: 13, color: _kMuted, height: 1.4),
        ),
        if (technicalDetail != null && technicalDetail.trim().isNotEmpty) ...[
          const SizedBox(height: 12),
          Theme(
            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              tilePadding: EdgeInsets.zero,
              childrenPadding: const EdgeInsets.only(bottom: 8),
              title: const Text(
                'Détail technique',
                style: TextStyle(fontSize: 12, color: _kMuted),
              ),
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: SelectableText(
                    technicalDetail,
                    style: const TextStyle(fontSize: 12, color: _kMuted),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    ),
    actionsBuilder: (dialogContext) => [
      TextButton(
        onPressed: () => Navigator.of(dialogContext).pop(false),
        child: const Text('Fermer'),
      ),
      if (actionLabel != null)
        ElevatedButton(
          onPressed: () => Navigator.of(dialogContext).pop(true),
          style: ElevatedButton.styleFrom(
            backgroundColor: _kPrimary,
            foregroundColor: Colors.white,
          ),
          child: Text(actionLabel),
        ),
    ],
  );
  return result ?? false;
}
