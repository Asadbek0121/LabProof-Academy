import 'dart:html' as html;
import 'dart:ui_web' as ui_web;

import 'package:flutter/widgets.dart';

int _pdfViewCounter = 0;

const bool canUseEmbeddedPdfViewer = true;

Widget buildEmbeddedPdfViewer(String url) {
  final viewType = 'labproof-pdf-viewer-${_pdfViewCounter++}-${url.hashCode}';

  ui_web.platformViewRegistry.registerViewFactory(viewType, (int viewId) {
    return html.IFrameElement()
      ..src = url
      ..title = 'PDF viewer'
      ..style.border = '0'
      ..style.width = '100%'
      ..style.height = '100%'
      ..style.backgroundColor = '#f8fafc'
      ..style.display = 'block'
      ..allowFullscreen = true
      ..setAttribute('loading', 'lazy')
      ..setAttribute('referrerpolicy', 'no-referrer-when-downgrade');
  });

  return HtmlElementView(viewType: viewType);
}
