import 'package:flutter/widgets.dart';

class PdfViewer extends StatelessWidget {
  final String url;

  const PdfViewer({
    super.key,
    required this.url,
  });

  @override
  Widget build(BuildContext context) {
    // Stub pour plateformes non-web : aucune intégration interne.
    return const SizedBox.shrink();
  }
}
