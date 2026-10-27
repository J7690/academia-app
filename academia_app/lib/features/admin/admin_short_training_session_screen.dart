import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../config/supabase_config.dart';
import '../auth/phone_rules.dart';
import '../short_trainings/short_training_checkout_sheet.dart';
import '../short_trainings/short_training_links.dart';

const Color _kGreen = Color(0xFF1EA75C);
const Color _kNavy = Color(0xFF0A2540);
const Color _kGrey = Color(0xFF6B7280);
const Color _kOrange = Color(0xFFEA580C);

/// Le tableau d'une session de formation courte, côté équipe (lot 2, 27/10).
///
/// Tout passe par `app_admin_short_training_session_board` (une lecture) :
/// inscrits, état lisible, moyen de paiement, référence opérateur, reçu, totaux.
/// Trois gestes :
///   * **Encaisser au guichet** — espèces au siège : compte retrouvé par le
///     téléphone, ou créé sur place, puis `app_admin_short_training_cash` ;
///   * **Valider** un Mobile Money déclaré au 66 66 05 38 —
///     `app_admin_confirm_payment`, qui émet le reçu ;
///   * **Refuser** une déclaration — `app_admin_verify_payment('invalid')` ;
///     la place se libère d'elle-même.
class AdminShortTrainingSessionScreen extends StatefulWidget {
  const AdminShortTrainingSessionScreen({
    super.key,
    required this.sessionId,
    this.onOpenMessages,
  });

  final String sessionId;

  /// Ouvre la messagerie d'une inscription (fournie par l'écran des formations).
  final void Function(String registrationId, String studentName)? onOpenMessages;

  @override
  State<AdminShortTrainingSessionScreen> createState() => _AdminShortTrainingSessionScreenState();
}

class _AdminShortTrainingSessionScreenState extends State<AdminShortTrainingSessionScreen> {
  final _client = Supabase.instance.client;

