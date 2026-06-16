import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Admin UGC Moderation screen — lists content reports, allows resolve/suspend.
class AdminModerationScreen extends StatefulWidget {
  const AdminModerationScreen({super.key});

  @override
  State<AdminModerationScreen> createState() => _AdminModerationScreenState();
}

class _AdminModerationScreenState extends State<AdminModerationScreen> {
  List<Map<String, dynamic>> _reports = [];
  bool _loading = true;
  String _statusFilter = 'pending';

  @override
  void initState() {
    super.initState();
    _loadReports();
  }

  Future<void> _loadReports() async {
    setState(() => _loading = true);
    try {
      final result = await Supabase.instance.client.rpc(
        'app_admin_list_content_reports',
        params: {
          'p_status': _statusFilter.isEmpty ? null : _statusFilter,
          'p_content_type': null,
          'p_limit': 50,
        },
      );
      if (result is List) {
        _reports = result.cast<Map<String, dynamic>>();
      } else {
        _reports = [];
      }
    } catch (e) {
      debugPrint('Error loading reports: $e');
      _reports = [];
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _resolveReport(String reportId, String status) async {
    try {
      await Supabase.instance.client.rpc('app_admin_resolve_content_report', params: {
        'p_report_id': reportId,
        'p_status': status,
        'p_admin_notes': null,
      });
      await _loadReports();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e')),
        );
      }
    }
  }

  Future<void> _suspendUser(String userId, String reason) async {
    try {
      await Supabase.instance.client.rpc('app_admin_suspend_user', params: {
        'p_user_id': userId,
        'p_reason': reason,
        'p_duration_hours': 24,
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Utilisateur suspendu 24h')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur suspension: $e')),
        );
      }
    }
  }

  Color _reasonColor(String reason) {
    switch (reason) {
      case 'nudity': return Colors.pink;
      case 'violence': return Colors.red;
      case 'harassment': return Colors.orange;
      case 'spam': return Colors.grey;
      case 'scam': return Colors.amber;
      case 'inappropriate': return Colors.purple;
      case 'fake_profile': return Colors.teal;
      case 'hate_speech': return Colors.deepOrange;
      default: return Colors.blueGrey;
    }
  }

  String _reasonLabel(String reason) {
    switch (reason) {
      case 'nudity': return 'Nudite';
      case 'violence': return 'Violence';
      case 'harassment': return 'Harcelement';
      case 'spam': return 'Spam';
      case 'scam': return 'Arnaque';
      case 'inappropriate': return 'Inapproprie';
      case 'fake_profile': return 'Faux profil';
      case 'hate_speech': return 'Haine';
      default: return reason;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Filter chips
        Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              _FilterChip('En attente', 'pending'),
              const SizedBox(width: 8),
              _FilterChip('Resolus', 'resolved'),
              const SizedBox(width: 8),
              _FilterChip('Rejetes', 'rejected'),
              const SizedBox(width: 8),
              _FilterChip('Tous', ''),
            ],
          ),
        ),
        // Stats bar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          color: Colors.grey[100],
          child: Row(
            children: [
              Text('${_reports.length} signalements',
                  style: const TextStyle(fontWeight: FontWeight.w600)),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.refresh, size: 20),
                onPressed: _loadReports,
              ),
            ],
          ),
        ),
        // List
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _reports.isEmpty
                  ? const Center(child: Text('Aucun signalement', style: TextStyle(color: Colors.grey)))
                  : ListView.builder(
                      itemCount: _reports.length,
                      itemBuilder: (context, index) {
                        final r = _reports[index];
                        return _ReportCard(
                          report: r,
                          reasonColor: _reasonColor(r['reason'] ?? ''),
                          reasonLabel: _reasonLabel(r['reason'] ?? ''),
                          onResolve: () => _resolveReport(r['id'], 'resolved'),
                          onReject: () => _resolveReport(r['id'], 'rejected'),
                          onSuspend: () {
                            final targetId = r['target_user_id']?.toString();
                            if (targetId != null) {
                              _suspendUser(targetId, 'Signalement: ${r['reason']}');
                            }
                          },
                        );
                      },
                    ),
        ),
      ],
    );
  }

  Widget _FilterChip(String label, String value) {
    final selected = _statusFilter == value;
    return ChoiceChip(
      label: Text(label, style: TextStyle(fontSize: 12, color: selected ? Colors.white : Colors.black87)),
      selected: selected,
      selectedColor: Colors.indigo,
      onSelected: (_) {
        setState(() => _statusFilter = value);
        _loadReports();
      },
    );
  }
}

class _ReportCard extends StatelessWidget {
  final Map<String, dynamic> report;
  final Color reasonColor;
  final String reasonLabel;
  final VoidCallback onResolve;
  final VoidCallback onReject;
  final VoidCallback onSuspend;

  const _ReportCard({
    required this.report,
    required this.reasonColor,
    required this.reasonLabel,
    required this.onResolve,
    required this.onReject,
    required this.onSuspend,
  });

  @override
  Widget build(BuildContext context) {
    final type = report['content_type']?.toString() ?? '?';
    final reporter = report['reporter_name']?.toString() ?? 'Anonyme';
    final target = report['target_name']?.toString() ?? '?';
    final details = report['details']?.toString() ?? '';
    final status = report['status']?.toString() ?? 'pending';
    final createdAt = report['created_at']?.toString() ?? '';

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: reasonColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(reasonLabel,
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: reasonColor)),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.blue[50],
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(type, style: TextStyle(fontSize: 10, color: Colors.blue[700])),
                ),
                const Spacer(),
                if (status == 'pending')
                  Container(
                    width: 8, height: 8,
                    decoration: const BoxDecoration(color: Colors.orange, shape: BoxShape.circle),
                  ),
                if (status == 'resolved')
                  const Icon(Icons.check_circle, size: 16, color: Colors.green),
                if (status == 'rejected')
                  const Icon(Icons.cancel, size: 16, color: Colors.grey),
              ],
            ),
            const SizedBox(height: 8),
            Text('Par: $reporter  →  Cible: $target',
                style: const TextStyle(fontSize: 12, color: Colors.black87)),
            if (details.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(details, maxLines: 2, overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12, color: Colors.grey[600])),
            ],
            if (createdAt.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(createdAt.substring(0, 16).replaceAll('T', ' '),
                  style: TextStyle(fontSize: 10, color: Colors.grey[400])),
            ],
            if (status == 'pending') ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  TextButton.icon(
                    onPressed: onResolve,
                    icon: const Icon(Icons.check, size: 16),
                    label: const Text('Resolu', style: TextStyle(fontSize: 12)),
                    style: TextButton.styleFrom(foregroundColor: Colors.green),
                  ),
                  TextButton.icon(
                    onPressed: onReject,
                    icon: const Icon(Icons.close, size: 16),
                    label: const Text('Rejeter', style: TextStyle(fontSize: 12)),
                    style: TextButton.styleFrom(foregroundColor: Colors.grey),
                  ),
                  const Spacer(),
                  TextButton.icon(
                    onPressed: onSuspend,
                    icon: const Icon(Icons.gavel, size: 16),
                    label: const Text('Suspendre 24h', style: TextStyle(fontSize: 12)),
                    style: TextButton.styleFrom(foregroundColor: Colors.red),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
