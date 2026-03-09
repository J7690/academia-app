import 'package:flutter/material.dart';
import 'package:animate_do/animate_do.dart';

import '../../services/td_service.dart';
import '../../theme/prep_theme.dart';

/// Écran enseignant — Création de quiz, upload de sujets, analytics étudiants.
class TeacherPrepScreen extends StatefulWidget {
  const TeacherPrepScreen({super.key});

  @override
  State<TeacherPrepScreen> createState() => _TeacherPrepScreenState();
}

class _TeacherPrepScreenState extends State<TeacherPrepScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TdService _service = TdService();

  List<Map<String, dynamic>> _banks = [];
  List<Map<String, dynamic>> _questions = [];
  List<Map<String, dynamic>> _examPapers = [];
  List<Map<String, dynamic>> _flashcardDecks = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    try {
      final results = await Future.wait([
        _service.prepListQuestionBanks(),
        _service.prepAdminListQuestions(limit: 30),
        _service.prepListExamPapers(),
        _service.prepListFlashcardDecks(),
      ]);
      if (!mounted) return;
      setState(() {
        _banks = results[0];
        _questions = results[1];
        _examPapers = results[2];
        _flashcardDecks = results[3];
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: PrepTheme.scaffoldBg,
      appBar: AppBar(
        elevation: 0,
        title: const Text('Préparation — Enseignant',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 17)),
        foregroundColor: Colors.white,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [PrepTheme.success, PrepTheme.successLight],
            ),
          ),
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          indicatorWeight: 3,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          labelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
          isScrollable: true,
          labelPadding: const EdgeInsets.symmetric(horizontal: 12),
          tabs: const [
            Tab(icon: Icon(Icons.quiz, size: 18), text: 'Questions'),
            Tab(icon: Icon(Icons.description, size: 18), text: 'Sujets'),
            Tab(icon: Icon(Icons.style, size: 18), text: 'Flashcards'),
            Tab(icon: Icon(Icons.analytics, size: 18), text: 'Résultats'),
          ],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: PrepTheme.success))
          : TabBarView(
              controller: _tabController,
              children: [
                _QuestionsTab(
                  banks: _banks,
                  questions: _questions,
                  service: _service,
                  onRefresh: _loadData,
                ),
                _ExamPapersTab(
                  papers: _examPapers,
                  service: _service,
                  onRefresh: _loadData,
                ),
                _FlashcardsTab(
                  decks: _flashcardDecks,
                  service: _service,
                  onRefresh: _loadData,
                ),
                _ResultsTab(service: _service),
              ],
            ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// Tab 1: Questions — Créer des banques et des questions
// ═══════════════════════════════════════════════════════════════════
class _QuestionsTab extends StatelessWidget {
  final List<Map<String, dynamic>> banks;
  final List<Map<String, dynamic>> questions;
  final TdService service;
  final VoidCallback onRefresh;

  const _QuestionsTab({
    required this.banks,
    required this.questions,
    required this.service,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      physics: const BouncingScrollPhysics(),
      children: [
        // ─── Create bank button ──────────────────────────────────
        FadeInDown(
          duration: const Duration(milliseconds: 350),
          child: Row(
            children: [
              Expanded(
                child: _ActionCard(
                  icon: Icons.library_add,
                  label: 'Nouvelle banque',
                  color: PrepTheme.success,
                  onTap: () => _showCreateBankDialog(context),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _ActionCard(
                  icon: Icons.add_circle,
                  label: 'Nouvelle question',
                  color: PrepTheme.primary,
                  onTap: () => _showCreateQuestionDialog(context),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // ─── Banks ───────────────────────────────────────────────
        const Text('Banques de questions',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: PrepTheme.textPrimary)),
        const SizedBox(height: 10),
        if (banks.isEmpty)
          _EmptyState(icon: Icons.folder_open, message: 'Aucune banque créée')
        else
          ...banks.asMap().entries.map((e) => FadeInUp(
                delay: Duration(milliseconds: 40 * e.key),
                duration: const Duration(milliseconds: 350),
                child: _BankCard(bank: e.value),
              )),

        const SizedBox(height: 20),

        // ─── Recent questions ────────────────────────────────────
        const Text('Questions récentes',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: PrepTheme.textPrimary)),
        const SizedBox(height: 10),
        if (questions.isEmpty)
          _EmptyState(icon: Icons.quiz, message: 'Aucune question')
        else
          ...questions.take(10).toList().asMap().entries.map((e) => FadeInUp(
                delay: Duration(milliseconds: 40 * e.key),
                duration: const Duration(milliseconds: 350),
                child: _QuestionCard(question: e.value),
              )),
      ],
    );
  }

  void _showCreateBankDialog(BuildContext context) {
    final titleCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    String? selectedConcours;
    String? selectedSubject;

    showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Nouvelle banque de questions', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: titleCtrl,
                  decoration: const InputDecoration(labelText: 'Titre *', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: descCtrl,
                  decoration: const InputDecoration(labelText: 'Description', border: OutlineInputBorder()),
                  maxLines: 2,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: selectedConcours,
                  decoration: const InputDecoration(labelText: 'Concours', border: OutlineInputBorder()),
                  items: ['ENAM', 'ENS', 'ENSET', 'BAC', 'BEPC', 'IRIC']
                      .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                      .toList(),
                  onChanged: (v) => setDialogState(() => selectedConcours = v),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: selectedSubject,
                  decoration: const InputDecoration(labelText: 'Matière', border: OutlineInputBorder()),
                  items: ['Culture Générale', 'Mathématiques', 'Droit', 'Économie', 'Français', 'Physique-Chimie', 'Biologie', 'Histoire-Géo', 'Philosophie']
                      .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                      .toList(),
                  onChanged: (v) => setDialogState(() => selectedSubject = v),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Annuler')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: PrepTheme.success),
              onPressed: () async {
                if (titleCtrl.text.trim().isEmpty) return;
                Navigator.of(ctx).pop();
                try {
                  await service.prepCreateQuestionBank(
                    title: titleCtrl.text.trim(),
                    description: descCtrl.text.trim().isEmpty ? null : descCtrl.text.trim(),
                    concoursType: selectedConcours,
                    subject: selectedSubject,
                  );
                  onRefresh();
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur: $e')));
                  }
                }
              },
              child: const Text('Créer', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  void _showCreateQuestionDialog(BuildContext context) {
    final contentCtrl = TextEditingController();
    final explanationCtrl = TextEditingController();
    final optionCtrls = List.generate(4, (_) => TextEditingController());
    int correctIndex = 0;
    int difficulty = 1;
    String? selectedBankId;
    String? selectedSubject;

    showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Nouvelle question QCM', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          content: SizedBox(
            width: double.maxFinite,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (banks.isNotEmpty)
                    DropdownButtonFormField<String>(
                      value: selectedBankId,
                      decoration: const InputDecoration(labelText: 'Banque *', border: OutlineInputBorder()),
                      items: banks.map((b) => DropdownMenuItem(
                            value: b['id']?.toString(),
                            child: Text(b['title']?.toString() ?? '', overflow: TextOverflow.ellipsis),
                          )).toList(),
                      onChanged: (v) => setDialogState(() => selectedBankId = v),
                    ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: contentCtrl,
                    decoration: const InputDecoration(labelText: 'Question *', border: OutlineInputBorder()),
                    maxLines: 3,
                  ),
                  const SizedBox(height: 12),
                  ...List.generate(4, (i) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          children: [
                            Radio<int>(
                              value: i,
                              groupValue: correctIndex,
                              onChanged: (v) => setDialogState(() => correctIndex = v!),
                              activeColor: PrepTheme.success,
                            ),
                            Expanded(
                              child: TextField(
                                controller: optionCtrls[i],
                                decoration: InputDecoration(
                                  labelText: 'Option ${String.fromCharCode(65 + i)}',
                                  border: const OutlineInputBorder(),
                                  suffixIcon: correctIndex == i
                                      ? const Icon(Icons.check_circle, color: PrepTheme.success, size: 18)
                                      : null,
                                ),
                              ),
                            ),
                          ],
                        ),
                      )),
                  TextField(
                    controller: explanationCtrl,
                    decoration: const InputDecoration(labelText: 'Explication', border: OutlineInputBorder()),
                    maxLines: 2,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const Text('Difficulté: ', style: TextStyle(fontWeight: FontWeight.w600)),
                      ...List.generate(5, (i) => GestureDetector(
                            onTap: () => setDialogState(() => difficulty = i + 1),
                            child: Icon(
                              i < difficulty ? Icons.star : Icons.star_border,
                              color: PrepTheme.accent,
                              size: 28,
                            ),
                          )),
                    ],
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: selectedSubject,
                    decoration: const InputDecoration(labelText: 'Matière', border: OutlineInputBorder()),
                    items: ['Culture Générale', 'Mathématiques', 'Droit', 'Économie', 'Français', 'Physique-Chimie', 'Biologie', 'Histoire-Géo']
                        .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                        .toList(),
                    onChanged: (v) => setDialogState(() => selectedSubject = v),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Annuler')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: PrepTheme.primary),
              onPressed: () async {
                if (selectedBankId == null || contentCtrl.text.trim().isEmpty) return;
                final options = optionCtrls.map((c) => c.text.trim()).where((t) => t.isNotEmpty).toList();
                if (options.length < 2) return;
                Navigator.of(ctx).pop();
                try {
                  await service.prepCreateQuestion(
                    bankId: selectedBankId!,
                    content: contentCtrl.text.trim(),
                    options: options,
                    correctIndex: correctIndex,
                    explanation: explanationCtrl.text.trim().isEmpty ? null : explanationCtrl.text.trim(),
                    difficulty: difficulty,
                    subject: selectedSubject,
                  );
                  onRefresh();
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur: $e')));
                  }
                }
              },
              child: const Text('Créer', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// Tab 2: Exam Papers — Upload de sujets
// ═══════════════════════════════════════════════════════════════════
class _ExamPapersTab extends StatelessWidget {
  final List<Map<String, dynamic>> papers;
  final TdService service;
  final VoidCallback onRefresh;

  const _ExamPapersTab({required this.papers, required this.service, required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      physics: const BouncingScrollPhysics(),
      children: [
        FadeInDown(
          duration: const Duration(milliseconds: 350),
          child: _ActionCard(
            icon: Icons.upload_file,
            label: 'Ajouter un sujet d\'épreuve',
            color: PrepTheme.coral,
            onTap: () => _showCreatePaperDialog(context),
          ),
        ),
        const SizedBox(height: 16),
        if (papers.isEmpty)
          _EmptyState(icon: Icons.description, message: 'Aucun sujet uploadé')
        else
          ...papers.asMap().entries.map((e) => FadeInUp(
                delay: Duration(milliseconds: 40 * e.key),
                duration: const Duration(milliseconds: 350),
                child: _ExamPaperCard(paper: e.value),
              )),
      ],
    );
  }

  void _showCreatePaperDialog(BuildContext context) {
    final titleCtrl = TextEditingController();
    String? concours;
    String? year;
    String? subject;
    int difficulty = 1;
    bool isOfficial = false;

    showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Nouveau sujet d\'épreuve', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: titleCtrl,
                  decoration: const InputDecoration(labelText: 'Titre *', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: concours,
                  decoration: const InputDecoration(labelText: 'Concours *', border: OutlineInputBorder()),
                  items: ['ENAM', 'ENS', 'ENSET', 'BAC', 'BEPC', 'IRIC']
                      .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                      .toList(),
                  onChanged: (v) => setDialogState(() => concours = v),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: year,
                  decoration: const InputDecoration(labelText: 'Année', border: OutlineInputBorder()),
                  items: ['2025', '2024', '2023', '2022', '2021', '2020']
                      .map((y) => DropdownMenuItem(value: y, child: Text(y)))
                      .toList(),
                  onChanged: (v) => setDialogState(() => year = v),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: subject,
                  decoration: const InputDecoration(labelText: 'Matière', border: OutlineInputBorder()),
                  items: ['Culture Générale', 'Mathématiques', 'Droit', 'Économie', 'Français', 'Physique-Chimie', 'Biologie', 'Histoire-Géo']
                      .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                      .toList(),
                  onChanged: (v) => setDialogState(() => subject = v),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Text('Difficulté: '),
                    ...List.generate(5, (i) => GestureDetector(
                          onTap: () => setDialogState(() => difficulty = i + 1),
                          child: Icon(i < difficulty ? Icons.star : Icons.star_border, color: PrepTheme.accent, size: 24),
                        )),
                  ],
                ),
                const SizedBox(height: 8),
                CheckboxListTile(
                  value: isOfficial,
                  onChanged: (v) => setDialogState(() => isOfficial = v ?? false),
                  title: const Text('Sujet officiel', style: TextStyle(fontSize: 14)),
                  controlAffinity: ListTileControlAffinity.leading,
                  contentPadding: EdgeInsets.zero,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Annuler')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: PrepTheme.coral),
              onPressed: () async {
                if (titleCtrl.text.trim().isEmpty || concours == null) return;
                Navigator.of(ctx).pop();
                try {
                  await service.prepCreateExamPaper(
                    title: titleCtrl.text.trim(),
                    concoursType: concours!,
                    year: year,
                    subject: subject,
                    difficulty: difficulty,
                    isOfficial: isOfficial,
                  );
                  onRefresh();
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur: $e')));
                  }
                }
              },
              child: const Text('Créer', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// Tab 3: Flashcards — Créer des decks et des flashcards
// ═══════════════════════════════════════════════════════════════════
class _FlashcardsTab extends StatelessWidget {
  final List<Map<String, dynamic>> decks;
  final TdService service;
  final VoidCallback onRefresh;

  const _FlashcardsTab({required this.decks, required this.service, required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      physics: const BouncingScrollPhysics(),
      children: [
        FadeInDown(
          duration: const Duration(milliseconds: 350),
          child: _ActionCard(
            icon: Icons.library_add,
            label: 'Nouveau deck de flashcards',
            color: PrepTheme.xpPurple,
            onTap: () => _showCreateDeckDialog(context),
          ),
        ),
        const SizedBox(height: 16),
        Text('${decks.length} deck(s)',
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: PrepTheme.textPrimary)),
        const SizedBox(height: 10),
        if (decks.isEmpty)
          _EmptyState(icon: Icons.style, message: 'Aucun deck de flashcards')
        else
          ...decks.asMap().entries.map((e) => FadeInUp(
                delay: Duration(milliseconds: 40 * e.key),
                duration: const Duration(milliseconds: 350),
                child: _FlashcardDeckCard(
                  deck: e.value,
                  service: service,
                  onRefresh: onRefresh,
                ),
              )),
      ],
    );
  }

  void _showCreateDeckDialog(BuildContext context) {
    final titleCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    String? selectedSubject;
    String? selectedConcours;

    showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Nouveau deck', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: titleCtrl,
                  decoration: const InputDecoration(labelText: 'Titre *', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: descCtrl,
                  decoration: const InputDecoration(labelText: 'Description', border: OutlineInputBorder()),
                  maxLines: 2,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: selectedConcours,
                  decoration: const InputDecoration(labelText: 'Concours', border: OutlineInputBorder()),
                  items: ['ENAM', 'ENS', 'ENSET', 'BAC', 'BEPC', 'IRIC']
                      .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                      .toList(),
                  onChanged: (v) => setDialogState(() => selectedConcours = v),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: selectedSubject,
                  decoration: const InputDecoration(labelText: 'Matière', border: OutlineInputBorder()),
                  items: ['Culture Générale', 'Mathématiques', 'Droit', 'Économie', 'Français', 'Physique-Chimie', 'Biologie', 'Histoire-Géo']
                      .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                      .toList(),
                  onChanged: (v) => setDialogState(() => selectedSubject = v),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Annuler')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: PrepTheme.xpPurple),
              onPressed: () async {
                if (titleCtrl.text.trim().isEmpty) return;
                Navigator.of(ctx).pop();
                try {
                  await service.prepCreateFlashcardDeck(
                    title: titleCtrl.text.trim(),
                    description: descCtrl.text.trim().isEmpty ? null : descCtrl.text.trim(),
                    subject: selectedSubject,
                    concoursType: selectedConcours,
                  );
                  onRefresh();
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur: $e')));
                  }
                }
              },
              child: const Text('Créer', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }
}

class _FlashcardDeckCard extends StatelessWidget {
  final Map<String, dynamic> deck;
  final TdService service;
  final VoidCallback onRefresh;

  const _FlashcardDeckCard({required this.deck, required this.service, required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    final title = deck['title']?.toString() ?? '';
    final subject = deck['subject']?.toString();
    final concoursType = deck['concours_type']?.toString();
    final cardCount = deck['card_count'] as int? ?? 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: PrepTheme.cardBox(),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: PrepTheme.xpPurple.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.style, color: PrepTheme.xpPurple, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Row(
                  children: [
                    if (concoursType != null) ...[
                      PrepTheme.chip(concoursType, PrepTheme.xpPurple),
                      const SizedBox(width: 6),
                    ],
                    if (subject != null) PrepTheme.chip(subject, PrepTheme.primary),
                  ],
                ),
              ],
            ),
          ),
          Text('$cardCount', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: PrepTheme.xpPurple)),
          const SizedBox(width: 4),
          const Icon(Icons.style, color: PrepTheme.textTertiary, size: 16),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.add_circle_outline, size: 20, color: PrepTheme.success),
            tooltip: 'Ajouter une carte',
            onPressed: () => _showAddCardDialog(context),
          ),
        ],
      ),
    );
  }

  void _showAddCardDialog(BuildContext context) {
    final frontCtrl = TextEditingController();
    final backCtrl = TextEditingController();

    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Nouvelle flashcard', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: frontCtrl,
                maxLines: 3,
                decoration: const InputDecoration(labelText: 'Recto (question) *', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: backCtrl,
                maxLines: 3,
                decoration: const InputDecoration(labelText: 'Verso (réponse) *', border: OutlineInputBorder()),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Annuler')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: PrepTheme.success),
            onPressed: () async {
              if (frontCtrl.text.trim().isEmpty || backCtrl.text.trim().isEmpty) return;
              Navigator.of(ctx).pop();
              try {
                await service.prepCreateFlashcard(
                  deckId: deck['id'].toString(),
                  frontText: frontCtrl.text.trim(),
                  backText: backCtrl.text.trim(),
                  subject: deck['subject']?.toString(),
                );
                onRefresh();
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur: $e')));
                }
              }
            },
            child: const Text('Créer', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// Tab 4: Results — Analytics étudiants
// ═══════════════════════════════════════════════════════════════════
class _ResultsTab extends StatefulWidget {
  final TdService service;

  const _ResultsTab({required this.service});

  @override
  State<_ResultsTab> createState() => _ResultsTabState();
}

class _ResultsTabState extends State<_ResultsTab> {
  List<Map<String, dynamic>> _leaderboard = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final lb = await widget.service.prepGetLeaderboard(limit: 20);
      if (!mounted) return;
      setState(() {
        _leaderboard = lb;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: PrepTheme.success));
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      physics: const BouncingScrollPhysics(),
      children: [
        FadeInDown(
          duration: const Duration(milliseconds: 350),
          child: Container(
            padding: const EdgeInsets.all(18),
            decoration: PrepTheme.gradientBox([PrepTheme.success, PrepTheme.successLight], radius: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.leaderboard, color: Colors.white, size: 22),
                    SizedBox(width: 10),
                    Text('Classement étudiants',
                        style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700)),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  '${_leaderboard.length} étudiant(s) actif(s)',
                  style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 12),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        if (_leaderboard.isEmpty)
          _EmptyState(icon: Icons.people, message: 'Aucun étudiant n\'a encore passé de quiz')
        else
          ..._leaderboard.asMap().entries.map((e) {
            final student = e.value;
            final rank = e.key + 1;
            return FadeInUp(
              delay: Duration(milliseconds: 40 * e.key),
              duration: const Duration(milliseconds: 350),
              child: Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(14),
                decoration: PrepTheme.cardBox(),
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: rank <= 3 ? PrepTheme.accentSurface : PrepTheme.shimmer,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Center(
                        child: Text(
                          rank <= 3 ? ['🥇', '🥈', '🥉'][rank - 1] : '#$rank',
                          style: TextStyle(
                            fontSize: rank <= 3 ? 18 : 13,
                            fontWeight: FontWeight.w700,
                            color: PrepTheme.textSecondary,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            student['student_name']?.toString() ?? 'Étudiant',
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                          ),
                          Text(
                            '${student['total_questions_answered'] ?? 0} réponses · ${student['correct_count'] ?? 0} correctes',
                            style: const TextStyle(fontSize: 11, color: PrepTheme.textTertiary),
                          ),
                        ],
                      ),
                    ),
                    PrepTheme.xpBadge((student['total_xp'] as num?)?.toInt() ?? 0),
                  ],
                ),
              ),
            );
          }),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// Shared Widgets
// ═══════════════════════════════════════════════════════════════════
class _ActionCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ActionCard({required this.icon, required this.label, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(PrepTheme.radiusMd),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(width: 10),
            Expanded(
              child: Text(label,
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: color)),
            ),
          ],
        ),
      ),
    );
  }
}