  bool _loading = true;
  String? _error;
  Map<String, dynamic> _session = const {};
  Map<String, dynamic> _totals = const {};
  List<Map<String, dynamic>> _rows = const [];
  String _filtre = 'tous';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final res = await _client.rpc('app_admin_short_training_session_board',
          params: {'p_session_id': widget.sessionId});
      final data = res is Map ? Map<String, dynamic>.from(res) : null;
      if (data == null || data['success'] != true) {
        setState(() => _error = 'Chargement impossible (${data?['error'] ?? 'réponse vide'}).');
        return;
      }
      setState(() {
        _session = Map<String, dynamic>.from(data['session'] as Map? ?? const {});
        _totals = Map<String, dynamic>.from(data['totals'] as Map? ?? const {});
        _rows = ((data['registrations'] as List?) ?? const [])
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
      });
    } catch (e) {
      debugPrint('[AdminSession] chargement : $e');
      setState(() => _error = 'Erreur réseau : $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _snack(String text, {bool ok = true}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(text),
      backgroundColor: ok ? _kGreen : const Color(0xFFB91C1C),
    ));
  }

  // ─── Gestes ──────────────────────────────────────────────────────────────

  Future<void> _valider(Map<String, dynamic> row) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Valider le paiement ?'),
        content: Text(
          '${row['full_name'] ?? 'Inscrit'} — ${formatFcfa((row['amount'] as num?) ?? 0)}\n'
          'Référence : ${row['external_reference'] ?? '—'} (${_libelleCanal(row['channel'])})\n\n'
          'Vérifiez que cette transaction figure bien sur le téléphone du $kNexiomMobileMoney. '
          'La validation confirme la place et émet le reçu.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Valider')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      final res = await _client.rpc('app_admin_confirm_payment', params: {'p_payment_id': row['payment_id']});
      final data = res is Map ? res : const {};
      if (data['success'] == true) {
        _snack('Paiement validé — reçu ${data['receipt_number'] ?? ''}');
      } else {
        _snack('Validation refusée : ${data['error']}', ok: false);
      }
    } catch (e) {
      _snack('Erreur : $e', ok: false);
    }
    await _load();
  }

  Future<void> _refuser(Map<String, dynamic> row) async {
    final motif = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Refuser la déclaration ?'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Text('La place de ${row['full_name'] ?? 'cet inscrit'} sera libérée. '
              'La personne pourra payer de nouveau.'),
          const SizedBox(height: 12),
          TextField(controller: motif, decoration: const InputDecoration(labelText: 'Motif (ex. référence introuvable)')),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFB91C1C), foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Refuser'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      final res = await _client.rpc('app_admin_verify_payment', params: {
        'p_payment_id': row['payment_id'],
        'p_decision': 'invalid',
        'p_comment': motif.text.trim().isEmpty ? null : motif.text.trim(),
      });
      final data = res is Map ? res : const {};
      _snack(data['success'] == true ? 'Déclaration refusée.' : 'Refus impossible : ${data['error']}',
          ok: data['success'] == true);
    } catch (e) {
      _snack('Erreur : $e', ok: false);
    }
    await _load();
  }

  Future<void> _ouvrirGuichet() async {
    final done = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useRootNavigator: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _GuichetSheet(session: _session),
    );
    if (done == true) await _load();
  }

  Future<void> _ouvrirScan() async {
    await Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => _ScanTicketsScreen(
        sessionId: widget.sessionId,
        title: _session['title']?.toString() ?? 'Session',
      ),
    ));
    await _load();
  }

  Future<void> _copierLien() async {
    final url = shortTrainingShareUrl(_session['slug'].toString(), src: 'admin');
    await Clipboard.setData(ClipboardData(text: url));
    _snack('Lien copié : $url');
  }

  Future<void> _copierPresence() async {
    final confirmes = _rows.where((r) => r['etat'] == 'confirmee').toList();
    final buf = StringBuffer()
      ..writeln('${_session['title'] ?? 'Formation'} — ${formatShortTrainingDates(_session['start_at'], _session['end_at'])}')
      ..writeln('Liste de présence : ${confirmes.length} inscrit(s)')
      ..writeln();
    for (var i = 0; i < confirmes.length; i++) {
      final r = confirmes[i];
      buf.writeln('${i + 1}. ${r['full_name'] ?? '?'} — ${r['phone'] ?? ''} — '
          '${_libelleCanal(r['channel'])} — ${r['receipt_number'] ?? ''}');
    }
    await Clipboard.setData(ClipboardData(text: buf.toString()));
    _snack('Liste de présence copiée (${confirmes.length} personne(s)).');
  }

  // ─── Affichage ───────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final title = _session['title']?.toString() ?? 'Session';
    return Scaffold(
      appBar: AppBar(
        title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
        actions: [
          IconButton(
            tooltip: "Scanner les tickets à l'entrée",
            onPressed: _session.isEmpty ? null : _ouvrirScan,
            icon: const Icon(Icons.qr_code_scanner),
          ),
          IconButton(
            tooltip: "Copier le lien d'inscription",
            onPressed: (_session['slug'] ?? '').toString().isEmpty ? null : _copierLien,
            icon: const Icon(Icons.link),
          ),
          IconButton(tooltip: 'Copier la liste de présence', onPressed: _rows.isEmpty ? null : _copierPresence, icon: const Icon(Icons.copy_all)),
          IconButton(tooltip: 'Actualiser', onPressed: _loading ? null : _load, icon: const Icon(Icons.refresh)),
        ],
      ),
      floatingActionButton: _session.isEmpty
          ? null
          : FloatingActionButton.extended(
              onPressed: _ouvrirGuichet,
              backgroundColor: _kGreen,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.point_of_sale),
              label: const Text('Encaisser au guichet'),
            ),
      body: _loading && _session.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : _error != null && _session.isEmpty
              ? Center(child: Padding(padding: const EdgeInsets.all(24), child: Text(_error!)))
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
                    children: [
                      _entete(),
                      const SizedBox(height: 12),
                      _filtres(),
                      const SizedBox(height: 8),
                      ..._lignesFiltrees().map(_ligne),
                      if (_lignesFiltrees().isEmpty)
                        const Padding(
                          padding: EdgeInsets.all(24),
                          child: Center(child: Text('Aucune inscription dans cette catégorie.', style: TextStyle(color: _kGrey))),
                        ),
                    ],
                  ),
                ),
    );
  }

  Widget _entete() {
    final capacity = _session['capacity'];
    final confirmes = (_totals['confirmes'] as num?)?.toInt() ?? 0;
    final aValider = (_totals['a_valider'] as num?)?.toInt() ?? 0;
    final accueil = (_session['welcome_location'] ?? _session['location'])?.toString() ?? '';
    final pratique = _session['practice_location']?.toString() ?? '';
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: const BorderSide(color: Color(0xFFE5E7EB))),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(
            [formatShortTrainingDates(_session['start_at'], _session['end_at']),
             formatFcfa((_session['price'] as num?) ?? 0)].where((e) => e.isNotEmpty).join(' · '),
            style: const TextStyle(fontSize: 13, color: _kNavy, fontWeight: FontWeight.w600),
          ),
          if (accueil.isNotEmpty || pratique.isNotEmpty)
            Text([if (accueil.isNotEmpty) 'Accueil : $accueil', if (pratique.isNotEmpty) 'Pratique : $pratique'].join(' · '),
                style: const TextStyle(fontSize: 12, color: _kGrey)),
          const SizedBox(height: 12),
          Wrap(spacing: 10, runSpacing: 10, children: [
            _kpi('Places confirmées', capacity == null ? '$confirmes' : '$confirmes / $capacity', _kGreen),
            _kpi('Présents', '${(_totals['presents'] as num?)?.toInt() ?? 0} / $confirmes', const Color(0xFF0EA5E9)),
            _kpi('À valider', '$aValider', aValider > 0 ? _kOrange : _kGrey),
            _kpi('Encaissé', formatFcfa((_totals['encaisse'] as num?) ?? 0), _kNavy),
          ]),
          const SizedBox(height: 8),
          Text(
            'Espèces ${formatFcfa((_totals['encaisse_especes'] as num?) ?? 0)} · '
            'LigdiCash ${formatFcfa((_totals['encaisse_ligdicash'] as num?) ?? 0)} · '
            'Mobile Money ${formatFcfa((_totals['encaisse_mobile_money'] as num?) ?? 0)}',
            style: const TextStyle(fontSize: 11.5, color: _kGrey),
          ),
        ]),
      ),
    );
  }

  Widget _kpi(String label, String value, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(color: color.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(10)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: color)),
          Text(label, style: const TextStyle(fontSize: 11, color: _kGrey)),
        ]),
      );

  static const _kFiltres = [
    ('tous', 'Tous'),
    ('a_valider', 'À valider'),
    ('confirmee', 'Confirmés'),
    ('en_cours', 'Paiement en cours'),
    ('autres', 'Expirés / refusés'),
  ];

  Widget _filtres() => Wrap(spacing: 8, runSpacing: 6, children: [
        for (final f in _kFiltres)
          ChoiceChip(
            label: Text('${f.$2} (${_compte(f.$1)})'),
            selected: _filtre == f.$1,
            onSelected: (_) => setState(() => _filtre = f.$1),
          ),
      ]);

  int _compte(String filtre) => _rows.where((r) => _correspond(r, filtre)).length;

  bool _correspond(Map<String, dynamic> r, String filtre) {
    final etat = r['etat']?.toString() ?? '';
    return switch (filtre) {
      'tous' => true,
      'autres' => etat == 'expiree' || etat == 'refusee' || etat == 'ancienne',
      _ => etat == filtre,
    };
  }

  List<Map<String, dynamic>> _lignesFiltrees() => _rows.where((r) => _correspond(r, _filtre)).toList();

  Widget _ligne(Map<String, dynamic> r) {
    final etat = r['etat']?.toString() ?? '';
    final (label, color) = switch (etat) {
      'confirmee' => ('Confirmée', _kGreen),
      'a_valider' => ('À valider', _kOrange),
      'en_cours' => ('Paiement en cours', const Color(0xFF2563EB)),
      'refusee' => ('Refusée', const Color(0xFFB91C1C)),
      'expiree' => ('Expirée', _kGrey),
      _ => ('Ancienne réservation', _kGrey),
    };
    final name = r['full_name']?.toString() ?? 'Inscrit';
    final details = <String>[
      if ((r['phone'] ?? '').toString().isNotEmpty) '${r['phone']}',
      _libelleCanal(r['channel'] ?? r['payment_method']),
      if ((r['external_reference'] ?? '').toString().isNotEmpty) 'Réf. ${r['external_reference']}',
      if ((r['receipt_number'] ?? '').toString().isNotEmpty) '${r['receipt_number']}',
      if (r['checked_in_at'] != null) 'Présent ${_heure(r['checked_in_at'])}',
    ].where((e) => e.isNotEmpty);
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: Color(0xFFE5E7EB))),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 8, 6),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Text(name, style: const TextStyle(fontWeight: FontWeight.w700, color: _kNavy))),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(999)),
              child: Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color)),
            ),
          ]),
          const SizedBox(height: 3),
          Text(details.join(' · '), style: const TextStyle(fontSize: 12, color: _kGrey)),
          Row(mainAxisAlignment: MainAxisAlignment.end, children: [
            if (widget.onOpenMessages != null)
              TextButton.icon(
                onPressed: () => widget.onOpenMessages!(r['registration_id'].toString(), name),
                icon: const Icon(Icons.chat_bubble_outline, size: 18),
                label: const Text('Messages'),
              ),
            if (etat == 'a_valider') ...[
              TextButton(onPressed: () => _refuser(r), child: const Text('Refuser', style: TextStyle(color: Color(0xFFB91C1C)))),
              const SizedBox(width: 4),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: _kGreen, foregroundColor: Colors.white),
                onPressed: () => _valider(r),
                child: const Text('Valider'),
              ),
            ],
          ]),
        ]),
      ),
    );
  }
}

