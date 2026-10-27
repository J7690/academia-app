import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import 'short_training_checkout_sheet.dart';

/// Lien partageable d'une formation courte (27/10/2026).
///
/// Forme : `https://app.academiea.com/?formation=<slug>&src=<canal>`. Un
/// paramètre plutôt qu'un chemin : la page d'accueil reste la porte d'entrée
/// (aucune route ni règle Netlify à ajouter), et `src` alimente le suivi
/// marketing déjà lu à l'inscription (`mkt_ref`).
const String kAcademiaWebUrl = 'https://app.academiea.com';

String shortTrainingShareUrl(String slug, {String src = 'partage'}) =>
    '$kAcademiaWebUrl/?formation=${Uri.encodeQueryComponent(slug)}&src=${Uri.encodeQueryComponent(src)}';

/// Copie le lien et ouvre le partage du système (WhatsApp, SMS…).
Future<void> shareShortTraining(BuildContext context, Map<String, dynamic> session) async {
  final slug = session['slug']?.toString() ?? '';
  if (slug.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Cette formation n\'a pas encore de lien court.')),
    );
    return;
  }
  final url = shortTrainingShareUrl(slug);
  final title = session['title']?.toString() ?? 'Formation';
  final dates = formatShortTrainingDates(session['start_at'], session['end_at']);
  await Clipboard.setData(ClipboardData(text: url));
  if (context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Lien copié.')));
  }
  try {
    await Share.share('$title${dates.isEmpty ? '' : ' — $dates'}\nInscription et paiement : $url');
  } catch (_) {
    // Le lien est déjà copié : le partage système est un confort.
  }
}

/// Ouvre le formulaire d'inscription quand l'app est ouverte par un lien
/// `?formation=<slug>`. Une seule fois par lancement : la page publique, puis
/// l'accueil connecté (après création du compte dans le formulaire) appellent
/// tous deux cette fonction, le formulaire ne doit pas s'ouvrir deux fois.
class ShortTrainingDeepLink {
  ShortTrainingDeepLink._();

  static bool _handled = false;

  static String? get requestedSlug {
    try {
      final v = Uri.base.queryParameters['formation'];
      return (v == null || v.trim().isEmpty) ? null : v.trim();
    } catch (_) {
      return null;
    }
  }

  static void maybeOpen(
    BuildContext context,
    List<Map<String, dynamic>> sessions, {
    VoidCallback? onChanged,
  }) {
    if (_handled) return;
    final slug = requestedSlug;
    if (slug == null) return;
    final match = sessions.where((s) => s['slug']?.toString() == slug).toList();
    if (match.isEmpty) return;
    _handled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!context.mounted) return;
      ShortTrainingCheckoutSheet.show(context, match.first, onChanged: onChanged);
    });
  }
}
