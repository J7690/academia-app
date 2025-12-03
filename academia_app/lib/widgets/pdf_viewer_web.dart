// ignore_for_file: avoid_web_libraries_in_flutter

import 'dart:html' as html;
import 'dart:ui_web' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

class PdfViewer extends StatefulWidget {
  final String url;

  const PdfViewer({
    super.key,
    required this.url,
  });

  @override
  State<PdfViewer> createState() => _PdfViewerState();
}

class _PdfViewerState extends State<PdfViewer> {
  late final String _viewType;

  @override
  void initState() {
    super.initState();
    assert(kIsWeb, 'PdfViewer should only be used on web.');

    _viewType = 'pdf-viewer-${DateTime.now().microsecondsSinceEpoch}-${widget.url.hashCode}';

    // ignore: undefined_prefixed_name
    ui.platformViewRegistry.registerViewFactory(_viewType, (int viewId) {
      final iframe = html.IFrameElement()
        ..src = widget.url
        ..style.border = 'none'
        ..style.width = '100%'
        ..style.height = '100%';
      return iframe;
    });
  }

  @override
  Widget build(BuildContext context) {
    return HtmlElementView(viewType: _viewType);
  }
}