String _heure(dynamic v) {
  final d = DateTime.tryParse('${v ?? ''}')?.toLocal();
  if (d == null) return '';
  return '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
}

/// Contrôle des tickets à l'entrée (27/10) : le QR du reçu
/// (« ACADEMIA-FC:<n° de reçu>:<12 car. d'empreinte> ») ou le numéro tapé.
/// Le serveur dit présent, déjà présent, autre session, faux ou inconnu.
class _ScanTicketsScreen extends StatefulWidget {
  const _ScanTicketsScreen({required this.sessionId, required this.title});
  final String sessionId;
  final String title;

  @override
  State<_ScanTicketsScreen> createState() => _ScanTicketsScreenState();
}

class _ScanTicketsScreenState extends State<_ScanTicketsScreen> {
  final _client = Supabase.instance.client;
  final MobileScannerController _controleur = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
    formats: const [BarcodeFormat.qrCode],
  );
  final _saisie = TextEditingController();
  bool _enCours = false;
  Map<String, dynamic>? _resultat;
  String? _dernierCode;
  DateTime? _dernierInstant;
  int _presents = 0;

  @override
  void dispose() {
    _controleur.dispose();
    _saisie.dispose();
    super.dispose();
  }

  Future<void> _verifier(String code) async {
    final c = code.trim();
    if (c.isEmpty || _enCours) return;
    // Le même QR reste devant la caméra : on ne le revérifie pas aussitôt.
    final now = DateTime.now();
    if (c == _dernierCode && _dernierInstant != null && now.difference(_dernierInstant!).inSeconds < 4) return;
    _dernierCode = c;
    _dernierInstant = now;
    setState(() => _enCours = true);
    try {
      final res = await _client.rpc('app_admin_short_training_check_ticket',
          params: {'p_session_id': widget.sessionId, 'p_code': c});
      final data = res is Map ? Map<String, dynamic>.from(res) : <String, dynamic>{'message': 'Réponse vide.'};
      if (data['resultat'] == 'present') _presents++;
      HapticFeedback.mediumImpact();
      setState(() => _resultat = data);
    } catch (e) {
      setState(() => _resultat = {'success': false, 'message': 'Erreur réseau : $e'});
    } finally {
      if (mounted) setState(() => _enCours = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = _resultat;
    final etat = r?['resultat']?.toString();
    final (couleur, icone) = switch (etat) {
      'present' => (_kGreen, Icons.check_circle),
      'deja_present' => (_kOrange, Icons.info),
      null => (_kGrey, Icons.qr_code),
      _ => (const Color(0xFFB91C1C), Icons.cancel),
    };
    return Scaffold(
      appBar: AppBar(title: Text('Entrée — ${widget.title}', maxLines: 1, overflow: TextOverflow.ellipsis)),
      body: Column(
        children: [
          Expanded(
            child: MobileScanner(
              controller: _controleur,
              onDetect: (capture) {
                for (final b in capture.barcodes) {
                  final v = b.rawValue;
                  if (v != null && v.toUpperCase().startsWith('ACADEMIA-FC:')) {
                    _verifier(v);
                    return;
                  }
                }
              },
              errorBuilder: (context, erreur) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    'Caméra indisponible (${erreur.errorCode.name}). Saisissez le numéro du reçu ci-dessous.',
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ),
          ),
          Container(
            width: double.infinity,
            color: couleur.withValues(alpha: 0.1),
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Icon(icone, color: couleur, size: 32),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    r == null
                        ? 'Présentez le QR du reçu devant la caméra.'
                        : [r['nom'], r['message']].where((e) => e != null && '$e'.isNotEmpty).join(' — '),
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: couleur),
                  ),
                ),
                if (_enCours) const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
              ]),
              const SizedBox(height: 6),
              Text('$_presents entrée(s) enregistrée(s) depuis l\'ouverture de cet écran.',
                  style: const TextStyle(fontSize: 12, color: _kGrey)),
              const SizedBox(height: 10),
              Row(children: [
                Expanded(
                  child: TextField(
                    controller: _saisie,
                    textCapitalization: TextCapitalization.characters,
                    decoration: const InputDecoration(
                      labelText: 'Ou numéro du reçu (REC-2026-…)',
                      isDense: true,
                      border: OutlineInputBorder(),
                    ),
                    onSubmitted: _verifier,
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _enCours ? null : () => _verifier(_saisie.text),
                  child: const Text('Vérifier'),
                ),
              ]),
            ]),
          ),
        ],
      ),
    );
  }
}

