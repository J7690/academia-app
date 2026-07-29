import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Rédaction d'une publication texte pour le feed.
///
/// Ajouté le 29/07/2026 : l'entrée « Publication texte » existait dans le menu
/// « Créer du contenu » mais affichait « à implémenter ». Publier demandait donc
/// de filmer. Le texte ouvre la porte à ceux qui veulent partager une astuce ou
/// une question sans passer devant la caméra.
///
/// Renvoie `true` à la fermeture si une publication a bien été créée, pour que
/// le feed se rafraîchisse.
class TextPostComposerScreen extends StatefulWidget {
  const TextPostComposerScreen({super.key});

  @override
  State<TextPostComposerScreen> createState() => _TextPostComposerScreenState();
}

class _TextPostComposerScreenState extends State<TextPostComposerScreen> {
  static const int _maxCaracteres = 2000;

  /// Le feed est plein écran : une carte de texte nue paraîtrait terne à côté
  /// des vidéos. L'auteur choisit son fond.
  static const _fonds = <String, List<Color>>{
    'vert': [Color(0xFF1EA75C), Color(0xFF0B7A3E)],
    'nuit': [Color(0xFF2B3A55), Color(0xFF141C2B)],
    'ocre': [Color(0xFFD9822B), Color(0xFF9C4C10)],
    'prune': [Color(0xFF6D3B8E), Color(0xFF3E1F55)],
    'ardoise': [Color(0xFF4A5A63), Color(0xFF23303A)],
  };

  final _corps = TextEditingController();
  final _titre = TextEditingController();
  String _fond = 'vert';
  bool _envoiEnCours = false;

  @override
  void dispose() {
    _corps.dispose();
    _titre.dispose();
    super.dispose();
  }

  Future<void> _publier() async {
    final corps = _corps.text.trim();
    if (corps.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Écris quelque chose avant de publier.')),
      );
      return;
    }

    setState(() => _envoiEnCours = true);
    try {
      final reponse = await Supabase.instance.client.rpc(
        'text_post_create',
        params: {
          'p_body': corps,
          'p_title': _titre.text.trim().isEmpty ? null : _titre.text.trim(),
          'p_background': _fond,
        },
      );

      if (!mounted) return;

      if (reponse is Map && reponse['success'] == true) {
        Navigator.of(context).pop(true);
        return;
      }

      // Le serveur dit précisément ce qui bloque : on le traduit plutôt que
      // d'afficher un « une erreur est survenue » qui n'aide personne.
      final code = reponse is Map ? reponse['error']?.toString() : null;
      final message = switch (code) {
        'body_required' => 'Le texte est vide.',
        'body_too_long' => 'Le texte dépasse $_maxCaracteres caractères.',
        'not_authenticated' => 'Reconnecte-toi pour publier.',
        _ => 'Publication impossible pour le moment. Réessaie.',
      };
      setState(() => _envoiEnCours = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));
    } catch (e) {
      if (!mounted) return;
      setState(() => _envoiEnCours = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pas de connexion. Réessaie dans un instant.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final couleurs = _fonds[_fond] ?? _fonds['vert']!;
    final restants = _maxCaracteres - _corps.text.length;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.white,
        title: const Text('Publication texte'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: TextButton(
              onPressed: _envoiEnCours ? null : _publier,
              child: _envoiEnCours
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Text(
                      'Publier',
                      style: TextStyle(
                          color: Colors.white, fontWeight: FontWeight.bold),
                    ),
            ),
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: couleurs,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextField(
                        controller: _titre,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                        cursorColor: Colors.white,
                        decoration: const InputDecoration(
                          hintText: 'Titre (facultatif)',
                          hintStyle: TextStyle(color: Colors.white54),
                          border: InputBorder.none,
                        ),
                        textCapitalization: TextCapitalization.sentences,
                        maxLength: 120,
                        buildCounter: (_, {required currentLength, required isFocused, maxLength}) => null,
                      ),
                      const Divider(color: Colors.white24, height: 8),
                      Expanded(
                        child: TextField(
                          controller: _corps,
                          onChanged: (_) => setState(() {}),
                          style: const TextStyle(color: Colors.white, fontSize: 17, height: 1.5),
                          cursorColor: Colors.white,
                          maxLines: null,
                          expands: true,
                          textAlignVertical: TextAlignVertical.top,
                          maxLength: _maxCaracteres,
                          textCapitalization: TextCapitalization.sentences,
                          decoration: const InputDecoration(
                            hintText: 'Partage une astuce, une question, une fiche...',
                            hintStyle: TextStyle(color: Colors.white54),
                            border: InputBorder.none,
                          ),
                          buildCounter: (_, {required currentLength, required isFocused, maxLength}) => null,
                        ),
                      ),
                      Align(
                        alignment: Alignment.centerRight,
                        child: Text(
                          '$restants',
                          style: TextStyle(
                            color: restants < 100 ? Colors.orangeAccent : Colors.white60,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              _choixDuFond(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _choixDuFond() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      color: Colors.black26,
      child: Row(
        children: [
          const Text('Fond', style: TextStyle(color: Colors.white70, fontSize: 13)),
          const SizedBox(width: 12),
          Expanded(
            child: SizedBox(
              height: 34,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _fonds.length,
                separatorBuilder: (_, __) => const SizedBox(width: 10),
                itemBuilder: (_, i) {
                  final cle = _fonds.keys.elementAt(i);
                  final couleurs = _fonds[cle]!;
                  final actif = cle == _fond;
                  return GestureDetector(
                    onTap: () => setState(() => _fond = cle),
                    child: Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(colors: couleurs),
                        border: Border.all(
                          color: actif ? Colors.white : Colors.white24,
                          width: actif ? 3 : 1,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}
