import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:pdf_viewer_jk/src/page.dart';
import 'package:path_provider/path_provider.dart';

class PDFDocument {
  static const MethodChannel _channel = const MethodChannel('pdf_viewer_jk');

  String? _filePath;
  int? count;
  List<PDFPage> _pages = [];
  bool _preloaded = false;

  /// Load a PDF File from a given File
  ///
  ///
  static Future<PDFDocument> fromFile(File f) async {
    PDFDocument document = PDFDocument();
    document._filePath = f.path;
    try {
      var pageCount =
          await _channel.invokeMethod('getNumberOfPages', {'filePath': f.path});
      document.count = document.count = int.parse(pageCount);
    } catch (e) {
      throw Exception('Error reading PDF!');
    }
    return document;
  }

  /// Load a PDF File from a given URL.
  /// File is saved in cache
  ///
  static Future<PDFDocument> fromURL(String url, {Map<String, String>? headers}) async {
    // Download into cache
    File f = await DefaultCacheManager().getSingleFile(url, headers: headers);
    PDFDocument document = PDFDocument();
    document._filePath = f.path;
    try {
      var pageCount = await _channel.invokeMethod('getNumberOfPages', {'filePath': f.path});
      document.count = document.count = int.parse(pageCount);
    } catch (e) {
      throw Exception('Error reading PDF!');
    }
    return document;
  }

  /// Load a PDF File from assets folder
  ///
  ///
  static Future<PDFDocument> fromAsset(String asset) async {
    // To open from assets, you can copy them to the app storage folder, and the access them "locally"
    File file;
    try {
      var dir = await getApplicationDocumentsDirectory();
      file = File("${dir.path}/file.pdf");
      var data = await rootBundle.load(asset);
      var bytes = data.buffer.asUint8List();
      await file.writeAsBytes(bytes, flush: true);
    } catch (e) {
      throw Exception('Error parsing asset file!');
    }
    PDFDocument document = PDFDocument();
    document._filePath = file.path;
    try {
      var pageCount = await _channel
          .invokeMethod('getNumberOfPages', {'filePath': file.path});
      document.count = document.count = int.parse(pageCount);
    } catch (e) {
      throw Exception('Error reading PDF!');
    }
    return document;
  }

  /// Load specific page
  ///
  /// [page] defaults to `1` and must be equal or above it
  Future<PDFPage> get({
    int page = 1,
    final Function(double)? onZoomChanged,
    final int? zoomSteps,
    final double? minScale,
    final double? maxScale,
    final double? panLimit,
  }) async {
    assert(page > 0);
    if (_preloaded && _pages.isNotEmpty) return _pages[page - 1];
    var data = await _channel
        .invokeMethod('getPage', {'filePath': _filePath, 'pageNumber': page});
    return new PDFPage(
      data,
      page,
      onZoomChanged: onZoomChanged,
      zoomSteps: zoomSteps,
      minScale: minScale,
      maxScale: maxScale,
      panLimit: panLimit,
    );
  }

  Future<void> preloadPages({
    final Function(double)? onZoomChanged,
    final int? zoomSteps,
    final double? minScale,
    final double? maxScale,
    final double? panLimit,
  }) async {
    int countvar = 1;
    await Future.forEach<int>(List.filled(count!, 0), (i) async {
      final data = await _channel.invokeMethod('getPage', {'filePath': _filePath, 'pageNumber': countvar});
      _pages.add(PDFPage(
        data,
        countvar,
        onZoomChanged: onZoomChanged,
        zoomSteps: zoomSteps,
        minScale: minScale,
        maxScale: maxScale,
        panLimit: panLimit,
      ));
      countvar++;
    });
    _preloaded = true;
  }

  // Stream all pages
  Stream<PDFPage?> getAll({final Function(double)? onZoomChanged}) {
    return Future.forEach<PDFPage?>(List.filled(count!, null), (i) async {
      final data = await _channel.invokeMethod('getPage', {'filePath': _filePath, 'pageNumber': i});
      return new PDFPage(
        data,
        1,
        onZoomChanged: onZoomChanged,
      );
    }).asStream() as Stream<PDFPage?>;
  }
}