String _libelleCanal(dynamic canal) => switch (canal?.toString()) {
      'cash' || 'especes' => 'Espèces',
      'ligdicash' => 'LigdiCash',
      'orange_money' => 'Orange Money',
      'moov_money' => 'Moov Money',
      'telecel_money' => 'Telecel Money',
      'mobile_money' => 'Mobile Money',
      _ => '',
    };

/// Le guichet : retrouver la personne par son numéro, ou lui créer son compte
/// sur place, puis encaisser.
///
/// LA CRÉATION DE COMPTE PASSE PAR L'API HTTP, PAS PAR UN SECOND CLIENT
/// SUPABASE. Sur le web, `GoTrueClient` diffuse chaque connexion sur un
/// BroadcastChannel partagé par toutes les instances du même projet
/// (`sb-<projet>-auth-token`) : un second client qui inscrirait la personne
/// ferait basculer la session de l'administrateur sur le compte créé. L'appel
/// direct à `/auth/v1/signup` n'ouvre aucune session dans l'application.
///
/// Le code à 6 chiffres est choisi et saisi par la personne elle-même : il ne
/// s'affiche pas, n'est ni enregistré ni journalisé.
class _GuichetSheet extends StatefulWidget {
  const _GuichetSheet({required this.session});
  final Map<String, dynamic> session;

