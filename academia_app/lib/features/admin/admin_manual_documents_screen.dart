import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../providers/admin_manual_documents_provider.dart';
import '../../utils/bon_courtage_pdf.dart';
import '../../utils/payment_receipt_pdf.dart';

/// « Saisie au comptoir » — l'administrateur ouvre le dossier d'une personne
/// qui n'est pas devant un téléphone, encaisse hors plateforme, et repart avec
/// le reçu et le bon de courtage.
///
/// CE QUE L'ÉCRAN NE FAIT PAS. Il ne fabrique aucun document et n'invente
/// aucune règle. Le serveur enchaîne les MÊMES fonctions que le parcours
/// étudiant ; le bon produit ici se vérifie au guichet exactement comme un
/// autre — seul `origin` le distingue, et il n'apparaît nulle part sur le
/// papier.
///
/// L'ORDRE DES TROIS BLOCS N'EST PAS COSMÉTIQUE. Le candidat d'abord, parce
/// qu'une fiche `app.students` EST un compte : `students.id` référence
/// `auth.users(id)`. La formation ensuite, parce qu'elle impose le tarif du
/// courtage — le montant ne vient jamais de l'écran. Le pourcentage en
/// dernier, parce que c'est LUI qui ouvre l'émission : sans taux enregistré,
/// le serveur refuse d'émettre, et c'est l'exigence du 09/09.
class AdminManualDocumentsScreen extends StatelessWidget {
  const AdminManualDocumentsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<AdminManualDocumentsProvider>(
      create: (_) => AdminManualDocumentsProvider()..chargerFormations(),
      child: const _Corps(),
    );
  }
}

enum _Origine { nouveau, existant }

class _Corps extends StatefulWidget {
  const _Corps();

  @override
  State<_Corps> createState() => _CorpsState();
}

class _CorpsState extends State<_Corps> {
  final _formulaire = GlobalKey<FormState>();

  _Origine _origine = _Origine.nouveau;

  final _nom = TextEditingController();
  final _email = TextEditingController();
  final _motDePasse = TextEditingController();
  final _telephone = TextEditingController();
  final _ville = TextEditingController();
  final _pays = TextEditingController(text: 'Burkina Faso');
  final _taux = TextEditingController();
  final _montant = TextEditingController();
  final _reference = TextEditingController();
  final _note = TextEditingController();

  DateTime? _naissance;
  String? _universiteId;
  String? _programmeId;
  String _canal = 'cash';

  // Candidat déjà inscrit
  List<Map<String, dynamic>> _comptes = [];
  bool _comptesEnCours = false;
  String? _studentIdChoisi;
  String _rechercheCompte = '';

  bool _envoi = false;
  Map<String, dynamic>? _resultat;

