import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AdminFinanceProvider extends ChangeNotifier {
  final SupabaseClient _client = Supabase.instance.client;

  // ─── State ───
  bool _isLoading = false;
  String? _error;

  // Overview KPIs
  Map<String, dynamic>? _overview;

  // Live feed (ledger)
  List<Map<String, dynamic>> _liveFeed = [];
  int _liveFeedTotal = 0;
  String? _feedDirectionFilter;
  DateTime? _feedDateFrom;
  DateTime? _feedDateTo;

  // Payouts
  List<Map<String, dynamic>> _payouts = [];
  int _payoutsTotal = 0;
  Map<String, dynamic> _payoutKpi = {};
  String? _payoutStatusFilter;
  String? _payoutActorFilter;

  // Actor balances
  List<Map<String, dynamic>> _actorBalances = [];
  String? _actorTypeFilter;

  // Realtime
  RealtimeChannel? _realtimeChannel;
  Timer? _kpiRefreshTimer;

  // New items (for animation)
  final Set<String> _newLedgerIds = {};
  final Set<String> _newPayoutIds = {};

  // ─── Getters ───
  bool get isLoading => _isLoading;
  String? get error => _error;
  Map<String, dynamic>? get overview => _overview;
  List<Map<String, dynamic>> get liveFeed => _liveFeed;
  int get liveFeedTotal => _liveFeedTotal;
  String? get feedDirectionFilter => _feedDirectionFilter;
  List<Map<String, dynamic>> get payouts => _payouts;
  int get payoutsTotal => _payoutsTotal;
  Map<String, dynamic> get payoutKpi => _payoutKpi;
  String? get payoutStatusFilter => _payoutStatusFilter;
  String? get payoutActorFilter => _payoutActorFilter;
  List<Map<String, dynamic>> get actorBalances => _actorBalances;
  String? get actorTypeFilter => _actorTypeFilter;
  Set<String> get newLedgerIds => _newLedgerIds;
  Set<String> get newPayoutIds => _newPayoutIds;

  // ─── Init ───
  Future<void> init() async {
    _isLoading = true;
    notifyListeners();
    try {
      await Future.wait([
        loadOverview(),
        loadLiveFeed(),
        loadPayouts(),
        loadActorBalances(),
      ]);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
    _subscribeRealtime();
    _kpiRefreshTimer = Timer.periodic(const Duration(seconds: 30), (_) => loadOverview());
  }

  // ─── Overview ───
  Future<void> loadOverview() async {
    try {
      final resp = await _client.rpc('app_admin_finance_overview');
      final data = resp as Map<String, dynamic>?;
      if (data != null && data['success'] == true) {
        _overview = data;
        notifyListeners();
      }
    } catch (e) {
      debugPrint('[AdminFinanceProvider] loadOverview error=$e');
    }
  }

  // ─── Live Feed (Ledger) ───
  Future<void> loadLiveFeed({int limit = 50, int offset = 0}) async {
    try {
      final resp = await _client.rpc('app_admin_finance_live_feed', params: {
        'p_limit': limit,
        'p_offset': offset,
        if (_feedDirectionFilter != null) 'p_direction': _feedDirectionFilter,
        if (_feedDateFrom != null) 'p_date_from': _feedDateFrom!.toIso8601String(),
        if (_feedDateTo != null) 'p_date_to': _feedDateTo!.toIso8601String(),
      });
      final data = resp as Map<String, dynamic>?;
      if (data != null && data['success'] == true) {
        final entries = (data['entries'] as List<dynamic>? ?? []).cast<Map<String, dynamic>>();
        if (offset == 0) {
          _liveFeed = entries;
        } else {
          _liveFeed = [..._liveFeed, ...entries];
        }
        _liveFeedTotal = data['total'] as int? ?? 0;
        notifyListeners();
      }
    } catch (e) {
      debugPrint('[AdminFinanceProvider] loadLiveFeed error=$e');
    }
  }

  void setFeedDirection(String? direction) {
    _feedDirectionFilter = direction;
    loadLiveFeed();
  }

  void setFeedDateRange(DateTime? from, DateTime? to) {
    _feedDateFrom = from;
    _feedDateTo = to;
    loadLiveFeed();
  }

  // ─── Payouts ───
  Future<void> loadPayouts({int limit = 50, int offset = 0}) async {
    try {
      final resp = await _client.rpc('app_admin_finance_payout_feed', params: {
        'p_limit': limit,
        'p_offset': offset,
        if (_payoutStatusFilter != null) 'p_status': _payoutStatusFilter,
        if (_payoutActorFilter != null) 'p_beneficiary_type': _payoutActorFilter,
      });
      final data = resp as Map<String, dynamic>?;
      if (data != null && data['success'] == true) {
        final list = (data['payouts'] as List<dynamic>? ?? []).cast<Map<String, dynamic>>();
        if (offset == 0) {
          _payouts = list;
        } else {
          _payouts = [..._payouts, ...list];
        }
        _payoutsTotal = data['total'] as int? ?? 0;
        _payoutKpi = (data['kpi'] as Map<String, dynamic>?) ?? {};
        notifyListeners();
      }
    } catch (e) {
      debugPrint('[AdminFinanceProvider] loadPayouts error=$e');
    }
  }

  void setPayoutStatusFilter(String? status) {
    _payoutStatusFilter = status;
    loadPayouts();
  }

  void setPayoutActorFilter(String? actor) {
    _payoutActorFilter = actor;
    loadPayouts();
  }

  Future<bool> triggerPayouts({bool allPending = false, List<String>? ids}) async {
    try {
      final response = await _client.functions.invoke(
        'ligdicash-payout',
        body: allPending ? {'all_pending': true} : {'payout_ids': ids ?? []},
      );
      final rawData = response.data;
      Map<String, dynamic>? data;
      if (rawData is Map<String, dynamic>) {
        data = rawData;
      } else if (rawData is String) {
        try { data = jsonDecode(rawData) as Map<String, dynamic>?; } catch (_) {}
      }
      if (data?['success'] == true) {
        await loadPayouts();
        await loadOverview();
        return true;
      }
      _error = data?['error']?.toString();
      notifyListeners();
      return false;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  // ─── Actor Balances ───
  Future<void> loadActorBalances() async {
    try {
      final resp = await _client.rpc('app_admin_list_actor_balances', params: {
        if (_actorTypeFilter != null && _actorTypeFilter!.isNotEmpty) 'p_actor_type': _actorTypeFilter,
      });
      final data = resp as Map<String, dynamic>?;
      if (data != null && data['success'] == true) {
        _actorBalances = (data['balances'] as List<dynamic>? ?? []).cast<Map<String, dynamic>>();
        notifyListeners();
      }
    } catch (e) {
      debugPrint('[AdminFinanceProvider] loadActorBalances error=$e');
    }
  }

  void setActorTypeFilter(String? type) {
    _actorTypeFilter = type;
    loadActorBalances();
  }

  // ─── Actor History ───
  Future<Map<String, dynamic>?> loadActorHistory(String actorId) async {
    try {
      final resp = await _client.rpc('app_admin_finance_actor_history', params: {'p_actor_id': actorId});
      final data = resp as Map<String, dynamic>?;
      if (data != null && data['success'] == true) return data;
    } catch (e) {
      debugPrint('[AdminFinanceProvider] loadActorHistory error=$e');
    }
    return null;
  }

  // ─── Supabase Realtime ───
  void _subscribeRealtime() {
    _realtimeChannel = _client.channel('admin_finance_live')
      .onPostgresChanges(
        event: PostgresChangeEvent.insert,
        schema: 'app',
        table: 'platform_ledger',
        callback: (payload) {
          final rec = payload.newRecord;
          if (rec.isNotEmpty) {
            _liveFeed.insert(0, Map<String, dynamic>.from(rec));
            final id = rec['id']?.toString();
            if (id != null) {
              _newLedgerIds.add(id);
              Future.delayed(const Duration(seconds: 30), () {
                _newLedgerIds.remove(id);
                notifyListeners();
              });
            }
            _liveFeedTotal++;
            notifyListeners();
          }
        },
      )
      .onPostgresChanges(
        event: PostgresChangeEvent.insert,
        schema: 'app',
        table: 'payout_queue',
        callback: (payload) {
          final rec = payload.newRecord;
          if (rec.isNotEmpty) {
            _payouts.insert(0, Map<String, dynamic>.from(rec));
            final id = rec['id']?.toString();
            if (id != null) {
              _newPayoutIds.add(id);
              Future.delayed(const Duration(seconds: 30), () {
                _newPayoutIds.remove(id);
                notifyListeners();
              });
            }
            _payoutsTotal++;
            notifyListeners();
          }
        },
      )
      .onPostgresChanges(
        event: PostgresChangeEvent.update,
        schema: 'app',
        table: 'payout_queue',
        callback: (payload) {
          final rec = payload.newRecord;
          final id = rec['id']?.toString();
          if (id != null) {
            final idx = _payouts.indexWhere((p) => p['id']?.toString() == id);
            if (idx >= 0) {
              _payouts[idx] = Map<String, dynamic>.from(rec);
              // Move to top
              final item = _payouts.removeAt(idx);
              _payouts.insert(0, item);
              _newPayoutIds.add(id);
              Future.delayed(const Duration(seconds: 30), () {
                _newPayoutIds.remove(id);
                notifyListeners();
              });
              notifyListeners();
            }
          }
        },
      )
      .subscribe();
  }

  // ─── CSV Export ───
  String exportLedgerCsv() {
    final buf = StringBuffer();
    buf.writeln('Date,Type,Direction,Montant,Devise,Acteur,Description');
    for (final e in _liveFeed) {
      final date = e['created_at']?.toString() ?? '';
      final type = e['transaction_type']?.toString() ?? '';
      final dir = e['direction']?.toString() ?? '';
      final amount = e['amount']?.toString() ?? '';
      final cur = e['currency']?.toString() ?? 'XOF';
      final actor = (e['actor_name'] ?? e['counterpart_type'] ?? '').toString().replaceAll(',', ' ');
      final desc = (e['description'] ?? '').toString().replaceAll(',', ' ');
      buf.writeln('$date,$type,$dir,$amount,$cur,$actor,$desc');
    }
    return buf.toString();
  }

  @override
  void dispose() {
    _realtimeChannel?.unsubscribe();
    _kpiRefreshTimer?.cancel();
    super.dispose();
  }
}