  @override
  State<_GuichetSheet> createState() => _GuichetSheetState();
}

class _GuichetSheetState extends State<_GuichetSheet> {
  final _client = Supabase.instance.client;
  final _phone = TextEditingController();
  final _firstName = TextEditingController();
  final _lastName = TextEditingController();
  final _code = TextEditingController();
  final _note = TextEditingController();

  bool _busy = false;
  bool _searched = false;
  bool _creation = false;
  bool _depasser = false;
  String? _error;
  List<Map<String, dynamic>> _found = const [];
  Map<String, dynamic>? _selected;
  String? _receipt;

  num get _price => (widget.session['price'] as num?) ?? 0;

  @override
  void dispose() {
    _phone.dispose();
    _firstName.dispose();
    _lastName.dispose();
    _code.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _chercher() async {
    final check = checkPhoneNumber(_phone.text, kBurkinaFaso);
    if (!check.isValid) {
      setState(() => _error = check.error);
      return;
    }
    setState(() { _busy = true; _error = null; _selected = null; _creation = false; });
    try {
      final res = await _client.rpc('app_admin_find_students_by_phone', params: {'p_phone': check.e164});
      final data = res is Map ? Map<String, dynamic>.from(res) : const <String, dynamic>{};
      if (data['success'] != true) {
        setState(() => _error = data['message']?.toString() ?? 'Recherche impossible (${data['error']}).');
        return;
      }
      final list = ((data['students'] as List?) ?? const []).whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
      setState(() {
        _searched = true;
        _found = list;
        if (list.length == 1) _selected = list.first;
        _creation = list.isEmpty;
      });
    } catch (e) {
      setState(() => _error = 'Erreur réseau : $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Crée le compte de la personne sans toucher à la session de l'admin.
  Future<String?> _creerCompte() async {
    final check = checkPhoneNumber(_phone.text, kBurkinaFaso);
    final first = _firstName.text.trim();
    final last = _lastName.text.trim();
    final code = _code.text.trim();
    if (!check.isValid) { setState(() => _error = check.error); return null; }
    if (first.isEmpty || last.isEmpty) { setState(() => _error = 'Saisissez le prénom et le nom.'); return null; }
    if (!RegExp(r'^\d{6}$').hasMatch(code)) { setState(() => _error = 'Le code doit compter 6 chiffres.'); return null; }

    final fullName = '$first $last';
    final headers = {'apikey': SupabaseConfig.anonKey, 'Content-Type': 'application/json'};
    final res = await http.post(
      Uri.parse('${SupabaseConfig.url}/auth/v1/signup'),
      headers: headers,
      body: jsonEncode({'phone': check.e164, 'password': code, 'data': {'role': 'student', 'full_name': fullName}}),
    );
    final body = res.body.isEmpty ? <String, dynamic>{} : jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode >= 400) {
      final msg = (body['msg'] ?? body['message'] ?? body['error_description'] ?? '').toString().toLowerCase();
      if (msg.contains('already') || msg.contains('registered') || msg.contains('exists')) {
        setState(() => _error = 'Ce numéro a déjà un compte : relancez la recherche.');
      } else if (msg.contains('password')) {
        setState(() => _error = 'Code refusé : demandez 6 chiffres moins simples.');
      } else {
        setState(() => _error = 'Création du compte impossible (${res.statusCode}).');
      }
      return null;
    }
    final token = body['access_token']?.toString();
    final user = (body['user'] ?? body) as Map<String, dynamic>;
    final userId = user['id']?.toString();
    if (userId == null || userId.isEmpty) {
      setState(() => _error = 'Compte créé sans identifiant exploitable : relancez la recherche.');
      return null;
    }
    // Le nom envoyé dans `data` n'arrive pas (mesuré le 04/09) : on l'écrit
    // avec le jeton de la personne, puis on ferme cette session.
    if (token != null && token.isNotEmpty) {
      final authHeaders = {...headers, 'Authorization': 'Bearer $token'};
      try {
        await http.post(Uri.parse('${SupabaseConfig.url}/rest/v1/rpc/app_student_update_full_profile'),
            headers: authHeaders, body: jsonEncode({'p_full_name': fullName}));
      } catch (e) {
        debugPrint('[Guichet] nom non enregistré : $e');
      }
      try {
        await http.post(Uri.parse('${SupabaseConfig.url}/auth/v1/logout?scope=local'), headers: authHeaders);
      } catch (_) {}
    }
    return userId;
  }

  Future<void> _encaisser() async {
    setState(() { _busy = true; _error = null; });
    try {
      String? studentId = _selected?['student_id']?.toString();
      if (studentId == null && _creation) {
        studentId = await _creerCompte();
      }
      if (studentId == null) {
        if (_error == null) setState(() => _error = 'Choisissez la personne ou créez son compte.');
        return;
      }
      final res = await _client.rpc('app_admin_short_training_cash', params: {
        'p_session_id': widget.session['session_id'],
        'p_student_id': studentId,
        'p_note': _note.text.trim().isEmpty ? null : _note.text.trim(),
        'p_allow_over_capacity': _depasser,
      });
      final data = res is Map ? Map<String, dynamic>.from(res) : const <String, dynamic>{};
      if (data['success'] != true) {
        setState(() => _error = data['message']?.toString() ?? 'Encaissement refusé (${data['error']}).');
        return;
      }
      setState(() => _receipt = data['receipt_number']?.toString() ?? '');
    } catch (e) {
      setState(() => _error = 'Erreur réseau : $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.92),
      decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      padding: EdgeInsets.fromLTRB(20, 16, 20, 20 + MediaQuery.of(context).viewInsets.bottom),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: SingleChildScrollView(child: _receipt != null ? _vueFaite() : _vueSaisie()),
        ),
      ),
    );
  }

  Widget _vueFaite() => Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const Icon(Icons.verified, size: 56, color: _kGreen),
        const SizedBox(height: 8),
        const Text('Encaissé — place confirmée', textAlign: TextAlign.center,
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: _kNavy)),
        const SizedBox(height: 6),
        Text('Reçu ${_receipt!.isEmpty ? '' : 'n° $_receipt '}émis : il est dans « Documents » de la personne '
            'et dans Admin › Reçus.',
            textAlign: TextAlign.center, style: const TextStyle(color: _kGrey)),
        const SizedBox(height: 16),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: _kGreen, foregroundColor: Colors.white, minimumSize: const Size.fromHeight(48)),
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('Terminer'),
        ),
      ]);

  Widget _vueSaisie() {
    final dec = InputDecoration(border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)), isDense: true);
    return Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const Text('Encaisser au guichet', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: _kNavy)),
      Text('${widget.session['title'] ?? ''} — ${formatFcfa(_price)} en espèces',
          style: const TextStyle(fontSize: 13, color: _kGrey)),
      const SizedBox(height: 14),
      if (_error != null)
        Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: const Color(0xFFFEF2F2), borderRadius: BorderRadius.circular(10)),
          child: Text(_error!, style: const TextStyle(color: Color(0xFFB91C1C), fontSize: 13)),
        ),
      Row(children: [
        Expanded(
          child: TextField(
            controller: _phone,
            keyboardType: TextInputType.phone,
            decoration: dec.copyWith(labelText: 'Téléphone de la personne', prefixText: '${kBurkinaFaso.dialPrefix} '),
            onSubmitted: (_) => _chercher(),
          ),
        ),
        const SizedBox(width: 8),
        OutlinedButton(onPressed: _busy ? null : _chercher, child: const Text('Rechercher')),
      ]),
      if (_searched && _found.isNotEmpty) ...[
        const SizedBox(height: 10),
        for (final s in _found)
          Card(
            margin: const EdgeInsets.only(bottom: 6),
            color: _selected == s ? const Color(0xFFF0FDF4) : null,
            child: ListTile(
              dense: true,
              leading: Icon(_selected == s ? Icons.radio_button_checked : Icons.radio_button_off, color: _kGreen),
              title: Text(s['full_name']?.toString() ?? 'Sans nom'),
              subtitle: Text([s['phone'], s['email']].where((e) => e != null && '$e'.isNotEmpty).join(' · ')),
              onTap: () => setState(() { _selected = s; _creation = false; }),
            ),
          ),
        TextButton(
          onPressed: () => setState(() { _creation = true; _selected = null; }),
          child: const Text('Ce n\'est pas cette personne : créer un compte'),
        ),
      ],
      if (_creation) ...[
        const SizedBox(height: 10),
        Text(_found.isEmpty ? 'Aucun compte pour ce numéro : créez-le.' : 'Nouveau compte',
            style: const TextStyle(fontWeight: FontWeight.w700, color: _kNavy)),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(child: TextField(controller: _firstName, textCapitalization: TextCapitalization.words, decoration: dec.copyWith(labelText: 'Prénom'))),
          const SizedBox(width: 8),
          Expanded(child: TextField(controller: _lastName, textCapitalization: TextCapitalization.characters, decoration: dec.copyWith(labelText: 'Nom'))),
        ]),
        const SizedBox(height: 10),
        TextField(
          controller: _code,
          obscureText: true,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(6)],
          decoration: dec.copyWith(labelText: 'Code à 6 chiffres — saisi par la personne'),
        ),
        const SizedBox(height: 4),
        const Text('Tendez l\'appareil : la personne choisit son code. Il lui servira à se connecter avec son numéro.',
            style: TextStyle(fontSize: 11.5, color: _kGrey)),
      ],
      if (_selected != null || _creation) ...[
        const SizedBox(height: 12),
        TextField(controller: _note, decoration: dec.copyWith(labelText: 'Note (facultatif)')),
        if (widget.session['capacity'] != null)
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            dense: true,
            value: _depasser,
            onChanged: (v) => setState(() => _depasser = v ?? false),
            title: const Text('Dépasser la capacité si la session est complète'),
          ),
        const SizedBox(height: 8),
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(backgroundColor: _kGreen, foregroundColor: Colors.white, minimumSize: const Size.fromHeight(50)),
          onPressed: _busy ? null : _encaisser,
          icon: _busy
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Icon(Icons.payments),
          label: Text('Encaisser ${formatFcfa(_price)} en espèces'),
        ),
      ],
      const SizedBox(height: 6),
      TextButton(onPressed: _busy ? null : () => Navigator.of(context).pop(false), child: const Text('Fermer')),
    ]);
  }
}
