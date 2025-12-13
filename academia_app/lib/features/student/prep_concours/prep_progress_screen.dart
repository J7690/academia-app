import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../providers/prep_concours_provider.dart';

class PrepProgressScreen extends StatefulWidget {
  final PrepSubject subject;

  const PrepProgressScreen({
    super.key,
    required this.subject,
  });

  @override
  State<PrepProgressScreen> createState() => _PrepProgressScreenState();
}

class _PrepProgressScreenState extends State<PrepProgressScreen> {
  bool _initialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    _initialized = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<PrepConcoursProvider>();
      provider.loadMySubjectStats(subjectId: widget.subject.id);
      provider.loadMyAttempts(subjectId: widget.subject.id);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F6),
      appBar: AppBar(
        elevation: 0,
        title: Text('Historique - ${widget.subject.title}'),
        foregroundColor: Colors.white,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFFA3D65C), Color(0xFF1EA75C)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
      ),
      body: Consumer<PrepConcoursProvider>(
        builder: (context, provider, child) {
          if (provider.isLoading && provider.myAttempts.isEmpty && provider.mySubjectStats == null) {
            return const Center(child: CircularProgressIndicator());
          }

          if (provider.error != null && provider.myAttempts.isEmpty && provider.mySubjectStats == null) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      provider.error!,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    ElevatedButton(
                      onPressed: () {
                        provider.loadMySubjectStats(subjectId: widget.subject.id);
                        provider.loadMyAttempts(subjectId: widget.subject.id);
                      },
                      child: const Text('Recharger'),
                    ),
                  ],
                ),
              ),
            );
          }

          final stats = provider.mySubjectStats;
          final attempts = provider.myAttempts;

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
            children: [
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        'Statistiques (30 jours)',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 10),
                      if (stats == null)
                        const Text('Aucune statistique disponible.')
                      else
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text('Total: ${stats.total}'),
                            Text('Correct: ${stats.correct}'),
                            Text('Accuracy: ${stats.accuracy.toStringAsFixed(1)}%'),
                            Text('Temps moyen: ${stats.avgTimeSec.toStringAsFixed(1)}s'),
                          ],
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Historique',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              if (attempts.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Text(
                    'Aucune tentative enregistrée pour le moment.',
                    textAlign: TextAlign.center,
                  ),
                )
              else
                for (final a in attempts)
                  Card(
                    elevation: 0,
                    margin: const EdgeInsets.only(bottom: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: ListTile(
                      leading: Icon(
                        a.isCorrect == true
                            ? Icons.check_circle_outline
                            : Icons.cancel_outlined,
                        color: a.isCorrect == true ? const Color(0xFF1EA75C) : Colors.redAccent,
                      ),
                      title: Text(
                        a.question,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(
                        '${a.attemptType} • ${a.createdAt?.toLocal().toString().split('.').first ?? ''}',
                      ),
                      trailing: a.timeSpentSec == null
                          ? null
                          : Text('${a.timeSpentSec}s'),
                      onTap: () {
                        showDialog<void>(
                          context: context,
                          builder: (dialogContext) {
                            return AlertDialog(
                              title: const Text('Détail'),
                              content: SingleChildScrollView(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: [
                                    Text(a.question),
                                    const SizedBox(height: 10),
                                    Text('Type: ${a.attemptType}'),
                                    Text('Résultat: ${a.isCorrect == true ? 'Correct' : 'Incorrect'}'),
                                    if (a.correctAnswer != null) ...[
                                      const SizedBox(height: 10),
                                      Text('Bonne réponse: ${a.correctAnswer}'),
                                    ],
                                  ],
                                ),
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.of(dialogContext).pop(),
                                  child: const Text('Fermer'),
                                ),
                              ],
                            );
                          },
                        );
                      },
                    ),
                  ),
            ],
          );
        },
      ),
    );
  }
}