  @override
  void dispose() {
    for (final c in [
      _nom, _email, _motDePasse, _telephone, _ville, _pays,
      _taux, _montant, _reference, _note,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.watch<AdminManualDocumentsProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Saisie au comptoir'),
        actions: [
          IconButton(
            tooltip: 'Recharger les formations',
            onPressed: p.enCours ? null : p.chargerFormations,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _resultat != null
          ? _Resultat(
              donnees: _resultat!,
              surNouvelleSaisie: _reinitialiser,
            )
          : Form(
              key: _formulaire,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
                children: [
                  const _Rappel(),
                  const SizedBox(height: 16),
                  _Bloc(
                    numero: '1',
                    titre: 'Le candidat',
                    enfants: _blocCandidat(p),
                  ),
                  const SizedBox(height: 16),
                  _Bloc(
                    numero: '2',
                    titre: 'La formation',
                    enfants: _blocFormation(p),
                  ),
                  const SizedBox(height: 16),
                  _Bloc(
                    numero: '3',
                    titre: 'Le courtage',
                    enfants: _blocCourtage(p),
                  ),
                  const SizedBox(height: 22),
                  FilledButton.icon(
                    onPressed: _envoi ? null : () => _emettre(p),
                    icon: _envoi
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.description_outlined),
                    label: Text(_envoi
                        ? 'Émission en cours…'
                        : 'Émettre le reçu et le bon'),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(48),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  // ── Bloc 1 ───────────────────────────────────────────────────────────────
  List<Widget> _blocCandidat(AdminManualDocumentsProvider p) {
    return [
      SegmentedButton<_Origine>(
        segments: const [
          ButtonSegment(
            value: _Origine.nouveau,
            label: Text('Nouveau'),
            icon: Icon(Icons.person_add_alt),
          ),
          ButtonSegment(
            value: _Origine.existant,
            label: Text('Déjà inscrit'),
            icon: Icon(Icons.person_search),
          ),
        ],
        selected: {_origine},
        onSelectionChanged: (s) {
          setState(() {
            _origine = s.first;
            _studentIdChoisi = null;
          });
          if (_origine == _Origine.existant && _comptes.isEmpty) {
            _chargerComptes();
          }
        },
      ),
      const SizedBox(height: 14),
      if (_origine == _Origine.nouveau) ...[
        const _Note(
          'Le compte est créé pour le candidat. Une adresse de courriel est '
          'obligatoire : c\'est Auth qui l\'exige, et c\'est elle qui lui '
          'permettra un jour de récupérer son dossier. Remets-lui le mot de '
          'passe avec ses papiers.',
        ),
        const SizedBox(height: 12),
        _champ(_nom, 'Nom et prénoms', obligatoire: true),
        _champ(_email, 'Adresse de courriel',
            obligatoire: true,
            clavier: TextInputType.emailAddress,
            validation: (v) => (v ?? '').contains('@')
                ? null
                : 'Une adresse de courriel valide est requise.'),
        _champ(_motDePasse, 'Mot de passe temporaire',
            obligatoire: true,
            validation: (v) => (v ?? '').length >= 8
                ? null
                : 'Au moins 8 caractères — il sera remis au candidat.'),
      ] else ...[
        TextField(
          decoration: const InputDecoration(
            isDense: true,
            prefixIcon: Icon(Icons.search),
            hintText: 'Nom, courriel ou téléphone',
            border: OutlineInputBorder(),
          ),
          onChanged: (v) => setState(() => _rechercheCompte = v),
        ),
        const SizedBox(height: 10),
        if (_comptesEnCours)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Center(child: CircularProgressIndicator()),
          )
        else
          _listeComptes(),
        const SizedBox(height: 12),
        _champ(_nom, 'Nom et prénoms (corrige la fiche si renseigné)'),
      ],
      _champ(_telephone, 'Téléphone', clavier: TextInputType.phone),
      Row(
        children: [
          Expanded(child: _champ(_ville, 'Ville')),
          const SizedBox(width: 12),
          Expanded(child: _champ(_pays, 'Pays')),
        ],
      ),
      InkWell(
        onTap: _choisirDate,
        child: InputDecorator(
          decoration: const InputDecoration(
            labelText: 'Date de naissance',
            border: OutlineInputBorder(),
            isDense: true,
          ),
          child: Text(
            _naissance == null
                ? 'Non renseignée'
                : '${_naissance!.day.toString().padLeft(2, '0')}/'
                    '${_naissance!.month.toString().padLeft(2, '0')}/'
                    '${_naissance!.year}',
            style: TextStyle(
              color: _naissance == null ? Colors.black45 : null,
            ),
          ),
        ),
      ),
    ];
  }

  Widget _listeComptes() {
    final q = _rechercheCompte.trim().toLowerCase();
    var liste = _comptes;
    if (q.isNotEmpty) {
      liste = liste.where((c) {
        bool a(dynamic v) => (v?.toString().toLowerCase() ?? '').contains(q);
        return a(c['full_name']) || a(c['email']) || a(c['phone']);
      }).toList(growable: false);
    }
    if (liste.isEmpty) {
      return const _Note('Aucun compte ne correspond à cette recherche.');
    }
    return Container(
      constraints: const BoxConstraints(maxHeight: 220),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.black12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: ListView.builder(
        shrinkWrap: true,
        itemCount: liste.length > 40 ? 40 : liste.length,
        itemBuilder: (context, i) {
          final c = liste[i];
          final id = c['id']?.toString();
          final nom = (c['full_name'] ?? '').toString();
          final contact =
              (c['email'] ?? c['phone'] ?? 'sans contact').toString();
          final choisi = id != null && id == _studentIdChoisi;
          return ListTile(
            dense: true,
            selected: choisi,
            leading: Icon(
              choisi ? Icons.radio_button_checked : Icons.radio_button_off,
              color: choisi ? const Color(0xFF14663A) : Colors.black38,
            ),
            onTap: id == null
                ? null
                : () => setState(() => _studentIdChoisi = id),
            title: Text(nom.isEmpty ? contact : nom),
            subtitle: nom.isEmpty ? null : Text(contact),
          );
        },
      ),
    );
  }

  // ── Bloc 2 ───────────────────────────────────────────────────────────────
  List<Widget> _blocFormation(AdminManualDocumentsProvider p) {
    final ecoles = p.etablissements;
    final formations = p.formationsDe(_universiteId);
    final choisie = formations.where((f) => f['id'] == _programmeId).toList();
    final frais = choisie.isEmpty
        ? null
        : (choisie.first['brokerage_fee'] as num?)?.toDouble();

    return [
      if (p.enCours && ecoles.isEmpty)
        const Center(child: Padding(
          padding: EdgeInsets.all(12),
          child: CircularProgressIndicator(),
        ))
      else ...[
        DropdownButtonFormField<String>(
          isExpanded: true,
          initialValue: _universiteId,
          decoration: const InputDecoration(
            labelText: 'Établissement',
            border: OutlineInputBorder(),
            isDense: true,
          ),
          items: ecoles
              .map((e) => DropdownMenuItem(
                    value: e.id,
                    child: Text(e.nom, overflow: TextOverflow.ellipsis),
                  ))
              .toList(),
          onChanged: (v) => setState(() {
            _universiteId = v;
            _programmeId = null;
            _montant.clear();
          }),
          validator: (v) =>
              v == null ? 'Choisis l\'établissement destinataire.' : null,
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          isExpanded: true,
          initialValue: _programmeId,
          decoration: const InputDecoration(
            labelText: 'Formation',
            border: OutlineInputBorder(),
            isDense: true,
          ),
          items: formations
              .map((f) => DropdownMenuItem(
                    value: f['id']?.toString(),
                    child: Text(
                      '${f['title']}'
                      '${(f['degree_level'] ?? '').toString().isEmpty ? '' : ' · ${f['degree_level']}'}',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ))
              .toList(),
          onChanged: formations.isEmpty
              ? null
              : (v) => setState(() {
                    _programmeId = v;
                    final f = formations.firstWhere(
                      (e) => e['id']?.toString() == v,
                      orElse: () => const <String, dynamic>{},
                    );
                    final fee = (f['brokerage_fee'] as num?)?.toDouble();
                    _montant.text =
                        fee == null || fee <= 0 ? '' : fee.toStringAsFixed(0);
                  }),
          validator: (v) => v == null ? 'Choisis la formation.' : null,
        ),
        if (frais != null)
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: _Note(frais <= 0
                ? 'Aucun frais de courtage n\'est défini sur cette formation : '
                    'saisis le montant encaissé ci-dessous.'
                : 'Frais de courtage de cette formation : '
                    '${frais.toStringAsFixed(0)} FCFA. C\'est ce montant qui '
                    'sera porté sur le reçu, sauf si tu en saisis un autre.'),
          ),
      ],
    ];
  }

  // ── Bloc 3 ───────────────────────────────────────────────────────────────
  List<Widget> _blocCourtage(AdminManualDocumentsProvider p) {
    return [
      const _Note(
        'Le pourcentage obtenu auprès de l\'établissement est OBLIGATOIRE : '
        'c\'est lui que le bon imprime, et sans lui le serveur refuse '
        'd\'émettre. Il accepte les décimales (12,5).',
      ),
      const SizedBox(height: 12),
      _champ(
        _taux,
        'Pourcentage de réduction obtenu (%)',
        obligatoire: true,
        clavier: const TextInputType.numberWithOptions(decimal: true),
        entrees: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
        validation: (v) {
          final n = double.tryParse((v ?? '').replaceAll(',', '.'));
          if (n == null) return 'Saisis un nombre, par exemple 12,5.';
          if (n < 0 || n > 100) return 'Un pourcentage va de 0 à 100.';
          return null;
        },
      ),
      _champ(
        _montant,
        'Montant encaissé (FCFA)',
        clavier: TextInputType.number,
        entrees: [FilteringTextInputFormatter.digitsOnly],
      ),
      DropdownButtonFormField<String>(
        initialValue: _canal,
        decoration: const InputDecoration(
          labelText: 'Moyen de paiement',
          border: OutlineInputBorder(),
          isDense: true,
        ),
        items: const [
          DropdownMenuItem(value: 'cash', child: Text('Espèces')),
          DropdownMenuItem(value: 'orange_money', child: Text('Orange Money')),
          DropdownMenuItem(value: 'moov_money', child: Text('Moov Money')),
          DropdownMenuItem(
              value: 'telecel_money', child: Text('Telecel Money')),
        ],
        onChanged: (v) => setState(() => _canal = v ?? 'cash'),
      ),
      const SizedBox(height: 12),
      _champ(_reference, 'Référence de l\'encaissement (facultatif)'),
      _champ(_note, 'Note de négociation (facultatif)', lignes: 2),
    ];
  }

  // ── Actions ──────────────────────────────────────────────────────────────
  Future<void> _chargerComptes() async {
    setState(() => _comptesEnCours = true);
    try {
      final reponse = await Supabase.instance.client
          .rpc('app_admin_list_users_overview');
      if (reponse is Map<String, dynamic> && reponse['success'] == true) {
        final brut = reponse['users'];
        final tous = brut is List
            ? brut.map((e) => Map<String, dynamic>.from(e as Map)).toList()
            : <Map<String, dynamic>>[];
        setState(() {
          // Un compte supprimé ou suspendu ne doit pas recevoir de dossier :
          // il ne pourrait ni le consulter ni s'en servir.
          _comptes = tous
              .where((u) =>
                  (u['role'] ?? 'student') == 'student' &&
                  u['is_deleted'] != true &&
                  u['is_suspended'] != true)
              .toList(growable: false);
        });
      }
    } finally {
      if (mounted) setState(() => _comptesEnCours = false);
    }
  }

  Future<void> _choisirDate() async {
    final maintenant = DateTime.now();
    final choix = await showDatePicker(
      context: context,
      initialDate: _naissance ?? DateTime(maintenant.year - 20),
      firstDate: DateTime(maintenant.year - 90),
      lastDate: maintenant,
      helpText: 'Date de naissance du candidat',
    );
    if (choix != null) setState(() => _naissance = choix);
  }

  Future<void> _emettre(AdminManualDocumentsProvider p) async {
    if (!(_formulaire.currentState?.validate() ?? false)) return;
    if (_origine == _Origine.existant && _studentIdChoisi == null) {
      _dire('Choisis le candidat dans la liste.');
      return;
    }

    setState(() => _envoi = true);
    try {
      var studentId = _studentIdChoisi;

      if (_origine == _Origine.nouveau) {
        final compte = await p.creerCompteCandidat(
          email: _email.text,
          motDePasse: _motDePasse.text,
          nom: _nom.text,
        );
        if (compte.studentId == null) {
          _dire(compte.message);
          return;
        }
        studentId = compte.studentId;
      }

      final taux =
          double.parse(_taux.text.trim().replaceAll(',', '.'));
      final montant = double.tryParse(_montant.text.trim());

      var sortie = await p.emettre(
        studentId: studentId!,
        programId: _programmeId!,
        taux: taux,
        nom: _nom.text,
        telephone: _telephone.text,
        email: _email.text,
        ville: _ville.text,
        pays: _pays.text,
        dateDeNaissance: _naissance,
        montant: montant,
        canal: _canal,
        reference: _reference.text,
        note: _note.text,
      );

      // Un bon vivant existe déjà : l'administrateur tranche, on ne tranche
      // pas pour lui. Le compte, lui, est déjà créé — on ne le refait pas.
      if (!sortie.reussi &&
          sortie.documents?['error'] == 'bon_deja_vivant' &&
          mounted) {
        final forcer = await showDialog<bool>(
          context: context,
          builder: (c) => AlertDialog(
            title: const Text('Un bon existe déjà'),
            content: Text('${sortie.message}\n\n'
                'En émettre un second signifie que deux papiers valides '
                'circulent pour le même candidat et la même formation. '
                'Continuer ?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(c, false),
                child: const Text('Annuler'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(c, true),
                child: const Text('Émettre quand même'),
              ),
            ],
          ),
        );
        if (forcer != true) return;
        sortie = await p.emettre(
          studentId: studentId,
          programId: _programmeId!,
          taux: taux,
          nom: _nom.text,
          telephone: _telephone.text,
          email: _email.text,
          ville: _ville.text,
          pays: _pays.text,
          dateDeNaissance: _naissance,
          montant: montant,
          canal: _canal,
          reference: _reference.text,
          note: _note.text,
          forcer: true,
        );
      }

      if (!sortie.reussi) {
        _dire(sortie.message);
        return;
      }
      setState(() => _resultat = sortie.documents);
    } finally {
      if (mounted) setState(() => _envoi = false);
    }
  }

  void _reinitialiser() {
    setState(() {
      _resultat = null;
      _studentIdChoisi = null;
      _naissance = null;
      _programmeId = null;
      for (final c in [
        _nom, _email, _motDePasse, _telephone, _ville,
        _taux, _montant, _reference, _note,
      ]) {
        c.clear();
      }
    });
  }

  void _dire(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  Widget _champ(
    TextEditingController c,
    String libelle, {
    bool obligatoire = false,
    TextInputType? clavier,
    List<TextInputFormatter>? entrees,
    String? Function(String?)? validation,
    int lignes = 1,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: c,
        keyboardType: clavier,
        inputFormatters: entrees,
        maxLines: lignes,
        decoration: InputDecoration(
          labelText: obligatoire ? '$libelle *' : libelle,
          border: const OutlineInputBorder(),
          isDense: true,
        ),
        validator: (v) {
          if (obligatoire && (v == null || v.trim().isEmpty)) {
            return 'Ce champ est obligatoire.';
          }
          if (v != null && v.trim().isNotEmpty && validation != null) {
            return validation(v);
          }
          return null;
        },
      ),
    );
  }
}

// ── Le résultat ────────────────────────────────────────────────────────────
class _Resultat extends StatelessWidget {
  const _Resultat({required this.donnees, required this.surNouvelleSaisie});

  final Map<String, dynamic> donnees;
  final VoidCallback surNouvelleSaisie;

  @override
  Widget build(BuildContext context) {
    final paiement = _objet(donnees['payment']);
    final recu = _objet(donnees['receipt']);
    final bon = _objet(donnees['voucher']);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 40),
      children: [
        Row(
          children: [
            const Icon(Icons.check_circle, color: Color(0xFF1EA75C), size: 30),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Documents émis',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        const _Note(
          'Le dossier est enregistré comme s\'il avait suivi le parcours '
          'normal. Le candidat doit toujours se présenter au guichet de '
          'l\'établissement avec son bon : la procédure ne change pas.',
        ),
        const SizedBox(height: 18),
        _Document(
          titre: 'Reçu de paiement',
          numero: (recu['receipt_number'] ?? '—').toString(),
          icone: Icons.receipt_long,
          surTelechargement: recu.isEmpty
              ? null
              : () => _telecharger(
                    context,
                    () => genererEtEnregistrerRecuPdf(
                      payment: paiement,
                      receipt: recu,
                    ),
                    'Reçu',
                  ),
        ),
        const SizedBox(height: 12),
        _Document(
          titre: 'Bon de courtage',
          numero: (bon['voucher_number'] ?? '—').toString(),
          detail: 'Code de vérification : '
              '${bon['verification_code'] ?? '—'}',
          icone: Icons.qr_code_2,
          surTelechargement: bon.isEmpty
              ? null
              : () => _telecharger(
                    context,
                    () => genererEtEnregistrerBonPdf(bon: bon),
                    'Bon',
                  ),
        ),
        const SizedBox(height: 24),
        OutlinedButton.icon(
          onPressed: surNouvelleSaisie,
          icon: const Icon(Icons.add),
          label: const Text('Nouvelle saisie'),
          style: OutlinedButton.styleFrom(
            minimumSize: const Size.fromHeight(46),
          ),
        ),
        const SizedBox(height: 10),
        TextButton.icon(
          onPressed: () => Navigator.of(context).pop(true),
          icon: const Icon(Icons.list_alt),
          label: const Text('Revenir à la liste des bons'),
        ),
      ],
    );
  }

  Future<void> _telecharger(
    BuildContext context,
    Future<dynamic> Function() fabrique,
    String quoi,
  ) async {
    final messager = ScaffoldMessenger.of(context);
    final resultat = await fabrique();
    messager.showSnackBar(SnackBar(
      content: Text(
        !resultat.reussi
            ? '$quoi non enregistré : ${resultat.erreur}'
            : resultat.enregistreSurLAppareil
                ? '$quoi enregistré dans Téléchargements '
                    '(${resultat.nomFichier})'
                : '$quoi téléchargé',
      ),
    ));
  }
}

class _Document extends StatelessWidget {
  const _Document({
    required this.titre,
    required this.numero,
    required this.icone,
    this.detail,
    this.surTelechargement,
  });

  final String titre;
  final String numero;
  final String? detail;
  final IconData icone;
  final VoidCallback? surTelechargement;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.black12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(icone, size: 30, color: const Color(0xFF14663A)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(titre,
                    style: const TextStyle(fontWeight: FontWeight.w600)),
                Text(numero,
                    style: const TextStyle(
                        fontSize: 13, color: Colors.black54)),
                if (detail != null)
                  Text(detail!,
                      style: const TextStyle(
                          fontSize: 12, color: Colors.black45)),
              ],
            ),
          ),
          FilledButton.tonalIcon(
            onPressed: surTelechargement,
            icon: const Icon(Icons.download),
            label: const Text('Télécharger'),
          ),
        ],
      ),
    );
  }
}

