import 'package:flutter/material.dart';

import '../../../utils/responsive.dart';

/// Conteneur de base pour les écrans mobiles étudiants.
///
/// - Applique le fond gris clair global.
/// - Gère SafeArea en haut/bas.
/// - Encapsule un Scaffold pour simplifier la réutilisation.
class StudentMobileScaffold extends StatelessWidget {
  const StudentMobileScaffold({
    super.key,
    this.appBar,
    required this.body,
    this.bottomNavigationBar,
    this.backgroundColor = const Color(0xFFF7F8FA),
  });

  final PreferredSizeWidget? appBar;
  final Widget body;
  final Widget? bottomNavigationBar;
  final Color backgroundColor;

  @override
  Widget build(BuildContext context) {
    // Si on n'est pas en mobile, on ne force pas de comportement spécifique.
    // Les écrans pourront décider plus tard comment utiliser ce scaffold.
    final isMobile = context.isMobile;

    return Scaffold(
      appBar: appBar,
      backgroundColor: backgroundColor,
      body: SafeArea(
        top: true,
        bottom: isMobile,
        child: body,
      ),
      bottomNavigationBar: bottomNavigationBar,
    );
  }
}

/// Helper pour des pages mobiles scrollables avec un padding cohérent.
class StudentMobileScrollablePage extends StatelessWidget {
  const StudentMobileScrollablePage({
    super.key,
    this.appBar,
    required this.children,
    this.bottomNavigationBar,
    this.horizontalPadding = 16,
    this.verticalPadding = 16,
  });

  final PreferredSizeWidget? appBar;
  final List<Widget> children;
  final Widget? bottomNavigationBar;
  final double horizontalPadding;
  final double verticalPadding;

  @override
  Widget build(BuildContext context) {
    return StudentMobileScaffold(
      appBar: appBar,
      bottomNavigationBar: bottomNavigationBar,
      body: SingleChildScrollView(
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: horizontalPadding,
            vertical: verticalPadding,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: children,
          ),
        ),
      ),
    );
  }
}
