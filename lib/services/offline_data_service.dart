import 'dart:io';
import 'dart:isolate';

import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:qcf_quran_plus/qcf_quran_plus.dart';

class OfflineDataService {
  OfflineDataService._();

  static final OfflineDataService instance = OfflineDataService._();
  final Map<int, Future<void>> _cacheTasks = <int, Future<void>>{};

  Future<Set<int>> getCachedPages() async {
    final Directory fontDirectory = await _getFontDirectory();
    if (!await fontDirectory.exists()) {
      return <int>{};
    }

    final Set<int> cachedPages = <int>{};
    const int batchSize = 32;
    for (int firstPage = 1; firstPage <= QcfFontLoader.totalPages;) {
      final int lastPage = (firstPage + batchSize - 1).clamp(
        1,
        QcfFontLoader.totalPages,
      );
      final List<Future<void>> checks = <Future<void>>[];
      for (int page = firstPage; page <= lastPage; page++) {
        checks.add(_addIfCached(fontDirectory, page, cachedPages));
      }
      await Future.wait(checks);
      firstPage = lastPage + 1;
    }
    return cachedPages;
  }

  Future<void> cachePage(int page) {
    if (page < 1 || page > QcfFontLoader.totalPages) {
      return Future<void>.error(RangeError('Invalid Quran page: $page'));
    }

    final Future<void>? existingTask = _cacheTasks[page];
    if (existingTask != null) {
      return existingTask;
    }

    final Future<void> task = _cachePage(page);
    _cacheTasks[page] = task;
    return task.whenComplete(() {
      _cacheTasks.remove(page);
    });
  }

  Future<void> _cachePage(int page) async {
    final Directory fontDirectory = await _getFontDirectory();
    await fontDirectory.create(recursive: true);

    final String fontName = QcfFontLoader.getBaseFontFamily(page);
    final File fontFile = File('${fontDirectory.path}/$fontName.ttf');
    if (await _isValidFont(fontFile)) {
      return;
    }

    final ByteData compressedData = await rootBundle.load(
      'packages/qcf_quran_plus/assets/fonts/qcf_tajweed/$fontName.ttf.gz',
    );
    final Uint8List compressedBytes = Uint8List.fromList(
      compressedData.buffer.asUint8List(
        compressedData.offsetInBytes,
        compressedData.lengthInBytes,
      ),
    );
    final String temporaryPath = '${fontFile.path}.tmp';

    await Isolate.run(() {
      final List<int> fontBytes = gzip.decode(compressedBytes);
      File(temporaryPath).writeAsBytesSync(fontBytes, flush: true);
    });

    final File temporaryFile = File(temporaryPath);
    try {
      if (await _isValidFont(fontFile)) {
        await temporaryFile.delete();
        return;
      }
      if (await fontFile.exists()) {
        await fontFile.delete();
      }
      await temporaryFile.rename(fontFile.path);
    } on FileSystemException {
      if (await _isValidFont(fontFile)) {
        if (await temporaryFile.exists()) {
          await temporaryFile.delete();
        }
        return;
      }
      rethrow;
    }
  }

  Future<Directory> _getFontDirectory() async {
    final Directory appDirectory = await getApplicationDocumentsDirectory();
    return Directory('${appDirectory.path}/qcf_fonts');
  }

  Future<void> _addIfCached(
    Directory fontDirectory,
    int page,
    Set<int> cachedPages,
  ) async {
    final File fontFile = File(
      '${fontDirectory.path}/${QcfFontLoader.getBaseFontFamily(page)}.ttf',
    );
    if (await _isValidFont(fontFile)) {
      cachedPages.add(page);
    }
  }

  Future<bool> _isValidFont(File fontFile) async {
    return await fontFile.exists() && await fontFile.length() > 1000;
  }
}