// ── Petits morceaux ────────────────────────────────────────────────────────
class _Bloc extends StatelessWidget {
  const _Bloc({
    required this.numero,
    required this.titre,
    required this.enfants,
  });

  final String numero;
  final String titre;
  final List<Widget> enfants;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.black12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 12,
                backgroundColor: const Color(0xFF14663A),
                child: Text(numero,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w700)),
              ),
              const SizedBox(width: 10),
              Text(titre,
                  style: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 14),
          ...enfants,
        ],
      ),
    );
  }
}

class _Rappel extends StatelessWidget {
  const _Rappel();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF0FDF4),
        border: Border.all(color: const Color(0xFF86EFAC)),
        borderRadius: BorderRadius.circular(9),
      ),
      child: const Text(
        'Cette saisie produit exactement les mêmes pièces que le parcours '
        'étudiant, et le bon se vérifie au guichet de la même façon. '
        'L\'encaissement est enregistré comme reçu hors plateforme.',
        style: TextStyle(fontSize: 13, color: Color(0xFF14532D)),
      ),
    );
  }
}

class _Note extends StatelessWidget {
  const _Note(this.texte);

  final String texte;

  @override
  Widget build(BuildContext context) {
    return Text(
      texte,
      style: const TextStyle(fontSize: 12.5, color: Colors.black54),
    );
  }
}

Map<String, dynamic> _objet(dynamic v) =>
    v is Map ? Map<String, dynamic>.from(v) : <String, dynamic>{};