class _BankCard extends StatelessWidget {
  final Map<String, dynamic> bank;

  const _BankCard({required this.bank});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: PrepTheme.cardBox(),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: PrepTheme.primarySurface,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.folder, color: PrepTheme.primary, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(bank['title']?.toString() ?? '',
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Row(
                  children: [
                    if (bank['concours_type'] != null)
                      PrepTheme.chip(bank['concours_type'].toString(), PrepTheme.xpPurple),
                    if (bank['concours_type'] != null) const SizedBox(width: 6),
                    if (bank['subject'] != null)
                      PrepTheme.chip(bank['subject'].toString(), PrepTheme.primary),
                  ],
                ),
              ],
            ),
          ),
          Text(
            '${bank['question_count'] ?? 0}',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: PrepTheme.primary),
          ),
          const SizedBox(width: 4),
          const Icon(Icons.quiz, color: PrepTheme.textTertiary, size: 16),
        ],
      ),
    );
  }
}

class _QuestionCard extends StatelessWidget {
  final Map<String, dynamic> question;

  const _QuestionCard({required this.question});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: PrepTheme.cardBox(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            question['content']?.toString() ?? '',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              if (question['subject'] != null)
                PrepTheme.chip(question['subject'].toString(), PrepTheme.primary),
              const SizedBox(width: 6),
              PrepTheme.chip('Diff. ${question['difficulty'] ?? 1}', PrepTheme.accent),
              const Spacer(),
              Icon(
                question['is_active'] == true ? Icons.check_circle : Icons.cancel,
                size: 16,
                color: question['is_active'] == true ? PrepTheme.success : PrepTheme.danger,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ExamPaperCard extends StatelessWidget {
  final Map<String, dynamic> paper;

  const _ExamPaperCard({required this.paper});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: PrepTheme.cardBox(),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: PrepTheme.coralSurface,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.description, color: PrepTheme.coral, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(paper['title']?.toString() ?? '',
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    if (paper['concours_type'] != null)
                      PrepTheme.chip(paper['concours_type'].toString(), PrepTheme.xpPurple),
                    if (paper['year'] != null)
                      PrepTheme.chip(paper['year'].toString(), PrepTheme.textSecondary),
                    if (paper['is_official'] == true)
                      PrepTheme.chip('Officiel', PrepTheme.success),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String message;

  const _EmptyState({required this.icon, required this.message});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32),
      child: Column(
        children: [
          Icon(icon, size: 40, color: PrepTheme.textTertiary),
          const SizedBox(height: 8),
          Text(message, style: const TextStyle(color: PrepTheme.textTertiary, fontSize: 13)),
        ],
      ),
    );
  }
}
