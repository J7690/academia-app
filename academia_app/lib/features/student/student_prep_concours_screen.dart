import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/prep_quiz_provider.dart';
import '../../theme/prep_theme.dart';
import '../share/share_service.dart';
import '../share/share_mode_provider.dart';
import '../share/widgets/share_signature.dart';
import 'prep/prep_home_tab.dart';
import 'prep/prep_quiz_tab.dart';
import 'prep/prep_subjects_tab.dart';
import 'prep/prep_ai_tab.dart';
import 'prep/prep_stats_tab.dart';

/// Écran principal Préparation Concours — 5 onglets dédiés.
/// Affiché dans l'onglet "Concours" (index 6) du dashboard étudiant.
class StudentPrepConcoursScreen extends StatefulWidget {
  const StudentPrepConcoursScreen({super.key});

  @override
  State<StudentPrepConcoursScreen> createState() =>
      _StudentPrepConcoursScreenState();
}

class _StudentPrepConcoursScreenState extends State<StudentPrepConcoursScreen> {
  final GlobalKey _shareBoundaryKey = GlobalKey();
  final ShareService _shareService = ShareService();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<PrepQuizProvider>().loadProgress();
    });
  }

  Future<void> _shareCurrentView() async {
    await _shareService.shareCurrentView(
      context: context,
      boundaryKey: _shareBoundaryKey,
      shareText:
          'Découvert via Academia – Module Préparation Concours de mon espace étudiant.',
    );
  }

  void _openShareOptions() {
    showModalBottomSheet<void>(
      context: context,
      builder: (ctx) {
        return SafeArea(
          child: Wrap(
            children: [
              ListTile(
                leading: const Icon(Icons.web),
                title: const Text('Vue complète Prépa Concours'),
                subtitle: const Text(
                  'Capture tout l\'écran du module Préparation Concours.',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                onTap: () {
                  Navigator.of(ctx).pop();
                  _shareCurrentView();
                },
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 5,
      child: RepaintBoundary(
        key: _shareBoundaryKey,
        child: Stack(
          children: [
            Scaffold(
              backgroundColor: PrepTheme.scaffoldBg,
              appBar: AppBar(
                elevation: 0,
                centerTitle: false,
                title: const Text('Préparation Concours',
                    style:
                        TextStyle(fontWeight: FontWeight.w700, fontSize: 17)),
                foregroundColor: Colors.white,
                flexibleSpace: Container(
                  decoration:
                      PrepTheme.gradientBox(PrepTheme.headerGradient, radius: 0),
                ),
                actions: [
                  Consumer<ShareModeProvider>(
                    builder: (context, shareMode, _) {
                      final isBusy = shareMode.isBusy;
                      return IconButton(
                        icon: const Icon(Icons.share),
                        onPressed: isBusy ? null : _openShareOptions,
                        tooltip: 'Partager',
                      );
                    },
                  ),
                ],
                bottom: const TabBar(
                  isScrollable: true,
                  indicatorColor: Colors.white,
                  indicatorWeight: 3,
                  labelColor: Colors.white,
                  unselectedLabelColor: Colors.white70,
                  labelStyle:
                      TextStyle(fontWeight: FontWeight.w600, fontSize: 11),
                  labelPadding: EdgeInsets.symmetric(horizontal: 12),
                  tabs: [
                    Tab(
                        icon: Icon(Icons.home_outlined, size: 18),
                        text: 'Accueil'),
                    Tab(
                        icon: Icon(Icons.quiz_outlined, size: 18),
                        text: 'Quiz'),
                    Tab(
                        icon: Icon(Icons.description_outlined, size: 18),
                        text: 'Sujets'),
                    Tab(
                        icon: Icon(Icons.auto_awesome_outlined, size: 18),
                        text: 'IA Tutor'),
                    Tab(
                        icon: Icon(Icons.bar_chart_outlined, size: 18),
                        text: 'Stats'),
                  ],
                ),
              ),
              body: const TabBarView(
                children: [
                  PrepHomeTab(),
                  PrepQuizTab(),
                  PrepSubjectsTab(),
                  PrepAiTab(),
                  PrepStatsTab(),
                ],
              ),
            ),
            Positioned(
              right: 16,
              bottom: 16,
              child: IgnorePointer(
                child: Consumer<ShareModeProvider>(
                  builder: (context, shareMode, _) {
                    if (!shareMode.isShareModeEnabled) {
                      return const SizedBox.shrink();
                    }
                    return const ShareSignature();
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
